// F28 28-20: Google Places API (New) → draft hostels.
//   For each area in areas.json, Text Search for 4 PG / hostel terms, biased
//   to the area's circle; each result becomes a draft (status 'draft', source
//   'places') unless its place_id or its name within 150 m is already there.
//   Rows not seen this run and older than 30 days are re-fetched (Place
//   Details): gone or closed for good → dropped. Only place_id is kept for
//   ever; name, pin, phone, photos are Google's and refreshed within 30 days.
// Needs GOOGLE_PLACES_KEY (founder one-time GitHub secret) and SUPABASE_DB_URL.
// Without the key it prints "No key yet" and exits 0. Never prints either.
//   IMPORT_PAGES   pages per search (20 results each), default 2
//   IMPORT_AREAS   comma-separated area names to limit a run (default: all)
import { AREAS, connect, dropGone, log, looksLikePg, phone10, sleep, upsertDraft } from './lib.mjs';

const KEY = process.env.GOOGLE_PLACES_KEY;
if (!KEY) {
  console.log('No key yet (GOOGLE_PLACES_KEY): the Google Places import is skipped. FOUNDER-TODO has the one-time step.');
  process.exit(0);
}
const TERMS = ['PG hostel', 'paying guest', 'hostel for men', 'hostel for women'];
const PAGES = Math.max(1, Math.min(3, Number(process.env.IMPORT_PAGES) || 2));
const ONLY = (process.env.IMPORT_AREAS ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
const FIELDS = 'id,displayName,formattedAddress,location,nationalPhoneNumber,internationalPhoneNumber,photos,businessStatus,types';

async function google(path, init) {
  const r = await fetch(`https://places.googleapis.com/v1/${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': KEY, ...(init.headers ?? {}) },
  });
  if (r.status === 404) return null;
  if (r.status === 429) { await sleep(5000); return google(path, init); }
  if (!r.ok) throw new Error(`Places ${path.split('/')[0]} ${r.status}`);
  return r.json();
}

async function* search(area, term) {
  let pageToken;
  for (let page = 0; page < PAGES; page++) {
    const body = {
      textQuery: `${term} in ${area.name}, Hyderabad`,
      locationBias: { circle: { center: { latitude: area.lat, longitude: area.lng }, radius: area.radius } },
      languageCode: 'en', regionCode: 'IN', pageSize: 20, ...(pageToken ? { pageToken } : {}),
    };
    const res = await google('places:searchText', {
      method: 'POST', body: JSON.stringify(body),
      headers: { 'X-Goog-FieldMask': ['places.' + FIELDS.split(',').join(',places.'), 'nextPageToken'].join(',') },
    });
    for (const p of res?.places ?? []) yield p;
    pageToken = res?.nextPageToken;
    if (!pageToken) return;
    await sleep(300);
  }
}

const toDraft = (p, area) => ({
  placeId: p.id, source: 'places',
  name: p.displayName?.text ?? '',
  lat: p.location?.latitude, lng: p.location?.longitude,
  area,
  address: p.formattedAddress ?? '',
  phone: phone10(p.nationalPhoneNumber || p.internationalPhoneNumber),
  photos: (p.photos ?? []).map((ph) => ph.name).filter(Boolean).slice(0, 3),
});

const client = await connect();
const seenNow = new Set();
const n = { new: 0, dup: 0, seen: 0, skip: 0, closed: 0, refreshed: 0, deleted: 0, kept: 0 };
try {
  for (const area of AREAS) {
    if (ONLY.length && !ONLY.includes(area.name.toLowerCase())) continue;
    let found = 0;
    for (const term of TERMS) {
      for await (const p of search(area, term)) {
        if (!p.id || seenNow.has(p.id)) continue;
        seenNow.add(p.id);
        if (p.businessStatus === 'CLOSED_PERMANENTLY') { n.closed++; continue; }
        if (!looksLikePg(p.displayName?.text, p.types ?? [])) { n.skip++; continue; }
        const r = await upsertDraft(client, toDraft(p, area.name));
        n[r]++;
        found++;
      }
      await sleep(200);
    }
    log(`${area.name}: ${found} places`);
  }

  // Refresh what this run didn't see and is older than 30 days; drop the gone.
  const stale = await client.query(
    `select id, place_id, area from public.hostels where source = 'places' and place_id is not null
       and (source_seen_at is null or source_seen_at < now() - interval '30 days')`);
  for (const h of stale.rows) {
    if (seenNow.has(h.place_id)) continue;
    const p = await google(`places/${encodeURIComponent(h.place_id)}`, { method: 'GET', headers: { 'X-Goog-FieldMask': FIELDS } });
    if (!p || p.businessStatus === 'CLOSED_PERMANENTLY') { n[await dropGone(client, h.place_id)]++; continue; }
    await upsertDraft(client, toDraft(p, h.area));
    n.refreshed++;
    await sleep(100);
  }
  log(`Places: ${n.new} new drafts, ${n.dup} matched an existing hostel, ${n.seen} seen again, ${n.skip} not a PG, ${n.closed} closed, ` +
      `${n.refreshed} refreshed, ${n.deleted} gone drafts deleted, ${n.kept} gone places kept (listed or verified).`);
} catch (e) {
  console.error('Places import stopped:', e.message);
  process.exitCode = 1;
} finally {
  await client.end();
}
