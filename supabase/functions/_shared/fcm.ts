// B5: sends the rows in public.push_outbox with FCM HTTP v1. Plain TypeScript
// with fetch and WebCrypto only, so it runs on Supabase Edge (Deno) and in the
// Node tests (supabase/functions/tests).

export type ServiceAccount = { project_id: string; client_email: string; private_key: string };
export type OutboxRow = { id: number; user_id: string; title: string; body: string; data: Record<string, unknown>; kind?: string | null };

/** F24: each user's Settings switches (profiles.notify), e.g. { hold: true, rent: false, beds: true }. */
export type Prefs = Record<string, Record<string, unknown>>;

/** F24: does [user] want a push of [kind]? Other kinds always go; "beds" only when switched on. */
export const wantsPush = (prefs: Prefs, user: string, kind?: string | null) => {
  if (!kind || !['hold', 'rent', 'beds'].includes(kind)) return true;
  const v = prefs[user]?.[kind];
  return typeof v === 'boolean' ? v : kind !== 'beds';
};
export type Fetch = typeof fetch;

const b64url = (b: Uint8Array | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/** A signed JWT asking Google for an access token (RS256), FCM by default. */
export async function serviceAccountJwt(sa: ServiceAccount, nowSecs: number, scope = FCM_SCOPE): Promise<string> {
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope,
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSecs,
    exp: nowSecs + 3600,
  }));
  // A key pasted with literal "\n" (escaped twice) still works.
  const pem = sa.private_key.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  let key: CryptoKey;
  try {
    const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
    key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  } catch (e) {
    throw new Error(`FCM_SERVICE_ACCOUNT private_key can't be read (${(e as Error).name})`);
  }
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${claims}`)));
  return `${head}.${claims}.${b64url(sig)}`;
}

export async function accessToken(sa: ServiceAccount, f: Fetch, nowSecs: number, scope = FCM_SCOPE): Promise<string> {
  const r = await f('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: await serviceAccountJwt(sa, nowSecs, scope) }),
  });
  if (!r.ok) throw new Error(`Google token: ${r.status} ${await r.text()}`);
  return (await r.json()).access_token;
}

/** Brand: the Android small icon (res/drawable/ic_stat_hostelzy.xml) and its tint (Pal light `ac`). */
export const PUSH_ICON = 'ic_stat_hostelzy';
export const PUSH_COLOR = '#EC3013';

/** FCM v1 body: a visible notification plus string data for the app to route.
 *  The icon and colour are set here too, so they never depend on the manifest. */
export function fcmMessage(token: string, row: OutboxRow) {
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(row.data ?? {})) data[k] = String(v);
  return { message: { token, notification: { title: row.title, body: row.body }, data, android: { priority: 'high', notification: { icon: PUSH_ICON, color: PUSH_COLOR } } } };
}

/** Phones that no longer exist: FCM says the token is gone. */
export const tokenGone = (status: number, body: string) =>
  status === 404 || (status === 400 && body.includes('registration token is not a valid FCM registration token')) || body.includes('UNREGISTERED');

/** A short reason for push_outbox.error and the HTTP reply. */
export const errorText = (e: unknown) => (e instanceof Error ? e.message : String(e)).slice(0, 500);

export type Db = {
  pending(limit: number): Promise<OutboxRow[]>;
  tokens(userIds: string[]): Promise<{ token: string; user_id: string }[]>;
  markSent(id: number, error: string | null): Promise<void>;
  /** Notes why a row couldn't be sent yet; it stays pending and is retried. */
  markError(id: number, error: string): Promise<void>;
  dropToken(token: string): Promise<void>;
  /** F24: the users' notification switches; a user missing here has the defaults. */
  prefs?(userIds: string[]): Promise<Prefs>;
};

/** Sends up to [limit] pending rows. A row is "sent" once every phone of its
 *  user was tried; with no phones it is closed with error "no phones". */
export async function sendOutbox(db: Db, sa: ServiceAccount, f: Fetch, nowSecs: number, limit = 100) {
  const all = await db.pending(limit);
  if (all.length === 0) return { rows: 0, sent: 0, failed: 0, dropped: 0, errored: 0 };
  // F24: a switch turned off after the push was queued still counts.
  let prefs: Prefs = {};
  if (db.prefs) prefs = await db.prefs([...new Set(all.map((r) => r.user_id))]).catch(() => ({}));
  const rows: OutboxRow[] = [];
  for (const r of all) {
    if (wantsPush(prefs, r.user_id, r.kind ?? (r.data?.kind as string | undefined))) rows.push(r);
    else await db.markSent(r.id, 'switched off');
  }
  if (rows.length === 0) return { rows: all.length, sent: 0, failed: 0, dropped: 0, errored: 0 };
  let toks: { token: string; user_id: string }[], auth: string;
  try {
    toks = await db.tokens([...new Set(rows.map((r) => r.user_id))]);
    auth = await accessToken(sa, f, nowSecs);
  } catch (e) {
    // Nothing can be sent: say why on every row (they stay pending), then fail.
    const why = errorText(e);
    for (const row of rows) await db.markError(row.id, why).catch(() => {});
    throw e;
  }
  let sent = 0, failed = 0, dropped = 0, errored = 0;
  for (const row of rows) {
    try {
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
    } catch (e) {
      // One bad row doesn't stop the rest; it is retried next minute.
      errored++;
      await db.markError(row.id, errorText(e)).catch(() => {});
    }
  }
  return { rows: all.length, sent, failed, dropped, errored };
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
    // `*`: works before and after push_outbox.kind exists (FOUNDER-TODO 4zz3).
    pending: (limit) => call(`push_outbox?select=*&sent_at=is.null&order=id&limit=${limit}`),
    tokens: (ids) => call(`push_tokens?select=token,user_id&user_id=in.(${ids.map((i) => `"${i.replace(/"/g, '')}"`).join(',')})`),
    markSent: async (id, error) => {
      await call(`push_outbox?id=eq.${id}`, { method: 'PATCH', headers: { prefer: 'return=minimal' }, body: JSON.stringify({ sent_at: new Date().toISOString(), error }) });
    },
    markError: async (id, error) => {
      await call(`push_outbox?id=eq.${id}`, { method: 'PATCH', headers: { prefer: 'return=minimal' }, body: JSON.stringify({ error }) });
    },
    prefs: async (ids) => {
      const rows: { id: string; notify?: Record<string, unknown> }[] = await call(`profiles?select=id,notify&id=in.(${ids.map((i) => `"${i.replace(/"/g, '')}"`).join(',')})`);
      return Object.fromEntries(rows.map((r) => [r.id, r.notify ?? {}]));
    },
    dropToken: async (token) => {
      await call(`push_tokens?token=eq.${encodeURIComponent(token)}`, { method: 'DELETE', headers: { prefer: 'return=minimal' } });
    },
  };
}

/** The send-push request: checks the secret, sends, and on any failure answers
 *  500 with the reason (never a secret) so net._http_response shows it. */
export async function pushHandler(req: Request, env: (k: string) => string | undefined, f: Fetch, nowSecs: number, makeDb = restDb): Promise<Response> {
  const secret = env('PUSH_SECRET');
  if (!secret || req.headers.get('x-hz-secret') !== secret) return new Response('not allowed', { status: 401 });
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(env('FCM_SERVICE_ACCOUNT') ?? '{}');
  } catch {
    return new Response('send-push: FCM_SERVICE_ACCOUNT is not valid JSON (paste the whole file)', { status: 500 });
  }
  if (!sa.private_key) return new Response('FCM_SERVICE_ACCOUNT is not set', { status: 500 });
  if (!sa.client_email || !sa.project_id) return new Response('send-push: FCM_SERVICE_ACCOUNT has no client_email or project_id', { status: 500 });
  const url = env('SUPABASE_URL'), key = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return new Response('send-push: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing', { status: 500 });
  try {
    return Response.json(await sendOutbox(makeDb(url, key, f), sa, f, nowSecs));
  } catch (e) {
    console.error('send-push failed:', errorText(e));
    return new Response(`send-push: ${errorText(e)}`, { status: 500 });
  }
}
