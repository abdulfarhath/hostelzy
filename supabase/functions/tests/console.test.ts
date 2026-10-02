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
