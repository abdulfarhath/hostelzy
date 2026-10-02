import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setTeam } from '../_shared/team.ts';

async function account() {
  const kp = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  return { project_id: 'hostelzy', client_email: 'admin@hostelzy.iam.gserviceaccount.com', private_key: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----` };
}

function fakeGoogle(users: Record<string, { localId: string; customAttributes?: string }>) {
  const updates: { localId: string; customAttributes: string }[] = [];
  const f = (async (url: string, init: RequestInit) => {
    if (url.startsWith('https://oauth2')) return new Response(JSON.stringify({ access_token: 't' }));
    const body = JSON.parse(init.body as string);
    if (url.endsWith('accounts:lookup')) {
      const u = users[body.email[0]];
      return new Response(JSON.stringify(u ? { users: [u] } : {}));
    }
    if (url.endsWith('accounts:update')) {
      updates.push(body);
      return new Response('{}');
    }
    return new Response('?', { status: 404 });
  }) as typeof fetch;
  return { f, updates };
}

test('add keeps other claims; remove takes only team away', async () => {
  const sa = await account();
  const g = fakeGoogle({ 'asha@gmail.com': { localId: 'u1', customAttributes: '{"beta":true}' } });
  assert.match(await setTeam(sa, ' Asha@Gmail.com ', true, g.f, 0), /now on the Hostelzy team/);
  assert.deepEqual(g.updates[0], { localId: 'u1', customAttributes: '{"beta":true,"team":true}' });
  const g2 = fakeGoogle({ 'asha@gmail.com': { localId: 'u1', customAttributes: '{"beta":true,"team":true}' } });
  await setTeam(sa, 'asha@gmail.com', false, g2.f, 0);
  assert.deepEqual(g2.updates[0], { localId: 'u1', customAttributes: '{"beta":true}' });
});

test('someone who never signed in, or not an email, is refused', async () => {
  const sa = await account();
  await assert.rejects(setTeam(sa, 'new@gmail.com', true, fakeGoogle({}).f, 0), /hasn't signed in to Hostelzy yet/);
  await assert.rejects(setTeam(sa, 'not-an-email', true, fakeGoogle({}).f, 0), /Not an email address/);
});
