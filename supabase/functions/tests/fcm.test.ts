// Run: node --experimental-strip-types --test supabase/functions/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accessToken, fcmMessage, sendOutbox, serviceAccountJwt, tokenGone, type Db, type OutboxRow } from '../_shared/fcm.ts';

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
  assert.deepEqual(fcmMessage('tok', row), { message: { token: 'tok', notification: { title: 'New hold on bed 101-A', body: 'HZ-5002' }, data: { screen: 'oToday', n: '2' }, android: { priority: 'high' } } });
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
  assert.deepEqual(out, { rows: 2, sent: 1, failed: 0, dropped: 1 });
  assert.deepEqual(dropped, ['old-phone']);
  assert.deepEqual(marked, [[1, null], [2, 'no phones']]);
  assert.equal(calls.filter((u) => u.includes('/projects/hostelzy/messages:send')).length, 2);
});

test('nothing pending: no Google call at all', async () => {
  const { sa } = await fakeAccount();
  const db = { pending: async () => [] } as unknown as Db;
  const f = (async () => { throw new Error('should not fetch'); }) as unknown as typeof fetch;
  assert.deepEqual(await sendOutbox(db, sa, f, 0), { rows: 0, sent: 0, failed: 0, dropped: 0 });
});

test('a Google error is reported, not swallowed', async () => {
  const { sa } = await fakeAccount();
  const f = (async () => new Response('bad key', { status: 400 })) as unknown as typeof fetch;
  await assert.rejects(accessToken(sa, f, 0), /Google token: 400 bad key/);
});
