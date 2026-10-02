# Hostelzy architecture (target) · Ideas chat, 2026-10-02

## Today
One Flutter app (~17k lines). Everything runs through one big `AppState` (`state.dart`, ~2k lines)
with string screens (`screen`, `hist`) inside a single `MaterialApp(home:)`. Data is seeded in
`data.dart` and lives only in memory. Supabase, Firebase Auth/FCM/Crashlytics are wired in but the
release APK runs `DATA=sample`. Problems: no back stack, nothing persists, sample identity
everywhere, one class owns every feature.

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
1. Router + back stack (go_router) and session restore (shared_preferences + Firebase currentUser). (F18 groups 1–2)
2. `Me` profile (name, phone, role) from Supabase `profiles`; sample identity removed. (F18 group 3)
3. Repository interface; move hostels/rooms/beds/rates reads to SupabaseRepo; release builds use it. **Done 2026-10-02 (B3):** `lib/features/listings/repo.dart`; CI publishes `hostelzy.apk` (Supabase) and `hostelzy-demo.apk` (samples).
4. Split `AppState` by area as each feature moves to the repository. **Done 2026-10-02 (B4):** `lib/features/<area>/` parts (fair_play, rewards, plan, layouts, team, onboarding, reviews, session, map, residents, holds, payments, listings, links); `state.dart` keeps the core.
5. Edge Functions: HZ codes, hold expiry cron, push sending, resident matching.
6. Realtime for holds/enquiries/payments so owner and tenant phones stay in sync.
7. Storage for photos; team web console with admin login; remove passcode mode.
