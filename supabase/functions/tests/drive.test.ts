import { test } from 'node:test';
import assert from 'node:assert/strict';
import { connectHandler, uploadHandler, viewHandler, mintTicket, readTicket, uidOf, DRIVE_SCOPE, VIEW_SECS } from '../_shared/drive.ts';

// F29 Part 3: the three Drive functions against a fake Google and a fake
// PostgREST. The image bytes must reach Drive and nothing else.

const ENV: Record<string, string> = {
  GOOGLE_OAUTH_CLIENT_ID: 'cid', GOOGLE_OAUTH_CLIENT_SECRET: 'csec', DRIVE_TOKEN_KEY: 'k-secret',
  SUPABASE_URL: 'https://x.supabase.co', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'service',
};
const env = (o: Record<string, string> = ENV) => (k: string) => o[k];

const jwt = (sub: string) => `h.${btoa(JSON.stringify({ sub })).replace(/=+$/, '')}.s`;
const H = '11111111-1111-1111-1111-111111111111';
const OWNER = jwt('fb-owner'), MGR = jwt('fb-mgr'), TENANT = jwt('fb-tenant'), NOBODY = jwt('fb-nobody');

type Call = { url: string; method: string; auth: string; body: string | Uint8Array | null; headers: Record<string, string> };

/** A fake server: Google OAuth + Drive and Supabase PostgREST (drive_* RPCs). */
function world(opts: { stored?: { refresh_token: string; folder_id: string; full_copy: boolean } | null; scope?: string; refresh?: string | null; badCode?: boolean } = {}) {
  const calls: Call[] = [];
  const log: string[] = [];
  let stored = opts.stored === undefined ? null : opts.stored;
  const scope = opts.scope ?? `openid ${DRIVE_SCOPE}`;
  const refresh = opts.refresh === undefined ? 'rt-1' : opts.refresh;
  const folders: Record<string, string> = {};
  let n = 0;
  const f = (async (url: string, init: RequestInit = {}) => {
    const headers = Object.fromEntries(Object.entries((init.headers as Record<string, string>) ?? {}).map(([k, v]) => [k.toLowerCase(), v]));
    const auth = (headers.authorization ?? '').replace('Bearer ', '');
    const bodyRaw = init.body as string | Uint8Array | URLSearchParams | null;
    const body = bodyRaw instanceof URLSearchParams ? bodyRaw.toString() : bodyRaw;
    calls.push({ url, method: init.method ?? 'GET', auth, body: body ?? null, headers });
    const ok = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status });
    // Google OAuth
    if (url === 'https://oauth2.googleapis.com/token') {
      const p = new URLSearchParams(body as string);
      if (p.get('grant_type') === 'authorization_code') {
        if (opts.badCode) return new Response('{"error":"invalid_grant"}', { status: 400 });
        return ok({ access_token: 'at-from-code', scope, ...(refresh ? { refresh_token: refresh } : {}) });
      }
      if (p.get('refresh_token') === 'rt-gone') return new Response('{"error":"invalid_grant"}', { status: 400 });
      return ok({ access_token: `at-for-${p.get('refresh_token')}` });
    }
    if (url === 'https://oauth2.googleapis.com/revoke') return ok({});
    // Google Drive
    if (url.startsWith('https://www.googleapis.com/drive/v3/files?q=')) {
      const q = decodeURIComponent(url.split('q=')[1].split('&')[0]);
      const name = q.match(/name = '([^']*)'/)![1];
      const parent = q.match(/'([^']*)' in parents/)?.[1] ?? '';
      const id = folders[`${parent}/${name}`];
      return ok({ files: id ? [{ id }] : [] });
    }
    if (url.startsWith('https://www.googleapis.com/drive/v3/files?fields=id') && init.method === 'POST') {
      const m = JSON.parse(body as string);
      const id = `fold-${++n}`;
      folders[`${m.parents?.[0] ?? ''}/${m.name}`] = id;
      return ok({ id });
    }
    if (url.startsWith('https://www.googleapis.com/upload/drive/v3/files')) return ok({ id: 'file-9' });
    if (url.startsWith('https://www.googleapis.com/drive/v3/files/') && url.includes('alt=media')) {
      if (auth !== 'at-for-rt-1') return new Response('nope', { status: 401 });
      return new Response(new Uint8Array([0xff, 0xd8, 1, 2]), { status: 200, headers: { 'content-type': 'image/jpeg' } });
    }
    if (url.startsWith('https://www.googleapis.com/drive/v3/files/') && init.method === 'DELETE') return new Response(null, { status: 204 });
    // Supabase PostgREST
    if (url.startsWith('https://x.supabase.co/rest/v1/rpc/')) {
      const fn = url.split('/rpc/')[1];
      const args = JSON.parse(body as string);
      const asServer = auth === 'service';
      const err = (m: string) => new Response(JSON.stringify({ message: m }), { status: 400 });
      if (fn === 'drive_role') {
        if (auth === OWNER) return ok([{ role: 'owner', name: 'Sai Residency' }]);
        if (auth === MGR) return ok([{ role: 'manager', name: 'Sai Residency' }]);
        return ok([]);
      }
      if (fn === 'id_upload_target') {
        if (auth !== TENANT) return err('sign in first');
        if (args.p_token === 'tok-1') return stored ? ok([{ hostel_id: H, full_copy: stored.full_copy }]) : err('The owner hasn’t connected Google Drive');
        return err('This link isn’t valid any more');
      }
      if (!asServer) return new Response('{"message":"permission denied for function"}', { status: 401 });
      if (fn === 'drive_token') return ok(stored && args.h === H && args.p_key === 'k-secret' ? [stored] : []);
      if (fn === 'drive_put') {
        log.push(`put ${args.h} ${args.p_uid} ${args.p_token} ${args.p_folder} ${args.p_key}`);
        stored = { refresh_token: args.p_token, folder_id: args.p_folder, full_copy: false };
        return ok(null);
      }
      if (fn === 'drive_forget') {
        log.push(`forget ${args.h}`);
        stored = null;
        return ok(null);
      }
      if (fn === 'drive_file_added') {
        log.push(`files ${args.h} ${args.delta}`);
        return ok(null);
      }
    }
    return new Response('?', { status: 404 });
  }) as unknown as typeof fetch;
  return { f, calls, log, get stored() { return stored; } };
}

const post = (url: string, auth: string | null, body: unknown) =>
  new Request(url, { method: 'POST', headers: { ...(auth ? { authorization: `Bearer ${auth}` } : {}), 'content-type': 'application/json' }, body: JSON.stringify(body) });

test('uidOf reads the Firebase uid; garbage is null', () => {
  assert.equal(uidOf(OWNER), 'fb-owner');
  assert.equal(uidOf('nope'), null);
  assert.equal(uidOf(''), null);
});

test('without the secrets every function says not_ready (the app shows "Not available yet")', async () => {
  const w = world();
  const e = env({ ...ENV, GOOGLE_OAUTH_CLIENT_ID: '' });
  for (const h of [connectHandler, uploadHandler, viewHandler]) {
    const r = await h(post('https://x/fn', OWNER, { hostel_id: H }), e, w.f, 0);
    assert.equal(r.status, 503);
    assert.equal((await r.json()).error, 'not_ready');
  }
  assert.equal(w.calls.length, 0);
});

test('drive-connect: the owner’s code → refresh token → Hostelzy / <hostel> / Tenant IDs → stored encrypted with the key', async () => {
  const w = world();
  const r = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, code: '4/abc' }), env(), w.f, 1000);
  assert.deepEqual(await r.json(), { connected: true, files: 0, full_copy: false });
  // The code exchange asks Google with the client secret, never the user's token.
  const ex = w.calls.find((c) => c.url === 'https://oauth2.googleapis.com/token')!;
  assert.match(ex.body as string, /code=4%2Fabc/);
  assert.match(ex.body as string, /client_secret=csec/);
  // Three nested folders, then the row.
  const made = w.calls.filter((c) => c.url.startsWith('https://www.googleapis.com/drive/v3/files?fields=id')).map((c) => JSON.parse(c.body as string));
  assert.deepEqual(made.map((m) => m.name), ['Hostelzy', 'Sai Residency', 'Tenant IDs']);
  assert.deepEqual(made.map((m) => m.parents?.[0]), [undefined, 'fold-1', 'fold-2']);
  assert.deepEqual(w.log, [`put ${H} fb-owner rt-1 fold-3 k-secret`]);
  // Connecting again finds the same folders instead of making new ones.
  await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, code: '4/def' }), env(), w.f, 1000);
  assert.equal(w.calls.filter((c) => c.url.startsWith('https://www.googleapis.com/drive/v3/files?fields=id')).length, 3);
  assert.equal(w.log.at(-1), `put ${H} fb-owner rt-1 fold-3 k-secret`);
});

test('drive-connect: a manager, a stranger or no sign-in can’t connect; no scope or no refresh token is said plainly', async () => {
  const w = world();
  for (const [who, status, code] of [[MGR, 403, 'not_owner'], [NOBODY, 403, 'not_owner'], [null, 401, 'sign_in']] as const) {
    const r = await connectHandler(post('https://x/fn', who, { hostel_id: H, code: 'c' }), env(), w.f, 0);
    assert.equal(r.status, status);
    assert.equal((await r.json()).error, code);
  }
  assert.equal(w.log.length, 0);
  const noScope = world({ scope: 'openid email' });
  const r1 = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, code: 'c' }), env(), noScope.f, 0);
  assert.equal(r1.status, 400);
  assert.equal((await r1.json()).error, 'no_scope');
  const noRefresh = world({ refresh: null });
  const r2 = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, code: 'c' }), env(), noRefresh.f, 0);
  assert.equal((await r2.json()).error, 'no_refresh');
  const bad = world({ badCode: true });
  const r3 = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, code: 'c' }), env(), bad.f, 0);
  assert.equal((await r3.json()).error, 'no_scope');
  assert.equal(noScope.log.length + noRefresh.log.length + bad.log.length, 0);
});

test('drive-connect: disconnect revokes the token at Google and forgets the row (owner only)', async () => {
  const w = world({ stored: { refresh_token: 'rt-1', folder_id: 'fold-3', full_copy: true } });
  const no = await connectHandler(post('https://x/fn', MGR, { hostel_id: H, action: 'disconnect' }), env(), w.f, 0);
  assert.equal(no.status, 403);
  const r = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, action: 'disconnect' }), env(), w.f, 0);
  assert.deepEqual(await r.json(), { connected: false, files: 0, full_copy: false });
  assert.match(w.calls.find((c) => c.url.endsWith('/revoke'))!.body as string, /token=rt-1/);
  assert.deepEqual(w.log, [`forget ${H}`]);
  assert.equal(w.stored, null);
  // Already disconnected: still fine.
  const again = await connectHandler(post('https://x/fn', OWNER, { hostel_id: H, action: 'disconnect' }), env(), w.f, 0);
  assert.equal(again.status, 200);
});

test('id-upload: the tenant’s photo goes to Drive in the owner’s folder with the owner’s token; only the file id comes back', async () => {
  const w = world({ stored: { refresh_token: 'rt-1', folder_id: 'fold-3', full_copy: false } });
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 7, 8, 9]);
  const r = await uploadHandler(post('https://x/fn', TENANT, { token: 'tok-1', image: btoa(String.fromCharCode(...bytes)), mime: 'image/jpeg' }), env(), w.f, 1760000000);
  assert.deepEqual(await r.json(), { file_id: 'file-9' });
  const up = w.calls.find((c) => c.url.startsWith('https://www.googleapis.com/upload/'))!;
  assert.equal(up.auth, 'at-for-rt-1');
  const raw = up.body as Uint8Array;
  const text = new TextDecoder('latin1').decode(raw);
  assert.match(text, /"parents":\["fold-3"\]/);
  assert.match(text, /"name":"ID 2025-10-09 \d\d:\d\d\.jpg"/);
  assert.match(text, /content-type: image\/jpeg/);
  // The bytes are in the multipart body, untouched.
  const at = text.indexOf('\r\n\r\n', text.indexOf('image/jpeg')) + 4;
  assert.deepEqual([...raw.slice(at, at + bytes.length)], [...bytes]);
  // The image never went to Supabase.
  for (const c of w.calls.filter((c) => c.url.includes('supabase.co'))) assert.doesNotMatch(String(c.body), /\u0007|AAA/);
  assert.deepEqual(w.log, [`files ${H} 1`]);
});

test('id-upload: refusals: no sign-in, bad token, owner not connected, too big, wrong type', async () => {
  const w = world({ stored: { refresh_token: 'rt-1', folder_id: 'fold-3', full_copy: false } });
  const img = btoa('abc');
  const cases: [string | null, Record<string, unknown>, number, string][] = [
    [null, { token: 'tok-1', image: img }, 401, 'sign_in'],
    [TENANT, { token: 'tok-x', image: img }, 400, 'sql'],
    [TENANT, { token: 'tok-1', image: img, mime: 'application/pdf' }, 400, 'bad_request'],
    [TENANT, { token: 'tok-1', image: 'A'.repeat(6 * 1024 * 1024 * 2) }, 413, 'too_big'],
    [TENANT, { token: 'tok-1' }, 400, 'bad_request'],
  ];
  for (const [who, body, status, code] of cases) {
    const r = await uploadHandler(post('https://x/fn', who, body), env(), w.f, 0);
    assert.equal(r.status, status, code);
    assert.equal((await r.json()).error, code);
  }
  const bad = await uploadHandler(post('https://x/fn', TENANT, { token: 'tok-x', image: img }), env(), w.f, 0);
  assert.equal((await bad.json()).message, 'This link isn’t valid any more');
  const off = world({ stored: null });
  const r = await uploadHandler(post('https://x/fn', TENANT, { token: 'tok-1', image: img }), env(), off.f, 0);
  assert.equal((await r.json()).message, 'The owner hasn’t connected Google Drive');
  assert.equal(w.calls.some((c) => c.url.startsWith('https://www.googleapis.com/upload/')), false);
});

test('view tickets: signed with the key, expire, can’t be forged', async () => {
  const t = await mintTicket('k', H, 'file-9', 1000);
  assert.deepEqual(await readTicket('k', t, 999), { hostelId: H, fileId: 'file-9' });
  assert.equal(await readTicket('k', t, 1001), null);
  assert.equal(await readTicket('other', t, 999), null);
  const [p, s] = t.split('.');
  assert.equal(await readTicket('k', `${p}x.${s}`, 999), null);
  assert.equal(await readTicket('k', 'junk', 999), null);
});

test('id-view: owner or manager gets a 10-minute link and the Drive page; the link streams the image; others are refused', async () => {
  const w = world({ stored: { refresh_token: 'rt-1', folder_id: 'fold-3', full_copy: false } });
  for (const who of [OWNER, MGR]) {
    const r = await viewHandler(post('https://x/fn', who, { hostel_id: H, file_id: 'file-9' }), env(), w.f, 5000);
    const j = await r.json();
    assert.equal(j.until, 5000 + VIEW_SECS);
    assert.equal(j.open, 'https://drive.google.com/file/d/file-9/view');
    assert.match(j.url, /^https:\/\/x\.supabase\.co\/functions\/v1\/id-view\?t=/);
    // The link works without any sign-in (it's an <img> src), until it expires.
    const img = await viewHandler(new Request(j.url), env(), w.f, 5100);
    assert.equal(img.status, 200);
    assert.equal(img.headers.get('content-type'), 'image/jpeg');
    assert.equal(img.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual([...new Uint8Array(await img.arrayBuffer())], [0xff, 0xd8, 1, 2]);
    const late = await viewHandler(new Request(j.url), env(), w.f, 5000 + VIEW_SECS + 1);
    assert.equal(late.status, 403);
    assert.equal((await late.json()).error, 'expired');
  }
  for (const who of [TENANT, NOBODY]) {
    const r = await viewHandler(post('https://x/fn', who, { hostel_id: H, file_id: 'file-9' }), env(), w.f, 0);
    assert.equal(r.status, 403);
    assert.equal((await r.json()).error, 'not_staff');
  }
  const none = await viewHandler(post('https://x/fn', null, { hostel_id: H, file_id: 'file-9' }), env(), w.f, 0);
  assert.equal(none.status, 401);
  const forged = await viewHandler(new Request('https://x.supabase.co/functions/v1/id-view?t=abc.def'), env(), w.f, 0);
  assert.equal(forged.status, 403);
});

test('id-view: "Delete from my Drive" deletes the file and counts down; access the owner removed is said plainly', async () => {
  const w = world({ stored: { refresh_token: 'rt-1', folder_id: 'fold-3', full_copy: false } });
  const r = await viewHandler(post('https://x/fn', MGR, { hostel_id: H, file_id: 'file-9', action: 'delete' }), env(), w.f, 0);
  assert.deepEqual(await r.json(), { deleted: true });
  assert.equal(w.calls.find((c) => c.method === 'DELETE')!.url, 'https://www.googleapis.com/drive/v3/files/file-9');
  assert.deepEqual(w.log, [`files ${H} -1`]);
  const gone = world({ stored: { refresh_token: 'rt-gone', folder_id: 'fold-3', full_copy: false } });
  const r2 = await viewHandler(post('https://x/fn', OWNER, { hostel_id: H, file_id: 'file-9', action: 'delete' }), env(), gone.f, 0);
  assert.equal(r2.status, 409);
  assert.equal((await r2.json()).error, 'not_connected');
});
