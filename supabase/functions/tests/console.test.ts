import { test } from 'node:test';
import assert from 'node:assert/strict';
// @ts-ignore plain JS module served by GitHub Pages
import { columns, fmtUtr, invoiceTag, waLink, rupees } from '../../../app/console/logic.js';

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
