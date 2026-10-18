// node --test test.mjs   (pure helpers always; the database part when
// SUPABASE_DB_URL points at a test database with the migrations applied)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { AREAS, areaOf, genderOf, inHyderabad, looksLikePg, metres, normName, phone10, upsertDraft, dropGone } from './lib.mjs';

test('areas: ~30 Hyderabad centres, each with a radius', () => {
  assert.ok(AREAS.length >= 25);
  for (const a of AREAS) assert.ok(a.name && inHyderabad(a.lat, a.lng) && a.radius >= 800 && a.radius <= 3000, a.name);
  assert.equal(areaOf(17.4483, 78.3915), 'Madhapur');
  assert.equal(areaOf(17.0, 78.0), '');
});

test('phone10, normName, genderOf, looksLikePg, metres', () => {
  assert.equal(phone10('098765 43210'), '9876543210');
  assert.equal(phone10('+91 98765-43210'), '9876543210');
  assert.equal(phone10('040 2345 6789'), '');
  assert.equal(normName("Sri Sai Men's PG"), 'srisaimenspg');
  assert.equal(genderOf('Lakshmi Ladies Hostel'), 'Women');
  assert.equal(genderOf('Sai Co-living'), 'Co-living');
  assert.equal(genderOf('Sri Balaji PG'), 'Men');
  assert.equal(looksLikePg('Sri Balaji PG', []), true);
  assert.equal(looksLikePg('Taj Hotel', ['lodging']), false);
  assert.equal(looksLikePg('Sunrise Residency', ['lodging']), true);
  assert.equal(looksLikePg('Sunrise Bakery', ['bakery']), false);
  assert.ok(Math.abs(metres(17.4, 78.4, 17.4, 78.401) - 106) < 2);
});

test('database: dedupe by place_id and by name within 150 m; gone drafts are dropped', { skip: !process.env.SUPABASE_DB_URL }, async () => {
  const { connect } = await import('./lib.mjs');
  const c = await connect();
  try {
    await c.query("delete from public.hostels where place_id like 'test:%' or slug like 'w3-test%'");
    const p = { placeId: 'test:1', source: 'places', name: 'W3 Test PG', lat: 17.4483, lng: 78.3915, phone: '9876543210', photos: ['places/x/photos/a', 'b', 'c', 'd'] };
    assert.equal(await upsertDraft(c, p), 'new');
    assert.equal(await upsertDraft(c, p), 'seen');
    const row = (await c.query("select * from public.hostels where place_id = 'test:1'")).rows[0];
    assert.equal(row.status, 'draft'); assert.equal(row.source, 'places'); assert.equal(row.area, 'Madhapur');
    assert.equal(row.owner_phone_hint, '9876543210'); assert.equal(row.source_photos.length, 3); assert.equal(row.gender, 'Men');
    // the same name 100 m away (OSM) attaches to the same row, no second draft
    assert.equal(await upsertDraft(c, { placeId: 'test:2', source: 'osm', name: 'w3 test p.g.', lat: 17.4492, lng: 78.3915 }), 'dup');
    assert.equal((await c.query("select count(*)::int as n from public.hostels where lower(name) like 'w3 test%'")).rows[0].n, 1);
    // 400 m away is another hostel
    assert.equal(await upsertDraft(c, { placeId: 'test:3', source: 'osm', name: 'W3 Test PG', lat: 17.452, lng: 78.3915 }), 'new');
    // outside Hyderabad: skipped
    assert.equal(await upsertDraft(c, { placeId: 'test:4', source: 'osm', name: 'W3 Test Far', lat: 12.9, lng: 77.6 }), 'skip');
    // gone: a draft is deleted, a listed one keeps its row
    assert.equal(await dropGone(c, 'test:3'), 'deleted');
    // only the team changes a status (guard_hostel): act as the team for this one line
    await c.query(`select set_config('request.jwt.claims', '{"sub":"w3","role":"authenticated","iss":"https://securetoken.google.com/hostelzy","aud":"hostelzy","team":true}', false)`);
    await c.query("update public.hostels set status = 'listed', rent_min = 7000, rent_max = 8000 where place_id = 'test:1'");
    await c.query("select set_config('request.jwt.claims', '', false)");
    assert.equal(await dropGone(c, 'test:1'), 'kept');
    assert.equal((await c.query("select source_seen_at from public.hostels where place_id = 'test:1'")).rows[0].source_seen_at, null);
    await c.query("delete from public.hostels where place_id like 'test:%'");
  } finally {
    await c.end();
  }
});
