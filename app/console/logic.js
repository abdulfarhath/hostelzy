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

/** Owner phone for WhatsApp, or null. */
export function waLink(phone, text) {
  const d = String(phone ?? '').replace(/\D/g, '').slice(-10);
  return d.length === 10 ? `https://wa.me/91${d}?text=${encodeURIComponent(text)}` : null;
}

export const slugOf = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) + '-' + Math.random().toString(36).slice(2, 6);
