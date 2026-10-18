// Hostelzy outreach (F28 28-60): the pure parts of the founder's WhatsApp sender.
// No network, no files, no WhatsApp here, so `node --test` can check every rule.
// The runner is send.mjs; the limits and the ban risk are in README.md.

export const LIMITS = { perHour: 25, perDay: 150, gapMinS: 60, gapMaxS: 180 };

/** One CSV line → fields; quotes and doubled quotes as in a spreadsheet export. */
export function splitCsvLine(line) {
  const out = [];
  let cur = '';
  let q = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) {
      if (c === '"' && line[i + 1] === '"') { cur += '"'; i++; }
      else if (c === '"') q = false;
      else cur += c;
    } else if (c === '"') q = true;
    else if (c === ',') { out.push(cur); cur = ''; }
    else cur += c;
  }
  out.push(cur);
  return out;
}

/** "+91 98765 43210", "09876543210", "9876543210" → "9876543210"; anything else → ''. */
export function cleanPhone(s) {
  let d = String(s ?? '').replace(/\D/g, '');
  if (d.length === 12 && d.startsWith('91')) d = d.slice(2);
  if (d.length === 11 && d.startsWith('0')) d = d.slice(1);
  return /^[6-9]\d{9}$/.test(d) ? d : '';
}

/** The console's "Export CSV" (columns name, phone, area, id, any order). Rows without a valid phone are dropped. */
export function parseCsv(text) {
  const lines = String(text ?? '').replace(/\r/g, '').split('\n').filter((l) => l.trim());
  if (lines.length < 2) return [];
  const head = splitCsvLine(lines[0]).map((h) => h.trim().toLowerCase());
  const col = (f, k) => (head.indexOf(k) < 0 ? '' : (f[head.indexOf(k)] ?? '')).trim();
  const rows = [];
  for (const line of lines.slice(1)) {
    const f = splitCsvLine(line);
    const phone = cleanPhone(col(f, 'phone'));
    if (!phone) continue;
    rows.push({ name: col(f, 'name'), phone, area: col(f, 'area'), id: col(f, 'id') });
  }
  return rows;
}

/** WhatsApp id for an Indian mobile number. */
export const chatId = (phone) => `91${phone}@c.us`;

/** The one message, word for word (F28 28-60), with the STOP line. */
export function message(founder, hostel) {
  return `Hi, this is ${founder} from Hostelzy, a free app where tenants find PGs in Hyderabad. ${hostel} is listed as unverified. Reply 1 to add your rent and get verified, 2 to remove it. – Hostelzy\nReply STOP to never hear from us`;
}

/** A random gap of 60–180 s, in ms. [rand] is 0 ≤ r < 1 (injectable for tests). */
export function gapMs(rand = Math.random()) {
  return Math.round((LIMITS.gapMinS + rand * (LIMITS.gapMaxS - LIMITS.gapMinS)) * 1000);
}

/** sent.json: { "<phone>": { at: ISO (sent), hostel, replied?: ISO, reply?, stop?: true, skipped?, checkedAt? } } */
export function countSince(sent, now, ms) {
  return Object.values(sent).filter((e) => e.at && now - Date.parse(e.at) < ms).length;
}

/** Why the next message can't go now: '' (go), 'hour' (25 in the last hour), 'day' (150 in the last 24 h). */
export function limitHit(sent, now = Date.now()) {
  if (countSince(sent, now, 24 * 3600e3) >= LIMITS.perDay) return 'day';
  if (countSince(sent, now, 3600e3) >= LIMITS.perHour) return 'hour';
  return '';
}

/** ms until the oldest send inside the last hour ages out (a slot frees); 0 when no wait is needed. */
export function msUntilHourSlot(sent, now = Date.now()) {
  const ages = Object.values(sent).map((e) => (e.at ? now - Date.parse(e.at) : Infinity)).filter((a) => a >= 0 && a < 3600e3);
  if (ages.length < LIMITS.perHour) return 0;
  return 3600e3 - Math.max(...ages) + 1000;
}

/** Rows still to message: not in sent.json (sent, skipped or stopped), one per phone. */
export function pending(rows, sent) {
  const seen = new Set();
  return rows.filter((r) => {
    if (sent[r.phone] || seen.has(r.phone)) return false;
    seen.add(r.phone);
    return true;
  });
}

/** A reply from a number we messaged: recorded, and "STOP" (alone, any case) marks it never again. Null = not ours. */
export function onReply(sent, phone, body, now = Date.now()) {
  const e = sent[phone];
  if (!e) return null;
  e.replied = new Date(now).toISOString();
  e.reply = String(body ?? '').slice(0, 200);
  if (/^\s*stop\s*[.!]?\s*$/i.test(e.reply)) e.stop = true;
  return e;
}

/** --csv x --name "Y" --dry → { csv: 'x', name: 'Y', dry: true } */
export function parseArgs(argv) {
  const a = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (!k.startsWith('--')) continue;
    const key = k.slice(2);
    const v = argv[i + 1];
    if (v === undefined || v.startsWith('--')) a[key] = true;
    else { a[key] = v; i++; }
  }
  return a;
}
