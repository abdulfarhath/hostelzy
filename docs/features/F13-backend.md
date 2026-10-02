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

**Part 2 (next):**
- SMS check of the phone (Firebase Phone Auth) once billing works;
- owner, resident and team screens read and write their tables;
- realtime updates;
- photo storage;
- switch the default to `supabase`;
- staging and production projects.
- The `send-push` Edge Function (FCM HTTP v1).
