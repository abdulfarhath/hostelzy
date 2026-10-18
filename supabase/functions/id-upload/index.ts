// F29 Part 3: the tenant's masked ID photo goes to the owner's Google Drive.
// The image is in memory only: never stored, never logged (_shared/drive.ts).
// Deployed with --no-verify-jwt: PostgREST checks the tenant's Firebase token.
import { uploadHandler } from '../_shared/drive.ts';

Deno.serve((req) => uploadHandler(req, (k) => Deno.env.get(k), fetch, Math.floor(Date.now() / 1000)));
