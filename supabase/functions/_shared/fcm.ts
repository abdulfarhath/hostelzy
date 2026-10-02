// B5: sends the rows in public.push_outbox with FCM HTTP v1. Plain TypeScript
// with fetch and WebCrypto only, so it runs on Supabase Edge (Deno) and in the
// Node tests (supabase/functions/tests).

export type ServiceAccount = { project_id: string; client_email: string; private_key: string };
export type OutboxRow = { id: number; user_id: string; title: string; body: string; data: Record<string, unknown> };
export type Fetch = typeof fetch;

const b64url = (b: Uint8Array | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/** A signed JWT asking Google for an FCM access token (RS256). */
export async function serviceAccountJwt(sa: ServiceAccount, nowSecs: number): Promise<string> {
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSecs,
    exp: nowSecs + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${claims}`)));
  return `${head}.${claims}.${b64url(sig)}`;
}

export async function accessToken(sa: ServiceAccount, f: Fetch, nowSecs: number): Promise<string> {
  const r = await f('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: await serviceAccountJwt(sa, nowSecs) }),
  });
  if (!r.ok) throw new Error(`Google token: ${r.status} ${await r.text()}`);
  return (await r.json()).access_token;
}

/** FCM v1 body: a visible notification plus string data for the app to route. */
export function fcmMessage(token: string, row: OutboxRow) {
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(row.data ?? {})) data[k] = String(v);
  return { message: { token, notification: { title: row.title, body: row.body }, data, android: { priority: 'high' } } };
}

/** Phones that no longer exist: FCM says the token is gone. */
export const tokenGone = (status: number, body: string) =>
  status === 404 || (status === 400 && body.includes('registration token is not a valid FCM registration token')) || body.includes('UNREGISTERED');

export type Db = {
  pending(limit: number): Promise<OutboxRow[]>;
  tokens(userIds: string[]): Promise<{ token: string; user_id: string }[]>;
  markSent(id: number, error: string | null): Promise<void>;
  dropToken(token: string): Promise<void>;
};

/** Sends up to [limit] pending rows. A row is "sent" once every phone of its
 *  user was tried; with no phones it is closed with error "no phones". */
export async function sendOutbox(db: Db, sa: ServiceAccount, f: Fetch, nowSecs: number, limit = 100) {
  const rows = await db.pending(limit);
  if (rows.length === 0) return { rows: 0, sent: 0, failed: 0, dropped: 0 };
  const toks = await db.tokens([...new Set(rows.map((r) => r.user_id))]);
  const auth = await accessToken(sa, f, nowSecs);
  let sent = 0, failed = 0, dropped = 0;
  for (const row of rows) {
    const mine = toks.filter((t) => t.user_id === row.user_id);
    const errors: string[] = [];
    for (const t of mine) {
      const r = await f(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${auth}`, 'content-type': 'application/json' },
        body: JSON.stringify(fcmMessage(t.token, row)),
      });
      if (r.ok) { sent++; continue; }
      const body = await r.text();
      if (tokenGone(r.status, body)) { await db.dropToken(t.token); dropped++; continue; }
      failed++;
      errors.push(`${r.status} ${body.slice(0, 200)}`);
    }
    await db.markSent(row.id, mine.length === 0 ? 'no phones' : errors.length ? errors.join('; ') : null);
  }
  return { rows: rows.length, sent, failed, dropped };
}

/** The database side over Supabase's REST API with the service role key. */
export function restDb(url: string, serviceKey: string, f: Fetch): Db {
  const h = { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, 'content-type': 'application/json' };
  const call = async (path: string, init: RequestInit = {}) => {
    const r = await f(`${url}/rest/v1/${path}`, { ...init, headers: { ...h, ...(init.headers ?? {}) } });
    if (!r.ok) throw new Error(`${path}: ${r.status} ${await r.text()}`);
    return r.status === 204 ? null : r.json();
  };
  return {
    pending: (limit) => call(`push_outbox?select=id,user_id,title,body,data&sent_at=is.null&order=id&limit=${limit}`),
    tokens: (ids) => call(`push_tokens?select=token,user_id&user_id=in.(${ids.map((i) => `"${i.replace(/"/g, '')}"`).join(',')})`),
    markSent: async (id, error) => {
      await call(`push_outbox?id=eq.${id}`, { method: 'PATCH', headers: { prefer: 'return=minimal' }, body: JSON.stringify({ sent_at: new Date().toISOString(), error }) });
    },
    dropToken: async (token) => {
      await call(`push_tokens?token=eq.${encodeURIComponent(token)}`, { method: 'DELETE', headers: { prefer: 'return=minimal' } });
    },
  };
}
