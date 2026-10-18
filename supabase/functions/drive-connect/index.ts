// F29 Part 3: the owner connects (or disconnects) their Google Drive for
// tenant IDs. Deployed with --no-verify-jwt: the user's Firebase token is
// checked by PostgREST on the drive_role call (see _shared/drive.ts).
import { connectHandler } from '../_shared/drive.ts';

Deno.serve((req) => connectHandler(req, (k) => Deno.env.get(k), fetch, Math.floor(Date.now() / 1000)));
