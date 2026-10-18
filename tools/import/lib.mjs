// F28 wave 3: what places.mjs and osm.mjs share. Node 22, `pg` only.
// Connects with SUPABASE_DB_URL (the same GitHub secret as the SQL autorun);
// never prints it, never prints a key.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
/** ~30 Hyderabad areas: centre + radius (m). */
export const AREAS = JSON.parse(readFileSync(join(here, 'areas.json'), 'utf8'));
/** Hyderabad, roughly: [south, west, north, east]. */
export const HYD_BBOX = [17.25, 78.2, 17.62, 78.7];

export const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Metres between two pins (haversine). */
export function metres(lat1, lng1, lat2, lng2) {
  const R = 6371000, d = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * d) / 2) ** 2 + Math.cos(lat1 * d) * Math.cos(lat2 * d) * Math.sin(((lng2 - lng1) * d) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** The nearest area centre; '' when the pin is outside every circle by more than 3 km. */
export function areaOf(lat, lng) {
  let best = null, bestD = Infinity;
  for (const a of AREAS) {
    const dist = metres(lat, lng, a.lat, a.lng);
    if (dist < bestD) { best = a; bestD = dist; }
  }
  return best && bestD <= best.radius + 3000 ? best.name : '';
}

export const inHyderabad = (lat, lng) => lat >= HYD_BBOX[0] && lat <= HYD_BBOX[2] && lng >= HYD_BBOX[1] && lng <= HYD_BBOX[3];

/** "098765 43210" / "+91 98765-43210" → "9876543210"; '' when it isn't an Indian mobile. */
export function phone10(s) {
  let d = String(s ?? '').replace(/\D/g, '');
  if (d.length === 12 && d.startsWith('91')) d = d.slice(2);
  if (d.length === 11 && d.startsWith('0')) d = d.slice(1);
  return /^[6-9][0-9]{9}$/.test(d) ? d : '';
}

/** "Sri Sai Men's PG" → "srisaimenspg" (for the name-within-150 m check). */
export const normName = (s) => String(s ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');

/** Men / Women / Co-living from the name; the call confirms it. */
export function genderOf(name) {
  const n = String(name ?? '').toLowerCase();
  if (/co.?liv|unisex|co.?ed/.test(n)) return 'Co-living';
  if (/women|ladies|girls|female|mahila/.test(n)) return 'Women';
  return 'Men';
}

/** Does this look like a PG / hostel (and not a hotel, lodge or resort)? */
export function looksLikePg(name, types = []) {
  const n = String(name ?? '').toLowerCase();
  if (/\b(pg|p\.g\.|hostel|paying guest|dormitory|boys|girls|ladies|mens|men's|womens|women's|gents)\b/.test(n)) return true;
  if (/hotel|resort|service apartment|lodge|inn\b|guest house/.test(n)) return false;
  return types.includes('lodging');
}

/** A unique slug for a new hostel row. */
export async function freeSlug(client, name) {
  let base = String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'hostel';
  let slug = base;
  for (;;) {
    const { rows } = await client.query('select 1 from public.hostels where slug = $1', [slug]);
    if (!rows.length) return slug;
    slug = `${base}-${Math.random().toString(36).slice(2, 6)}`;
  }
}

export async function connect() {
  const url = process.env.SUPABASE_DB_URL;
  if (!url) {
    console.log('No database secret yet (SUPABASE_DB_URL): nothing imported.');
    process.exit(0);
  }
  const local = /@(localhost|127\.0\.0\.1)[:/]/.test(url) || process.env.PGSSL === 'disable';
  const client = new pg.Client({ connectionString: url, ssl: local ? false : { rejectUnauthorized: false }, statement_timeout: 60000 });
  await client.connect();
  const { rows } = await client.query("select 1 from information_schema.columns where table_schema = 'public' and table_name = 'hostels' and column_name = 'place_id'");
  if (!rows.length) {
    console.log('The database has no hostels.place_id yet: run the F28 migration first (it ships with the SQL autorun). Nothing imported.');
    await client.end();
    process.exit(0);
  }
  return client;
}

/**
 * One place from Places or OSM → a draft hostel, deduped:
 *  1. by place_id: refresh what we may keep (phone hint on drafts, photos, seen_at);
 *  2. by name within 150 m of an existing hostel: attach the place_id, no new row;
 *  3. else insert a draft (status 'draft', source 'places' | 'osm').
 * Returns 'seen' | 'dup' | 'new' | 'skip'.
 */
export async function upsertDraft(client, p) {
  if (!p.placeId || !p.name || !Number.isFinite(p.lat) || !Number.isFinite(p.lng)) return 'skip';
  if (!inHyderabad(p.lat, p.lng)) return 'skip';
  const photos = (p.photos ?? []).slice(0, 3);
  const seen = await client.query('select id, status, removed_at, owner_phone_hint from public.hostels where place_id = $1', [p.placeId]);
  if (seen.rows.length) {
    const h = seen.rows[0];
    // Google fields are refreshed; a human's edits (name, pin, rent) are never overwritten.
    await client.query(
      `update public.hostels set source_seen_at = now(), source_photos = $2,
         owner_phone_hint = case when status = 'draft' and coalesce(owner_phone_hint, '') = '' then $3 else owner_phone_hint end
       where id = $1`,
      [h.id, photos, p.phone ?? '']);
    return 'seen';
  }
  const near = await client.query(
    `select id, place_id, lat, lng from public.hostels
     where lat is not null and lng is not null and removed_at is null
       and lower(regexp_replace(name, '[^A-Za-z0-9]', '', 'g')) = $1
       and abs(lat - $2) < 0.002 and abs(lng - $3) < 0.002`,
    [normName(p.name), p.lat, p.lng]);
  const dup = near.rows.find((r) => metres(p.lat, p.lng, r.lat ?? p.lat, r.lng ?? p.lng) <= 150) ?? near.rows[0];
  if (dup) {
    if (!dup.place_id) await client.query('update public.hostels set place_id = $2, source_seen_at = now(), source_photos = $3 where id = $1', [dup.id, p.placeId, photos]);
    return 'dup';
  }
  const slug = await freeSlug(client, p.name);
  await client.query(
    `insert into public.hostels (slug, name, gender, area, lat, lng, address, status, source, place_id, owner_phone_hint, source_photos, source_seen_at)
     values ($1, $2, $3, $4, $5, $6, $7, 'draft', $8, $9, $10, $11, now())`,
    [slug, p.name.slice(0, 80), genderOf(p.name), p.area || areaOf(p.lat, p.lng) || 'Hyderabad', p.lat, p.lng, (p.address ?? '').slice(0, 200), p.source, p.placeId, p.phone ?? '', photos]);
  return 'new';
}

/**
 * The place is gone (Google says so, or OSM no longer has it): a draft row is
 * deleted; a listed or live hostel (a human confirmed it) only loses the
 * Google fields.
 */
export async function dropGone(client, placeId) {
  const del = await client.query("delete from public.hostels where place_id = $1 and status = 'draft' and source in ('places', 'osm') returning id", [placeId]);
  if (del.rows.length) return 'deleted';
  await client.query("update public.hostels set source_photos = '{}', source_seen_at = null where place_id = $1", [placeId]);
  return 'kept';
}
