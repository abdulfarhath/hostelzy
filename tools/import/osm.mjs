// F28 28-80: OpenStreetMap (Overpass) → draft hostels.
//   One query for tourism=hostel, amenity=dormitory and building=dormitory in
//   Hyderabad; every named element becomes a draft (status 'draft', source
//   'osm', place_id 'osm:n123' / 'osm:w123' / 'osm:r123') unless its id or its
//   name within 150 m is already there. OSM drafts that the query no longer
//   returns are dropped. Map data © OpenStreetMap contributors (ODbL); the
//   console footer carries the credit.
// Needs SUPABASE_DB_URL only. Never prints it.
import { HYD_BBOX, connect, dropGone, log, phone10, upsertDraft } from './lib.mjs';

const bbox = HYD_BBOX.join(',');
const QUERY = `[out:json][timeout:120];
(
  nwr["tourism"="hostel"](${bbox});
  nwr["amenity"="dormitory"](${bbox});
  nwr["building"="dormitory"](${bbox});
);
out center tags;`;

async function overpass() {
  for (const host of ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter']) {
    try {
      const r = await fetch(host, { method: 'POST', body: 'data=' + encodeURIComponent(QUERY), headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'hostelzy-import (farhath.me/hostelzy)' } });
      if (r.ok) return (await r.json()).elements ?? [];
      log(`Overpass ${new URL(host).host}: ${r.status}`);
    } catch (e) {
      log(`Overpass ${new URL(host).host}: ${e.message}`);
    }
  }
  throw new Error('Overpass did not answer');
}

const client = await connect();
const n = { new: 0, dup: 0, seen: 0, skip: 0, deleted: 0, kept: 0 };
try {
  const elements = await overpass();
  const seenNow = new Set();
  for (const e of elements) {
    const t = e.tags ?? {};
    const name = (t['name:en'] || t.name || '').trim();
    if (!name) { n.skip++; continue; }
    const lat = e.lat ?? e.center?.lat, lng = e.lon ?? e.center?.lon;
    const placeId = `osm:${e.type[0]}${e.id}`;
    seenNow.add(placeId);
    const address = [t['addr:housenumber'], t['addr:street'], t['addr:suburb'] || t['addr:neighbourhood']].filter(Boolean).join(', ');
    n[await upsertDraft(client, { placeId, source: 'osm', name, lat, lng, address, phone: phone10(t.phone || t['contact:phone'] || t['contact:mobile']) })]++;
  }
  // The query succeeded: OSM drafts it no longer returns are gone.
  const old = await client.query("select place_id from public.hostels where source = 'osm' and place_id like 'osm:%'");
  for (const r of old.rows) if (!seenNow.has(r.place_id)) n[await dropGone(client, r.place_id)]++;
  log(`OSM: ${elements.length} elements, ${n.new} new drafts, ${n.dup} matched an existing hostel, ${n.seen} seen again, ${n.skip} unnamed, ${n.deleted} gone drafts deleted, ${n.kept} gone kept (listed or verified).`);
} catch (e) {
  console.error('OSM import stopped:', e.message);
  process.exitCode = 1;
} finally {
  await client.end();
}
