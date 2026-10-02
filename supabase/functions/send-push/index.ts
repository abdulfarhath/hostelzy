// B5: sends pending push notifications (public.push_outbox) with FCM.
// Called every minute by pg_cron (pg_net) with the x-hz-secret header; see
// docs/FOUNDER-TODO.md. Secrets (Supabase → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT  the Firebase service account JSON (never in the repo)
//   PUSH_SECRET          a random string, also stored in Vault for the cron call
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
import { restDb, sendOutbox, type ServiceAccount } from '../_shared/fcm.ts';

Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET');
  if (!secret || req.headers.get('x-hz-secret') !== secret) return new Response('not allowed', { status: 401 });
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}') as ServiceAccount;
  if (!sa.private_key) return new Response('FCM_SERVICE_ACCOUNT is not set', { status: 500 });
  const db = restDb(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, fetch);
  const out = await sendOutbox(db, sa, fetch, Math.floor(Date.now() / 1000));
  return Response.json(out);
});
