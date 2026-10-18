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

## Build · Part 1 (wave 1, branch `feature/w1-filter-wall-contacts`, PR #W1, 2026-10-18)
- **Model** `lib/data/residents.dart`: `Resident.uid` (`stays.user_id`; `onApp`) and `Resident.paidOn` (the last paid rent's
  `confirmed_at` / `created_at`; a move-in payment = the join date; the sample rows carry their dates), parsed in
  `features/listings/live.dart` `residentFromRow`; `copy()` and the Fair Play fix path keep both.
- **S38** `features/owner/owner_rent_screen.dart`: **Call · WhatsApp** on every row (the Paid rows' blank spacer went);
  `rentThanks(s, r)` = "Hi Ravi, thanks, August rent received. – <hostel>" (the month of the payment), `rentWhatsApp(s, r)` by
  status (Paid → thanks; Due / Late / Waiting → `rentReminder`).
- **S40** `features/owner/owner_manage_screen.dart` (`_Residents`, `_ContactBtn`): under every row **Call** (`call`),
  **WhatsApp** (the H6 sheet with the Beds › Message resident greeting, `openWA`), **Notify** (`openNotify`); a resident without
  the app: Notify muted, no tap, and "Not on the app yet · Ask to join" as plain text (key `resNoApp-<bed>`).
- **Notify** `features/residents/residents.dart` `openNotify` / `sendNote`: the H6 `wa` sheet in its Notify form (`waMode =
  'notify'`, `noteDraft`, `noteTo` in `reviews.dart`; `WaSheet` in `features/holds/holds_sheets.dart`; title "Notify X", kicker
  "Residents · bed N" in `ui/shell.dart`): the note field and **Send**, nothing else (F31 Rule A). `HostelRepo.notifyResident
  (stayKey, note)` → `SupabaseRepo` RPC `notify_resident(p_stay, p_note)`; a missing function → `UnsupportedError` → toast "Not
  available yet. Use WhatsApp."; sample data (no server) → "Sent to Ravi." like the demo's other sample actions. Toasts ≤ 6 words.
- **Tests** `hostelzy/test/f29_contacts_test.dart` (5): Rent rows and texts by status (the Paid filter too); Residents rows,
  Notify off with the text, WhatsApp → H6, the note sends, WhatsApp is the plain sheet again; the server path (`uid`, `paidOn`,
  the RPC call, "not available yet"); Rent and Residents fit 360 px at 2× text, light and dark. Updated `owner_test`,
  `f26_owner_test` (paid rows have the buttons now). No SQL in wave 1.

## Not in the spec
- **Notify needs SQL** (wave 1 ships none): the app has no push it can send today (`push_outbox` has no client policy;
  `tell_resident` is server-internal, execute revoked). The app already calls RPC **`notify_resident(p_stay uuid, p_note
  text)`** and says "Not available yet. Use WhatsApp." until it exists. For wave 2's `f29_join.sql` (or now, if the hub says so):
  `security definer set search_path = ''`; only staff of the stay's hostel (`is_staff`); the stay current (`left_on is null`)
  with a `user_id`; `p_note` trimmed, 1–200 chars; `insert into push_outbox (user_id, title, body, data, kind)` with the hostel's
  name as the title, the note as the body, `{"screen":"rHome"}`, kind `note`; `grant execute … to authenticated`; a SQL test.
  decided: wire the app now, the function lands with Part 2.
- The note sheet is a **variant of H6 `wa`** (same key, `waMode`), not a new sheet id: Design draws no new board; the hub may
  give it its own id later. decided.
- S40 WhatsApp text = the existing Beds › Message resident greeting ("Hi, this is <owner> from <hostel>."), through the H6
  sheet, as the bed sheet does. decided.
- "Ask to join" is plain text in wave 1; wave 2 (H48) turns it into the link: open H48 for that resident from key
  `resNoApp-<bed>`. (For wave 2.)
- Sample data: who is on the app (Rahul Varma, Sai Kiran, Nikhil Goud, Ravi Teja = the demo resident and those who came
  through Hostelzy) and the paid dates added to the sample rows. decided.
- "On the app" = an account on the stay (`stays.user_id`), so an owner-added resident who never signed up gets the text. decided.
- Build lists extras here; the hub decides within the day. Known later items: OneDrive, OCR masking, police verification form export.

## Design
**Design approved** (Design, 2026-10-18). Canvas v25 on branch `design/f26-merge` (`docs/design/v25/`, hub publishes). Sample: bed 203-B · ₹8,000/month (room 203's rate) · advance ₹3,000 · Ravi Teja · owner Srinivas.
- **[H48]** askJoin over Residents: free-bed chips, Monthly fee, Advance, Moves in, First name (optional), Send on WhatsApp.
- **[S94]** joinForm light + dark: name, phone (+91, from the account), moves in, ID box "Take a photo of your Aadhaar (or any government ID)" with Send ID on WhatsApp (the Drive camera path is wave 4, not drawn), Send to owner. [variant] done: "Sent · Srinivas will approve · we'll notify you" + the values.
- **[H49]** joinReview over Today › Joining: name, phone, moves in, fee, advance, ID row as a checkbox "ID received on WhatsApp" (main), ✓ ticked variant, Drive variant with the masked image, Open in Drive, Delete from my Drive; Approve (red) / Ask again / Decline. Dark of the main.
- **[H50]** drive over Manage: "Full copy needed (police file)" switch, Connect Google Drive (red); variants Connected · 12 files + Disconnect, and "Not available yet" (button disabled).
- [variant of S36] Today with the Joining tab (Holds · Payments · Joining · Fixes per F31 Rule B) and the card "Ravi wants to join · Bed 203-B · moves in 1 Nov".
- S38 (+ dark): Call · WhatsApp on the Paid row too. S40: Call · WhatsApp · Notify on every row (Notify disabled + "Not on the app yet · Ask to join ›" for a resident without the app), red Add resident · Ask to join in the beds notice.
Rule A (F31) applied: no helper lines, no sheet intros. Not drawn: S39 Manage "Tenant IDs" row (not in the hub's list), W3 `app/j/` join-token copy (Build's wording).


## Hub decisions on Build 4's Part 3 extras (2026-10-18 20:45)
1–10 accepted as built (owner-only connect, switch only when connected, revoke on disconnect, 10-minute proxied view link,
JPEG/PNG/WebP ≤ 6 MB, camera-only capture with a fixed draggable bar, counter restarts on reconnect, 3 Edge Function secrets
added to the founder's one-time list, `join_hostel_for_token` hook replaced by wave 2 at integration, Rule A applied).

## Hub decisions on Build 2's wave 2 extras (2026-10-18 20:50)
F29 #1–7 accepted as built (`join_request_info(token)`, Ask to join alone under search, Approve needs an ID (tick or Drive file),
Drive stub replaced by Build 4's pieces at integration, Rule A, demo without an ID image, no Realtime).
