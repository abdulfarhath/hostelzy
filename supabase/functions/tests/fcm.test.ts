// Run: node --experimental-strip-types --test supabase/functions/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accessToken, fcmMessage, pushHandler, sendOutbox, serviceAccountJwt, tokenGone, wantsPush, type Db, type OutboxRow } from '../_shared/fcm.ts';

async function fakeAccount() {
  const kp = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der)).replace(/(.{64})/g, '$1\n')}\n-----END PRIVATE KEY-----\n`;
  return { sa: { project_id: 'hostelzy', client_email: 'push@hostelzy.iam.gserviceaccount.com', private_key: pem }, pub: kp.publicKey };
}
const unb64 = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));

test('service account JWT is RS256-signed for the FCM scope', async () => {
  const { sa, pub } = await fakeAccount();
  const jwt = await serviceAccountJwt(sa, 1_800_000_000);
  const [h, c, s] = jwt.split('.');
  assert.deepEqual(JSON.parse(new TextDecoder().decode(unb64(h))), { alg: 'RS256', typ: 'JWT' });
  const claims = JSON.parse(new TextDecoder().decode(unb64(c)));
  assert.equal(claims.iss, sa.client_email);
  assert.equal(claims.scope, 'https://www.googleapis.com/auth/firebase.messaging');
  assert.equal(claims.exp - claims.iat, 3600);
  assert.ok(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', pub, unb64(s), new TextEncoder().encode(`${h}.${c}`)));
});

test('FCM message carries the title, body and string data', () => {
  const row: OutboxRow = { id: 1, user_id: 'u', title: 'New hold on bed 101-A', body: 'HZ-5002', data: { screen: 'oToday', n: 2 } };
  assert.deepEqual(fcmMessage('tok', row), { message: { token: 'tok', notification: { title: 'New hold on bed 101-A', body: 'HZ-5002' }, data: { screen: 'oToday', n: '2' }, android: { priority: 'high', notification: { icon: 'ic_stat_hostelzy', color: '#EC3013' } } } });
  assert.ok(tokenGone(404, ''));
  assert.ok(tokenGone(400, '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}'));
  assert.ok(!tokenGone(500, 'internal'));
});

test('sendOutbox: sends to every phone, drops dead tokens, closes rows with no phones', async () => {
  const { sa } = await fakeAccount();
  const marked: [number, string | null][] = [];
  const dropped: string[] = [];
  const db: Db = {
    pending: async () => [
      { id: 1, user_id: 'owner', title: 'New enquiry', body: '', data: {} },
      { id: 2, user_id: 'nobody', title: 'Payment confirmed', body: '', data: {} },
    ],
    tokens: async (ids) => {
      assert.deepEqual(ids, ['owner', 'nobody']);
      return [{ token: 'phone-1', user_id: 'owner' }, { token: 'old-phone', user_id: 'owner' }];
    },
    markSent: async (id, e) => { marked.push([id, e]); },
    markError: async () => { throw new Error('no errors expected'); },
    dropToken: async (t) => { dropped.push(t); },
  };
  const calls: string[] = [];
  const f = (async (url: string, init: RequestInit) => {
    calls.push(url);
    if (url.startsWith('https://oauth2')) return new Response(JSON.stringify({ access_token: 'ya29.x' }));
    assert.equal((init.headers as Record<string, string>).authorization, 'Bearer ya29.x');
    const token = JSON.parse(init.body as string).message.token;
    return token === 'old-phone' ? new Response('{"error":{"status":"NOT_FOUND"}}', { status: 404 }) : new Response('{}');
  }) as typeof fetch;
  const out = await sendOutbox(db, sa, f, 1_800_000_000);
  assert.deepEqual(out, { rows: 2, sent: 1, failed: 0, dropped: 1, errored: 0 });
  assert.deepEqual(dropped, ['old-phone']);
  assert.deepEqual(marked, [[1, null], [2, 'no phones']]);
  assert.equal(calls.filter((u) => u.includes('/projects/hostelzy/messages:send')).length, 2);
});

test('nothing pending: no Google call at all', async () => {
  const { sa } = await fakeAccount();
  const db = { pending: async () => [] } as unknown as Db;
  const f = (async () => { throw new Error('should not fetch'); }) as unknown as typeof fetch;
  assert.deepEqual(await sendOutbox(db, sa, f, 0), { rows: 0, sent: 0, failed: 0, dropped: 0, errored: 0 });
});

test('a Google error is reported, not swallowed', async () => {
  const { sa } = await fakeAccount();
  const f = (async () => new Response('bad key', { status: 400 })) as unknown as typeof fetch;
  await assert.rejects(accessToken(sa, f, 0), /Google token: 400 bad key/);
});

function memDb(rows: OutboxRow[], tokens: { token: string; user_id: string }[]) {
  const sent: [number, string | null][] = [];
  const errors: [number, string][] = [];
  const db: Db = {
    pending: async () => rows,
    tokens: async () => tokens,
    markSent: async (id, e) => { sent.push([id, e]); },
    markError: async (id, e) => { errors.push([id, e]); },
    dropToken: async () => {},
  };
  return { db, sent, errors };
}

test('Google token fails: every row gets the reason and stays pending', async () => {
  const { sa } = await fakeAccount();
  const m = memDb([{ id: 7, user_id: 'u', title: 't', body: '', data: {} }], [{ token: 'p', user_id: 'u' }]);
  const f = (async () => new Response('{"error":"invalid_grant"}', { status: 400 })) as unknown as typeof fetch;
  await assert.rejects(sendOutbox(m.db, sa, f, 0), /Google token: 400/);
  assert.deepEqual(m.errors, [[7, 'Google token: 400 {"error":"invalid_grant"}']]);
  assert.deepEqual(m.sent, []);
});

test('a row that throws is noted and the next row still goes', async () => {
  const { sa } = await fakeAccount();
  const m = memDb([{ id: 1, user_id: 'a', title: 't', body: '', data: {} }, { id: 2, user_id: 'b', title: 't', body: '', data: {} }],
    [{ token: 'pa', user_id: 'a' }, { token: 'pb', user_id: 'b' }]);
  const f = (async (url: string, init: RequestInit) => {
    if (url.startsWith('https://oauth2')) return new Response(JSON.stringify({ access_token: 'x' }));
    if (JSON.parse(init.body as string).message.token === 'pa') throw new Error('network down');
    return new Response('{}');
  }) as typeof fetch;
  assert.deepEqual(await sendOutbox(m.db, sa, f, 0), { rows: 2, sent: 1, failed: 0, dropped: 0, errored: 1 });
  assert.deepEqual(m.errors, [[1, 'network down']]);
  assert.deepEqual(m.sent, [[2, null]]);
});

test('send-push answers 500 with the reason, never the secret', async () => {
  const { sa } = await fakeAccount();
  const req = (s = 'shh') => new Request('https://x/send-push', { method: 'POST', headers: { 'x-hz-secret': s } });
  const env = (o: Record<string, string>) => (k: string) => o[k];
  const base = { PUSH_SECRET: 'shh', SUPABASE_URL: 'https://db', SUPABASE_SERVICE_ROLE_KEY: 'svc-key' };
  const noFetch = (async () => { throw new Error('should not fetch'); }) as unknown as typeof fetch;
  assert.equal((await pushHandler(req('wrong'), env({ ...base, FCM_SERVICE_ACCOUNT: JSON.stringify(sa) }), noFetch, 0)).status, 401);
  const bad = await pushHandler(req(), env({ ...base, FCM_SERVICE_ACCOUNT: '{not json' }), noFetch, 0);
  assert.equal(bad.status, 500);
  assert.match(await bad.text(), /not valid JSON/);
  // A key pasted with escaped newlines still signs.
  const escaped = { ...sa, private_key: sa.private_key.replace(/\n/g, '\\n') };
  const m = memDb([{ id: 3, user_id: 'u', title: 't', body: '', data: {} }], [{ token: 'p', user_id: 'u' }]);
  const google500 = (async (url: string) => url.startsWith('https://oauth2') ? new Response('boom', { status: 500 }) : new Response('{}')) as typeof fetch;
  const r = await pushHandler(req(), env({ ...base, FCM_SERVICE_ACCOUNT: JSON.stringify(escaped) }), google500, 0, () => m.db);
  const text = await r.text();
  assert.equal(r.status, 500);
  assert.equal(text, 'send-push: Google token: 500 boom');
  assert.ok(!text.includes('svc-key') && !text.includes('PRIVATE KEY'));
  assert.deepEqual(m.errors, [[3, 'Google token: 500 boom']]);
  const ok = await pushHandler(req(), env({ ...base, FCM_SERVICE_ACCOUNT: JSON.stringify(escaped) }),
    (async (url: string) => new Response(url.startsWith('https://oauth2') ? '{"access_token":"x"}' : '{}')) as typeof fetch, 0, () => memDb([], []).db);
  assert.deepEqual(await ok.json(), { rows: 0, sent: 0, failed: 0, dropped: 0, errored: 0 });
});

test('F24: a kind the user switched off is closed, not sent; other kinds still go', async () => {
  const { sa } = await fakeAccount();
  assert.ok(wantsPush({}, 'u', 'hold'));
  assert.ok(!wantsPush({}, 'u', 'beds'));
  assert.ok(wantsPush({ u: { beds: true } }, 'u', 'beds'));
  assert.ok(wantsPush({ u: { hold: false } }, 'u', null));
  const m = memDb([
    { id: 1, user_id: 'a', title: 'Bed kept', body: '', data: {}, kind: 'hold' },
    { id: 2, user_id: 'a', title: 'Fix approved', body: '', data: {} },
    { id: 3, user_id: 'b', title: 'A bed is free', body: '', data: { kind: 'beds' } },
  ], [{ token: 'pa', user_id: 'a' }, { token: 'pb', user_id: 'b' }]);
  const asked: string[][] = [];
  m.db.prefs = async (ids) => { asked.push(ids); return { a: { hold: false, rent: true, beds: false } }; };
  const f = (async (url: string) => new Response(url.startsWith('https://oauth2') ? '{"access_token":"x"}' : '{}')) as typeof fetch;
  assert.deepEqual(await sendOutbox(m.db, sa, f, 0), { rows: 3, sent: 1, failed: 0, dropped: 0, errored: 0 });
  assert.deepEqual(asked, [['a', 'b']]);
  assert.deepEqual(m.sent, [[1, 'switched off'], [3, 'switched off'], [2, null]]);
});

test('F24: switches can\'t be read (before the SQL runs): everything is sent as before', async () => {
  const { sa } = await fakeAccount();
  const m = memDb([{ id: 1, user_id: 'a', title: 'Bed kept', body: '', data: {}, kind: 'hold' }], [{ token: 'pa', user_id: 'a' }]);
  m.db.prefs = async () => { throw new Error('column profiles.notify does not exist'); };
  const f = (async (url: string) => new Response(url.startsWith('https://oauth2') ? '{"access_token":"x"}' : '{}')) as typeof fetch;
  assert.deepEqual(await sendOutbox(m.db, sa, f, 0), { rows: 1, sent: 1, failed: 0, dropped: 0, errored: 0 });
});
