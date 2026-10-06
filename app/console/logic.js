// Team console: pure helpers (tested in supabase/functions/tests/console.test.ts).

export const STAGES = [
  ['lead', 'Lead'],
  ['visited', 'Visited'],
  ['signed_up', 'Signed up'],
  ['data_complete', 'Data complete'],
  ['live', 'Live / trial'],
  ['paying', 'Paying'],
];

/** Onboarding column for a hostel: drafts by their lead stage; live ones by plan. */
export function stageOf(hostel, lead, plan) {
  if (hostel.status === 'live' || hostel.status === 'paused') return plan && (plan.status === 'active' || plan.status === 'overdue') ? 'paying' : 'live';
  return lead?.stage ?? 'lead';
}

/** Kanban columns: [{key, label, cards: [{id, name, area, next}]}]. */
export function columns(hostels, leads, plans) {
  const byId = (rows, k) => Object.fromEntries((rows ?? []).map((r) => [r[k], r]));
  const L = byId(leads, 'hostel_id'), P = byId(plans, 'hostel_id');
  const cols = STAGES.map(([key, label]) => ({ key, label, cards: [] }));
  for (const h of hostels ?? []) {
    const k = stageOf(h, L[h.id], P[h.id]);
    const next = L[h.id]?.next_step || (P[h.id]?.trial_ends && k === 'live' ? `Trial ends ${dayMon(P[h.id].trial_ends)}` : '');
    cols.find((c) => c.key === k).cards.push({ id: h.id, name: h.name, area: h.area, next });
  }
  return cols;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export function dayMon(iso) {
  const d = new Date(iso);
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

/** "402188341297" → "4021 8834 1297". */
export const fmtUtr = (u) => (u ? u.replace(/(\d{4})(?=\d)/g, '$1 ') : '—');

export const rupees = (n) => '₹' + Number(n).toLocaleString('en-IN');

/** Status tag for an invoice: [text, kind] with kind red | solid | neutral. */
export function invoiceTag(inv) {
  if (inv.status === 'paid') return ['Paid', 'neutral'];
  if (inv.status === 'checking') return ['Checking', 'red'];
  if (inv.status === 'missing') return ['Not received', 'red'];
  if (inv.late > 0) return [`${inv.late} days late`, 'solid'];
  return ['Due', 'neutral'];
}

/** Fair Play tabs → case statuses. */
export const CASE_TABS = [
  ['new', 'New'],
  ['waiting', 'Waiting'],
  ['decided', 'Decide'],
  ['closed', 'Closed'],
];

/** F07 / DECISIONS: what strike n means. The server writes the same words. */
export const strikeWords = (n) => (n <= 1 ? 'warning' : n === 2 ? 'deals hidden for 30 days' : 'removed from Hostelzy');

/** The team's strike button: the next strike and what it does. */
export const strikeButton = (n) => (n >= 3 ? 'Removed already' : `Strike ${n + 1} · ${strikeWords(n + 1)}`);

/** A hostel's strikes now, from fair_standing(): strike 2 hides deals for 30 days, then they come back. */
export function standingLine(st, now = Date.now()) {
  if (!st || !st.n) return 'No strikes';
  if (st.removed) return `${st.n} strikes · removed from Hostelzy`;
  if (st.n === 2 && st.hidden_until) {
    return new Date(st.hidden_until).getTime() > now ? `2 strikes · deals hidden until ${dayMon(st.hidden_until)}` : `2 strikes · deals back since ${dayMon(st.hidden_until)}`;
  }
  return `${st.n} ${st.n === 1 ? 'strike' : 'strikes'} · ${strikeWords(st.n)}${st.last_reason === 'fixes' ? ' (3 fixes in 6 months)' : ''}`;
}

/** A tenant report, for the team: what happened, their note, when. */
export const reportLine = (r) => [r.why, r.note ? `“${r.note}”` : null, dayMon(r.created_at)].filter(Boolean).join(' · ');

/** Where the team puts a tenant's photo for a case (the `case-photos` bucket). */
export const casePhotoPath = (hostelId, uid, now = Date.now()) => `${hostelId}/${uid}/tenant-${now}.jpg`;

/** F24 item 14: tenants' "Did you join?" answers for one hostel, in words. */
export function joinSummary(rows) {
  if (!rows.length) return 'No answers yet';
  const n = (a) => rows.filter((r) => r.answer === a).length;
  return [['yes', 'Joined'], ['not_yet', 'Not yet'], ['deciding', 'Still deciding']].filter(([a]) => n(a)).map(([a, l]) => `${l} ${n(a)}`).join(' · ');
}

/** Owner phone for WhatsApp, or null. */
export function waLink(phone, text) {
  const d = String(phone ?? '').replace(/\D/g, '').slice(-10);
  return d.length === 10 ? `https://wa.me/91${d}?text=${encodeURIComponent(text)}` : null;
}

export const slugOf = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) + '-' + Math.random().toString(36).slice(2, 6);

/** F19: whole days a resident's layout fix has waited. */
export function waitedDays(iso, now = Date.now()) {
  return Math.max(0, Math.floor((now - new Date(iso).getTime()) / 86400000));
}

/** F19: owners decide first; after 7 days the team may. [label, tag kind]. */
export function fixStatus(days) {
  return days >= 7 ? ['Owner silent', 'red'] : ['With owner', 'neutral'];
}

const KIND = { fan: 'Fan', ac: 'AC unit', window: 'Window', door: 'Door', wash: 'Washroom', pillar: 'Pillar' };

/** F19: what a fix changes compared with the live layout, in words. */
export function layoutChanges(before, after) {
  const b = before ?? { w: 0, h: 0, beds: {}, items: [] };
  const out = [];
  for (const i of after.items ?? []) {
    const o = (b.items ?? []).find((x) => x.id === i.id);
    const name = KIND[i.kind] ?? i.kind;
    if (!o) out.push(`${name} added`);
    else if (o.x !== i.x || o.y !== i.y || o.w !== i.w || o.h !== i.h) out.push(`${name} moved`);
    else if ((o.working ?? true) !== (i.working ?? true)) out.push(`${name} ${i.working === false ? 'not working' : 'working again'}`);
  }
  for (const o of b.items ?? []) if (!(after.items ?? []).some((x) => x.id === o.id)) out.push(`${KIND[o.kind] ?? o.kind} taken off`);
  for (const [k, p] of Object.entries(after.beds ?? {})) {
    const q = (b.beds ?? {})[k];
    if (!q || q[0] !== p[0] || q[1] !== p[1]) out.push(`Bed ${k} moved`);
  }
  if (b.w !== after.w || b.h !== after.h) out.push(`Size ${Math.round(b.w)} × ${Math.round(b.h)} → ${Math.round(after.w)} × ${Math.round(after.h)} ft`);
  return out;
}

// F19 extras: a quick fix in one line ("Broken: AC unit").
export function quickLine(f) {
  const what = { broken: 'Broken', missing: 'Missing', not_here: 'Not in this room', wrong_place: 'Wrong place' }[f.issue] ?? 'Quick fix';
  return `${what}: ${f.item ?? 'an item'}`;
}

// F24 item 11: room shapes (same presets as the app's shapeOutline in data.dart).
export const SHAPES = ['Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom'];

/** A preset shape's walls in a w × h ft room, [[x, y], …]; null for a rectangle or Custom. */
export function shapeOutline(shape, w, h) {
  const r = (v) => Math.round(v * 2) / 2;
  const m = Math.min(w, h) * 0.35;
  switch (shape) {
    case 'L shape': return [[0, 0], [r(w * 0.55), 0], [r(w * 0.55), r(h * 0.45)], [w, r(h * 0.45)], [w, h], [0, h]];
    case 'T shape': return [[0, 0], [w, 0], [w, r(h * 0.45)], [r(w * 0.8), r(h * 0.45)], [r(w * 0.8), h], [r(w * 0.2), h], [r(w * 0.2), r(h * 0.45)], [0, r(h * 0.45)]];
    case 'U shape': return [[0, 0], [r(w * 0.3), 0], [r(w * 0.3), r(h * 0.4)], [r(w * 0.7), r(h * 0.4)], [r(w * 0.7), 0], [w, 0], [w, h], [0, h]];
    case 'Angled corner': return [[0, 0], [r(w - m), 0], [w, r(m)], [w, h], [0, h]];
    case 'Narrow end': return [[0, 0], [w, 0], [r(w * 0.78), h], [r(w * 0.22), h]];
    case 'Alcove': return [[0, 0], [w, 0], [w, h], [r(w * 0.62), h], [r(w * 0.62), r(h - 2.5)], [r(w * 0.38), r(h - 2.5)], [r(w * 0.38), h], [0, h]];
    default: return null;
  }
}

/** "0,0 14,0 14,8 10,12 0,12" (typed by the team) → [[x, y], …] inside w × h, or null when it isn't one. */
export function parsePoints(text, w, h) {
  const pts = String(text ?? '').trim().split(/\s+/).filter(Boolean).map((p) => p.split(',').map(Number));
  if (pts.length < 3 || pts.length > 40) return null;
  if (pts.some((p) => p.length !== 2 || p.some((v) => !Number.isFinite(v)) || p[0] < 0 || p[0] > w || p[1] < 0 || p[1] > h)) return null;
  return pts;
}

/** Hours left until [dueIso]: "22 h left", "Due now", or "Late 5 h". */
export function hoursLeft(dueIso, now = Date.now()) {
  const h = Math.ceil((new Date(dueIso).getTime() - now) / 3600000);
  if (h > 0) return `${h} h left`;
  return h === 0 ? 'Due now' : `Late ${-h} h`;
}

/** Layout help status: [label, tag kind]. */
export function helpStatus(req, now = Date.now()) {
  if (req.status === 'sent') return ['With owner', 'neutral'];
  if (req.status === 'published') return ['Published', 'neutral'];
  if (new Date(req.due_at).getTime() < now) return ['Late', 'red'];
  return req.status === 'drawing' ? ['Drawing', 'solid'] : ['New', 'red'];
}

/** F24 Wave 4c: why go_live() said no, in the team's words. */
export function goLiveWords(message) {
  const m = String(message || '');
  for (const k of ['add at least one room', 'add a price for', 'link the owner', 'add 8 photos', 'drop the map pin', 'only the Hostelzy team']) {
    const i = m.indexOf(k);
    if (i >= 0) {
      const w = m.slice(i).split(/[\n}]/)[0].trim().replace(/\.$/, '');
      return `Not live yet: ${w}.`;
    }
  }
  return 'Couldn’t put it live. Check your internet and try again.';
}

/** F26 #21: a listed (UNVERIFIED) hostel's expected rent range: '' when fine, else what to fix (the server checks the same). */
export function rentRangeError(min, max) {
  const a = Number(min), b = Number(max);
  if (!Number.isInteger(a) || !Number.isInteger(b) || a < 1000 || b > 100000) return 'Enter the expected rent, ₹1,000 to ₹1,00,000.';
  if (b < a) return 'The highest rent can’t be below the lowest.';
  return '';
}

/** "Around ₹7,000–9,000", as the app shows it. */
export const rentRangeLabel = (min, max) => (Number(max) > Number(min) ? `Around ${rupees(min)}–${Number(max).toLocaleString('en-IN')}` : `Around ${rupees(min)}`);

/** F26 #21: a listed hostel's photo in the hostel-photos bucket (the app's layout: <hostel>/<random>.jpg). */
export const listedPhotoPath = (hostelId, now = Date.now(), rnd = Math.random()) => `${hostelId}/${now.toString(36)}${Math.floor(rnd * 1e8).toString(36)}.jpg`;

/** F26 #21: why list_hostel() said no, in plain words. */
export function listWords(message) {
  const m = String(message || '');
  for (const k of ['add a photo first', 'add the expected rent range', 'add the hostel name', 'already verified', 'isn’t in Hyderabad', 'isn\'t in Hyderabad', 'only the Hostelzy team']) {
    if (m.includes(k)) return `Not listed: ${k === 'isn\'t in Hyderabad' || k === 'isn’t in Hyderabad' ? 'the map pin isn’t in Hyderabad' : k}.`;
  }
  return 'Couldn’t save: ' + m;
}
