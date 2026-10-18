import { test } from 'node:test';
import assert from 'node:assert/strict';
// @ts-ignore plain JS module run by the founder on a laptop
import { LIMITS, chatId, cleanPhone, gapMs, limitHit, message, msUntilHourSlot, onReply, parseArgs, parseCsv, pending } from '../../../tools/outreach/lib.mjs';

test('F28 28-60: the message is word for word, with the STOP line', () => {
  assert.equal(
    message('Farhath', 'Sri Balaji Men’s PG'),
    'Hi, this is Farhath from Hostelzy, a free app where tenants find PGs in Hyderabad. Sri Balaji Men’s PG is listed as unverified. Reply 1 to add your rent and get verified, 2 to remove it. – Hostelzy\nReply STOP to never hear from us',
  );
});

test('F28 28-60: the console CSV parses; phones are cleaned; bad rows are dropped', () => {
  const csv = 'name,phone,area,id\n"Balaji, Sri PG","+91 98765 43210",Madhapur,h1\nNo phone,,Kondapur,h2\nOld style,09123456789,Ameerpet,h3\nLandline,04012345678,Begumpet,h4\n';
  assert.deepEqual(parseCsv(csv), [
    { name: 'Balaji, Sri PG', phone: '9876543210', area: 'Madhapur', id: 'h1' },
    { name: 'Old style', phone: '9123456789', area: 'Ameerpet', id: 'h3' },
  ]);
  assert.equal(cleanPhone('919876543210'), '9876543210');
  assert.equal(cleanPhone('1234567890'), '');
  assert.equal(chatId('9876543210'), '919876543210@c.us');
  assert.deepEqual(parseCsv(''), []);
});

test('F28 28-60: random gaps stay inside 60–180 s', () => {
  assert.equal(gapMs(0), 60000);
  assert.equal(gapMs(0.5), 120000);
  assert.ok(gapMs(0.999999) <= 180000);
  for (let i = 0; i < 50; i++) {
    const g = gapMs();
    assert.ok(g >= 60000 && g <= 180000);
  }
});

test('F28 28-60: 25 an hour, 150 a day; the hour slot frees when the oldest send ages out', () => {
  const now = Date.parse('2026-10-18T12:00:00Z');
  const at = (minAgo: number) => new Date(now - minAgo * 60000).toISOString();
  const sent: Record<string, { at?: string; hostel: string }> = {};
  for (let i = 0; i < LIMITS.perHour - 1; i++) sent[`90000000${String(i).padStart(2, '0')}`] = { at: at(i + 1), hostel: 'x' };
  assert.equal(limitHit(sent, now), '');
  sent['9000000099'] = { at: at(50), hostel: 'y' };
  assert.equal(limitHit(sent, now), 'hour');
  assert.equal(msUntilHourSlot(sent, now), 10 * 60000 + 1000);
  const day: Record<string, { at?: string; hostel: string }> = {};
  for (let i = 0; i < LIMITS.perDay; i++) day[`91000000${String(i).padStart(2, '0')}`] = { at: at(70 + i), hostel: 'z' };
  assert.equal(limitHit(day, now), 'day');
  assert.equal(limitHit({ a: { at: at(25 * 60), hostel: 'old' } }, now), '');
});

test('F28 28-60: never twice; a reply stops the run and STOP is final', () => {
  const rows = [
    { name: 'A', phone: '9876543210', area: '', id: '1' },
    { name: 'B', phone: '9876543211', area: '', id: '2' },
    { name: 'A again', phone: '9876543210', area: '', id: '3' },
  ];
  const sent: Record<string, { at?: string; hostel: string; replied?: string; reply?: string; stop?: boolean; skipped?: string }> = {
    '9876543211': { hostel: 'B', skipped: 'not on WhatsApp' },
  };
  assert.deepEqual(pending(rows, sent).map((r) => r.phone), ['9876543210']);
  assert.equal(onReply(sent, '9999999999', 'hi'), null);
  sent['9876543210'] = { at: '2026-10-18T12:00:00Z', hostel: 'A' };
  const e = onReply(sent, '9876543210', ' Stop. ', Date.parse('2026-10-18T12:05:00Z'));
  assert.equal(e?.stop, true);
  assert.equal(e?.replied, '2026-10-18T12:05:00.000Z');
  assert.equal(onReply(sent, '9876543210', '1')?.stop, true);
  assert.deepEqual(pending(rows, sent), []);
});

test('F28 28-60: command line flags', () => {
  assert.deepEqual(parseArgs(['--csv', 'x.csv', '--name', 'Farhath', '--dry']), { csv: 'x.csv', name: 'Farhath', dry: true });
  assert.deepEqual(parseArgs([]), {});
});
