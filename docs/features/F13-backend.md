# F13 · Backend

**Stage:** Building · part 1 (Supabase schema + data layer) merged 2026-10-02

## Problem
Everything is sample data on one phone.

## What it does
Supabase (Mumbai): multi-hostel schema, row-level security, phone OTP (MSG91), realtime, storage; Firebase push + Crashlytics; staging + production projects.

## Rules
- Free plan while building; Pro at launch.

## Open questions
- SMS provider for phone OTP (MSG91 or Twilio): founder sets it up, then part 2.

## Founder steps · Supabase (do these once)

Run the database setup:
1. Open https://supabase.com/dashboard/project/oafiaczotlilomlvhphp
2. Left menu → **SQL Editor**.
3. Click **New query**.
4. Open `supabase/migrations/20261002000000_f13_schema.sql` on GitHub.
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

Later, when phone login is ready (part 2), you'll get 3 more short steps for the SMS provider.

## Founder steps · Firebase

Nothing to do now. Push and crash reports are already in the app.

Lock the Firebase key to the app (do this **after** the app has its real signing key, F15):
1. Play Console → your app → Test and release → App integrity → App signing.
2. Copy the **SHA-1** of the app signing key.
3. Open https://console.cloud.google.com/apis/credentials?project=hostelzy
4. Click **Android key (auto created by Firebase)**.
5. Application restrictions → **Android apps**.
6. Add: package `app.hostelzy.hostelzy` + the SHA-1.
7. Save.

Why wait: today's test APKs are signed with a throwaway key that changes every build. A SHA-1 lock now would break push in them. The key in `google-services.json` is meant to be in the app; the lock stops other apps from using it.

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

**Part 2 (next):**
- phone OTP through Supabase Auth plus MSG91 or Twilio;
- owner, resident and team screens read and write their tables;
- realtime updates;
- photo storage;
- switch the default to `supabase`;
- staging and production projects.
- Save push tokens and add the `send-push` Edge Function (FCM HTTP v1).
