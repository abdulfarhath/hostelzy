// Hostelzy team console (design boards 19–22). Google sign-in with Firebase;
// only accounts with the `team` claim get in. Data comes from Supabase with
// the same Row Level Security as the app: is_team() opens the team's rows.
import { firebaseConfig, supabaseUrl, supabaseAnonKey, hostelzyUpi } from './config.js';
import { columns, fmtUtr, invoiceTag, waLink, rupees, CASE_TABS, slugOf, dayMon, waitedDays, fixStatus, layoutChanges } from './logic.js';

const app = document.getElementById('app');

/** Tiny DOM builder: el('div', {class: 'x', onclick}, 'text', child…). Text is never parsed as HTML. */
function el(tag, attrs = {}, ...kids) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v == null || v === false) continue;
    if (k.startsWith('on')) n.addEventListener(k.slice(2), v);
    else if (k === 'class') n.className = v;
    else n.setAttribute(k, v === true ? '' : v);
  }
  for (const k of kids.flat()) if (k != null && k !== false) n.append(k instanceof Node ? k : String(k));
  return n;
}
const mount = (...n) => app.replaceChildren(...n);
function toast(msg) {
  const t = el('div', { class: 'toast' }, msg);
  document.body.append(t);
  setTimeout(() => t.remove(), 3000);
}
const word = () => el('span', { class: 'word' }, 'hostelzy ', el('b', {}, 'team'));

if (!firebaseConfig) {
  mount(el('div', { class: 'signin' }, el('div', { class: 'card' }, word(), el('h1', {}, 'Team console'),
    el('p', { class: 'mu' }, 'Not set up yet. The founder adds the Firebase web app config (docs/FOUNDER-TODO.md), then this page works.'))));
} else {
  start().catch((e) => mount(el('p', { class: 'pad' }, 'Couldn’t start: ' + e.message)));
}

async function start() {
  const [{ initializeApp }, fa, { createClient }] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js'),
    import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'),
  ]);
  const auth = fa.getAuth(initializeApp(firebaseConfig));
  const db = createClient(supabaseUrl, supabaseAnonKey, { accessToken: async () => (auth.currentUser ? auth.currentUser.getIdToken() : null) });

  const signInView = (msg) => mount(el('div', { class: 'signin' }, el('div', { class: 'card' },
    word(),
    el('h1', { style: 'font-size:30px;margin:0' }, 'Team console'),
    el('p', { class: 'mu', style: 'margin:0' }, 'Onboarding, payments, Fair Play and layout help. Only Hostelzy team Google accounts can sign in.'),
    el('button', { class: 'google', onclick: () => fa.signInWithPopup(auth, new fa.GoogleAuthProvider()).catch((e) => toast(e.code === 'auth/popup-closed-by-user' ? 'Sign-in cancelled.' : 'Couldn’t sign in: ' + e.code)) },
      el('span', { class: 'g' }, 'G'), 'Continue with Google'),
    el('p', { class: 'mu', style: 'margin:0;font-size:12px' }, msg ?? 'Not on the team? Use the Hostelzy app instead.'))));

  fa.onAuthStateChanged(auth, async (u) => {
    if (!u) return signInView();
    const claims = (await u.getIdTokenResult(true)).claims;
    if (claims.team !== true) {
      await fa.signOut(auth);
      return signInView(`${u.email} isn’t a Hostelzy team account. Ask the founder to add it.`);
    }
    shell(u, db, () => fa.signOut(auth));
  });
}

const NAV = [
  ['onboarding', 'Onboarding'],
  ['payments', 'Payments'],
  ['cases', 'Fair Play'],
  ['layout', 'Layout help'],
  ['rewards', 'Rewards'],
  ['fixes', 'Layout fixes'],
  ['hostels', 'Hostels'],
];

function shell(user, db, out) {
  const render = async () => {
    const view = (location.hash.slice(1) || 'onboarding');
    const main = el('main', { class: 'main' }, el('p', { class: 'pad mu' }, 'Loading…'));
    mount(
      el('header', { class: 'top' }, word(), el('span', { class: 'sp' }), el('span', { class: 'who' }, `${user.email} · Team`), el('button', { class: 'btn', onclick: out }, 'Sign out')),
      el('div', { class: 'shell' }, el('aside', { class: 'side' }, NAV.map(([k, l]) => el('a', { href: '#' + k, class: k === view ? 'on' : '' }, l))), main),
    );
    try {
      const v = await VIEWS[view]?.(db, render);
      main.replaceChildren(...(v ?? [el('p', { class: 'pad' }, 'Not found.')]));
    } catch (e) {
      main.replaceChildren(el('p', { class: 'pad' }, 'Couldn’t load: ' + (e.message ?? e)));
    }
  };
  window.onhashchange = render;
  render();
}

const ok = ({ data, error }) => {
  if (error) throw new Error(error.message);
  return data;
};

const VIEWS = {
  async onboarding(db, again) {
    const [hostels, leads, plans] = await Promise.all([
      db.from('hostels').select('id, name, area, status').order('created_at').then(ok),
      db.from('hostel_leads').select().then(ok),
      db.from('owner_plans').select().then(ok),
    ]);
    const cols = columns(hostels, leads, plans);
    const live = cols.find((c) => c.key === 'live').cards.length + cols.find((c) => c.key === 'paying').cards.length;
    const next = { lead: 'visited', visited: 'signed_up', signed_up: 'data_complete' };
    const advance = async (card, key) => {
      const to = next[key];
      if (!to || !confirm(`Move ${card.name} to “${cols.find((c) => c.key === to).label}”?`)) return;
      ok(await db.from('hostel_leads').upsert({ hostel_id: card.id, stage: to, updated_at: new Date().toISOString() }));
      again();
    };
    const f = { name: '', phone: '', area: 'Ameerpet', gender: 'Men', visit: '' };
    const seg = (opts, k) => el('div', { class: 'seg' }, opts.map((o) => el('button', { class: f[k] === o ? 'on' : '', onclick: (e) => { f[k] = o; [...e.target.parentNode.children].forEach((b) => b.classList.toggle('on', b === e.target)); } }, o)));
    const create = async () => {
      if (f.name.trim().length < 3) return toast('Enter the hostel’s name.');
      if (f.phone.replace(/\D/g, '').length < 10) return toast('Enter the owner’s 10-digit phone.');
      const h = ok(await db.from('hostels').insert({ slug: slugOf(f.name), name: f.name.trim(), gender: f.gender, area: f.area, status: 'draft' }).select('id').single());
      ok(await db.from('hostel_leads').insert({ hostel_id: h.id, owner_phone: f.phone.replace(/\D/g, '').slice(-10), visit_on: f.visit ? new Date(f.visit).toISOString() : null, stage: 'lead', next_step: f.visit ? `Visit ${dayMon(new Date(f.visit).toISOString())}` : '' }));
      toast(`${f.name.trim()} added as a draft.`);
      again();
    };
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Onboarding'), el('span', {}, el('b', {}, `Live ${live} of ${hostels.length}`))),
      el('div', { class: 'board' },
        el('div', { class: 'kanban' }, cols.map((c) => el('div', { class: 'col' }, el('div', { class: 'kick' }, `${c.label} · ${c.cards.length}`),
          c.cards.map((x) => el('button', { class: 'kcard', title: next[c.key] ? 'Move to the next stage' : '', onclick: () => advance(x, c.key) }, el('b', {}, x.name), el('span', { class: 'a' }, x.area), x.next ? el('span', { class: 'n' }, 'Next: ' + x.next) : null))))),
        el('aside', { class: 'add' },
          el('h2', {}, 'Add hostel'),
          el('label', {}, 'Hostel name'), el('input', { oninput: (e) => (f.name = e.target.value), placeholder: 'Vasavi Boys Hostel' }),
          el('label', {}, 'Owner’s phone'), el('input', { oninput: (e) => (f.phone = e.target.value), inputmode: 'tel', placeholder: '+91 90000 00007' }),
          el('label', {}, 'Area'), seg(['Ameerpet', 'SR Nagar', 'Madhapur'], 'area'),
          el('label', {}, 'For'), seg(['Men', 'Women', 'Co-living'], 'gender'),
          el('label', {}, 'Visit on'), el('input', { type: 'datetime-local', oninput: (e) => (f.visit = e.target.value) }),
          el('button', { class: 'btn primary cta', onclick: create }, 'Create draft hostel', '✓'),
          el('p', { class: 'mu', style: 'font-size:12px;margin:0' }, 'The rest (rooms, rates, photos, residents) is done on the visit, in the app’s team mode.'))),
    ];
  },

  async payments(db, again) {
    const [invs, leads] = await Promise.all([
      db.from('invoices').select('*, hostels(name)').order('due', { ascending: false }).then(ok),
      db.from('hostel_leads').select('hostel_id, owner_phone').then(ok),
    ]);
    const phone = Object.fromEntries(leads.map((l) => [l.hostel_id, l.owner_phone]));
    const set = async (i, status) => {
      ok(await db.from('invoices').update({ status }).eq('id', i.id));
      toast(status === 'paid' ? `${i.ref} marked paid.` : `${i.ref}: not received. The owner is asked to check the UTR.`);
      again();
    };
    const row = (i) => {
      const [t, kind] = invoiceTag(i);
      const wa = waLink(phone[i.hostel_id], `Hi, your Hostelzy invoice ${i.ref} (${rupees(i.amount)}) is due. Pay to ${hostelzyUpi} and send the UTR in the app.`);
      return el('div', { class: 'tr' + (i.status === 'checking' ? ' hi' : '') },
        el('div', {}, `${i.hostels?.name ?? ''} · ${i.beds} beds`), el('div', {}, i.ref), el('div', {}, rupees(i.amount)), el('div', {}, fmtUtr(i.utr)),
        el('div', {}, `Due ${dayMon(i.due)}`), el('div', {}, el('span', { class: 'tag ' + kind }, t)),
        el('div', {}, i.status === 'checking'
          ? [el('button', { class: 'btn sm primary', onclick: () => set(i, 'paid') }, 'Mark paid ✓'), el('button', { class: 'btn sm', onclick: () => set(i, 'missing') }, 'Not received')]
          : i.status === 'paid' ? el('span', { class: 'mu', style: 'font-size:13px' }, 'Paid')
          : wa ? el('a', { class: 'btn sm', href: wa, target: '_blank', rel: 'noopener' }, 'Remind on WhatsApp') : el('span', { class: 'mu', style: 'font-size:13px' }, 'No owner phone')));
    };
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Owner payments'), el('span', { class: 'mu', style: 'font-size:13px' }, `Pay to ${hostelzyUpi} · match every UTR in the bank app. Never trust screenshots.`)),
      el('div', { class: 'table' }, el('div', { class: 'tr head' }, ['Hostel', 'Invoice', 'Amount', 'UTR', 'Due', 'Status', 'Action'].map((h) => el('div', {}, h))),
        invs.length ? invs.map(row) : el('p', { class: 'empty' }, 'No invoices yet. They start when a hostel’s 30-day trial ends.')),
    ];
  },

  async cases(db, again) {
    const tab = sessionStorage.getItem('hzCaseTab') || 'new';
    const cases = await db.from('fair_cases').select('*, hostels(name)').order('created_at', { ascending: false }).then(ok);
    const counts = Object.fromEntries(CASE_TABS.map(([k]) => [k, cases.filter((c) => c.status === k).length]));
    const shown = cases.filter((c) => c.status === tab);
    let sel = shown[0];
    const list = el('div', { class: 'list' });
    const draw = () => list.replaceChildren(...(shown.length ? shown.map((c) => el('button', { class: 'row' + (c === sel ? ' hi' : ''), onclick: () => { sel = c; draw(); } },
      el('span', { class: 't' }, `${c.ref} · ${c.hostels?.name ?? ''}`, el('span', { class: 'tag ' + (c.status === 'decided' ? 'red' : 'neutral') }, CASE_TABS.find(([k]) => k === c.status)[1])),
      el('span', { class: 's' }, c.signal))) : [el('p', { class: 'empty' }, 'Nothing here.')]));
    draw();
    const act = async (what) => {
      if (!sel) return;
      if (what === 'close') ok(await db.from('fair_cases').update({ status: 'closed', decision: 'No issue' }).eq('id', sel.id));
      if (what === 'ask') ok(await db.from('fair_cases').update({ status: 'waiting' }).eq('id', sel.id));
      if (what === 'strike') {
        ok(await db.from('strikes').insert({ hostel_id: sel.hostel_id, case_id: sel.id }));
        ok(await db.from('fair_cases').update({ status: 'decided', decision: 'Strike · warning' }).eq('id', sel.id));
      }
      toast('Saved.');
      again();
    };
    return [el('div', { class: 'split' },
      el('section', {},
        el('h2', {}, 'Fair Play cases'),
        el('div', { class: 'seg', style: 'margin:0 16px 10px' }, CASE_TABS.map(([k, l]) => el('button', { class: k === tab ? 'on' : '', onclick: () => { sessionStorage.setItem('hzCaseTab', k); again(); } }, counts[k] ? `${l} ${counts[k]}` : l))),
        list,
        el('div', { class: 'acts' },
          el('button', { class: 'btn full', onclick: () => act('close') }, 'Close · no issue', '✓'),
          el('button', { class: 'btn full', onclick: () => act('ask') }, 'Ask for more', '…'),
          el('button', { class: 'btn full primary', onclick: () => act('strike') }, 'Strike · warning', '⚑'))),
      el('section', {},
        el('div', { style: 'display:flex;justify-content:space-between;align-items:baseline;padding-right:16px' }, el('h2', {}, 'Layout help queue'), el('span', { class: 'mu', style: 'font-size:13px' }, 'Owners who asked us to draw')),
        el('div', { class: 'list' }, el('p', { class: 'empty' }, 'Owners ask for layout help on WhatsApp for now; requests show here once the app sends them.')),
        el('p', { class: 'note' }, 'Owners publish their own layouts. We draw only when asked; the owner then publishes it.')))];
  },

  async layout(db, again) {
    return VIEWS.cases(db, again);
  },

  // S6: the Stay Rewards ledger (append-only). The team can reverse an entry;
  // a reversal is a new row, never an edit.
  async rewards(db, again) {
    const rows = await db.from('reward_ledger').select('*, hostels(name)').order('created_at', { ascending: false }).limit(200).then(ok);
    const reversed = new Set(rows.filter((r) => r.reverses).map((r) => r.reverses));
    const reverse = async (r) => {
      const why = prompt('Why reverse this? (kept in the ledger)');
      if (!why) return;
      ok(await db.rpc('reverse_reward', { p_id: r.id, p_why: why }));
      toast('Reversed. A new ledger row records it.');
      again();
    };
    const who = (r) => r.hostels?.name ? `Owner · ${r.hostels.name}` : `Tenant · ${r.user_id ?? '—'}`;
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Stay Rewards'), el('span', { class: 'mu', style: 'font-size:13px' }, 'Every grant, spend and reversal. Only the server grants; nothing is ever edited or deleted.')),
      el('div', { class: 'table' }, el('div', { class: 'tr head' }, ['When', 'Who', 'What', 'Amount', 'Reason', ''].map((h) => el('div', {}, h))),
        rows.length ? rows.map((r) => el('div', { class: 'tr' },
          el('div', {}, dayMon(r.created_at)), el('div', {}, who(r)), el('div', {}, r.kind.replace('_', ' ')),
          el('div', {}, (r.amount > 0 ? '+' : '−') + rupees(Math.abs(r.amount))), el('div', {}, r.reason),
          el('div', {}, r.kind === 'reversal' ? el('span', { class: 'mu', style: 'font-size:13px' }, 'Reversal')
            : reversed.has(r.id) ? el('span', { class: 'tag neutral' }, 'Reversed')
            : el('button', { class: 'btn sm', onclick: () => reverse(r) }, 'Reverse')))) : el('p', { class: 'empty' }, 'No rewards yet. They start when a tenant’s first Hostelzy stay is confirmed.')),
    ];
  },

  // F19 board 12: residents' layout fixes, oldest first. Owners decide
  // first; after 7 days the team can approve or reject.
  async fixes(db, again) {
    const [fixes, leads] = await Promise.all([
      db.from('layout_fixes').select('*, hostels(name, owner_name)').eq('status', 'pending').order('created_at').then(ok),
      db.from('hostel_leads').select('hostel_id, owner_phone').then(ok),
    ]);
    const phone = Object.fromEntries(leads.map((l) => [l.hostel_id, l.owner_phone]));
    const silent = fixes.filter((f) => waitedDays(f.created_at) >= 7).length;
    let sel = fixes[0];
    const detail = el('section', { class: 'add' });
    const decide = async (f, approve) => {
      const reason = approve ? '' : (prompt('Why? (optional, the resident sees it)') ?? null);
      if (reason === null) return;
      ok(await db.rpc('decide_layout_fix', { p_id: f.id, p_approve: approve, p_reason: reason }));
      toast(approve ? 'Published. The resident is told.' : 'Rejected. The current layout stays live.');
      again();
    };
    const drawDetail = async () => {
      if (!sel) return detail.replaceChildren(el('p', { class: 'empty' }, 'No layout fixes waiting.'));
      const days = waitedDays(sel.created_at);
      const owner = sel.hostels?.owner_name || 'The owner';
      const live = await db.from('layouts').select('w, h, beds, items').eq('hostel_id', sel.hostel_id).eq('room', sel.room).eq('stage', 'published').maybeSingle().then(ok);
      const changes = layoutChanges(live, sel.layout);
      const wa = waLink(phone[sel.hostel_id], `Hi ${owner}, a resident sent a layout fix for room ${sel.room} ${days} days ago. Please approve or reject it in the Hostelzy app → Today.`);
      detail.replaceChildren(
        el('h2', {}, `${sel.hostels?.name ?? ''} · Room ${sel.room}`),
        el('p', { class: 'mu', style: 'margin:0' }, days >= 7 ? `${owner} hasn’t answered in ${days} days. The team can decide now.` : `With ${owner} for ${days} ${days === 1 ? 'day' : 'days'}. Owners decide first.`),
        el('div', { class: 'kick' }, `${changes.length} ${changes.length === 1 ? 'change' : 'changes'}`),
        el('ul', {}, changes.map((c) => el('li', {}, c))),
        sel.note ? el('p', {}, `“${sel.note}”`) : null,
        el('p', { class: 'mu', style: 'font-size:12px;margin:0' }, `${sel.author_name}${sel.author_bed ? ' · lives in ' + sel.author_bed : ''}`),
        el('button', { class: 'btn primary cta', disabled: days < 7, onclick: () => decide(sel, true) }, 'Approve & publish', '✓'),
        el('button', { class: 'btn full', disabled: days < 7, onclick: () => decide(sel, false) }, 'Reject'),
        wa ? el('a', { class: 'btn full', href: wa, target: '_blank', rel: 'noopener' }, `Remind ${owner} on WhatsApp`) : null,
        el('p', { class: 'note' }, 'Owners decide first. After 7 days the team can approve or reject. The resident’s name is shown only to the owner and the team.'),
      );
    };
    const row = (f) => {
      const days = waitedDays(f.created_at);
      const [t, kind] = fixStatus(days);
      return el('button', { class: 'tr' + (f === sel ? ' hi' : ''), onclick: () => { sel = f; drawDetail(); } },
        el('div', {}, f.hostels?.name ?? ''), el('div', {}, String(f.room)), el('div', {}, `${f.author_name}${f.author_bed ? ' · lives in ' + f.author_bed : ''}`),
        el('div', {}, f.note ? `“${f.note}”` : '—'), el('div', {}, `${days} ${days === 1 ? 'day' : 'days'}`), el('div', {}, el('span', { class: 'tag ' + kind }, t)));
    };
    drawDetail();
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Layout fixes'), el('span', { class: 'mu', style: 'font-size:13px' }, `From residents · oldest first${silent ? ` · ${silent} waiting over 7 days` : ''}`)),
      el('div', { class: 'board' },
        el('div', { class: 'table' }, el('div', { class: 'tr head' }, ['Hostel', 'Room', 'From', 'Note', 'Waiting', 'Status'].map((h) => el('div', {}, h))),
          fixes.length ? fixes.map(row) : el('p', { class: 'empty' }, 'No layout fixes waiting.')),
        detail),
    ];
  },

  async hostels(db, again) {
    const hs = await db.from('hostels').select('id, name, area, gender, status').order('name').then(ok);
    const set = async (h, status) => {
      if (!confirm(`${status === 'live' ? 'Put' : 'Take'} ${h.name} ${status === 'live' ? 'live for tenants' : 'off Explore'}?`)) return;
      ok(await db.from('hostels').update({ status }).eq('id', h.id));
      again();
    };
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Hostels'), el('span', { class: 'mu', style: 'font-size:13px' }, `${hs.length} in Hostelzy`)),
      el('div', { class: 'list', style: 'margin:0 24px' }, hs.map((h) => el('div', { class: 'row' },
        el('span', { class: 't' }, `${h.name} · ${h.area}`, el('span', { class: 'tag ' + (h.status === 'live' ? 'solid' : 'neutral') }, h.status)),
        el('span', { class: 's' }, h.gender, ' · ',
          h.status === 'live' ? el('button', { class: 'btn sm', onclick: () => set(h, 'paused') }, 'Pause') : el('button', { class: 'btn sm primary', onclick: () => set(h, 'live') }, 'Go live'))))),
    ];
  },
};
