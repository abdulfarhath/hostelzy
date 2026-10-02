// B5: sends pending push notifications (public.push_outbox) with FCM.
// Called every minute by pg_cron (pg_net) with the x-hz-secret header; see
// docs/FOUNDER-TODO.md. Secrets (Supabase → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT  the Firebase service account JSON (never in the repo)
//   PUSH_SECRET          a random string, also stored in Vault for the cron call
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
import { pushHandler } from '../_shared/fcm.ts';

Deno.serve((req) => pushHandler(req, (k) => Deno.env.get(k), fetch, Math.floor(Date.now() / 1000)));
