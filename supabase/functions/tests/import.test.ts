import { test } from 'node:test';
import assert from 'node:assert/strict';
// @ts-ignore plain JS module served by GitHub Pages
import { callScript, csv, rentAgeLine, callLaterLabel, claimAddedLine, partnerLine, w3Words, SOURCE_WORDS } from '../../../app/console/logic.js';

test('F28 To call: the 6-line call script names the hostel', () => {
  const s = callScript({ name: 'Sri Balaji PG' });
  assert.equal(s.length, 6);
  assert.match(s[0], /Hostelzy.*Sri Balaji PG/);
  assert.match(s[1], /free/i);
  assert.match(s[2], /rent/i);
  assert.match(s[3], /men, women/i);
  assert.match(s[4], /food/i);
  assert.match(s[5], /verif/i);
  assert.equal(callScript(null).length, 6);
});

test('F28 Export CSV: name, phone, area, id with quoting', () => {
  const out = csv([{ name: 'Sri "Sai" PG, Madhapur', phone: '9876543210', area: 'Madhapur', id: 'h1' }, { name: 'Plain', phone: null, area: 'SR Nagar', id: 'h2' }], ['name', 'phone', 'area', 'id']);
  assert.equal(out, 'name,phone,area,id\r\n"Sri ""Sai"" PG, Madhapur",9876543210,Madhapur,h1\r\nPlain,,SR Nagar,h2\r\n');
  assert.equal(csv([], ['name']), 'name\r\n');
});

test('F28 To refresh / Call later words', () => {
  const now = Date.UTC(2026, 9, 18, 12);
  assert.equal(rentAgeLine(null), 'rent never confirmed');
  assert.equal(rentAgeLine(new Date(now - 55 * 86400000).toISOString(), now), 'rent confirmed 55 days ago');
  assert.equal(rentAgeLine(new Date(now - 86400000).toISOString(), now), 'rent confirmed 1 day ago');
  assert.equal(rentAgeLine(new Date(now).toISOString(), now), 'rent confirmed today');
  assert.equal(callLaterLabel('2026-10-21T10:00:00Z', now), 'Call later · after 21 Oct');
  assert.equal(callLaterLabel('2026-10-10T10:00:00Z', now), '');
  assert.equal(callLaterLabel(null, now), '');
});

test('F28 Claims line: added by … · owner phone matches', () => {
  assert.equal(claimAddedLine({ source: 'resident', adder: 'Ravi', phone_match: true }), 'added by Ravi (resident) · owner phone matches ✓');
  assert.equal(claimAddedLine({ source: 'partner', adder: 'Suresh', phone_match: false }), 'added by Suresh (partner) · owner phone matches ✗');
  assert.equal(claimAddedLine({ source: 'web', adder: 'Lakshmi', phone_match: true }), 'added by Lakshmi (web form) · owner phone matches ✓');
  assert.equal(claimAddedLine({ source: 'places', adder: '', phone_match: false }), 'found on Google Places · owner phone matches ✗');
  assert.equal(claimAddedLine({ source: 'osm', adder: '', phone_match: false }), 'from OpenStreetMap · owner phone matches ✗');
  assert.equal(claimAddedLine({ source: 'team', adder: '', phone_match: true }), 'added by the team · owner phone matches ✓');
  assert.equal(claimAddedLine(null), '');
});

test('F28 Partners line and plain words', () => {
  assert.equal(partnerLine({ listed: 3, due: 60 }), '3 listed · ₹60 due');
  assert.equal(partnerLine({}), '0 listed · ₹0 due');
  assert.equal(SOURCE_WORDS.osm, 'OpenStreetMap');
  assert.equal(w3Words('Could not find the function public.call_list(p_kind) in the schema cache'), 'Needs the F28 SQL.');
  assert.equal(w3Words('ERROR: add the expected rent range'), 'Not done: add the expected rent range.');
  assert.equal(w3Words("this hostel is verified: pause it in Hostels"), 'Not done: pause it in Hostels.');
  assert.equal(w3Words('boom'), 'Couldn’t save: boom');
});
