// F29 Part 3 (wave 4): tenant IDs in the owner's own Google Drive.
// Plain TypeScript with fetch and WebCrypto only, so it runs on Supabase Edge
// (Deno) and in the Node tests (supabase/functions/tests/drive.test.ts).
//
// Three functions share this file:
//   drive-connect  the owner's app sends Google's server auth code (scope
//                  drive.file) → refresh token → folder "Hostelzy / <hostel>
//                  / Tenant IDs" → stored encrypted (SQL drive_put). Also
//                  disconnect: revoke at Google, forget the row.
//   id-upload      the tenant's app (signed in, with a join token) sends the
//                  masked ID photo → Drive files.create in the owner's folder
//                  with the owner's token → the file id. The image lives in
//                  memory for the length of the call: never written to
//                  Storage or the database, never logged.
//   id-view        the owner or a manager asks for a file → a short-lived
//                  link (10 min) back to this function, which streams the
//                  bytes through the owner's token; "Delete from my Drive".
//
// Secrets (Supabase → Edge Functions → Secrets; docs/FOUNDER-TODO.md):
//   GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET  the Web client of
//                  the Google Cloud project (same one as Google sign-in)
//   DRIVE_TOKEN_KEY  a long random string: encrypts the refresh tokens in
//                  the database and signs the view links
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY come from
// Supabase. Without the three secrets every call answers 503 `not_ready`
// and the app says "Not available yet".

export type Env = (k: string) => string | undefined;
export type Fetch = typeof fetch;

export const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive.file';
export const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
/** How long a view link works. */
export const VIEW_SECS = 600;

const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-headers': 'authorization, content-type', 'access-control-allow-methods': 'GET, POST, OPTIONS' };

/** A refusal the app can show: `{ error, message }` with the HTTP status. */
export class HzError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store', ...CORS } });

/** The first missing secret, or null when all three are set. */
export function missingSecret(env: Env): string | null {
  for (const k of ['GOOGLE_OAUTH_CLIENT_ID', 'GOOGLE_OAUTH_CLIENT_SECRET', 'DRIVE_TOKEN_KEY', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ANON_KEY']) {
    if (!env(k)) return k;
  }
  return null;
}

const b64url = (b: Uint8Array | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64url = (s: string) => atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4));

/** The Firebase uid (`sub`) in a JWT. Not verified here: PostgREST verifies
 *  the same token on every `rpcAsUser` call, and that call decides the role. */
export function uidOf(jwt: string): string | null {
  try {
    const sub = JSON.parse(unb64url(jwt.split('.')[1])).sub;
    return typeof sub === 'string' && sub ? sub : null;
  } catch {
    return null;
  }
}

export const bearer = (req: Request) => (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();

// ------------------------------------------------------------ PostgREST

async function rpc(env: Env, f: Fetch, fn: string, args: Record<string, unknown>, auth: string): Promise<unknown> {
  const r = await f(`${env('SUPABASE_URL')}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: env('SUPABASE_ANON_KEY')!, authorization: `Bearer ${auth}`, 'content-type': 'application/json' },
    body: JSON.stringify(args),
  });
  const text = await r.text();
  if (!r.ok) {
    let msg = text;
    try {
      msg = JSON.parse(text).message ?? text;
    } catch { /* plain text */ }
    // 401: the user's token is bad or expired; anything else is the SQL's own words.
    throw new HzError(r.status === 401 ? 401 : 400, r.status === 401 ? 'sign_in' : 'sql', r.status === 401 ? 'Sign in again' : String(msg).slice(0, 200));
  }
  return text ? JSON.parse(text) : null;
}

/** Runs as the signed-in user (RLS + public.uid()). */
export const rpcAsUser = (env: Env, f: Fetch, jwt: string, fn: string, args: Record<string, unknown>) => rpc(env, f, fn, args, jwt);
/** Runs as the service role (the owner_drive functions). */
export const rpcAsServer = (env: Env, f: Fetch, fn: string, args: Record<string, unknown>) => rpc(env, f, fn, args, env('SUPABASE_SERVICE_ROLE_KEY')!);

/** `drive_role(h)`: 'owner' | 'manager' and the hostel's name, or null. */
export async function roleOn(env: Env, f: Fetch, jwt: string, hostelId: string): Promise<{ role: string; name: string } | null> {
  const rows = (await rpcAsUser(env, f, jwt, 'drive_role', { h: hostelId })) as { role: string; name: string }[] | null;
  return rows?.[0] ?? null;
}

type Stored = { refresh_token: string; folder_id: string; full_copy: boolean };

/** The owner's stored token (decrypted in the database with the key). */
export async function stored(env: Env, f: Fetch, hostelId: string): Promise<Stored> {
  const rows = (await rpcAsServer(env, f, 'drive_token', { h: hostelId, p_key: env('DRIVE_TOKEN_KEY') })) as Stored[] | null;
  const s = rows?.[0];
  if (!s) throw new HzError(409, 'not_connected', 'The owner hasn’t connected Google Drive');
  return s;
}

// ------------------------------------------------------------ Google

const form = (o: Record<string, string>) => new URLSearchParams(o);

/** Server auth code → refresh token. Checks Google granted drive.file. */
export async function exchangeCode(env: Env, f: Fetch, code: string): Promise<string> {
  const r = await f('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: form({ code, client_id: env('GOOGLE_OAUTH_CLIENT_ID')!, client_secret: env('GOOGLE_OAUTH_CLIENT_SECRET')!, grant_type: 'authorization_code', redirect_uri: '' }),
  });
  if (!r.ok) throw new HzError(400, 'no_scope', `Google didn’t allow Drive access (${r.status})`);
  const t = (await r.json()) as { refresh_token?: string; scope?: string };
  if (!(t.scope ?? '').split(' ').includes(DRIVE_SCOPE)) throw new HzError(400, 'no_scope', 'Google didn’t allow Drive access');
  if (!t.refresh_token) throw new HzError(400, 'no_refresh', 'Google didn’t give Hostelzy a lasting permission. Remove Hostelzy in your Google account (Security › Third-party access) and try again.');
  return t.refresh_token;
}

/** A fresh access token for the owner's Drive. */
export async function accessToken(env: Env, f: Fetch, refreshToken: string): Promise<string> {
  const r = await f('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: form({ refresh_token: refreshToken, client_id: env('GOOGLE_OAUTH_CLIENT_ID')!, client_secret: env('GOOGLE_OAUTH_CLIENT_SECRET')!, grant_type: 'refresh_token' }),
  });
  // invalid_grant: the owner removed Hostelzy in their Google account.
  if (!r.ok) throw new HzError(409, 'not_connected', 'Google Drive access was removed. The owner can connect it again.');
  return ((await r.json()) as { access_token: string }).access_token;
}

export async function revoke(f: Fetch, token: string): Promise<void> {
  await f('https://oauth2.googleapis.com/revoke', { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: form({ token }) }).catch(() => {});
}

const DRIVE = 'https://www.googleapis.com/drive/v3';
const FOLDER = 'application/vnd.google-apps.folder';

async function google(f: Fetch, auth: string, url: string, init: RequestInit = {}): Promise<Response> {
  const r = await f(url, { ...init, headers: { ...(init.headers as Record<string, string> | undefined), authorization: `Bearer ${auth}` } });
  if (!r.ok) throw new HzError(502, 'google', `Google Drive: ${r.status}`);
  return r;
}

/** The folder [name] under [parent] (the app's own; drive.file sees only those), made when missing. */
export async function ensureFolder(f: Fetch, auth: string, name: string, parent?: string): Promise<string> {
  const q = [`name = '${name.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`, `mimeType = '${FOLDER}'`, 'trashed = false', parent ? `'${parent}' in parents` : null].filter(Boolean).join(' and ');
  const found = (await (await google(f, auth, `${DRIVE}/files?q=${encodeURIComponent(q)}&fields=files(id)&pageSize=1`)).json()) as { files?: { id: string }[] };
  if (found.files?.[0]) return found.files[0].id;
  const made = await google(f, auth, `${DRIVE}/files?fields=id`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name, mimeType: FOLDER, ...(parent ? { parents: [parent] } : {}) }),
  });
  return ((await made.json()) as { id: string }).id;
}

/** "Hostelzy / <hostel> / Tenant IDs". */
export async function tenantIdsFolder(f: Fetch, auth: string, hostelName: string): Promise<string> {
  const top = await ensureFolder(f, auth, 'Hostelzy');
  const mine = await ensureFolder(f, auth, hostelName, top);
  return ensureFolder(f, auth, 'Tenant IDs', mine);
}

/** files.create (multipart): the image goes straight from memory to Drive. */
export async function uploadFile(f: Fetch, auth: string, folderId: string, name: string, mime: string, bytes: Uint8Array): Promise<string> {
  const boundary = 'hz_' + crypto.randomUUID();
  const enc = new TextEncoder();
  const head = enc.encode(`--${boundary}\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify({ name, parents: [folderId] })}\r\n--${boundary}\r\ncontent-type: ${mime}\r\n\r\n`);
  const tail = enc.encode(`\r\n--${boundary}--`);
  const body = new Uint8Array(head.length + bytes.length + tail.length);
  body.set(head, 0);
  body.set(bytes, head.length);
  body.set(tail, head.length + bytes.length);
  const r = await google(f, auth, 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id', {
    method: 'POST',
    headers: { 'content-type': `multipart/related; boundary=${boundary}` },
    body,
  });
  return ((await r.json()) as { id: string }).id;
}

export const downloadFile = (f: Fetch, auth: string, fileId: string) => google(f, auth, `${DRIVE}/files/${encodeURIComponent(fileId)}?alt=media`);
export const deleteFile = (f: Fetch, auth: string, fileId: string) => google(f, auth, `${DRIVE}/files/${encodeURIComponent(fileId)}`, { method: 'DELETE' });
/** Where the owner opens the file in Drive themselves. */
export const driveLink = (fileId: string) => `https://drive.google.com/file/d/${encodeURIComponent(fileId)}/view`;

// ------------------------------------------------------------ view tickets

async function hmac(key: string, data: string): Promise<string> {
  const k = await crypto.subtle.importKey('raw', new TextEncoder().encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(new Uint8Array(await crypto.subtle.sign('HMAC', k, new TextEncoder().encode(data))));
}

/** A link ticket: hostel, file and expiry, signed with DRIVE_TOKEN_KEY. */
export async function mintTicket(key: string, hostelId: string, fileId: string, expSecs: number): Promise<string> {
  const payload = b64url(JSON.stringify({ h: hostelId, f: fileId, e: expSecs }));
  return `${payload}.${await hmac(key, payload)}`;
}

export async function readTicket(key: string, ticket: string, nowSecs: number): Promise<{ hostelId: string; fileId: string } | null> {
  const [payload, sig] = ticket.split('.');
  if (!payload || !sig || sig !== (await hmac(key, payload))) return null;
  try {
    const p = JSON.parse(unb64url(payload)) as { h: string; f: string; e: number };
    if (typeof p.e !== 'number' || p.e < nowSecs) return null;
    return { hostelId: p.h, fileId: p.f };
  } catch {
    return null;
  }
}

// ------------------------------------------------------------ handlers

/** Runs [fn], turning refusals into JSON. Logs a code, never a body. */
async function guard(name: string, env: Env, req: Request, fn: () => Promise<Response>): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  const miss = missingSecret(env);
  if (miss) return json(503, { error: 'not_ready', message: `Not available yet (${miss} isn’t set)` });
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HzError) {
      console.error(`${name}: ${e.code}`);
      return json(e.status, { error: e.code, message: e.message });
    }
    console.error(`${name}: ${(e as Error)?.name ?? 'error'}`);
    return json(500, { error: 'failed', message: 'Couldn’t do that. Try again.' });
  }
}

async function body(req: Request): Promise<Record<string, unknown>> {
  try {
    const b = (await req.json()) as Record<string, unknown>;
    return b && typeof b === 'object' ? b : {};
  } catch {
    throw new HzError(400, 'bad_request', 'Send JSON');
  }
}

const str = (v: unknown) => (typeof v === 'string' ? v.trim() : '');

/** drive-connect: `{ hostel_id, code }` to connect, `{ hostel_id, action: 'disconnect' }` to disconnect. Owner only. */
export function connectHandler(req: Request, env: Env, f: Fetch, _nowSecs: number): Promise<Response> {
  return guard('drive-connect', env, req, async () => {
    const jwt = bearer(req);
    const uid = uidOf(jwt);
    if (!uid) throw new HzError(401, 'sign_in', 'Sign in first');
    const b = await body(req);
    const hostelId = str(b.hostel_id);
    if (!hostelId) throw new HzError(400, 'bad_request', 'Which hostel?');
    const who = await roleOn(env, f, jwt, hostelId);
    if (who?.role !== 'owner') throw new HzError(403, 'not_owner', 'Only the owner connects Google Drive');
    if (str(b.action) === 'disconnect') {
      let s: Stored | null = null;
      try {
        s = await stored(env, f, hostelId);
      } catch (e) {
        if (!(e instanceof HzError && e.code === 'not_connected')) throw e;
      }
      if (s) await revoke(f, s.refresh_token);
      await rpcAsServer(env, f, 'drive_forget', { h: hostelId });
      return json(200, { connected: false, files: 0, full_copy: false });
    }
    const code = str(b.code);
    if (!code) throw new HzError(400, 'bad_request', 'No Google code');
    const refresh = await exchangeCode(env, f, code);
    const auth = await accessToken(env, f, refresh);
    const folder = await tenantIdsFolder(f, auth, who.name);
    await rpcAsServer(env, f, 'drive_put', { h: hostelId, p_uid: uid, p_token: refresh, p_folder: folder, p_key: env('DRIVE_TOKEN_KEY') });
    return json(200, { connected: true, files: 0, full_copy: false });
  });
}

/** id-upload: `{ token, image (base64), mime }` from the tenant's app → `{ file_id }`. */
export function uploadHandler(req: Request, env: Env, f: Fetch, nowSecs: number): Promise<Response> {
  return guard('id-upload', env, req, async () => {
    const jwt = bearer(req);
    if (!uidOf(jwt)) throw new HzError(401, 'sign_in', 'Sign in first');
    const b = await body(req);
    const token = str(b.token), image = str(b.image), mime = str(b.mime) || 'image/jpeg';
    if (!token) throw new HzError(400, 'bad_request', 'No join token');
    if (!image) throw new HzError(400, 'bad_request', 'No image');
    if (!/^image\/(jpeg|png|webp)$/.test(mime)) throw new HzError(400, 'bad_request', 'Send a JPEG, PNG or WebP');
    if (image.length > (MAX_IMAGE_BYTES * 4) / 3 + 4) throw new HzError(413, 'too_big', 'The photo is too big (6 MB max)');
    let bytes: Uint8Array;
    try {
      bytes = Uint8Array.from(atob(image), (c) => c.charCodeAt(0));
    } catch {
      throw new HzError(400, 'bad_request', 'The image isn’t base64');
    }
    if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) throw new HzError(413, 'too_big', 'The photo is too big (6 MB max)');
    // Which hostel this join token is for (the SQL checks the token is the caller's).
    const target = ((await rpcAsUser(env, f, jwt, 'id_upload_target', { p_token: token })) as { hostel_id: string; full_copy: boolean }[] | null)?.[0];
    if (!target) throw new HzError(400, 'bad_request', 'This link isn’t valid any more');
    const s = await stored(env, f, target.hostel_id);
    const auth = await accessToken(env, f, s.refresh_token);
    const d = new Date(nowSecs * 1000).toISOString().slice(0, 16).replace('T', ' ');
    const fileId = await uploadFile(f, auth, s.folder_id, `ID ${d}.${mime === 'image/png' ? 'png' : mime === 'image/webp' ? 'webp' : 'jpg'}`, mime, bytes);
    await rpcAsServer(env, f, 'drive_file_added', { h: target.hostel_id, delta: 1 });
    return json(200, { file_id: fileId });
  });
}

/** id-view: POST `{ hostel_id, file_id }` (owner / manager) → `{ url, until, open }`;
 *  POST `{ ..., action: 'delete' }` → files.delete; GET `?t=<ticket>` → the image. */
export function viewHandler(req: Request, env: Env, f: Fetch, nowSecs: number): Promise<Response> {
  return guard('id-view', env, req, async () => {
    const key = env('DRIVE_TOKEN_KEY')!;
    if (req.method === 'GET') {
      const t = new URL(req.url).searchParams.get('t') ?? '';
      const ok = await readTicket(key, t, nowSecs);
      if (!ok) throw new HzError(403, 'expired', 'This link has expired. Open the ID again in the app.');
      const s = await stored(env, f, ok.hostelId);
      const auth = await accessToken(env, f, s.refresh_token);
      const r = await downloadFile(f, auth, ok.fileId);
      return new Response(r.body, { status: 200, headers: { 'content-type': r.headers.get('content-type') ?? 'image/jpeg', 'cache-control': 'private, no-store', ...CORS } });
    }
    const jwt = bearer(req);
    if (!uidOf(jwt)) throw new HzError(401, 'sign_in', 'Sign in first');
    const b = await body(req);
    const hostelId = str(b.hostel_id), fileId = str(b.file_id);
    if (!hostelId || !fileId) throw new HzError(400, 'bad_request', 'Which file?');
    const who = await roleOn(env, f, jwt, hostelId);
    if (!who) throw new HzError(403, 'not_staff', 'Only the hostel’s owner and managers see tenant IDs');
    if (str(b.action) === 'delete') {
      const s = await stored(env, f, hostelId);
      const auth = await accessToken(env, f, s.refresh_token);
      await deleteFile(f, auth, fileId);
      await rpcAsServer(env, f, 'drive_file_added', { h: hostelId, delta: -1 });
      return json(200, { deleted: true });
    }
    const until = nowSecs + VIEW_SECS;
    const ticket = await mintTicket(key, hostelId, fileId, until);
    return json(200, { url: `${env('SUPABASE_URL')}/functions/v1/id-view?t=${ticket}`, until, open: driveLink(fileId) });
  });
}
