# Wave 2 handover · Build 2 → the integrating Build chat (2026-10-18)

Branch **`feature/w2-add-join`** from `main` @ a196b69. Not merged. F28 **Part 2** (S92, S93, entry points, dedupe, rewards
₹200 / ₹20 with the ₹2,000 cap, partner code, migration) and F29 **Part 2** (H48, S94, H49, Today › Joining, approve path,
pushes, W3 `?t=`, migration). App + SQL + web only; `app/console` untouched (Build 3). The two feature files' Build sections
list every piece and the "Not in the spec" items.

## 1. What is on the branch
| Area | Files |
|---|---|
| New feature folders | `hostelzy/lib/features/add_hostel/` (`add_hostel.dart` part of state, `add_hostel_screens.dart`), `hostelzy/lib/features/join/` (`join.dart`, `join_screens.dart`) |
| Shared app files (edits appended, marked `// W2`) | `state.dart` (2 parts, 2 mixins, 3 screen keys, `partnerCode` restore), `ui/shell.dart` (3 screens, 2 sheets + titles/kickers, 2 sign-in titles), `router.dart` (`/r?h=`, `/j?t=`), `features/listings/repo.dart` + `supabase_repo.dart` + `sample_repo.dart` (10 methods), `features/session/on_phone.dart` (snapshot), `features/session/guest_screens.dart` (2 sign-in lines), `features/photos/pick.dart` (`cameraPick`), `features/explore/explore_screen.dart` (`AddItRow`), `features/session/me_screen.dart` (row), `features/residents/resident_screens.dart` (T20 button), `features/rewards/rewards_screens.dart` (row), `features/owner/owner_today_screen.dart` (Joining group), `features/owner/owner_manage_screen.dart` (Ask to join button), `features/map/map_screen.dart` (pin kicker), `features/onboarding/onboarding.dart` (`pinFor`) |
| SQL | `supabase/migrations/20261018100000_f28_add_hostels.sql`, `20261018110000_f29_join.sql`; tests `supabase/tests/f28_add_hostels_test.sql`, `f29_join_test.sql` (+ 2 lines in `tests/run.sh`) |
| Web | `app/r/index.html` (`?h=&claim=1`), `app/j/index.html` (`?t=`) |
| Tests | `hostelzy/test/w2_add_join_test.dart` (8 flows) |
| Docs | F28 + F29 Build sections, this file |

Not touched on purpose: `docs/SCREENS.md`, `docs/BOARD.md`, `docs/FOUNDER-TODO.md`, the SQL bundle (`docs/sql/`), `app/console`, `main`.

## 2. Integration notes
1. **Columns shared with Build 3** (`feature/w3-import`, migration `20261018120000_f28_import.sql`, runs after mine): both add the
   six `hostels` columns with `add column if not exists` and the same `hostels_source_check` constraint text. Mine also adds
   `partner_code`, `owner_asked_at`; Build 3 adds `source_photos`, `removed_at`, `call_after`. No conflict.
2. **Owner phone**: `add_hostel` writes the number to `hostel_leads.owner_phone` (team-only) and leaves `owner_phone_hint = ''`.
   It dedupes with `public.hostel_owner_phone(h)`; my migration carries a stub with Build 3's exact body (`create or replace`,
   so theirs wins after). Build 3's `hostels_phone_hint` trigger is harmless on my rows (nothing to move).
3. **Console names Build 3 calls**: `new_partner(p_name text, p_phone text, p_upi text) returns text` ✓ and
   `partners_due() returns table (code, name, phone, upi, active, listed, checked, due, paid)` — the 7 columns Build 3 reads
   are all there (plus `checked`, `paid`). Extra RPCs the console can use: `check_partner_hostel(h)` (the "checked" tick →
   ₹20), `payouts_due()` and `mark_payout_paid(ledger_id, utr)` (console › Payments).
4. **Realtime**: `join_requests` is deliberately not added to `supabase_realtime` (the F26 RLS test pins the publication's
   list). If the integrator wants live Joining, add the table in a later migration and extend that test's expected list.
5. `tests/run.sh` bundle check: the two migrations are after `FROM`, so they belong in the next `tools/sql-bundle.sh` run
   (integrator). FOUNDER-TODO: none beyond the usual "SQL ships with the autorun" (no new keys or accounts).
6. **S40 "Not on the app yet · Ask to join"** (wave 1, Build 1): call `s.openAskJoin(bed: <bedId>)`; it opens H48 with that bed
   picked.
7. Me (S79): `s.myAdd` is a getter; demo seeds it once from the sample listed hostel `balaji` ("added by you", Owner asked).

## 3. SCREENS rows (verbatim)
§1 Tenant screens (two rows; the file column names the widget):
```
| 92 | `addHostel` | Add a hostel (F28 Part 2): name · gate photos 1–3 (camera / gallery) · pin on the map (aPin in add mode; area read off the pin) · For · "What do you pay? ₹ a month" (partner: from–to) · Sharing · Food · Owner's name + phone · I live here / I'm a Hostelzy partner + code · Add. Duplicate box "Already on Hostelzy: X. Ask your owner to verify it instead." + Share | `features/add_hostel/add_hostel_screens.dart` (`AddPgScreen`) | Explore end row / empty state "Can't find your PG? Add it ›"; Me › Add a hostel; My stay T20 › Add my hostel |
| 93 | `myAdd` | Your hostel on Hostelzy (F28 Part 2): the listed card, steps Added ✓ → Owner asked → Owner agreed → Verified → ₹200 paid, Send to your owner / Ask again (3 days), UPI id box after the owner agrees, the honest line | `features/add_hostel/add_hostel_screens.dart` (`MyAddScreen`) | Me › Your hostel; after Add; My stay T20 › Your hostel on Hostelzy |
```
§1 Resident / tenant screens:
```
| 94 | `joinForm` | Join <hostel> (F29 Part 2): kicker "Bed 203 · ₹6,500/month", advance, name, phone, moving in, Your ID (Send ID on WhatsApp; Drive camera in wave 4), Send to owner | `features/join/join_screens.dart` (`JoinFormScreen`) | Link `app/j/?t=<token>` (router `/j?t=`), after sign-in |
```
§2 Owner sheets:
```
| 48 | `askJoin` | Ask to join (F29 Part 2): free bed chips, monthly fee (room's rate), advance (terms), moves in, first name, Send on WhatsApp | `features/join/join_screens.dart` (`AskJoinSheet`) | Manage › Residents › Ask to join (`owner_manage_screen.dart` `askJoin`); S40 row "Ask to join" (wave 1) |
| 49 | `joinReview` | <Name> wants to join (F29 Part 2): name, phone, moves in, bed, fee; ID row (ID received on WhatsApp tick / No ID yet / Drive placeholder); Approve · Ask again · Decline | `features/join/join_screens.dart` (`JoinReviewSheet`) | Today › Joining › Review (`owner_today_screen.dart` `join-<id>-btn0`) |
```
§3 Full-screen states:
```
| 34 | `myAdd` | No hostel added yet (+ Add a hostel) | `myAdd == null` | `features/add_hostel/add_hostel_screens.dart` (`myAddEmptyAdd`) |
| 35 | `joinForm` | Sent · <owner> will approve · we'll notify you (done state, same screen) | `jSent` | `features/join/join_screens.dart` (`joinDone`) |
| 36 | `joinForm` | This bed was just taken, ask your owner / link not valid any more / already in | `!joinInfo.open` | `features/join/join_screens.dart` (`joinClosed`) |
```
§5 Web pages: change row 2 and row 3 to
```
| 2 | `app/r/` | Find this hostel on Hostelzy (old HZ links) · **F28: `?h=<id>&claim=1`** "Your PG is on Hostelzy" → opens the app on the UNVERIFIED page with Claim this hostel | — |
| 3 | `app/j/` | You're invited to your hostel (invite code) · **F29: `?t=<token>`** "Join your hostel on Hostelzy" → opens the app's join form, install hint | +1: "This link has no invite code" (`app/j/index.html`) |
```
§7 Status variants (not counted): `myAdd` Owner asked / Owner agreed (UPI box) / Verified / Paid / Still waiting (60 days) /
Queued (cap) / Removed / partner (₹20 line); `me` row "Add a hostel · ₹200 when verified" vs "Your hostel · <name> · <step>";
`rewards` row "₹200 · <hostel> verified · Paid by UPI on the 5th / Queued for <Month> / Paid <date>"; `oToday` Joining tab
(Holds · Payments · **Joining** · Fixes) only while non-empty; `joinReview` ID row: WhatsApp tick / No ID yet / Drive;
`explore` end row and empty-state row "Can't find your PG? Add it ›"; `rStay` T20 button Add my hostel / Your hostel on Hostelzy;
Manage › Residents button Ask to join; `signIn` titles "Sign in to add a hostel" / "Sign in to join your hostel".

Totals: screens +3 (S92, S93, S94), sheets +2 (H48, H49), states +3 → release app +8; web pages unchanged (2 changed rows).

## 4. The 3 wiring points for Build 4 (Drive option)
1. **SQL** `join_request_info(token)`: replace `'drive', false` with
   `'drive', exists (select 1 from public.owner_drive d where d.hostel_id = j.hostel_id)` (same function, `create or replace`
   in Build 4's migration). `fill_join_request` already stores `id_received = 'drive'` + `id_file_id`.
2. **S94** `features/join/join_screens.dart` (`JoinFormScreen`, the `Your ID` block, comment `Wave 4 (Build 4)`): when
   `i.drive` is true, show the camera button (mask the first 8 digits on the phone → Edge Function `id-upload` → file id), then
   `s.update(() { s.jId = 'drive'; s.jIdFileId = <id>; })` and pass it in `sendJoinForm` (`fillJoinRequest(idFileId: …)`,
   the repo method already takes it). The WhatsApp button stays as the other way.
3. **H49** `JoinReviewSheet`, the `'drive' =>` branch (key `idDrive`): swap the placeholder row for the masked image via
   `id-view` (tap → open in Drive) and the "Delete from my Drive" action; `JoinReq.idFileId` carries the Drive file id.
   Also add the Manage row **Tenant IDs** → H50 (`owner_manage_screen.dart` rows list) and `app/console` nothing.

## 5. Not in the spec (summary; details in the feature files)
F28: `hostels.partner_code` + `owner_asked_at`; `reward_payouts` + `payouts_due()` + `mark_payout_paid()`;
`check_partner_hostel(h)`; adder photo policies (listed without a photo first); partner S93 reuses the 5 steps, latest hostel
only; `my_added_hostel()` returns the owner's phone to the adder only; S22 row from the same call; Rule A applied; no Realtime.
F29: `join_request_info(token)` (owner's WhatsApp number to the invited tenant only); no extra Add a resident button;
Approve needs the ID tick; Drive stubbed; Rule A applied; demo has no ID image; no Realtime.

## 6. Checks
`tools/check.sh` on the branch: see the last commit message ("W2 DONE …") for the counts. Flutter analyze clean; all Flutter
tests incl. `w2_add_join_test.dart` (8); SQL tests incl. `f28_add_hostels_test.sql` and `f29_join_test.sql`, bundle twice;
function tests unchanged. The SQL bundle is **not** regenerated (integrator, after all waves).
