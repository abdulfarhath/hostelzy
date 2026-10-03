// Hostelzy team console (design boards 19–22). Google sign-in with Firebase;
// only accounts with the `team` claim get in. Data comes from Supabase with
// the same Row Level Security as the app: is_team() opens the team's rows.
import { firebaseConfig, supabaseUrl, supabaseAnonKey, hostelzyUpi } from './config.js';
import { columns, fmtUtr, invoiceTag, waLink, rupees, CASE_TABS, slugOf, dayMon, waitedDays, fixStatus, layoutChanges, quickLine, SHAPES, shapeOutline, parsePoints, hoursLeft, helpStatus, joinSummary } from './logic.js';

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
/** The same for SVG (the Layout help drawing). */
function svg(tag, attrs = {}) {
  const n = document.createElementNS('http://www.w3.org/2000/svg', tag);
  for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, String(v));
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
  ['reviews', 'Reported reviews'],
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
    // F24 item 14: tenants' "Did you join?" answers (90 days); empty before SQL 4zy3 runs.
    const since = new Date(Date.now() - 90 * 86400000).toISOString();
    const joins = await db.from('join_answers').select('hostel_id, answer, updated_at').gte('updated_at', since).then(({ data }) => data ?? []);
    const joined = el('p', { class: 'note' });
    const counts = Object.fromEntries(CASE_TABS.map(([k]) => [k, cases.filter((c) => c.status === k).length]));
    const shown = cases.filter((c) => c.status === tab);
    let sel = shown[0];
    const list = el('div', { class: 'list' });
    let draw = () => list.replaceChildren(...(shown.length ? shown.map((c) => el('button', { class: 'row' + (c === sel ? ' hi' : ''), onclick: () => { sel = c; draw(); } },
      el('span', { class: 't' }, `${c.ref} · ${c.hostels?.name ?? ''}`, el('span', { class: 'tag ' + (c.status === 'decided' ? 'red' : 'neutral') }, CASE_TABS.find(([k]) => k === c.status)[1])),
      el('span', { class: 's' }, c.signal))) : [el('p', { class: 'empty' }, 'Nothing here.')]));
    const drawJoined = () => joined.replaceChildren(...(sel ? [el('b', {}, `Did you join? · ${sel.hostels?.name ?? ''}`), ` · tenants whose hold ended, last 90 days: ${joinSummary(joins.filter((j) => j.hostel_id === sel.hostel_id))}. Only the team sees these.`] : []));
    const pick = draw;
    draw = () => { pick(); drawJoined(); };
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
        joined,
        el('div', { class: 'acts' },
          el('button', { class: 'btn full', onclick: () => act('close') }, 'Close · no issue', '✓'),
          el('button', { class: 'btn full', onclick: () => act('ask') }, 'Ask for more', '…'),
          el('button', { class: 'btn full primary', onclick: () => act('strike') }, 'Strike · warning', '⚑'))),
      el('section', {},
        el('h2', {}, 'Layout help'),
        el('p', { class: 'note' }, 'Owners draw and publish their own layouts. When one asks us to draw a room, it shows in Layout help, due within 48 hours.'),
        el('div', { style: 'padding:0 16px' }, el('a', { class: 'btn', href: '#layout' }, 'Open Layout help ›'))))];
  },

  // F24 board cLayoutHelp: owners who asked Hostelzy to draw a room. Oldest
  // due first; done within 48 hours. The team draws the room's walls here
  // (a preset shape at W × L, or typed corner points for a custom room) and
  // sends it to the owner, whose app places the beds inside and publishes.
  async layout(db, again) {
    const reqs = await db.from('shape_requests').select('*, hostels(name, owner_name)').in('status', ['requested', 'drawing', 'sent']).order('due_at').then(ok);
    const open = reqs.filter((r) => r.status !== 'sent').length;
    let sel = reqs[0];
    const detail = el('section', { class: 'add' });
    const editor = async (q) => {
      // "Open in layout editor": the walls, drawn on a 1-ft grid.
      if (q.status === 'requested') {
        ok(await db.rpc('start_shape_request', { p_id: q.id }));
        q.status = 'drawing';
        drawRows();
      }
      const d = { shape: q.drawing?.shape ?? q.shape, w: q.drawing?.w ?? (q.w || 14), h: q.drawing?.h ?? (q.h || 12), pts: (q.drawing?.outline ?? []).map((p) => p.join(',')).join(' ') };
      const preview = el('div', { class: 'shapeprev' });
      const walls = () => (d.shape === 'Custom' ? parsePoints(d.pts, d.w, d.h) : shapeOutline(d.shape, d.w, d.h));
      const draw = () => {
        const k = Math.min(300 / d.w, 220 / d.h);
        const o = walls() ?? (d.shape === 'Custom' ? null : [[0, 0], [d.w, 0], [d.w, d.h], [0, d.h]]);
        const s = svg('svg', { width: d.w * k + 4, height: d.h * k + 4, viewBox: `-2 -2 ${d.w * k + 4} ${d.h * k + 4}`, role: 'img', 'aria-label': `${d.shape}, ${d.w} by ${d.h} feet` });
        for (let x = 1; x < d.w; x++) s.append(svg('line', { x1: x * k, y1: 0, x2: x * k, y2: d.h * k, stroke: 'var(--hl)' }));
        for (let y = 1; y < d.h; y++) s.append(svg('line', { x1: 0, y1: y * k, x2: d.w * k, y2: y * k, stroke: 'var(--hl)' }));
        if (o) s.append(svg('polygon', { points: o.map(([x, y]) => `${x * k},${y * k}`).join(' '), fill: 'none', stroke: 'var(--tx)', 'stroke-width': 2 }));
        preview.replaceChildren(s, o ? '' : el('p', { class: 'mu', style: 'margin:0;font-size:12px' }, 'Type the corners clockwise from the top-left, in feet: 0,0 14,0 14,8 10,12 0,12'));
      };
      const num = (k) => el('input', { inputmode: 'numeric', value: String(d[k]), oninput: (e) => { d[k] = Math.max(6, Math.min(60, Number(e.target.value) || 0)); draw(); } });
      const seg = el('div', { class: 'seg', style: 'grid-auto-flow:row;grid-template-columns:repeat(4,1fr)' }, SHAPES.map((sh) => el('button', { class: d.shape === sh ? 'on' : '', onclick: (e) => { d.shape = sh; [...seg.children].forEach((b) => b.classList.toggle('on', b === e.target)); pts.style.display = sh === 'Custom' ? '' : 'none'; draw(); } }, sh)));
      const pts = el('input', { value: d.pts, placeholder: '0,0 14,0 14,8 10,12 0,12', style: d.shape === 'Custom' ? '' : 'display:none', oninput: (e) => { d.pts = e.target.value; draw(); } });
      const send = async () => {
        const o = walls();
        if (d.shape === 'Custom' && !o) return toast('Type at least 3 corners inside the room.');
        ok(await db.rpc('send_shape_drawing', { p_id: q.id, p_drawing: { w: d.w, h: d.h, shape: d.shape, ...(o ? { outline: o } : {}) } }));
        toast(`Sent to ${q.hostels?.owner_name || 'the owner'}. They check it and publish.`);
        again();
      };
      draw();
      detail.replaceChildren(
        el('h2', {}, `${q.hostels?.name ?? ''} · Room ${q.room}`),
        el('label', {}, 'Shape'), seg,
        el('div', { style: 'display:grid;grid-template-columns:1fr 1fr;gap:8px' }, el('label', {}, 'Width (ft)', num('w')), el('label', {}, 'Length (ft)', num('h'))),
        pts, preview,
        el('button', { class: 'btn primary cta', onclick: send }, 'Send to owner', '✓'),
        el('button', { class: 'btn full', onclick: () => drawDetail() }, 'Back to the request'),
        el('p', { class: 'note' }, 'The owner’s app places the beds, fans and windows inside these walls; they check it and publish.'),
      );
    };
    const drawDetail = async () => {
      if (!sel) return detail.replaceChildren(el('p', { class: 'empty' }, 'No owner has asked for help. Owners draw their own layouts; requests show here.'));
      const q = sel;
      const photos = await Promise.all((q.photos ?? []).map(async (p) => (await db.storage.from('fix-photos').createSignedUrl(p, 3600)).data?.signedUrl));
      const when = (iso) => `${dayMon(iso)}, ${new Date(iso).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: false })}`;
      detail.replaceChildren(
        el('h2', {}, `${q.hostels?.name ?? ''} · Room ${q.room}`),
        el('p', { class: 'mu', style: 'margin:0' }, `Asked ${when(q.created_at)} · due ${when(q.due_at)} · ${hoursLeft(q.due_at)}`),
        el('p', { style: 'margin:0' }, el('b', {}, 'Shape: '), `${q.shape}${q.w && q.h ? ` · ${q.w} × ${q.h} ft` : ''}`),
        el('p', { style: 'margin:0' }, el('b', {}, 'From: '), `${q.asked_name || q.hostels?.owner_name || 'The owner'}`),
        q.note ? el('p', { style: 'margin:0' }, `“${q.note}”`) : null,
        photos.filter(Boolean).map((u, i) => el('img', { src: u, alt: `Photo ${i + 1} from the owner`, style: 'max-width:100%;border:1px solid var(--hl)' })),
        q.status === 'sent'
          ? el('p', { class: 'mu', style: 'margin:0' }, `Sent ${dayMon(q.sent_at)}. Waiting for the owner to publish.`)
          : null,
        el('button', { class: 'btn primary cta', onclick: () => editor(q) }, q.status === 'sent' ? 'Change the drawing' : 'Open in layout editor', '✎'),
        el('p', { class: 'note' }, 'The owner checks it and publishes. Free, always within 48 hours.'),
      );
    };
    const rows = el('div', {});
    const drawRows = () => rows.replaceChildren(...(reqs.length ? reqs.map((q) => {
      const [t, kind] = helpStatus(q);
      return el('button', { class: 'tr' + (q === sel ? ' hi' : ''), style: 'width:100%;text-align:left', onclick: () => { sel = q; drawRows(); drawDetail(); } },
        el('div', {}, q.hostels?.name ?? ''), el('div', {}, String(q.room)), el('div', {}, q.shape),
        el('div', {}, [q.note ? `“${q.note}”` : '—', q.photos?.length ? ` · ${q.photos.length} ${q.photos.length === 1 ? 'photo' : 'photos'}` : ''].join('')),
        el('div', {}, q.status === 'sent' ? `Sent ${dayMon(q.sent_at)}` : hoursLeft(q.due_at)), el('div', {}, el('span', { class: 'tag ' + kind }, t)));
    }) : [el('p', { class: 'empty' }, 'No requests open.')]));
    drawRows();
    drawDetail();
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Layout help'), el('span', { class: 'mu', style: 'font-size:13px' }, `Owner requests · oldest due first · ${open} open`)),
      el('div', { class: 'board' },
        el('div', { class: 'table' }, el('div', { class: 'tr head' }, ['Hostel', 'Room', 'Shape', 'What they asked', 'Due', 'Status'].map((h) => el('div', {}, h))), rows),
        detail),
    ];
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
      // F19 extras: a quick fix is one item (no layout); the photo is private (signed link).
      const live = sel.kind === 'quick' ? null : await db.from('layouts').select('w, h, beds, items').eq('hostel_id', sel.hostel_id).eq('room', sel.room).eq('stage', 'published').maybeSingle().then(ok);
      const changes = sel.kind === 'quick' ? [quickLine(sel)] : layoutChanges(live, sel.layout);
      const photo = sel.photo ? (await db.storage.from('fix-photos').createSignedUrl(sel.photo, 3600)).data?.signedUrl : null;
      const wa = waLink(phone[sel.hostel_id], `Hi ${owner}, a resident sent a layout fix for room ${sel.room} ${days} days ago. Please approve or reject it in the Hostelzy app → Today.`);
      detail.replaceChildren(
        el('h2', {}, `${sel.hostels?.name ?? ''} · Room ${sel.room}`),
        el('p', { class: 'mu', style: 'margin:0' }, days >= 7 ? `${owner} hasn’t answered in ${days} days. The team can decide now.` : `With ${owner} for ${days} ${days === 1 ? 'day' : 'days'}. Owners decide first.`),
        el('div', { class: 'kick' }, `${changes.length} ${changes.length === 1 ? 'change' : 'changes'}`),
        el('ul', {}, changes.map((c) => el('li', {}, c))),
        sel.note ? el('p', {}, `“${sel.note}”`) : null,
        photo ? el('img', { src: photo, alt: 'Photo from the resident', style: 'max-width:100%;border:1px solid var(--hl)' }) : null,
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

  // F08 board 6, F24 Wave 4a: reviews reported for abuse. Reviews are never
  // deleted; the team hides one that breaks the rules, or keeps it.
  async reviews(db, again) {
    const reps = await db.from('review_reports').select('*, reviews(id, stars, body, author_name, kind, hidden, created_at, hostels(name))').eq('status', 'open').order('created_at').then(ok);
    const byReview = new Map();
    for (const r of reps) {
      if (!r.reviews) continue;
      const g = byReview.get(r.review_id) ?? { review: r.reviews, why: [], first: r.created_at };
      g.why.push(r.why);
      byReview.set(r.review_id, g);
    }
    const decide = async (g, hide) => {
      if (!confirm(hide ? `Hide ${g.review.author_name}’s review? It leaves the hostel page and the rating.` : `Keep ${g.review.author_name}’s review? The reports close.`)) return;
      ok(await db.rpc('decide_review_report', { p_review: g.review.id, p_hide: hide }));
      toast(hide ? 'Hidden. The author still sees it, marked hidden.' : 'Kept. The reports are closed.');
      again();
    };
    const groups = [...byReview.values()];
    return [
      el('div', { class: 'title' }, el('h1', {}, 'Reported reviews'), el('span', { class: 'mu', style: 'font-size:13px' }, 'Hide a review only if it breaks the rules (abuse, personal details, not a resident). A low rating is not a reason.')),
      el('div', { class: 'table' }, el('div', { class: 'tr head' }, ['Hostel', 'Review', 'Stars', 'Reported for', 'Since', 'Action'].map((h) => el('div', {}, h))),
        groups.length ? groups.map((g) => el('div', { class: 'tr' },
          el('div', {}, g.review.hostels?.name ?? ''),
          el('div', {}, `${g.review.author_name} · ${g.review.kind === 'exit' ? 'exit' : '30-day'}: ${g.review.body ? '“' + g.review.body + '”' : '(no words)'}`),
          el('div', {}, '★ ' + g.review.stars),
          el('div', {}, [...new Set(g.why)].join(', ') + (g.why.length > 1 ? ` (${g.why.length} reports)` : '')),
          el('div', {}, dayMon(g.first)),
          el('div', {}, el('button', { class: 'btn sm primary', onclick: () => decide(g, true) }, 'Hide'), el('button', { class: 'btn sm', onclick: () => decide(g, false) }, 'Keep')))) : el('p', { class: 'empty' }, 'No reported reviews.')),
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
