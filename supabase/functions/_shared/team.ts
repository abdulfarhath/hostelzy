// B7: adds or removes the Firebase custom claim `team: true` on a Google
// account, through the Identity Toolkit REST API with the service account.
// Run by the founder's "Team member" GitHub action (tools/team-member.ts).
// Supabase's public.is_team() and the app's team mode read this claim.

import { accessToken, type Fetch, type ServiceAccount } from './fcm.ts';

const SCOPE = 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/identitytoolkit';

export async function setTeam(sa: ServiceAccount, email: string, on: boolean, f: Fetch, nowSecs: number): Promise<string> {
  const addr = email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(addr)) throw new Error(`Not an email address: ${email}`);
  const auth = await accessToken(sa, f, nowSecs, SCOPE);
  const base = `https://identitytoolkit.googleapis.com/v1/projects/${sa.project_id}`;
  const post = async (path: string, body: unknown) => {
    const r = await f(`${base}/${path}`, { method: 'POST', headers: { authorization: `Bearer ${auth}`, 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (!r.ok) throw new Error(`${path}: ${r.status} ${await r.text()}`);
    return r.json();
  };
  const found = await post('accounts:lookup', { email: [addr] });
  const user = found.users?.[0];
  if (!user) throw new Error(`${addr} hasn't signed in to Hostelzy yet. Sign in once in the app, then run this again.`);
  const claims = JSON.parse(user.customAttributes || '{}');
  if (on) claims.team = true;
  else delete claims.team;
  await post('accounts:update', { localId: user.localId, customAttributes: JSON.stringify(claims) });
  return on ? `${addr} is now on the Hostelzy team. They sign out and in again (or wait up to an hour).` : `${addr} is no longer on the Hostelzy team.`;
}
