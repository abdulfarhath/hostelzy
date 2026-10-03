# Hostelzy architecture (target) · Ideas chat, 2026-10-02

## Today (updated 2026-10-03)
One Flutter app. `AppState` (`state.dart`) is a shell over per-feature state in `lib/features/*`,
with go_router deep links and the Android back stack. The release APK (`hostelzy.apk`) runs on
Supabase (`SupabaseRepo`): Google sign-in through Firebase, live rows with Realtime, RLS on every
table, photos in Storage, FCM push, Crashlytics, and an offline copy of the hostels list. Sample data
(`SampleRepo`, `DATA=sample`) is only for the demo APK (`hostelzy-demo.apk`) and the flow tests.

## Before (2026-10-02, for history)
Everything ran through one big `AppState` with string screens inside a single `MaterialApp(home:)`;
data was seeded in `data.dart`, lived only in memory, and the release APK ran `DATA=sample`.

## Target
```
 Phone app (Flutter)
 ├─ UI screens (unchanged look: kit.dart, Pal, T, CssLine…)
 ├─ Router: go_router, real back stack, deep links (hostelzy.in/r/HZ-…)
 ├─ State per area: session · explore · holds · resident · owner · team
 │    (ChangeNotifier per area, or Riverpod; AppState shrinks to a shell)
 ├─ Repositories (one interface, two sources)
 │    ├─ SupabaseRepo  → real data, realtime subscriptions
 │    └─ SampleRepo    → demo/tests only (debug builds, flow tests)
 ├─ Local cache: shared_preferences (session, settings) + Hive/drift (offline lists, drafts)
 └─ Services: AuthService (Firebase Google sign-in → Supabase third-party JWT),
              PushService (FCM token), LocationService (geolocator), Launch (wa.me, tel:, upi://)

 Firebase:  Auth (Google now, phone OTP later) · Cloud Messaging · Crashlytics
 Supabase:  Postgres + RLS (all tables) · Realtime · Storage (hostel/room photos)
            Edge Functions: issue HZ codes, expire holds (cron), send pushes (FCM),
            match residents (60-day window), Fair Play signals, invoice generation
 Team console: small separate web app (Flutter web or plain web) behind real admin login
            for onboarding, payments check, Fair Play cases, layout help. Removed from the
            phone app's passcode mode once ready.
 CI: GitHub Actions → test → APK (signed with secret key) → Releases; later AAB → Play Console.
```

## Rules
- The server is the source of truth for holds, payments, codes, stays, reviews, cases. The phone
  never decides "paid", "confirmed" or "verified" on its own.
- Every write goes through RLS-checked tables or an Edge Function; no service_role key in the app.
- Sample data only in debug builds and tests.
- Each feature folder owns its screens, state and repository calls (`lib/features/<area>/`).

## Migration order (small steps, app keeps working)
1. Router + back stack (go_router) and session restore (shared_preferences + Firebase currentUser). (F18 groups 1–2) **go_router 2026-10-02:** `lib/router.dart` (`MaterialApp.router`); deep links `hostelzy://app/r?c=HZ-…` and `/j?c=…` (also under `/hostelzy/app/`). Screens and the back stack stay in `AppState`; Android back is the shell's PopScope.
2. `Me` profile (name, phone, role) from Supabase `profiles`; sample identity removed. (F18 group 3)
3. Repository interface; move hostels/rooms/beds/rates reads to SupabaseRepo; release builds use it. **Done 2026-10-02 (B3):** `lib/features/listings/repo.dart`; CI publishes `hostelzy.apk` (Supabase) and `hostelzy-demo.apk` (samples).
4. Split `AppState` by area as each feature moves to the repository. **Done 2026-10-02 (B4):** `lib/features/<area>/` parts (fair_play, rewards, plan, layouts, team, onboarding, reviews, session, map, residents, holds, payments, listings, links); `state.dart` keeps the core.
5. Edge Functions: HZ codes, hold expiry cron, push sending, resident matching. **Built 2026-10-02 (B5):** rules in the database (`supabase/migrations/20261002030000_b5_server_rules.sql`: HZ/FP codes, hold rules + expiry, 60-day matching, Fair Play signals, invoices, push outbox; jobs on pg_cron) and the `send-push` Edge Function (FCM HTTP v1). Tests: `supabase/tests/b5_test.sql`, `supabase/functions/tests/`.
6. Realtime for holds/enquiries/payments so owner and tenant phones stay in sync. **Built 2026-10-02 (B6):** `lib/features/listings/live.dart` + `SupabaseRepo.live()/changes()`; migration `20261002040000_b6_realtime.sql` adds holds, enquiries, payments, complaints to `supabase_realtime`. A change is a signal; the app refetches (debounced 400 ms) under RLS.
7. Storage for photos; team web console with admin login; remove passcode mode. **Built 2026-10-02 (B7):** photos in Storage (`hostel_photos`, `hostel-photos` bucket); team = Firebase `team` claim set by the founder's "Team member" GitHub action (`tools/team-member.ts`); console at `app/console/` (farhath.me/hostelzy/app/console/); passcode removed.
