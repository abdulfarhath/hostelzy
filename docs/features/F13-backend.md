# F13 · Backend

**Stage:** Building · part 1 (Supabase schema + data layer) merged 2026-10-02

## Problem
Everything is sample data on one phone.

## What it does
Supabase (Mumbai): multi-hostel schema, row-level security, phone OTP (MSG91), realtime, storage; Firebase push + Crashlytics; staging + production projects.

## Rules
- Free plan while building; Pro at launch.

## Open questions
- SMS codes (Firebase Phone Auth) once Firebase billing works; until then phones are typed and shown as "not verified" (DECISIONS 2026-10-02).

## Founder steps · Supabase (do these once)

Run the database setup:
1. Open https://supabase.com/dashboard/project/oafiaczotlilomlvhphp
2. Left menu → **SQL Editor**.
3. Click **New query**.
4. Open `supabase/migrations/20261002020000_f13_firebase_ids.sql` on GitHub (only this file: it replaces the older two, and is safe to run again).
5. Click **Copy raw file** (the copy icon, top right of the file).
6. Paste it into the SQL Editor.
7. Click **Run**.
8. You should see **Success. No rows returned**. Done.

If you see a red error instead: copy it and send it to the Build chat. Nothing is half-done: the file stops at the error.

Keep these safe:
- Never paste the **service_role** key anywhere: not in chat, not in GitHub, not in the app.
- The **anon** key is already in the app. That one is fine to be public.

Leave as they are (defaults are right):
- Authentication → Sign In / Providers → **Anonymous sign-ins: off**.
- Table Editor: every table shows **RLS enabled**. If one ever says "RLS disabled", tell the Build chat.

Let Supabase trust Hostelzy's Google sign-ins:
1. Supabase dashboard → **Authentication** → **Third-party Auth** (left menu, under Configuration).
2. Click **Add provider** → **Firebase**.
3. Firebase project ID: `hostelzy`.
4. Click **Create** (or Save).

## Founder steps · Sign in with Google

Turn on Google sign-in:
1. Open https://console.firebase.google.com/project/hostelzy/authentication/providers
2. Click **Add new provider** → **Google**.
3. Switch **Enable** on.
4. Project support email: pick your email.
5. Click **Save**.

Make a test signing key (once; it makes the SHA-1 stay the same in every test APK). On a computer with Android Studio or Java:
1. Open a terminal (Android Studio: View → Tool Windows → Terminal).
2. Run: `keytool -genkeypair -v -keystore hostelzy-test.jks -alias hostelzy-test -keyalg RSA -keysize 2048 -validity 10000 -storetype JKS`
3. Pick a password. Type the same one at every password prompt. Write it down.
4. Name / organisation questions: anything is fine. Answer `yes` at the end.
5. Run: `keytool -list -v -keystore hostelzy-test.jks -alias hostelzy-test`
6. Copy the **SHA1** and **SHA256** lines.
7. Turn the file into text. Mac/Linux: `base64 -i hostelzy-test.jks | tr -d '\n'` · Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("hostelzy-test.jks"))`
8. Copy that long text.

Put it in GitHub (never in the repo itself):
1. Open https://github.com/abdulfarhath/hostelzy/settings/secrets/actions
2. **New repository secret** → name `HZ_TEST_KEYSTORE_BASE64` → value: the long text → Add secret.
3. **New repository secret** → name `HZ_TEST_KEYSTORE_PASSWORD` → value: your password → Add secret.
4. Keep `hostelzy-test.jks` and the password in a safe place. It is for test APKs only, never the Play Store.

Add the fingerprints to Firebase:
1. Firebase console → ⚙ **Project settings** → **General**.
2. Scroll to **Your apps** → the Android app `app.hostelzy.hostelzy`.
3. **Add fingerprint** → paste the SHA1 → Save.
4. **Add fingerprint** → paste the SHA256 → Save.
5. Click **google-services.json** to download it again (now it has Google sign-in in it).
6. Send its contents to the Build chat. It isn't secret.

Then the next test APK signs in with Google.

## Founder steps · Firebase

Nothing to do now. Push and crash reports are already in the app.

Lock the Firebase key to the app (do this **after** the app has its real Play Store signing key, F15; add that SHA-1 too, next to the test one):
1. Play Console → your app → Test and release → App integrity → App signing.
2. Copy the **SHA-1** of the app signing key.
3. Open https://console.cloud.google.com/apis/credentials?project=hostelzy
4. Click **Android key (auto created by Firebase)**.
5. Application restrictions → **Android apps**.
6. Add: package `app.hostelzy.hostelzy` + the SHA-1.
7. Save.

Why wait: the Play Store build will be signed with a different key; locking only to the test key would break the store build. The key in `google-services.json` is meant to be in the app; the lock stops other apps from using it.

To let Hostelzy **send** pushes (part 2, when the Build chat asks):
1. Firebase console → ⚙ Project settings → **Service accounts**.
2. Click **Generate new private key** → a `.json` file downloads.
3. Do NOT put this file in GitHub, chat or email.
4. Supabase dashboard → **Edge Functions** → **Secrets**.
5. Add secret: name `FCM_SERVICE_ACCOUNT`, value = open the file, copy everything, paste.
6. Save. Delete the downloaded file.
7. Tell the Build chat "FCM secret added".

Play Store form (Data safety), when you fill it: say the app collects **crash logs** and **device or other IDs** (the push token), for app functionality and analytics, not shared, not sold.

## Design
Not needed.

## Build

**Part 1 · Supabase schema + data layer · merged 2026-10-02** (branch `feature/f13-supabase`):
- **Schema with Row Level Security** in `supabase/migrations/20261002000000_f13_schema.sql`, one file:
  - profiles (made on sign-up) and hostel staff (owner / manager);
  - hostels, rooms, beds, rate cards and deals;
  - holds, enquiries, stays (residents), and payments (UPI → UTR → owner confirms);
  - complaints, vacate/swap requests and menus;
  - reviews, Fair Play reports, cases and strikes;
  - owner plans and invoices, room layouts (draft + published), and app settings (min build, maintenance).
- **Who sees what:**
  - Public (anon key): live hostels and their rooms, beds, rate cards, deals and reviews.
  - Signed-in users: their own profile, holds, enquiries, payments, stays, complaints and requests.
  - Owners and managers: everything about their own hostels.
  - Hostelzy team: everything. "Team" is `app_metadata.team = true`, which only the dashboard or the service_role key can set, never the app.
- **Rules the database itself enforces:**
  - A tenant can never mark a payment paid. Only the hostel's owner or manager confirms a waiting payment, and `confirmed_by` / `confirmed_at` are set by the database.
  - Owners can't mark their own Hostelzy invoice paid.
  - Reviews need a confirmed stay at that hostel, and owners can only add a reply.
  - On Fair Play cases owners can only reply; the team decides.
  - Owners can't put a hostel live or change its status, gender or map pin.
  - Members and referral codes can't be self-set.
  - Room layouts are for verified (non-anonymous) users only, per the women's PGs rule. The owner approves a draft with `approve_layout()`.
  - The migration refuses to finish if any table is missing RLS.
- **Tested on a local Postgres 16:** `supabase/tests/run.sh` (with `stub.sql` standing in for Supabase's auth). `rls_test.sql` checks about 80 allow and deny cases as anon, tenant, anonymous sign-in, resident, owner, manager, owner of a draft hostel and team. It also passed a mutation check: removing the payment guard makes it fail.
- **App:**
  - `supabase_flutter` is added. `lib/app_config.dart` has `supabaseUrl` / `supabaseAnonKey`, which `--dart-define` can override, and `dataSource`: `sample` by default, `supabase` with `--dart-define=DATA=supabase`.
  - `lib/backend.dart` has `HostelData`, with `SampleData` (offline, tests) and `SupabaseData` (live hostels with rooms, beds and rate cards, plus app settings), and the pure row → model mapping `listingsFromRows`.
  - With live data, tenants browse only live hostels (`browsable`). The owner and resident sample screens stay on sample data until part 2.
  - The min build and maintenance settings come from the database.
  - A live hostel with no UPI ID says so instead of opening an empty UPI link.
  - If Supabase can't be reached, the app says "Showing sample hostels".
- **Why sample is still the default:** the database is empty until the team adds real hostels, and writes (holds, enquiries, payments) need phone login (part 2).
- Tests: `backend config: sample data by default, only the public anon key (F13)` (also fails if a service_role key is ever pasted in) and `live hostels from Supabase replace the samples for tenants (F13)`.

**Firebase · push + Crashlytics · merged 2026-10-02** (branch `feature/f13-firebase`):
- `android/app/google-services.json` (project `hostelzy`, app `app.hostelzy.hostelzy`).
- Gradle plugins: `com.google.gms.google-services` 4.4.4 and `com.google.firebase.crashlytics` 3.0.6.
- Packages: `firebase_core`, `firebase_messaging` and `firebase_crashlytics`.
- `POST_NOTIFICATIONS` permission.
- `lib/push.dart`:
  - `startFirebase()` runs on Android only. It turns on Crashlytics in release builds (Flutter and platform errors are reported as fatal) and returns `FirebasePush`. On other platforms, or if Firebase fails to start, it returns `NoPush`, so web, desktop and tests run without it.
  - Turning on notifications in Settings shows the F15 explainer first, then Android's own prompt.
    - Allowed: the FCM token is kept in `AppState.pushToken` and the toast says sending starts once the account is online.
    - Denied: the toast says where to turn notifications on.
    - Messages that arrive while the app is open show as a toast.
- Migration `20261002010000_f13_push_tokens.sql`: a `push_tokens` table. Each user sees and manages only their own tokens; the send function reads them with the service role. RLS tests are extended.
- CI: the new `.github/workflows/android-check.yml` runs analyze, test and `build apk` on every pull request without publishing anything, so Gradle changes are checked before they reach `main`.
- Test: `push: explainer, then Android asks; allowed gets a token, denied says how to fix (F13)`.
- **Not yet:** saving the token to `push_tokens` (needs phone login) and the `send-push` Edge Function (needs the founder's FCM secret, steps above).

**Sign in with Google · merged 2026-10-02** (branch `feature/f13-google-login`, DECISIONS "Payments contact + login SMS"):
- **Login:**
  - Welcome → **Sign in** → **Continue with Google** (`firebase_auth` + `google_sign_in`; `lib/sign_in.dart`).
  - Then **Your mobile number**: typed, stored as not verified (`phone_verified` stays false; only the team can change it).
  - Then the role.
  - "Use on this phone only" is the honest fallback until Google sign-in is switched on. If it isn't, the app says "Google sign-in isn't switched on yet" instead of failing silently.
  - The old phone/OTP screens stay behind `phoneOtpLogin = false` in `lib/app_config.dart`.
- **No fake "verified" claims:**
  - Owners see enquiry phones as "not verified" (was "verified by OTP").
  - The Member checklist says "Signed in to Hostelzy".
  - The layout lock says "signed in".
  - Invite sign-ups say "signed in · phone not verified".
  - The team's Add-hostel visit now checks the owner's phone with **Call it** → **The owner's phone rang** (no fake 6-digit code).
- **Database v2** (`20261002020000_f13_firebase_ids.sql`, standalone, re-runnable):
  - User ids are Firebase uids (text). `public.uid()` returns the uid only for tokens whose issuer and audience are the `hostelzy` Firebase project, so another Firebase project's token counts as nobody.
  - `is_verified()` means a non-anonymous Firebase sign-in.
  - Team is the `team: true` custom claim (Admin SDK only).
  - Users create their own profile (never with `phone_verified`).
  - Push tokens are keyed to the Firebase uid.
  - RLS tests are updated, including the other-project and anonymous cases, and pass both after the older migrations and alone.
  - The policies don't depend on a `role: authenticated` claim, which Firebase tokens lack without a paid Cloud Function; they key off `sub`.
- **Supabase client:** sends the Firebase ID token (`accessToken`) when signed in. After the role is picked the profile is saved (name, email, typed phone, role), and the push token is saved once notifications are allowed.
- **Test signing key:** `android/app/build.gradle.kts` signs release builds with `HZ_TEST_KEYSTORE` when CI provides it from the GitHub secrets `HZ_TEST_KEYSTORE_BASE64` / `HZ_TEST_KEYSTORE_PASSWORD` (both workflows). Without them it falls back to the debug key, as before. The keystore is never in the repo.
- Tests:
  - `onboarding: sign in, phone and role lead to Explore`;
  - `Sign in with Google: account, phone not verified, profile saved (F13)` (fake sign-in: not switched on, cancelled, success, profile + push token saved, log out);
  - the enquiry, Add-hostel and login tests are updated.

**Google sign-in config · 2026-10-02:** the founder enabled Google sign-in, added the test key's SHA-1/SHA-256 in Firebase, and added Supabase Third-party Auth (Firebase `hostelzy`). `android/app/google-services.json` now has the Android OAuth client (certificate hash = the test key's SHA-1) and the web client (`…h2tkur1j…`), which `google_sign_in` reads as its server client id. Test APKs need the GitHub secrets `HZ_TEST_KEYSTORE_BASE64` / `HZ_TEST_KEYSTORE_PASSWORD` to sign with that key; without them Google sign-in fails with "isn't switched on yet".

**Part 2 (next):**
- SMS check of the phone (Firebase Phone Auth) once billing works;
- owner, resident and team screens read and write their tables;
- realtime updates;
- photo storage;
- ~~switch the default to `supabase`~~ (done in B3, below);
- staging and production projects.
- The `send-push` Edge Function (FCM HTTP v1).

**B3 · repository and two APKs · 2026-10-02** (branch `feature/b3-repo-two-apks`):
- `lib/backend.dart` is now `lib/features/listings/repo.dart`: `HostelRepo` with `SampleRepo` and `SupabaseRepo`.
- Supabase listings now include **published** room layouts (`layouts` rows with `stage = published`; drafts never reach tenants).
- Each `main` build publishes **two APKs**:
  - `hostelzy.apk` is the real app (`DATA=supabase`). It never shows sample hostels. With no hostels, or no internet, Explore says "No hostels in this area yet" and offers "Pick another area". Owner and resident screens stay gated until real data exists.
  - `hostelzy-demo.apk` is sample data with the DEMO banner (`DATA=sample`, Gradle `HZ_DEMO=1`). It uses the `app.hostelzy.hostelzy.demo` id and the label "Hostelzy Demo", so it installs next to the real app. Firebase: the founder registered the demo app (same test SHA-1) on 2026-10-02, so Google sign-in, push and Crashlytics work in it too.
  - Both are signed with the test key. The PR check builds both.
- Tests: the gated-roles test checks the banner appears only in the demo; the Supabase listings test covers published layouts and the empty state.

**B5 · server rules and push · 2026-10-02** (branch `feature/b5-server-logic`):
- What a modified app could skip now happens in the database (`20261002030000_b5_server_rules.sql`, safe to run again).
- HZ codes for holds and enquiries, and FP case numbers, are issued by the server. The app's own code is ignored.
- Hold rules:
  - the bed must be free and in that hostel;
  - at most 2 open holds per tenant;
  - a free hold lasts 1 hour (2 for Members); paid and advance holds wait for the owner;
  - the bed shows as held, and is freed again on release or expiry.
- `expire_holds()` runs every minute (pg_cron).
- Resident matching: a stay is "via Hostelzy" with its HZ code when that phone enquired, held or booked there in the 60 days before joining. The owner's pick can't change it.
- Fair Play cases open automatically for:
  - an HZ resident added more than 3 days after moving in;
  - a booked HZ hold with nobody added after 3 days (daily scan).
- Invoices:
  - `issue_invoices()` on the 1st: one per live hostel once its trial ends, priced by bed count (499 / 999 / 1,499), minus credit;
  - `invoice_sweep()` daily: late days; overdue (deals paused) at 15 days late, active again once paid.
- Push:
  - new holds, enquiries and complaints, and payments to check, add rows to `push_outbox` (only the server can read it);
  - the `send-push` Edge Function sends them with FCM and drops dead phone tokens;
  - pg_cron calls it every minute with a secret kept in Vault.
- Jobs and helpers can't be called from the app. `is_server()` is true only with no request JWT, so an app token is never "server".
- CI:
  - `supabase-check.yml` runs the SQL tests on Postgres 16 and the function tests on Node for PRs that touch `supabase/`;
  - `supabase-functions.yml` deploys `send-push` from main once `SUPABASE_ACCESS_TOKEN` exists.
- Founder steps: `docs/FOUNDER-TODO.md` items 3–4.
- Not yet: the app doesn't write holds or enquiries to Supabase. That comes with the live tenant, owner and resident screens (C), which will show the server's HZ code.
**B6 · Realtime · 2026-10-02** (branch `feature/b6-realtime`):
- When a user is signed in on Supabase, their holds, enquiries, payments and complaints come from the database (`SupabaseRepo.live()`). RLS decides who sees what.
- `20261002040000_b6_realtime.sql` puts those 4 tables in the `supabase_realtime` publication. Realtime checks RLS before sending a change.
- A change is only a signal. The app refetches, at most once per 400 ms, so bed labels and the rules stay in one place.
- Server statuses are mapped to the app's:
  - an advance hold shows as a booking;
  - an expired hold shows as released, marked as expired;
  - pending payments show as due;
  - fixed complaints show as resolved.
- Live rows replace the lists and are never mixed with samples. Logging out stops the updates.
- Tests:
  - `B6: live rows map…`;
  - `B6: signed in on Supabase…`;
  - the publication check in `rls_test.sql`.
- Founder: run the B6 SQL file once in the SQL Editor (`docs/FOUNDER-TODO.md`).
- Still to come (C): the owner and resident screens' writes (accept a hold, confirm a payment, update a complaint) go to Supabase, and Realtime then shows them on the other phone.


**C · account deletion · 2026-10-02** (branch `feature/c-account-deletion`, design board 18 "Delete account v2"):
- Settings → Delete account → **Confirm it’s you**: an account card with initials, name and email, and **Confirm with Google** (the official Google button, now also on the sign-in screen). **Keep my account** leaves.
- Order:
  1. Google re-authentication (`SignIn.reauth()`; a different account or a cancel stops it);
  2. `delete_my_account()` on the server;
  3. the Firebase user is deleted and Google disconnected;
  4. the phone forgets everything.
  If any step fails, nothing is called deleted.
- Not signed in with Google: "Delete from this phone" (all the data is there). The fake 6-digit code step is gone.
- `20261002070000_c_delete_account.sql`, `delete_my_account()` (signed-in users only):
  - removes the profile, push tokens, move requests and staff rows;
  - releases open holds and frees their beds;
  - keeps others' records without the person: enquiries as "Deleted user", reviews as "Former resident", payments and complaints detached, stays unlinked;
  - owners of a live hostel are asked to hand it over first;
  - `guard_payment` and `guard_review` allow only that change during the deletion;
  - tests: `supabase/tests/delete_test.sql`.
- Done screen copy from the design, and **Close Hostelzy**. The web delete page now says the app deletes server data.

**Push fix · 2026-10-02** (branch `feature/push-fix`, from the founder's phone test: no prompt, then no push):
- **Offer once after sign-in:** the first time a Google-signed-in user lands on a home screen, the notifications explainer shows, then Android's prompt. "Not now" is remembered on the phone (`pushAsked`).
- **Token saved every time:** on every app start (after Supabase connects), after Google sign-in, and when FCM rotates the token (`onTokenRefresh`). If Android already allows notifications and there's an account, `push_tokens` gets this phone's token. It also works when permission was given in the phone's settings or an earlier install.
- **Honest Settings switch:** it shows on only if Android allows notifications too. When Android has them off, tapping asks Android right away, with no second tap.
- **Sign-out and account deletion** remove this phone's token from the server and FCM.
- **Failures show a toast** ("Couldn't turn on notifications for this phone…") instead of a hidden debug line. In the demo APK the message says no server sends anything.
- Tests:
  - `push fix: after sign-in the app offers once…`;
  - the Settings switch test and the sign-in test are updated.


**C · server-issued invites · 2026-10-02** (branch `feature/c-invites`):
- `20261002080000_c_invites.sql`:
  - `invites` holds one active code per hostel, like `VAS-7Q2`, from the hostel's name plus 3 random letters or digits. Only the server makes codes.
  - `invite_signups` holds join requests.
  - RPCs:
    - `hostel_invite(h)` (staff);
    - `new_hostel_invite(h)` (the old code stops working);
    - `join_with_invite(code, name, phone, bed)`: signed in with Google; one pending request per person per hostel; the owner gets a push;
    - `decide_signup(id, approve)`: staff; an approval creates the stay, matched as usual, and tells the resident.
  - Tests: `supabase/tests/invites_test.sql`.
- **App:**
  - Owner Invite QR shows the server's code ("Getting your invite code…" until then), with "Make a new code".
  - The resident gate has "Have an invite code?" and **Ask to join**; the code is filled in when the invite link opened the app (go_router `j/`).
  - Server reasons are shown in plain words.
  - Sample data never pretends to send it.
- **Done later (C · server sign-ups):** the owner's "Waiting for you" list reads `invite_signups`, and Approve / Remove call `decide_signup`.

**C · live writes · 2026-10-02** (branch `feature/c-live-writes`):
- Signed in on Supabase with live rows (`AppState.onServer`), these actions write to the server first, then refetch. Realtime updates the other phone.
  - **Enquiry:** the server records it and returns the HZ code that goes into the WhatsApp message. Asking again reuses the code.
  - **Owner marks contacted.**
  - **Payments:** the tenant's UTR → `waiting`. The owner confirms received → `paid`, and the hold becomes `booked`; not received → `missing`.
  - **Complaints:** a resident raises one at their hostel (from their confirmed stay); the owner moves it Open → In progress → Resolved (`Fixed`).
- If a write fails it says so ("Couldn’t save it…"), and nothing is shown as sent.
- Sample data and the demo APK are unchanged (local only).
- `Complaint.key` keeps the server id. `LiveRows.myHostel` is the resident's hostel.
- Test: `C: on Supabase, enquiries, payments and complaints are written to the server`.
- Still local-only: holds (they need bed ids from the listings).

**C · server sign-ups · 2026-10-02** (branch `feature/c-server-signups`):
- On Supabase, the owner's Invite "Waiting for you" list comes from `invite_signups` (pending, not their own), and updates live (migration `20261002090000_c_signups_realtime.sql`).
- **Approve** calls `decide_signup(id, true)`: the server makes the stay; the app says "<name> is now a resident here." only after it succeeded. **Remove** calls `decide_signup(id, false)`.
- If it fails it says "Couldn’t save it…". Sample data and the demo are unchanged.
- Test: `C: on Supabase, the owner sees server sign-ups and approving or removing goes to the server`.

**B5 · push hardening · 2026-10-02** (branch `feature/b5-push-hardening`), after the live test showed send-push answering a bare 500:
- Every failure answers 500 with the reason in the body, so `net._http_response` shows it. Examples: "FCM_SERVICE_ACCOUNT is not valid JSON", a private key that can't be read, "Google token: 400 …", a REST error. Keys and secrets are never in the body. The reason is also logged.
- If the Google token fails, every pending row gets the reason in `push_outbox.error` and stays pending, so it is retried next minute. A row that throws gets its reason, and the other rows still go.
- A private key pasted with literal `\n` still works.
- Tests: three new ones in `supabase/functions/tests/fcm.test.ts`.

**S1 · holds and bookings on the server · 2026-10-02** (branch `feature/s1-server-holds`):
- Listings carry each bed's server id (`Bed.key`).
- Signed in on Supabase, **Hold free** and **Pay advance** insert the hold on the server. The server checks that the bed is free, allows at most 2 open holds, sets the 1-hour expiry and issues the HZ code. A booking also starts its advance payment (`note` = HZ code). The pay sheet opens on the server's payment.
- The owner gets the "New hold" push from the server. Plain reasons are shown: "Someone just took this bed", "You can hold 2 beds at a time".
- **Release:** the tenant's release sets the hold to `released` and cancels its unconfirmed advance; the bed frees itself on the server. An owner's release only releases the hold.
- Server holds don't expire on the phone; the server's every-minute job ends them and Realtime updates the screen.
- An advance hold waiting for the owner shows as "Advance · owner to confirm", with its amount from the payment. The locked deal is kept from what this phone showed when booking (it isn't stored on the server).
- **Migration `20261002100000_s1_holds.sql`:**
  - A confirmed (`booked`) hold books its bed.
  - The payer can no longer change a paid or cancelled payment (guard fix). The account-deletion exception is kept.
  - Tests: `supabase/tests/holds_test.sql`.
- Sample data and the demo are unchanged.
- Test: `S1: on Supabase, holds and bookings are placed on the server`.

**S2 · the owner's residents on the server · 2026-10-02** (branch `feature/s2-server-residents`):
- **Resident list:** signed in on Supabase, the owner's list comes from `stays` (current ones, RLS: their hostels'). It updates live, because `stays` was added to Realtime. Rent shows from the stay's latest rent payment: Paid, Waiting, or Due ("No rent payment yet this month").
- **Add a resident** and **Add booking** insert a stay. The server matches the phone to Hostelzy (60 days), opens a Fair Play case when the resident was added more than 3 days late, and books the bed.
- **Confirming:** a typed WhatsApp code proves nothing, so on the server the resident confirms by joining with the hostel's invite code. Approving it links the owner's entry with the same phone instead of adding a second one.
- **Hold requests:** the owner confirms a tenant's free hold (`held`) or declines it (released; the tenant's advance isn't touched). Tenants' names aren't shared, so the request shows "Hostelzy tenant" and the HZ code.
- Owner resident screens now follow the selected hostel instead of the sample one.
- **Migration `20261002110000_s2_residents.sql`:**
  - A current stay books its bed, and moving out frees it.
  - `decide_signup` links an existing entry.
  - `stays` is added to Realtime.
  - Tests: `supabase/tests/residents_test.sql`. The RLS fixture's resident now has their own bed.
- Not yet: rent payments started by residents on the server, and moving out from the app.
- Test: `S2: on Supabase, the owner's residents and hold decisions are on the server`.

**S3 · owner edits on the server · 2026-10-02** (branch `feature/s3-owner-edits`):
- Signed in on Supabase, each owner edit is saved on the server first. The phone changes, and says so, only after the save works. If the save fails it says "Couldn’t save it…" and the phone keeps the old values.
  - **Rooms and rent:** the rate card is upserted to `rate_cards`, and each room's type and rent go to `rooms`.
  - **Deals:** `deals` (which deals, which rooms, confirmed now).
  - **House rules:** `hostels.rules` (`[{k, v}]`). The hostel page shows the saved rules plus the money rules.
  - **UPI ID:** `hostels.upi_id` / `upi_name`. It is saved about a second after the owner stops typing, and only once it looks like a UPI ID. The screen design is unchanged; there's no extra button.
- Listings now read each hostel's deals and saved rules, so tenants see them.
- No new SQL: staff could already write these tables, and the hostel guard allows rules and the UPI ID.
- **Not here:** room layouts. On the server only the Hostelzy team edits layouts (RLS). Owner layout edits stay on the phone until the founder decides whether owners may publish layouts.
- Test: `S3: on Supabase, owner edits (rates, deals, rules, UPI ID) are saved on the server`.

**S7 · owner-plan invoices in the app · 2026-10-02** (branch `feature/s7-plan-invoices`):
- **Plan screen:** signed in on Supabase, it reads `invoices` and the trial end (`owner_plans.trial_ends`) from the server.
- **Before the first invoice:** the screen shows the trial. Paying early says "Your first invoice isn’t out yet". There are no sample invoices on the server.
- **Once an invoice exists:** the amount and UPI note come from the server's invoice. "I’ve paid" saves the UTR on the server (`checking`). The team marks it paid or not received, from the app's founder admin or the web console. Invoices update live.
- **Migration `20261002120000_s7_invoices.sql`:**
  - The owner can't change an invoice that is already paid (guard fix).
  - `invoices` is added to Realtime.
  - Tests: `supabase/tests/invoices_test.sql`.
- Test: `S7: on Supabase, the owner's plan invoice comes from the server`.

**S4 · reviews on the server · 2026-10-02** (branch `feature/s4-reviews`):
- **Reading:** listings read each live hostel's `reviews`, newest first. A hostel's rating, review count and stats (category averages, advance returned in full, layout accurate % with Mostly counting half) come from them. The ranking uses the real rating.
- **Posting:**
  - A resident posts a 30-day or exit review to the hostel they live in (`myHostel`). The server checks the confirmed stay. Without one the app says reviews open once the owner adds you, and nothing is sent.
  - Owners reply. The server lets them change only the reply, and it sets `replied_at`.
  - After posting, the hostels are fetched again.
- **Migration `20261002130000_s4_reviews.sql`:**
  - The layout answer may be Mostly (as the app asks).
  - Tests: `supabase/tests/reviews_test.sql`.
- **Not yet:** a "layout is wrong" review doesn't flag the room's layout on the server. Reviews don't store the room, so the team sees it in the review instead.
- Test: `S4: on Supabase, reviews come from the server, residents post them and owners reply`.

**S5 · Fair Play on the server · 2026-10-02** (branch `feature/s5-fair-play`):
- **Cases:** owners and the team see their `fair_cases` live. The statuses map to the app as new, decide (owner replied, team to decide), waiting (team asked for more) and closed.
- **Owner:**
  - **Fix:** `fix_case()` works only within 48 hours. It switches the resident to Via Hostelzy and closes the case with no strike. After 48 hours the owner is told to reply instead.
  - **Reply:** sets `owner_reply`. A reply to a case the team sent back returns it to the team.
- **Team (founder admin):** close, ask for more, or strike. A strike adds a `strikes` row and the result text.
- **Strike counts:** shared with everyone through `strike_counts()`, because 2 strikes hide deals, 3 hide the listing, and ranking uses them. The strike rows themselves stay private.
- **Tenant:**
  - The private report goes to `fair_reports`, about the hostel of the ended hold. The owner never sees it.
  - The report sheet names that hostel instead of the sample one.
- **Migration `20261002140000_s5_fair_play.sql`:**
  - Updated guard, `fix_case`, `strike_counts`, and `fair_cases` added to Realtime.
  - Tests: `supabase/tests/fairplay_test.sql`.
- **Not on the server:** the "3 fixes in 6 months = 1 warning" count. The team sees the fixes in closed cases.
- Test: `S5: on Supabase, Fair Play cases, replies, fixes, decisions and reports go to the server`.

**S8 · managers and multi-hostel owners · 2026-10-02** (branch `feature/s8-managers`):
- **Role gates (real APK):** the gates were still the sample ones, so owners couldn't open owner screens unless they were on the team, and residents could never open resident screens.
  - "I run a hostel" opens once the server lists you as staff of a hostel (`hostel_staff`).
  - "I live in a Hostelzy PG" opens once the owner has confirmed your stay.
- **Switcher:** the owner switcher lists the hostels you run on the server, and the owner screens follow the first one. Hostels whose rooms weren't loaded (for example, listings loaded before sign-in) are fetched once more, never opened empty.
- **Managers:** a typed phone number proves nothing (phones aren't verified), so a manager joins with a one-time code.
  - The owner adds a manager (name, phone), and the server makes the code (`new_manager_invite`, owner only).
  - WhatsApp opens with the invite link. The manager opens it, signs in with Google and is made staff (`join_as_manager`, which works once, for 7 days). The owner gets a push.
  - The owner's manager list shows who joined.
- **Migration `20261002150000_s8_managers.sql`:**
  - The `manager_invites` table and the two functions.
  - Tests: `supabase/tests/managers_test.sql`.
- Test: `S8: on Supabase, owners see the hostels they run; managers join with a one-time code`.

**S6 · Stay Rewards on the server · 2026-10-02** (branch `feature/s6-stay-rewards`). The amounts are DECISIONS': ₹100 Member reward and ₹100 each for referrals. Guardrails come from the Ideas chat.
- **Ledger:** `reward_ledger` is append-only. A trigger refuses every update and delete, even the team's.
  - Each row has: who (tenant `user_id` or owner `hostel_id`), kind, amount, reason, source stay or user, created by, and when.
  - A unique `event_key` means each event is granted once.
- **Grants:** only the server makes them, never the app.
  - `rewards_on_stay` (trigger): a confirmed "Via Hostelzy" stay makes the tenant a Member with +₹100. On a later Hostelzy stay, the tenant's balance is spent at move-in (`spend`), and the same amount is credited to that owner (`owner_credit`, added to `owner_plans.credit` for their next invoice).
  - `referral_sweep()` (daily, pg_cron): ₹100 to the friend and ₹100 to the referrer, once the friend's first Hostelzy month is done.
  - `my_referral_code()` makes the code ("ASHA-4K7Q"). `use_referral_code(code)` works once, before a first stay, and not with your own code.
- **No cash-out:** a tenant's balance only comes off a Hostelzy move-in, and an owner's credit only off a Hostelzy invoice.
- **Team:** `reverse_reward(id, why)` adds a reversal row with the opposite amount (an owner credit also comes off their plan credit). The console has a new "Rewards" page that shows the ledger, with Reverse.
- **App:**
  - Stay Rewards reads Member status, balance, the code, used, and friends rewarded from the server.
  - New tenants can enter a friend's code.
  - "Yes, I joined" and "I've moved in" no longer grant anything on the phone. They say the reward comes once the owner confirms the stay.
  - Owner credits on the plan screen come from the ledger.
- **Migration `20261002170000_s6_stay_rewards.sql`:** tests in `supabase/tests/rewards_test.sql`.
- **Not built:** F09's "Hostelzy-funded rewards capped monthly (e.g. ₹3,000)". No amount is decided, so there's no cap yet; the team can reverse entries.
- Test: `S6: on Supabase, Stay Rewards come from the server ledger; nothing is granted by the phone`.
