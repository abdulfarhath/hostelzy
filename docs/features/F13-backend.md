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
- Firebase (push, Crashlytics), package `app.hostelzy.hostelzy`: founder is creating it.

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

**Part 2 (next):**
- phone OTP through Supabase Auth plus MSG91 or Twilio;
- owner, resident and team screens read and write their tables;
- realtime updates;
- photo storage;
- switch the default to `supabase`;
- staging and production projects.
- Then Firebase: push and Crashlytics.
