import { test } from 'node:test';
import assert from 'node:assert/strict';
// @ts-ignore plain JS module served by GitHub Pages
import { columns, fmtUtr, invoiceTag, waLink, rupees, goLiveWords } from '../../../app/console/logic.js';

test('onboarding columns: drafts by lead stage, live by plan', () => {
  const cols = columns(
    [
      { id: 'a', name: 'Sri Sai PG', area: 'SR Nagar', status: 'draft' },
      { id: 'b', name: 'Greenview', area: 'Kondapur', status: 'draft' },
      { id: 'c', name: 'Anjani', area: 'Madhapur', status: 'live' },
      { id: 'd', name: 'Annex', area: 'Kondapur', status: 'live' },
    ],
    [{ hostel_id: 'b', stage: 'visited', next_step: 'Owner decides Fri' }],
    [{ hostel_id: 'c', status: 'trial', trial_ends: '2026-11-02' }, { hostel_id: 'd', status: 'active' }],
  );
  const by = Object.fromEntries(cols.map((c: { key: string; cards: { name: string; next: string }[] }) => [c.key, c.cards.map((x) => `${x.name}|${x.next}`)]));
  assert.deepEqual(by, { lead: ['Sri Sai PG|'], visited: ['Greenview|Owner decides Fri'], signed_up: [], data_complete: [], live: ['Anjani|Trial ends 2 Nov'], paying: ['Annex|'] });
});

test('payments helpers', () => {
  assert.equal(fmtUtr('402188341297'), '4021 8834 1297');
  assert.equal(fmtUtr(null), '—');
  assert.deepEqual(invoiceTag({ status: 'checking', late: 0 }), ['Checking', 'red']);
  assert.deepEqual(invoiceTag({ status: 'due', late: 15 }), ['15 days late', 'solid']);
  assert.deepEqual(invoiceTag({ status: 'paid', late: 0 }), ['Paid', 'neutral']);
  assert.equal(waLink('+91 90000 00007', 'Hi'), 'https://wa.me/919000000007?text=Hi');
  assert.equal(waLink('', 'Hi'), null);
  assert.equal(rupees(999), '₹999');
});

test('layout fixes: days waited, owner silent after 7, what changed', async () => {
  // @ts-ignore plain JS module
  const { waitedDays, fixStatus, layoutChanges } = await import('../../../app/console/logic.js');
  const now = Date.parse('2026-10-10T12:00:00Z');
  assert.equal(waitedDays('2026-10-01T10:00:00Z', now), 9);
  assert.deepEqual(fixStatus(9), ['Owner silent', 'red']);
  assert.deepEqual(fixStatus(2), ['With owner', 'neutral']);
  const before = { w: 18, h: 15, beds: { A: [1, 1], B: [5, 1] }, items: [{ id: 'fan1', kind: 'fan', x: 8, y: 7, w: 1, h: 1 }, { id: 'ac1', kind: 'ac', x: 17, y: 6, w: 0.5, h: 1.8 }] };
  const after = { w: 18, h: 16, beds: { A: [1, 1], B: [6, 1] }, items: [{ id: 'fan1', kind: 'fan', x: 2, y: 7, w: 1, h: 1 }, { id: 'ac1', kind: 'ac', x: 17, y: 6, w: 0.5, h: 1.8, working: false }, { id: 'window1', kind: 'window', x: 0, y: 0, w: 4, h: 0.3 }] };
  assert.deepEqual(layoutChanges(before, after), ['Fan moved', 'AC unit not working', 'Window added', 'Bed B moved', 'Size 18 × 15 → 18 × 16 ft']);
  assert.deepEqual(layoutChanges(null, { w: 10, h: 10, beds: {}, items: [] }), ['Size 0 × 0 → 10 × 10 ft']);
  const { quickLine } = await import('../../../app/console/logic.js');
  assert.equal(quickLine({ issue: 'broken', item: 'AC unit' }), 'Broken: AC unit');
  assert.equal(quickLine({ issue: 'not_here', item: 'Fan' }), 'Not in this room: Fan');
});

test('layout help: shapes, typed walls, hours left, status', async () => {
  // @ts-ignore plain JS module
  const { shapeOutline, parsePoints, hoursLeft, helpStatus, SHAPES } = await import('../../../app/console/logic.js');
  assert.equal(SHAPES.length, 8);
  assert.deepEqual(shapeOutline('L shape', 14, 12), [[0, 0], [7.5, 0], [7.5, 5.5], [14, 5.5], [14, 12], [0, 12]]);
  assert.equal(shapeOutline('Rectangle', 14, 12), null);
  assert.equal(shapeOutline('Custom', 14, 12), null);
  assert.deepEqual(parsePoints('0,0 14,0  14,8 10,12 0,12', 14, 12), [[0, 0], [14, 0], [14, 8], [10, 12], [0, 12]]);
  assert.equal(parsePoints('0,0 20,0 0,12', 14, 12), null);
  assert.equal(parsePoints('0,0 1,1', 14, 12), null);
  const now = Date.parse('2026-10-03T12:00:00Z');
  assert.equal(hoursLeft('2026-10-04T10:00:00Z', now), '22 h left');
  assert.equal(hoursLeft('2026-10-03T07:00:00Z', now), 'Late 5 h');
  assert.deepEqual(helpStatus({ status: 'requested', due_at: '2026-10-04T10:00:00Z' }, now), ['New', 'red']);
  assert.deepEqual(helpStatus({ status: 'drawing', due_at: '2026-10-04T10:00:00Z' }, now), ['Drawing', 'solid']);
  assert.deepEqual(helpStatus({ status: 'drawing', due_at: '2026-10-03T10:00:00Z' }, now), ['Late', 'red']);
  assert.deepEqual(helpStatus({ status: 'sent', due_at: '2026-10-03T10:00:00Z' }, now), ['With owner', 'neutral']);
});

test('F24 item 14: "Did you join?" answers in words', async () => {
  // @ts-ignore plain JS module
  const { joinSummary } = await import('../../../app/console/logic.js');
  assert.equal(joinSummary([]), 'No answers yet');
  assert.equal(joinSummary([{ answer: 'yes' }, { answer: 'deciding' }, { answer: 'yes' }, { answer: 'not_yet' }]), 'Joined 2 · Not yet 1 · Still deciding 1');
});

test('F24 item 18: strike words, standing and tenant reports', async () => {
  // @ts-ignore plain JS module
  const { strikeWords, strikeButton, standingLine, reportLine, casePhotoPath } = await import('../../../app/console/logic.js');
  assert.deepEqual([1, 2, 3].map(strikeWords), ['warning', 'deals hidden for 30 days', 'removed from Hostelzy']);
  assert.equal(strikeButton(0), 'Strike 1 · warning');
  assert.equal(strikeButton(1), 'Strike 2 · deals hidden for 30 days');
  assert.equal(strikeButton(2), 'Strike 3 · removed from Hostelzy');
  assert.equal(strikeButton(3), 'Removed already');
  const now = Date.parse('2026-10-20T00:00:00Z');
  assert.equal(standingLine(undefined, now), 'No strikes');
  assert.equal(standingLine({ n: 1, last_reason: 'fixes' }, now), '1 strike · warning (3 fixes in 6 months)');
  assert.equal(standingLine({ n: 2, hidden_until: '2026-11-02T10:00:00Z' }, now), '2 strikes · deals hidden until 2 Nov');
  assert.equal(standingLine({ n: 2, hidden_until: '2026-10-02T10:00:00Z' }, now), '2 strikes · deals back since 2 Oct');
  assert.equal(standingLine({ n: 3, removed: true }, now), '3 strikes · removed from Hostelzy');
  assert.equal(reportLine({ why: 'Asked to pay without the app', note: 'Said ₹500 less', created_at: '2026-10-03T06:00:00Z' }), 'Asked to pay without the app · “Said ₹500 less” · 3 Oct');
  assert.equal(reportLine({ why: 'Something else', note: '', created_at: '2026-10-03T06:00:00Z' }), 'Something else · 3 Oct');
  assert.equal(casePhotoPath('h1', 'fb-team', 42), 'h1/fb-team/tenant-42.jpg');
});

test('Go live goes through go_live(): the server reason in plain words', () => {
  assert.equal(goLiveWords('add 8 photos first'), 'Not live yet: add 8 photos first.');
  assert.equal(goLiveWords('PostgrestError: drop the map pin at the gate'), 'Not live yet: drop the map pin at the gate.');
  assert.equal(goLiveWords('add a price for 3 sharing AC'), 'Not live yet: add a price for 3 sharing AC.');
  assert.equal(goLiveWords('fetch failed'), 'Couldn’t put it live. Check your internet and try again.');
});
