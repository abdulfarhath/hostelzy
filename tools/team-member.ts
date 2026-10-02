// Founder tool, run by .github/workflows/team-member.yml:
//   node --experimental-strip-types tools/team-member.ts <email> <add|remove>
// Needs FIREBASE_SERVICE_ACCOUNT (the service account JSON) in the environment.
import { setTeam } from '../supabase/functions/_shared/team.ts';

const [email, action] = process.argv.slice(2);
const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
if (!sa.private_key) {
  console.error('FIREBASE_SERVICE_ACCOUNT is not set (GitHub → Settings → Secrets → Actions).');
  process.exit(1);
}
if (action !== 'add' && action !== 'remove') {
  console.error('Usage: team-member.ts <email> <add|remove>');
  process.exit(1);
}
try {
  console.log(await setTeam(sa, email ?? '', action === 'add', fetch, Math.floor(Date.now() / 1000)));
} catch (e) {
  console.error((e as Error).message);
  process.exit(1);
}
