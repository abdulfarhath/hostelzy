// F29 Part 3: the owner or a manager sees a tenant's ID from Drive through a
// short-lived link, or deletes it from the owner's Drive (_shared/drive.ts).
// Deployed with --no-verify-jwt: the GET link carries its own signed ticket.
import { viewHandler } from '../_shared/drive.ts';

Deno.serve((req) => viewHandler(req, (k) => Deno.env.get(k), fetch, Math.floor(Date.now() / 1000)));
