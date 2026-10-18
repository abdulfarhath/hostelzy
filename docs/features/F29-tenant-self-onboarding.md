# F29 · The owner does less typing: Ask to join, ID by the tenant, contact buttons for everyone

**Stage:** Ideas (founder, 2026-10-18) → **Spec final (hub, 2026-10-18, under the founder's delegation)** → Design → Build
(29-30 in wave 1 · 29-10 + 29-23 in wave 2 · 29-20/21 in wave 4).

**Founder (2026-10-18):** the owner should not keep the mess of Aadhaar copies or type residents in. Like Notify / Message /
Call, the owner taps one button for a tenant who is not yet in the app → a link goes to the tenant on WhatsApp from the
owner's number → the tenant fills their own details and ID → the owner approves → the tenant is in the app. Hostelzy must not
store the tenant's ID (DPDP, pre-launch): it goes to the **owner's own Google Drive**; showing it back in the app is optional.
Also: Call / WhatsApp / Notify on **every** resident, not only the unpaid ones.

## Part 1 · Contact buttons for everyone (29-30, wave 1)
| Where | Change |
|---|---|
| S38 `oRent` | Every resident row gets **Call · WhatsApp** (today only unpaid rows have them). Message text by status: Paid → "Hi Ravi, thanks, August rent received. – <hostel>" · Due → today's reminder · Late → today's reminder |
| S40 `oMore · residents` | Every row: **Call · WhatsApp · Notify** (Notify = the existing push to that resident with a short typed note, sheet H6 `wa` style). Rows of residents without the app: Notify disabled with "Not on the app yet · Ask to join" (links to Part 2) |

## Part 2 · Ask to join (29-10 + 29-23, wave 2)
| Step | Who | What |
|---|---|---|
| 1 | Owner | Manage › Residents › **Ask to join** (red, next to Add a resident). Sheet **H48 `askJoin`**: pick a free bed (from the Building view's free beds), monthly fee (prefilled from the room's rate), advance (prefilled from terms), moves-in date (default today), optional first name. **Send on WhatsApp** → WhatsApp opens on the owner's phone with: "Hi! Join <hostel> on Hostelzy for bed 203. Fill your details here (2 min): <link>". Link = `https://farhath.me/hostelzy/app/j/?t=<token>` (opens the app if installed, else the web page W3 `app/j/` with the store/APK hint) |
| 2 | Tenant | Opens the link → sign in (Google) → **S94 `joinForm`** "Join <hostel> · bed 203 · ₹6,500/month": name, phone (from the account, editable), moves-in date (prefilled, editable), **ID**: "Take a photo of your Aadhaar (or any government ID)". Two ways, the owner's setting decides which shows: (a) owner has Drive connected → camera → the app masks the first 8 digits on the phone → uploads to the owner's Drive (Part 3); (b) no Drive → button **Send ID on WhatsApp** opens WhatsApp to the owner with "Here is my ID for bed 203" (the tenant attaches the photo themselves; nothing touches Hostelzy). Then **Send to owner**. Done state on the same screen: "Sent · <owner> will approve · we'll notify you" |
| 3 | Owner | Today › **Joining** group (new tab next to Holds · Payments · Fixes, shows only when non-empty): card "Ravi wants to join · bed 203 · moves in 1 Nov" → sheet **H49 `joinReview`**: name, phone, date, fee; ID row: Drive → the masked image inline (tap to open in Drive) · WhatsApp → checkbox **ID received on WhatsApp ✓**; **Approve** (red) / **Ask again** (sends a push + WhatsApp text "Please re-send your ID") / Decline |
| 4 | App | Approve → resident row (same as Add a resident: bed, fee, advance, date, phone → Fair Play hz_match as today), rent card for the tenant, push to the tenant "You're in. Welcome to <hostel>". `id_received` = drive \| whatsapp \| none, `id_file_id` (Drive id or null). The owner typed nothing but the bed and the date |

Rules (hub decisions): a token is single-use, 7 days, tied to one bed; sending again makes a new token; the bed is not held
(first approved wins; a second form for a taken bed tells the tenant "This bed was just taken, ask your owner"). The tenant's
name/phone/date are personal data we already hold for every resident (as today). **Hostelzy never stores the ID image or
number**: Drive gets the file, we keep the Drive file id; WhatsApp path stores only the tick.

## Part 3 · ID in the owner's Google Drive (29-20 / 29-21, wave 4)
| Piece | How |
|---|---|
| Connect | Manage › **Tenant IDs** row → sheet **H50 `drive`**: "Keep tenant IDs in your own Google Drive. Hostelzy never stores them." **Connect Google Drive** → Google consent with scope `drive.file` only (the app sees only files it made). Creates folder `Hostelzy / <hostel> / Tenant IDs`. Disconnect any time. Status line "Connected · 12 files". Until the Google consent screen has the scope (founder one-time step), the sheet says honestly "Not available yet" |
| Upload | Tenant's app → Edge Function `id-upload` (owner's refresh token, encrypted at rest in `owner_drive`, service role only) → Drive `files.create` in the folder → returns file id. The image is in memory only; never written to Storage or the DB; function logs carry no body |
| Masking | On the tenant's phone before upload: the first 8 digits of a 12-digit number found by OCR-free heuristic are **not** attempted (no OCR in v1); instead the tenant drags a black bar over the number with a guide "Cover the first 8 digits" and a preview; the owner's hostel setting **Full copy needed (police file)** turns the bar off |
| Show | H49 shows the image via `id-view` function (short-lived `webContentLink` through the owner's token); only the hostel's owner/managers |
| Delete | File belongs to the owner. On move-out we drop our pointer. H49 "Delete from my Drive" calls `files.delete` |
| OneDrive | Not now (v2) |

## Screens
| Id | Screen | Notes |
|---|---|---|
| **H48** `askJoin` (new sheet, owner) | Ask to join | bed, fee, advance, date, name, Send on WhatsApp |
| **S94** `joinForm` (new screen, tenant) | Join <hostel> | name, phone, date, ID (Drive camera or Send ID on WhatsApp), Send to owner; done state on the same screen (variant) |
| **H49** `joinReview` (new sheet, owner) | Ravi wants to join | details, ID row (image or tick), Approve / Ask again / Decline |
| **H50** `drive` (new sheet, owner) | Tenant IDs in your Drive | Connect / Disconnect, status, Full copy needed switch, "Not available yet" state (variant) |
| S36 `oToday` (changed) | Joining tab | only when non-empty |
| S38 `oRent`, S40 residents (changed) | Contact buttons on every row | — |
| W3 `app/j/` (changed) | `?t=` token opens the join form; no app → install hint | — |

## Server
Migration `f29_join.sql` (rerun-safe): `join_requests` (token, hostel_id, bed, fee, advance, moves_in, name_hint, status
sent|filled|approved|declined|expired, tenant uid, tenant name/phone/date, id_received, id_file_id, created_at,
expires_at), RLS (owner/managers of the hostel; the tenant their own row by token), RPCs `new_join_request`,
`fill_join_request(token, name, phone, date, id_received, id_file_id)`, `decide_join(id, approve, note)` (approve → the
same path as the owner's Add a resident), `ask_id_again(id)`. `owner_drive` (hostel_id, refresh_token enc, folder_id,
full_copy bool) service-role only. pg_cron: expire tokens. Edge Functions `id-upload`, `id-view` (wave 4). FOUNDER-TODO
one-time: Drive scope on the consent screen (wave 4). Everything ships with the new SQL autorun.

## Build notes
- Wave 1: Part 1 only. Wave 2: Part 2 with the WhatsApp ID path (`id_received = whatsapp|none`); the Drive option is hidden
  until `owner_drive` has a row. Wave 4: Part 3.
- Demo (sample data): one pending join request with a sample ID placeholder image (drawn, not a real document).
- SCREENS: +1 screen (S94), +3 sheets (H48–H50). Changed S36, S38, S40, W3.

## Not in the spec
Build lists extras here; the hub decides within the day. Known later items: OneDrive, OCR masking, police verification form export.

**Part 3, decided by Build 4 (2026-10-18, wave 4; the hub can change any of them):**
| # | What Build 4 did | Why |
|---|---|---|
| 1 | **Connect / Disconnect are the owner's only**; managers see the status line and can flip the Full copy switch | The token is the owner's Google account; `drive_status` / `set_full_copy` are for owner + managers as the spec says |
| 2 | The **Full copy switch shows only once Drive is connected** (it lives on `owner_drive`) | Without Drive the tenant sends the ID on WhatsApp, so there is nothing to mask |
| 3 | **Disconnect also revokes** Hostelzy's access at Google (`oauth2 /revoke`), then forgets the row; the files stay in the Drive | "Disconnect any time" should really end the access |
| 4 | **`id-view` gives a 10-minute link served by the function itself** (it streams the bytes with the owner's token) plus the file's Drive page link, instead of Google's `webContentLink` | `webContentLink` only works in a browser signed in as the owner, so a manager (or the app's image widget) could never open it |
| 5 | `id-upload` takes **JPEG / PNG / WebP up to 6 MB** (base64 JSON); the file is named `ID <date time>.jpg` | A limit the function can hold in memory |
| 6 | **IdCapture uses the camera only** (no gallery), shrinks the photo to 1600 px on the phone, and the bar is a fixed size (half the width, 9 % of the height) that the tenant drags; it starts over the lower middle of an Aadhaar card | One job per screen; the spec's "drag a black bar" |
| 7 | Reconnecting finds the same Drive folders and **starts the file count at 0** | The count is the app's own counter (`owner_drive.files`), not a Drive query |
| 8 | **Three Edge Function secrets** are needed: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` (the Web client of the same Google Cloud project), `DRIVE_TOKEN_KEY` (random, encrypts the tokens and signs the links); the functions deploy with `--no-verify-jwt` because the gateway can't check Firebase tokens (PostgREST checks them inside) | Founder one-time step (handover) |
| 9 | `id_upload_target` reads the token through a **hook function `join_hostel_for_token(text)`** that is a stub until wave 2's `join_requests` replaces it | Wave 4 was built apart from wave 2 (`docs/handover/w4-build.md`) |

## Design
Boards H48, S94 (+ done variant), H49 (+ Drive and WhatsApp variants), H50 (+ not-available variant), S36 Joining tab variant,
S38/S40 with buttons on every row. Light + dark for S94 and H49.

## Build · Part 3 (wave 4, Build 4, 2026-10-18)
Branch `feature/w4-drive-fresh`, not merged; the integrator wires it after wave 2 (`docs/handover/w4-build.md`).
| Piece | Where | State |
|---|---|---|
| `owner_drive` + RPCs `drive_status`, `set_full_copy`, `drive_role`, `id_upload_target`; service-role `drive_put` / `drive_token` / `drive_forget` / `drive_file_added`; pgcrypto with the server secret | `supabase/migrations/20261018140000_f29_drive.sql`, test `supabase/tests/f29_drive_test.sql` | Done, rerun-safe |
| Edge Functions `drive-connect`, `id-upload`, `id-view` (shared `_shared/drive.ts`), 10 Node tests | `supabase/functions/…`, `supabase/functions/tests/drive.test.ts`, deploy lines in `.github/workflows/supabase-functions.yml` | Done |
| Sheet **H50** `drive` (Connect / Disconnect / status / Full copy switch / "Not available yet" variant), Manage › **Tenant IDs** row | `hostelzy/lib/features/drive/drive.dart`, `drive_sheets.dart`, `drive_auth.dart`; `owner_manage_screen.dart`; `ui/shell.dart` | Done, light + dark |
| `IdCapture` (camera → "Cover the first 8 digits" bar → preview → `id-upload`) for S94; `IdThumb` (via `id-view`, tap opens Drive) for H49; repo `idTarget` / `idUpload` / `idView` / `idDelete` | `hostelzy/lib/features/drive/id_capture.dart`, `id_thumb.dart`; `features/listings/repo.dart` + both repos | Done; S94 / H49 wire them (wave 2) |
| Flow tests (10) | `hostelzy/test/w4_drive_test.dart` | Green with `tools/check.sh` |
| FOUNDER-TODO one-time line, SCREENS rows for H50, SQL bundle | In the handover; the integrator adds them (not edited here on purpose) | Open |
