# Wave 4 handover · Build 4 (2026-10-18)

Branch **`feature/w4-drive-fresh`** (from `main`, not merged). F29 **Part 3** (tenant IDs in the owner's Google Drive) and
F28 **Part 4** (rent freshness, app side), built as self-contained pieces. `tools/check.sh` is green on the branch alone.
Not done here on purpose: the SQL bundle (`tools/sql-bundle.sh`), `docs/SCREENS.md`, `docs/BOARD.md`, `docs/FOUNDER-TODO.md`,
and any file of Build 2 / Build 3 (not on `main` yet).

## 1. What is on the branch

| Area | Files | What |
|---|---|---|
| SQL | `supabase/migrations/20261018140000_f29_drive.sql` · `supabase/tests/f29_drive_test.sql` (+ `run.sh` line) | `owner_drive` (refresh token encrypted with pgcrypto + the server secret, folder id, `full_copy`, file count; **no RLS policy at all**, only the service role reads it) · RPCs `drive_status(h)`, `set_full_copy(h, v)` (owner + managers), `drive_role(h)`, `id_upload_target(p_token)` (tenant) · service-role `drive_put`, `drive_token`, `drive_forget`, `drive_file_added` · stub hook `join_hostel_for_token(text)` (see §2.3) · `hostels.rent_confirmed_at` (`add column if not exists`) |
| Edge Functions | `supabase/functions/_shared/drive.ts` · `drive-connect/` · `id-upload/` · `id-view/` · `tests/drive.test.ts` (10 tests) · `.github/workflows/supabase-functions.yml` (3 deploy lines, `--no-verify-jwt`) | `drive-connect` (owner JWT + Google server auth code → refresh token, scope check `drive.file`, folder `Hostelzy / <hostel> / Tenant IDs`, `drive_put`; `action: 'disconnect'` revokes at Google + `drive_forget`) · `id-upload` (tenant JWT + join token + base64 image → Drive `files.create` in the owner's folder with the owner's token → `{ file_id }`; image in memory only, logs carry only an error code) · `id-view` (owner/manager JWT → `{ url, until, open }`: a 10-minute signed link back to the function that streams the bytes, plus the file's Drive page; `action: 'delete'` → `files.delete`; `GET ?t=` serves the image) |
| App · state + repo | `hostelzy/lib/features/drive/drive.dart` (part of `state.dart`: `_DriveData`, `DriveActions`) · `drive_auth.dart` (`DriveAuth`, `GoogleDriveAuth` via `google_sign_in` `authorizeServer([drive.file])`, `NoDriveAuth`) · `features/listings/repo.dart` (`DriveStatus`, `DriveFail`, `driveStatus`, `driveConnect`, `driveDisconnect`, `setFullCopy`, `idTarget`, `idUpload`, `idView`, `idDelete`) · `supabase_repo.dart` (`db.functions.invoke`, the user's Firebase token goes along) · `sample_repo.dart` (in-memory demo) · `sign_in.dart` (`ensureGoogleReady()` shared by sign-in and the Drive consent) · `main.dart` (`state.driveAuth`) | |
| App · UI | `features/drive/drive_sheets.dart` (**H50** `DriveSheet`) · `owner_manage_screen.dart` (Manage › **Tenant IDs** row, after Residents) · `ui/shell.dart` (sheet `drive`: title "Tenant IDs in your Drive", kicker "<hostel> · Manage") · `features/drive/id_capture.dart` (`IdCapture`, `CameraPicker`, `maskImage`, `defaultMaskBar`) · `features/drive/id_thumb.dart` (`IdThumb`) | **F31 Rule A from the start.** H50 = one status line + the button + the switch: "Checking…" · **"Not available yet"** (one line, no button; `driveUnavailable` = `server` or `scope`) · "Not connected" + **Connect Google Drive** (owner; a manager sees the line only) · "Connected · N files" + **Full copy needed (police file)** switch + **Disconnect** (owner) |
| App · F28 Part 4 | `data/hostels.dart` (`Hostel.rentConfirmedAt`) · `features/listings/rows.dart` · `features/listings/tiers.dart` (`rentFresh`, `rentLine`, `rentFreshCompare`, `rentFreshDays = 60`) · `features/explore/explore_screen.dart` (first sort step) · `features/explore/unverified_screen.dart` (card "Rent on request"; T32 page "Rent on request" + button Ask on WhatsApp, hub's F31 copy) · `supabase_repo.dart` `listings()` reads Build 3's view **`listed_rent_visible`** (hub, 2026-10-18): a listed row with `rent_visible = false` is treated as never confirmed; without the view (not on `main` yet) the same 60-day rule runs on `rent_confirmed_at` in the app | |
| Tests | `hostelzy/test/w4_drive_test.dart` (10: 28-90 unit + Explore flow; H50 demo light + dark, real-server flow, "Not available yet" ×4, manager; `maskImage`; IdCapture light + dark, full copy, refusals, server-asked fullCopy; IdThumb) | |
| Docs | Build sections + "Not in the spec" in `docs/features/F29-tenant-self-onboarding.md` (Part 3) and `F28-listed-hostels-import.md` (Part 4); this file | |

## 2. The 3 wiring points (integrator, after wave 2 lands)

### 2.1 S94 `joinForm` (tenant) → `IdCapture`
```dart
import 'package:hostelzy/features/drive/id_capture.dart';
// In the ID row of S94. fullCopy: null → the widget asks the server by the token
// (HostelRepo.idTarget → RPC id_upload_target) and shows the bar or not.
IdCapture(token: s.joinToken, fullCopy: null, ownerName: hostel.owner, onUploaded: (fileId) => s.update(() => s.joinIdFileId = fileId))
// (`joinToken` / `joinIdFileId` stand for wave 2's own field names.)
```
- Which path to show: `final t = await s.data.idTarget(token);` → **null** = the owner has no Drive (or the SQL isn't there): show
  **Send ID on WhatsApp** (`id_received = whatsapp`); non-null = show `IdCapture` (`id_received = drive`, `id_file_id` = the id from
  `onUploaded`). `idTarget` throws `DriveFail('bad_token', …)` for an expired / foreign token: say "This link isn't valid any more".
- `fill_join_request(token, name, phone, date, id_received, id_file_id)` is wave 2's; pass the file id through.
- S94 on sample data: `SampleRepo` has an in-memory Drive; `idUpload` returns `sample-id-N`.

### 2.2 H49 `joinReview` (owner) → `IdThumb` + "Delete from my Drive"
```dart
import 'package:hostelzy/features/drive/id_thumb.dart';
if (req.idReceived == 'drive' && req.idFileId != null) IdThumb(hid: s.ownHid, fileId: req.idFileId!)   // tap → opens the file in Drive
// "Delete from my Drive" (H49 button):
await s.data.idDelete(s.ownHid, req.idFileId!);   // files.delete + the count; then clear id_file_id on join_requests (wave 2 RPC)
```
`IdThumb` shows "Loading…", the image (through the 10-minute link; no Google sign-in needed in the app), "Not available yet" or the
fallback "Open in Drive" (tap opens the file). On sample data it draws "Sample ID (drawn)".
Move-out: wave 2 / the integrator drops the pointer (`id_file_id = null`); the file stays the owner's (DECISIONS).

### 2.3 SQL hook `join_hostel_for_token(text)` (wave 2's `join_requests`)
`id_upload_target(p_token)` calls `public.join_hostel_for_token(p_token) returns uuid`. On this branch it is a **stub that raises
"Ask to join isn't ready yet"**, created only `if not exists`. Wave 2 (or the integrator, in the f29_join migration or a later
one) replaces it with `create or replace`:
```sql
create or replace function public.join_hostel_for_token(p_token text) returns uuid
language sql stable security definer set search_path = ''
as $$
  select j.hostel_id from public.join_requests j
  where j.token = p_token and j.expires_at > now() and j.status in ('sent', 'filled')
    and (j.tenant_id is null or j.tenant_id = public.uid())
$$;
```
Order doesn't matter: if the wave 2 migration runs **after** mine, its `create or replace` wins; if it runs **before**, my
`if not exists` keeps theirs. `supabase/tests/f29_drive_test.sql` overrides the hook itself (test database only), so it stays green
either way. Also `hostels.rent_confirmed_at` is added `if not exists` in both migrations: no clash.

Then: `tools/sql-bundle.sh` + `--full`, and `supabase-functions.yml` deploys the three functions on the next push to `main`
(needs the existing `SUPABASE_ACCESS_TOKEN` secret, see FOUNDER-TODO 0b).

## 3. SCREENS rows for H50 (verbatim, for `docs/SCREENS.md` § 2 Owner sheets)

```
| 50 | `drive` | Tenant IDs in your Drive (F29 Part 3, F31 Rule A): status line "Not connected" / "Connected · N files" · **Connect Google Drive** or **Disconnect** (owner only; a manager sees the line and the switch) · switch **Full copy needed (police file)** (connected only) | `features/drive/drive_sheets.dart` (`DriveSheet`) | Manage › Tenant IDs (`features/drive/drive.dart` `openDrive`) |
```
Status variant (§ 7, not counted): **H50 not available** — the one line "Not available yet", no button (consent screen without the
scope / Google refused, or the SQL / functions missing). Changed: **Manage** gets the row **Tenant IDs** (subtitle = state:
"Google Drive · N files" · "Not connected"). Sheets +1 (Owner 17 → 18).

Widgets for Design (inside wave 2's boards, no board of their own): S94 ID row = `IdCapture` (button "Take a photo of your ID" →
the photo with a draggable black bar and the label "Cover the first 8 digits" (Full copy on: no bar, label "Full copy needed (police
file)"), Retake / Upload → "Uploaded to <owner>'s Drive"). H49 ID row = `IdThumb` (170 px framed image, tap opens Drive).

## 4. FOUNDER-TODO one-time line (verbatim; the integrator adds it under "Now")

```
- [ ] **Google Cloud consent screen: add the drive.file scope + the OAuth client for the app** (F29 Part 3, tenant IDs in the
  owner's Drive). Google Cloud → the Hostelzy project (same as Google sign-in) → **APIs & Services › OAuth consent screen › Data
  access › Add scope** → `https://www.googleapis.com/auth/drive.file` → Save. Then **Library → Google Drive API → Enable**. Then
  **Credentials → the Web client** (the one `google-services.json` / `GOOGLE_WEB_CLIENT_ID` uses): copy its **Client ID** and
  **Client secret**. Then Supabase → Edge Functions → **Secrets**: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, and
  `DRIVE_TOKEN_KEY` = any long random string (e.g. `openssl rand -hex 32`; never change it after the first owner connects, or their
  tokens can't be read). Until this is done the app says "Not available yet" in Manage › Tenant IDs and tenants send their ID on
  WhatsApp. (While the consent screen is in "Testing", only test users can connect; publish it for everyone.)
```

## 5. Things the hub may want to know
- **Nothing of the tenant's ID touches Hostelzy's storage**: the function holds the bytes in memory for one call; the DB keeps the
  Drive file id only (wave 2's `join_requests.id_file_id`), and `owner_drive` keeps the owner's token as pgcrypto ciphertext; the key
  is an Edge Function secret, so a database dump alone can't read the tokens.
- The three functions deploy with `--no-verify-jwt`: Supabase's gateway can't verify Firebase (third-party) tokens, so every call
  passes the user's token to PostgREST (`drive_role` / `id_upload_target`), which does verify it; the `id-view` GET link carries its
  own HMAC ticket (10 minutes). The GET link is what the app's image widget loads.
- `GoogleDriveAuth` asks Google for a **server auth code** with `drive.file` on the phone (`google_sign_in` 7 `authorizeServer`);
  the code is exchanged on the server, so the refresh token never exists on the phone.
- "Not in the spec" decisions are in the two feature files (10 for Part 3, 4 for Part 4). F31 Rule A (no explanations) was applied
  on the hub's note of 2026-10-18 before the branch was finished: every removed line is listed in the F29 file (#10).
- `tools/check.sh` on the branch (final tree, 2026-10-18): analyze clean · 385 Flutter tests · 42 SQL test files incl. `run-all-pending.sql` twice · 30 function tests (20 + 10 Drive).
