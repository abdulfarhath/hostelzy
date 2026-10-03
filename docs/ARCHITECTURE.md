# Hostelzy architecture (as it is, 2026-10-03)

How the code is organised today and how to change it safely. The repo map is in
`docs/START-HERE.md` §3; this file goes one level deeper. Build owns this file.

## 1. The pieces

```
 Phone app (Flutter 3.47.5, hostelzy/)
   UI (lib/ui kit + lib/features/<area> screens) ──reads/writes──▶ AppState (one ChangeNotifier)
                                                                     │  per-area state = `part` files
                                                                     ▼
                                                              HostelRepo (one interface)
                                                    ┌────────────────┴────────────────┐
                                               SampleRepo                        SupabaseRepo
                                          (demo APK, tests)                 (release APK, staging)
                                                                                    │ PostgREST + RPC
                                                                                    ▼
 Supabase (Mumbai)  Postgres + RLS on every table · SQL functions (RPC) · pg_cron jobs · Realtime · Storage
                    push_outbox ──▶ Edge Function send-push ──▶ FCM ──▶ phones
 Firebase           Auth (Google sign-in; its ID token is Supabase's third-party JWT) · FCM · Crashlytics
 Web (app/)         public pages (privacy, terms, delete-account, r/ enquiry links, j/ invite links)
                    + team console app/console/ (plain JS on Supabase, team claim required)
```

## 2. Code map (`hostelzy/lib/`)

| Path | What lives there |
|---|---|
| `main.dart` | Start-up: Firebase, Supabase, which repo, push, crash reporting, first listings load |
| `app_config.dart` | Build switches (`DATA`, `HZ_ENV`, Supabase URL/anon key, `phoneOtpLogin`), web base URL and links |
| `router.dart` | `go_router` for deep links (`/r?c=HZ-…`, `/j?c=…`); screens themselves are state, not routes |
| `state.dart` | `AppState` core: current screen, back stack, sheet, toast, persistence. `part`s every area's state |
| `data.dart` + `data/` | Models and pure helpers by domain (hostels, holds, deals, layouts, reviews, plan…), sample data, `fmt` (₹, dates) |
| `features/<area>/<area>.dart` | That area's state: a `mixin` of fields + an `<Area>Actions` extension on `AppState` (a `part of state.dart`) |
| `features/<area>/*_screen(s).dart`, `*_sheets.dart` | That area's screens and sheets |
| `features/listings/` | Data access: `repo.dart` (`HostelRepo` interface), `supabase_repo.dart`, `sample_repo.dart`, `rows.dart` (row → model), `live.dart` (realtime), `sync.dart` (load/apply), `cache.dart` (offline list) |
| `ui/kit.dart` | Design tokens (`Pal` light/dark) and CSS-faithful primitives: `T`, `CssLine`, `CssRow`, icons |
| `ui/common.dart` | Shared widgets: `Cta`, `OutlineCta`, `Seg`, chips, fields, bed boxes |
| `ui/shell.dart` | Frame, tab bar, the **screen map** (`s.screen` → widget) and **sheet map** (`s.sheet` → widget), toast |
| `ui/overview.dart` | Debug-only "all screens" page |
| `push.dart`, `reminders.dart`, `sign_in.dart`, `store.dart`, `locate.dart`, `l10n.dart` | Services: FCM token, local notifications, Google sign-in, local storage, location, strings |

Areas: `explore`, `holds`, `residents`, `owner`, `session`, `layouts`, `onboarding`, `team`,
`fair_play`, `reviews`, `rewards`, `plan`, `payments`, `moves`, `meter`, `laundry`, `food`, `amenities`,
`photos`, `map`, `reminders`, `links`, `listings`.

Other folders: `supabase/migrations/` (schema, RLS, RPCs, jobs; applied in file-name order),
`supabase/tests/` (SQL tests, `run.sh`), `supabase/functions/send-push/` (+ `tests/`), `app/console/`
(team console: `console.js` UI, `logic.js` pure helpers with node tests), `tools/` (`check.sh`, `team-member.ts`).

## 3. Data flow

1. **Read.** On start (and on pull/refresh) `sync.dart` calls `HostelRepo.listings()`. `SupabaseRepo`
   loads live hostels with rooms, beds, rates, deals, rules, reviews in a few batched selects plus public
   RPCs (`hostel_flags`, `fair_standing`, `layout_checks`, `hostel_layout_checks`…), parses them in
   `rows.dart`, and `AppState.applyListings` replaces the samples. The rows are also cached on the phone
   (`cache.dart`) so Explore can show "Offline · hostels as of…".
2. **Who sees what** is decided only by Postgres RLS and `security definer` functions (`is_staff`,
   `is_team`, `is_live`, `deals_paused`, `deals_hidden`…). The app holds only the public anon key; the
   signed-in user's Firebase ID token is passed as the JWT. Never put the service_role key anywhere.
3. **Write.** Actions in `features/<area>/<area>.dart` call one `HostelRepo` method (insert/update under
   RLS, or an RPC when the server must check rules: holds, go-live, payments, Fair Play, moves…). On error
   the state is rolled back and a plain toast says it couldn't save. The phone never decides "paid",
   "confirmed" or "verified".
4. **Realtime.** `live.dart` subscribes to holds, enquiries, payments, complaints (and others added to
   `supabase_realtime`). A change is only a signal: the app refetches the affected list under RLS,
   debounced 400 ms.
5. **Push.** SQL triggers and pg_cron jobs insert into `push_outbox` with `data.kind` (hold, rent, plan,
   beds…). The `send-push` Edge Function sends via FCM, skipping users whose switch for that kind is off
   and never notifying the person who caused the change. Local reminders (water, meals, laundry, rent)
   are scheduled on the phone by `reminders.dart`.
6. **Sample data** never reaches a real build: `AppState.samples` is true only for `DATA=sample`
   (demo APK, debug, tests). Real builds start empty and say so ("No hostels in this area yet"…).

## 4. How to add a screen or sheet

1. Put the widget in `features/<area>/<area>_screen(s).dart` (or `_sheets.dart`) using `kit.dart` /
   `common.dart` building blocks (`T`, `Pal` via `PalScope.of`, `Cta`, `Seg`, `box()`, `Ic`). Light and
   dark, 390×844, 2× text must fit. No hard-coded colours, no invented values.
2. Register it in `ui/shell.dart`: a key in the screen map (`'oMeter' => const OwnerMeterScreen()`) or
   the sheet map (body, title, kicker). Navigate with `s.go('key')`, open sheets with `s.sheet = 'key'`.
3. State: fields in the area's mixin, actions in its `<Area>Actions` extension; data via `HostelRepo`
   (add the method to the interface, `SupabaseRepo` and `SampleRepo`).
4. Add a flow test in `hostelzy/test/` (widget test pumping `HostelzyShell` with an `AppState`; use a fake
   repo for server paths).
5. Add the screen to `docs/SCREENS.md` (id, name, file, how it's reached) and list it under
   "Screens added" in the PR, so Design adds its board (canvas = app, 1:1).

## 5. How to add a migration

1. New file `supabase/migrations/<yyyymmddhhmmss>_<name>.sql`, later than every existing one. Make it
   re-runnable (`if not exists`, `create or replace`, `drop policy if exists`). RLS on every new table;
   `security definer set search_path = ''` for functions; `grant execute` only to who needs it.
2. Add `supabase/tests/<name>_test.sql` (use `test.act`, `test.rows`, `test.eq`, `test.fails`, `test.blocked`;
   unique fixture ids) and append it to `supabase/tests/run.sh`.
3. Add a FOUNDER-TODO step in run order (label after the last one): "Supabase → SQL Editor → paste
   `supabase/migrations/<file>` → **Run** → "Success". What it does. Until it runs, what the app does."
4. The app must keep working before the founder runs it: catch the missing function/column
   (`_missingFn` in `supabase_repo.dart`) and fall back or say it couldn't save.

## 6. Demo vs real builds

| | Real (`hostelzy.apk`) | Demo (`hostelzy-demo.apk`) | Debug / tests |
|---|---|---|---|
| `--dart-define` | `DATA=supabase` | `DATA=sample` | default `sample` |
| Repo | `SupabaseRepo` | `SampleRepo` | `SampleRepo` or a test fake |
| Data | live hostels only; empty states when none | built-in Hyderabad samples | samples |
| Banner | none | "DEMO" | none |
| Staging | `HZ_ENV=staging` + its own URL/key (Play build workflow) | — | — |

## 7. Checks, CI and release

- Locally: `tools/check.sh` = `flutter analyze` + `flutter test` + SQL tests (starts a throwaway
  Postgres 16 if needed) + push/console function tests; `--fast` for the first two. Cloud sessions get
  Flutter from `.claude/hooks/session-start.sh`.
- Lints: `hostelzy/analysis_options.yaml` (`flutter_lints` + strict set: const, final locals,
  unawaited futures, single quotes, directives ordering, strict casts…). Keep it clean.
- PRs: `android-check.yml` (analyze, test, release build), `supabase-check.yml` (SQL tests + function
  tests, on PRs touching `supabase/` or `tools/`). Branch `feature/<id>-<name>`; merge when green (standing approval in CLAUDE.md).
- Push to `main` → `android-apk.yml` builds both APKs and publishes GitHub release `apk-<run number>`
  (give the founder the release page, never the .apk link). `supabase-functions.yml` deploys
  `send-push` when its code changes. `android-aab.yml` (manual) makes the Play Store AAB.
- The founder runs SQL by hand (FOUNDER-TODO); nothing deploys migrations automatically.

## 8. Rules

- Server is the source of truth for holds, payments, codes, stays, reviews, cases, strikes, plans.
- Every write is RLS-checked or goes through a checked RPC; no service_role key in the app or repo.
- Sample data only in the demo build, debug and tests.
- Each feature folder owns its screens, state and repo calls. Keep files under ~800 lines.
- Never contradict `docs/DECISIONS.md`; the site root `index.html`, `project/` and `chats/` are history.
