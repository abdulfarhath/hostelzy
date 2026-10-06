-- Hostelzy: every migration, for a NEW Supabase project (staging), in ONE file. Generated 2026-10-06 by tools/sql-bundle.sh.
-- How: Supabase → SQL Editor → New query → paste this whole file → Run → "Success. No rows returned".
-- One transaction: if anything fails, nothing changes. Run it ONCE on an empty project. First enable pg_cron and pg_net (Database → Extensions).
begin;

-- ================================================================
-- 20261002000000_f13_schema.sql
-- ================================================================
-- Hostelzy F13 · schema + Row Level Security (one file: paste it into the
-- Supabase SQL editor and press Run, or `supabase db push`).
--
-- Who can see what:
--   anyone (anon key)      live hostels, their rooms, beds, rate cards, deals,
--                          reviews, app settings
--   signed-in user         + their own profile, holds, enquiries, payments,
--                          stays, complaints, requests, reports; published
--                          room layouts (women's PGs: not for anonymous users)
--   owner / manager        + everything about their own hostels
--   Hostelzy team          everything. "Team" is the `team: true` claim in the
--                          user's app_metadata, which only the dashboard or the
--                          service_role key can set. It never comes from the app.
--
-- Rules the database enforces, not just the app (DECISIONS "No fake
-- behaviour"): a tenant can never mark their own payment paid; only the
-- hostel's owner or manager confirms it. An owner can never mark their own
-- Hostelzy invoice paid. Reviews need a stay at that hostel.
-- The last block refuses to finish if any table is missing RLS.

-- ---------------------------------------------------------------- helpers

create or replace function public.is_team() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((auth.jwt() -> 'app_metadata' ->> 'team')::boolean, false) $$;

-- Real (not anonymous) signed-in user.
create or replace function public.is_verified() returns boolean
language sql stable security definer set search_path = ''
as $$ select auth.uid() is not null and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) $$;

-- ---------------------------------------------------------------- profiles

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text,
  name text not null default '',
  role text not null default 'tenant' check (role in ('tenant', 'resident', 'owner')),
  member boolean not null default false,          -- F09 Hostelzy Member
  ref_code text unique,                           -- F09 referral code
  created_at timestamptz not null default now()
);

-- New sign-up → empty profile with the phone from Auth.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, phone) values (new.id, new.phone) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- hostels

create table public.hostels (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  gender text not null check (gender in ('Men', 'Women', 'Co-living')),
  area text not null,
  address text not null default '',
  lat double precision,
  lng double precision,
  owner_name text not null default '',            -- first name shown to tenants
  food boolean not null default false,
  ac boolean not null default false,
  only_ac boolean not null default false,
  instant boolean not null default false,
  tags text[] not null default '{}',
  terms jsonb not null default '{"advance":3000,"maintenance":1000,"noticeDays":30,"dueOnJoining":true,"electricityExtra":true}',
  rules jsonb not null default '[]',              -- F07 house rules
  upi_id text not null default '',                -- F17: where tenants pay the owner
  upi_name text not null default '',
  status text not null default 'draft' check (status in ('draft', 'live', 'paused')),
  created_at timestamptz not null default now()
);

create table public.hostel_staff (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'manager')),
  created_at timestamptz not null default now(),
  primary key (hostel_id, user_id)
);

create or replace function public.is_staff(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.user_id = auth.uid()) $$;

create or replace function public.is_owner(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.user_id = auth.uid() and s.role = 'owner') $$;

create or replace function public.is_live(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.status = 'live') $$;

-- ---------------------------------------------------------------- rooms, beds, rates, deals

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  number int not null,
  label text,                                     -- "204A" when not a plain number
  floor int not null,
  share int not null check (share between 1 and 8),
  ac boolean not null default false,
  ac_repair boolean not null default false,
  bath text not null default 'Shared' check (bath in ('Attached', 'Shared')),
  rent int not null check (rent >= 0),
  unique (hostel_id, number)
);

create table public.beds (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room_id uuid not null references public.rooms (id) on delete cascade,
  letter text not null,
  spot text not null default '',
  state text not null default 'free' check (state in ('free', 'held', 'soon', 'booked')),
  free_from date,                                 -- for 'soon'
  confirmed_at timestamptz,                       -- owner's last "beds are right"
  unique (room_id, letter)
);

create table public.rate_cards (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  ac boolean not null,
  share int not null,
  rent int not null check (rent >= 0),
  primary key (hostel_id, ac, share)
);

create table public.deals (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  deals_on text[] not null default '{}',
  target text not null default '',
  confirmed_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- holds, enquiries

create table public.holds (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  bed_id uuid not null references public.beds (id) on delete cascade,
  tenant_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  opt text not null check (opt in ('free', 'paid', 'advance')),
  ref text,                                       -- HZ code
  status text not null default 'waiting' check (status in ('waiting', 'held', 'booked', 'released', 'expired')),
  started_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.enquiries (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  tenant_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  ref text not null,
  name text not null,
  phone text not null,
  source text not null default '',                -- "Hostel page · Ask on WhatsApp"
  msg text not null default '',
  bed text,
  contacted boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- residents (stays)

create table public.stays (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  bed_id uuid references public.beds (id) on delete set null,
  user_id uuid references auth.users (id) on delete set null,   -- set once the resident joins the app
  name text not null,
  phone text not null default '',
  via text not null default 'direct' check (via in ('hz', 'direct', 'before')),
  ref text,                                       -- matched HZ code (F06)
  rent int not null default 0,
  advance int not null default 0,
  joined_on date not null default current_date,
  late_days int not null default 0,               -- F06 3-day rule
  confirmed boolean not null default false,
  left_on date
);

create or replace function public.is_resident(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.stays s where s.hostel_id = h and s.user_id = auth.uid() and s.left_on is null) $$;

create or replace function public.has_stayed(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.stays s where s.hostel_id = h and s.user_id = auth.uid() and s.confirmed) $$;

-- ---------------------------------------------------------------- payments (F17: UPI → UTR → owner confirms)

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  payer_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  stay_id uuid references public.stays (id) on delete set null,
  hold_id uuid references public.holds (id) on delete set null,
  kind text not null check (kind in ('advance', 'rent')),
  amount int not null check (amount > 0),
  note text not null default '',                  -- UPI note
  utr text check (utr ~ '^[0-9]{12}$'),
  status text not null default 'pending' check (status in ('pending', 'waiting', 'missing', 'paid', 'cancelled')),
  confirmed_by uuid references auth.users (id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Who may change what on a payment. Staff (or the team) confirm; the payer only
-- adds the UTR, resends or cancels, and can never set 'paid'.
create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.hostel_id <> old.hostel_id or new.payer_id <> old.payer_id or new.kind <> old.kind or new.amount <> old.amount then
    raise exception 'payment details cannot change';
  end if;
  if public.is_staff(old.hostel_id) and old.payer_id <> auth.uid() then
    if new.utr is distinct from old.utr or new.note <> old.note then raise exception 'only the payer edits the UTR'; end if;
    if old.status <> 'waiting' or new.status not in ('paid', 'missing') then raise exception 'owner confirms waiting payments only'; end if;
    new.confirmed_by := auth.uid();
    new.confirmed_at := now();
  else
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

create trigger guard_payment before update on public.payments
for each row execute function public.guard_payment();

-- ---------------------------------------------------------------- resident life

create table public.complaints (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  bed text not null default '',
  cat text not null,
  body text not null,
  status text not null default 'Open' check (status in ('Open', 'In progress', 'Fixed')),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.move_requests (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('vacate', 'swap')),
  last_day date,
  to_bed text,
  status text not null default 'open' check (status in ('open', 'accepted', 'declined', 'withdrawn')),
  created_at timestamptz not null default now()
);

create table public.menus (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  day int not null check (day between 0 and 6),
  breakfast text not null default '',
  lunch text not null default '',
  dinner text not null default '',
  primary key (hostel_id, day)
);

-- ---------------------------------------------------------------- reviews (F08)

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  author_name text not null,                      -- "Rahul V."
  kind text not null default 'stay' check (kind in ('stay', 'exit')),
  stars int not null check (stars between 1 and 5),
  body text not null default '',
  cats jsonb not null default '{}',
  layout text check (layout in ('Yes', 'No')),
  advance text,                                   -- exit review: all | part | none
  again text,
  reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

-- Owners only add a reply; nobody else edits a review (the team can).
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  new.replied_at := now();
  return new;
end $$;

create trigger guard_review before update on public.reviews
for each row execute function public.guard_review();

-- ---------------------------------------------------------------- Fair Play (F07)

create table public.fair_reports (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  why text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.fair_cases (
  id uuid primary key default gen_random_uuid(),
  ref text unique not null,                       -- FP-0143
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  title text not null,
  signal text not null,
  status text not null default 'new' check (status in ('new', 'waiting', 'decided', 'closed')),
  resident text,
  events jsonb not null default '[]',
  owner_reply text,
  decision text,
  created_at timestamptz not null default now()
);

-- Owners only add their reply; the Hostelzy team decides.
create or replace function public.guard_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'owner_reply') <> (to_jsonb(old) - 'owner_reply') then
    raise exception 'owners can only reply; the Hostelzy team decides';
  end if;
  return new;
end $$;

create trigger guard_case before update on public.fair_cases
for each row execute function public.guard_case();

create table public.strikes (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  case_id uuid references public.fair_cases (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- owner plan (F10)

create table public.owner_plans (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  tier int not null default 0,
  trial_ends date,
  status text not null default 'trial' check (status in ('trial', 'active', 'overdue', 'paused')),
  credit int not null default 0
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  ref text unique not null,                       -- HZ-INV-1024
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  beds int not null,
  amount int not null check (amount >= 0),
  due date not null,
  utr text check (utr ~ '^[0-9]{12}$'),
  status text not null default 'due' check (status in ('due', 'checking', 'paid', 'missing')),
  late int not null default 0,
  created_at timestamptz not null default now()
);

-- Owners send the UTR; only the Hostelzy team marks an invoice paid.
create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

create trigger guard_invoice before update on public.invoices
for each row execute function public.guard_invoice();

-- ---------------------------------------------------------------- room layouts (F12)

-- One draft (the team edits) and one published copy (tenants see) per room.
create table public.layouts (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  stage text not null check (stage in ('draft', 'published')),
  version int not null default 1,
  w double precision not null,
  h double precision not null,
  beds jsonb not null default '{}',
  items jsonb not null default '[]',
  bunks jsonb not null default '{}',
  waiting_approval boolean not null default false,
  disputes int not null default 0,
  confirmed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (hostel_id, room, stage)
);

-- Owner approves the team's draft: it becomes the published copy.
create or replace function public.approve_layout(p_hostel uuid, p_room int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_owner(p_hostel) or public.is_team()) then raise exception 'only the owner approves a layout'; end if;
  insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items, bunks, disputes, confirmed_at)
  select hostel_id, room, 'published', version, w, h, beds, items, bunks, 0, now()
  from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'draft'
  on conflict (hostel_id, room, stage) do update
    set version = excluded.version, w = excluded.w, h = excluded.h, beds = excluded.beds,
        items = excluded.items, bunks = excluded.bunks, disputes = 0, confirmed_at = now(), updated_at = now();
  update public.layouts set waiting_approval = false where hostel_id = p_hostel and room = p_room and stage = 'draft';
end $$;

-- ---------------------------------------------------------------- app settings (F15 remote switches)

create table public.app_settings (
  key text primary key,
  value text not null default ''
);

insert into public.app_settings (key, value) values ('min_supported_build', '0'), ('maintenance_until', '');

-- ================================================================ Row Level Security

alter table public.profiles enable row level security;
alter table public.hostels enable row level security;
alter table public.hostel_staff enable row level security;
alter table public.rooms enable row level security;
alter table public.beds enable row level security;
alter table public.rate_cards enable row level security;
alter table public.deals enable row level security;
alter table public.holds enable row level security;
alter table public.enquiries enable row level security;
alter table public.stays enable row level security;
alter table public.payments enable row level security;
alter table public.complaints enable row level security;
alter table public.move_requests enable row level security;
alter table public.menus enable row level security;
alter table public.reviews enable row level security;
alter table public.fair_reports enable row level security;
alter table public.fair_cases enable row level security;
alter table public.strikes enable row level security;
alter table public.owner_plans enable row level security;
alter table public.invoices enable row level security;
alter table public.layouts enable row level security;
alter table public.app_settings enable row level security;

-- profiles: you see and edit your own; staff see their residents' and
-- tenants' names via stays/holds rows, not this table. Team sees all.
create policy "own profile" on public.profiles for select using (id = auth.uid() or public.is_team());
create policy "edit own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "team edits profiles" on public.profiles for all using (public.is_team()) with check (public.is_team());

-- Members and referral codes are earned, not self-set.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.member <> old.member or new.ref_code is distinct from old.ref_code or new.phone is distinct from old.phone then
    raise exception 'not allowed';
  end if;
  return new;
end $$;

create trigger guard_profile before update on public.profiles
for each row execute function public.guard_profile();

-- hostels: anyone reads live ones; staff read and edit their own; only the
-- team creates hostels, puts them live or changes the owner.
create policy "live hostels" on public.hostels for select using (status = 'live' or public.is_staff(id) or public.is_team());
create policy "staff edit hostel" on public.hostels for update using (public.is_staff(id)) with check (public.is_staff(id));
create policy "team manages hostels" on public.hostels for all using (public.is_team()) with check (public.is_team());

create or replace function public.guard_hostel() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.id <> old.id or new.slug <> old.slug or new.status <> old.status or new.gender <> old.gender
     or new.lat is distinct from old.lat or new.lng is distinct from old.lng then
    raise exception 'ask the Hostelzy team to change this';
  end if;
  return new;
end $$;

create trigger guard_hostel before update on public.hostels
for each row execute function public.guard_hostel();

-- staff list: owners see their team; the owner adds managers; team does all.
create policy "see own team" on public.hostel_staff for select using (user_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "owner adds managers" on public.hostel_staff for insert with check (public.is_owner(hostel_id) and role = 'manager');
create policy "owner removes managers" on public.hostel_staff for delete using (public.is_owner(hostel_id) and role = 'manager');
create policy "team manages staff" on public.hostel_staff for all using (public.is_team()) with check (public.is_team());

-- listing tables: public for live hostels; staff and team write.
create policy "read rooms" on public.rooms for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write rooms" on public.rooms for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read beds" on public.beds for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write beds" on public.beds for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read rates" on public.rate_cards for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write rates" on public.rate_cards for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read deals" on public.deals for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write deals" on public.deals for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- holds and enquiries: the tenant's own (verified users only), plus the hostel's staff.
create policy "own holds" on public.holds for select using (tenant_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "place hold" on public.holds for insert with check (tenant_id = auth.uid() and public.is_verified() and public.is_live(hostel_id) and status = 'waiting');
create policy "release own hold" on public.holds for update using (tenant_id = auth.uid()) with check (tenant_id = auth.uid() and status = 'released');
create policy "staff update holds" on public.holds for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

create policy "own enquiries" on public.enquiries for select using (tenant_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "send enquiry" on public.enquiries for insert with check (tenant_id = auth.uid() and public.is_verified() and public.is_live(hostel_id) and not contacted);
create policy "staff mark contacted" on public.enquiries for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- stays: staff and team manage; a resident sees their own.
create policy "read stays" on public.stays for select using (user_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "staff write stays" on public.stays for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- payments: payer and the hostel's staff. guard_payment() decides the fields.
create policy "read payments" on public.payments for select using (payer_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "start payment" on public.payments for insert with check (payer_id = auth.uid() and public.is_verified() and status in ('pending', 'waiting') and confirmed_by is null and confirmed_at is null);
create policy "update payment" on public.payments for update using (payer_id = auth.uid() or public.is_staff(hostel_id) or public.is_team()) with check (payer_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());

-- complaints and move requests: the resident's own, plus staff.
create policy "read complaints" on public.complaints for select using (author_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "raise complaint" on public.complaints for insert with check (author_id = auth.uid() and public.is_resident(hostel_id) and status = 'Open');
create policy "staff update complaint" on public.complaints for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

create policy "read requests" on public.move_requests for select using (user_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "make request" on public.move_requests for insert with check (user_id = auth.uid() and public.is_resident(hostel_id) and status = 'open');
create policy "withdraw request" on public.move_requests for update using (user_id = auth.uid()) with check (user_id = auth.uid() and status = 'withdrawn');
create policy "staff answer request" on public.move_requests for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- menus: residents and staff read; staff write.
create policy "read menu" on public.menus for select using (public.is_resident(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write menu" on public.menus for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- reviews: public for live hostels; only someone with a confirmed stay there
-- writes one (DECISIONS: reviews only from verified users with a stay).
create policy "read reviews" on public.reviews for select using (public.is_live(hostel_id) or author_id = auth.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "write review" on public.reviews for insert with check (author_id = auth.uid() and public.is_verified() and public.has_stayed(hostel_id) and reply is null);
create policy "owner replies" on public.reviews for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- Fair Play: tenants report; staff see their hostel's cases and reply; team decides.
create policy "own reports" on public.fair_reports for select using (reporter_id = auth.uid() or public.is_team());
create policy "report" on public.fair_reports for insert with check (reporter_id = auth.uid() and public.is_verified());
create policy "read cases" on public.fair_cases for select using (public.is_staff(hostel_id) or public.is_team());
create policy "owner replies to case" on public.fair_cases for update using (public.is_staff(hostel_id)) with check (public.is_staff(hostel_id));
create policy "team manages cases" on public.fair_cases for all using (public.is_team()) with check (public.is_team());
create policy "read strikes" on public.strikes for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team manages strikes" on public.strikes for all using (public.is_team()) with check (public.is_team());

-- owner plan and invoices: staff read, owners send the UTR, team manages.
create policy "read plan" on public.owner_plans for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team manages plans" on public.owner_plans for all using (public.is_team()) with check (public.is_team());
create policy "read invoices" on public.invoices for select using (public.is_staff(hostel_id) or public.is_team());
create policy "owner sends UTR" on public.invoices for update using (public.is_owner(hostel_id)) with check (public.is_owner(hostel_id));
create policy "team manages invoices" on public.invoices for all using (public.is_team()) with check (public.is_team());

-- layouts: published copies for signed-in, non-anonymous users (women's PGs
-- rule); drafts for the hostel's staff and the team; only the team edits.
create policy "read published layouts" on public.layouts for select using (stage = 'published' and public.is_verified() and public.is_live(hostel_id));
create policy "staff read layouts" on public.layouts for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team edits layouts" on public.layouts for all using (public.is_team()) with check (public.is_team());

-- app settings: everyone reads; team writes.
create policy "read settings" on public.app_settings for select using (true);
create policy "team writes settings" on public.app_settings for all using (public.is_team()) with check (public.is_team());

-- Helper functions are for policies, not for calling from the app.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ================================================================ safety check

do $$
declare missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if missing is not null then
    raise exception 'Row Level Security is off on: %', missing;
  end if;
end $$;


-- ================================================================
-- 20261002010000_f13_push_tokens.sql
-- ================================================================
-- Hostelzy F13 · push tokens (Firebase Cloud Messaging). One row per phone.
-- The app saves its token once phone login works; the send-push Edge
-- Function reads them with the service role (server side only).

create table public.push_tokens (
  token text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

-- Each user sees and manages only their own phones' tokens.
create policy "own tokens" on public.push_tokens for select using (user_id = auth.uid());
create policy "save token" on public.push_tokens for insert with check (user_id = auth.uid() and public.is_verified());
create policy "refresh token" on public.push_tokens for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "remove token" on public.push_tokens for delete using (user_id = auth.uid());

do $$
declare missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if missing is not null then
    raise exception 'Row Level Security is off on: %', missing;
  end if;
end $$;


-- ================================================================
-- 20261002020000_f13_firebase_ids.sql
-- ================================================================
-- Hostelzy F13 · schema + Row Level Security, v2: sign-in with Firebase
-- (Google), so user ids are Firebase uids (text). This file stands alone:
-- it first removes the v1 tables (no real data existed yet) and builds
-- everything again. Paste it into the Supabase SQL editor and press Run.
--
-- Who can see what:
--   anyone (anon key)      live hostels, their rooms, beds, rate cards, deals,
--                          reviews, app settings
--   signed-in user         + their own profile, holds, enquiries, payments,
--                          stays, complaints, requests, reports; published
--                          room layouts (women's PGs: not for anonymous users)
--   owner / manager        + everything about their own hostels
--   Hostelzy team          everything. "Team" is the `team: true` Firebase custom
--                          claim, which only the Firebase Admin SDK can set.
--                          It never comes from the app.
--
-- Identity: Supabase Third-party Auth (Firebase, project `hostelzy`). public.uid()
-- is the Firebase uid, and only for tokens from that project.
--
-- Rules the database enforces, not just the app (DECISIONS "No fake
-- behaviour"): a tenant can never mark their own payment paid; only the
-- hostel's owner or manager confirms it. An owner can never mark their own
-- Hostelzy invoice paid. Reviews need a stay at that hostel.
-- The last block refuses to finish if any table is missing RLS.

-- ---------------------------------------------------------------- remove v1

drop table if exists public.push_tokens, public.app_settings, public.layouts, public.invoices,
  public.owner_plans, public.strikes, public.fair_cases, public.fair_reports, public.reviews,
  public.menus, public.move_requests, public.complaints, public.payments, public.stays,
  public.enquiries, public.holds, public.deals, public.rate_cards, public.beds, public.rooms,
  public.hostel_staff, public.hostels, public.profiles cascade;
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user(), public.is_team(), public.is_verified(),
  public.is_staff(uuid), public.is_owner(uuid), public.is_live(uuid), public.is_resident(uuid),
  public.has_stayed(uuid), public.guard_payment(), public.guard_review(), public.guard_case(),
  public.guard_invoice(), public.guard_profile(), public.guard_hostel(), public.approve_layout(uuid, int) cascade;

-- ---------------------------------------------------------------- helpers

-- The signed-in user: the Firebase uid (text, not a uuid), and only for
-- tokens from Hostelzy's own Firebase project.
create or replace function public.uid() returns text
language sql stable security definer set search_path = ''
as $$
  select case when auth.jwt() ->> 'iss' = 'https://securetoken.google.com/hostelzy'
              and auth.jwt() ->> 'aud' = 'hostelzy'
         then nullif(auth.jwt() ->> 'sub', '') end
$$;

-- Hostelzy team: the `team: true` custom claim, which only the Firebase Admin
-- SDK (server side, the founder's service account) can set. Never the app.
create or replace function public.is_team() returns boolean
language sql stable security definer set search_path = ''
as $$ select public.uid() is not null and coalesce((auth.jwt() ->> 'team')::boolean, false) $$;

-- Real (not anonymous) signed-in user: Google today, SMS later.
create or replace function public.is_verified() returns boolean
language sql stable security definer set search_path = ''
as $$ select public.uid() is not null and coalesce(auth.jwt() -> 'firebase' ->> 'sign_in_provider', 'anonymous') <> 'anonymous' $$;

-- ---------------------------------------------------------------- profiles

create table public.profiles (
  id text primary key default public.uid(),
  phone text,                                     -- typed by the user
  phone_verified boolean not null default false,  -- true only after an SMS check (later)
  email text,
  name text not null default '',
  role text not null default 'tenant' check (role in ('tenant', 'resident', 'owner')),
  member boolean not null default false,          -- F09 Hostelzy Member
  ref_code text unique,                           -- F09 referral code
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- hostels

create table public.hostels (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  gender text not null check (gender in ('Men', 'Women', 'Co-living')),
  area text not null,
  address text not null default '',
  lat double precision,
  lng double precision,
  owner_name text not null default '',            -- first name shown to tenants
  food boolean not null default false,
  ac boolean not null default false,
  only_ac boolean not null default false,
  instant boolean not null default false,
  tags text[] not null default '{}',
  terms jsonb not null default '{"advance":3000,"maintenance":1000,"noticeDays":30,"dueOnJoining":true,"electricityExtra":true}',
  rules jsonb not null default '[]',              -- F07 house rules
  upi_id text not null default '',                -- F17: where tenants pay the owner
  upi_name text not null default '',
  status text not null default 'draft' check (status in ('draft', 'live', 'paused')),
  created_at timestamptz not null default now()
);

create table public.hostel_staff (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null,
  role text not null check (role in ('owner', 'manager')),
  created_at timestamptz not null default now(),
  primary key (hostel_id, user_id)
);

create or replace function public.is_staff(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.user_id = public.uid()) $$;

create or replace function public.is_owner(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.user_id = public.uid() and s.role = 'owner') $$;

create or replace function public.is_live(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.status = 'live') $$;

-- ---------------------------------------------------------------- rooms, beds, rates, deals

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  number int not null,
  label text,                                     -- "204A" when not a plain number
  floor int not null,
  share int not null check (share between 1 and 8),
  ac boolean not null default false,
  ac_repair boolean not null default false,
  bath text not null default 'Shared' check (bath in ('Attached', 'Shared')),
  rent int not null check (rent >= 0),
  unique (hostel_id, number)
);

create table public.beds (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room_id uuid not null references public.rooms (id) on delete cascade,
  letter text not null,
  spot text not null default '',
  state text not null default 'free' check (state in ('free', 'held', 'soon', 'booked')),
  free_from date,                                 -- for 'soon'
  confirmed_at timestamptz,                       -- owner's last "beds are right"
  unique (room_id, letter)
);

create table public.rate_cards (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  ac boolean not null,
  share int not null,
  rent int not null check (rent >= 0),
  primary key (hostel_id, ac, share)
);

create table public.deals (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  deals_on text[] not null default '{}',
  target text not null default '',
  confirmed_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- holds, enquiries

create table public.holds (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  bed_id uuid not null references public.beds (id) on delete cascade,
  tenant_id text not null default public.uid(),
  opt text not null check (opt in ('free', 'paid', 'advance')),
  ref text,                                       -- HZ code
  status text not null default 'waiting' check (status in ('waiting', 'held', 'booked', 'released', 'expired')),
  started_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.enquiries (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  tenant_id text not null default public.uid(),
  ref text not null,
  name text not null,
  phone text not null,
  source text not null default '',                -- "Hostel page · Ask on WhatsApp"
  msg text not null default '',
  bed text,
  contacted boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- residents (stays)

create table public.stays (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  bed_id uuid references public.beds (id) on delete set null,
  user_id text,   -- set once the resident joins the app
  name text not null,
  phone text not null default '',
  via text not null default 'direct' check (via in ('hz', 'direct', 'before')),
  ref text,                                       -- matched HZ code (F06)
  rent int not null default 0,
  advance int not null default 0,
  joined_on date not null default current_date,
  late_days int not null default 0,               -- F06 3-day rule
  confirmed boolean not null default false,
  left_on date
);

create or replace function public.is_resident(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.stays s where s.hostel_id = h and s.user_id = public.uid() and s.left_on is null) $$;

create or replace function public.has_stayed(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.stays s where s.hostel_id = h and s.user_id = public.uid() and s.confirmed) $$;

-- ---------------------------------------------------------------- payments (F17: UPI → UTR → owner confirms)

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  payer_id text not null default public.uid(),
  stay_id uuid references public.stays (id) on delete set null,
  hold_id uuid references public.holds (id) on delete set null,
  kind text not null check (kind in ('advance', 'rent')),
  amount int not null check (amount > 0),
  note text not null default '',                  -- UPI note
  utr text check (utr ~ '^[0-9]{12}$'),
  status text not null default 'pending' check (status in ('pending', 'waiting', 'missing', 'paid', 'cancelled')),
  confirmed_by text,
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Who may change what on a payment. Staff (or the team) confirm; the payer only
-- adds the UTR, resends or cancels, and can never set 'paid'.
create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.hostel_id <> old.hostel_id or new.payer_id <> old.payer_id or new.kind <> old.kind or new.amount <> old.amount then
    raise exception 'payment details cannot change';
  end if;
  if public.is_staff(old.hostel_id) and old.payer_id <> public.uid() then
    if new.utr is distinct from old.utr or new.note <> old.note then raise exception 'only the payer edits the UTR'; end if;
    if old.status <> 'waiting' or new.status not in ('paid', 'missing') then raise exception 'owner confirms waiting payments only'; end if;
    new.confirmed_by := public.uid();
    new.confirmed_at := now();
  else
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

create trigger guard_payment before update on public.payments
for each row execute function public.guard_payment();

-- ---------------------------------------------------------------- resident life

create table public.complaints (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  author_id text not null default public.uid(),
  bed text not null default '',
  cat text not null,
  body text not null,
  status text not null default 'Open' check (status in ('Open', 'In progress', 'Fixed')),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.move_requests (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null default public.uid(),
  kind text not null check (kind in ('vacate', 'swap')),
  last_day date,
  to_bed text,
  status text not null default 'open' check (status in ('open', 'accepted', 'declined', 'withdrawn')),
  created_at timestamptz not null default now()
);

create table public.menus (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  day int not null check (day between 0 and 6),
  breakfast text not null default '',
  lunch text not null default '',
  dinner text not null default '',
  primary key (hostel_id, day)
);

-- ---------------------------------------------------------------- reviews (F08)

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  author_id text not null default public.uid(),
  author_name text not null,                      -- "Rahul V."
  kind text not null default 'stay' check (kind in ('stay', 'exit')),
  stars int not null check (stars between 1 and 5),
  body text not null default '',
  cats jsonb not null default '{}',
  layout text check (layout in ('Yes', 'No')),
  advance text,                                   -- exit review: all | part | none
  again text,
  reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

-- Owners only add a reply; nobody else edits a review (the team can).
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  new.replied_at := now();
  return new;
end $$;

create trigger guard_review before update on public.reviews
for each row execute function public.guard_review();

-- ---------------------------------------------------------------- Fair Play (F07)

create table public.fair_reports (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  reporter_id text not null default public.uid(),
  why text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.fair_cases (
  id uuid primary key default gen_random_uuid(),
  ref text unique not null,                       -- FP-0143
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  title text not null,
  signal text not null,
  status text not null default 'new' check (status in ('new', 'waiting', 'decided', 'closed')),
  resident text,
  events jsonb not null default '[]',
  owner_reply text,
  decision text,
  created_at timestamptz not null default now()
);

-- Owners only add their reply; the Hostelzy team decides.
create or replace function public.guard_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'owner_reply') <> (to_jsonb(old) - 'owner_reply') then
    raise exception 'owners can only reply; the Hostelzy team decides';
  end if;
  return new;
end $$;

create trigger guard_case before update on public.fair_cases
for each row execute function public.guard_case();

create table public.strikes (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  case_id uuid references public.fair_cases (id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- owner plan (F10)

create table public.owner_plans (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  tier int not null default 0,
  trial_ends date,
  status text not null default 'trial' check (status in ('trial', 'active', 'overdue', 'paused')),
  credit int not null default 0
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  ref text unique not null,                       -- HZ-INV-1024
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  beds int not null,
  amount int not null check (amount >= 0),
  due date not null,
  utr text check (utr ~ '^[0-9]{12}$'),
  status text not null default 'due' check (status in ('due', 'checking', 'paid', 'missing')),
  late int not null default 0,
  created_at timestamptz not null default now()
);

-- Owners send the UTR; only the Hostelzy team marks an invoice paid.
create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

create trigger guard_invoice before update on public.invoices
for each row execute function public.guard_invoice();

-- ---------------------------------------------------------------- room layouts (F12)

-- One draft (the team edits) and one published copy (tenants see) per room.
create table public.layouts (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  stage text not null check (stage in ('draft', 'published')),
  version int not null default 1,
  w double precision not null,
  h double precision not null,
  beds jsonb not null default '{}',
  items jsonb not null default '[]',
  bunks jsonb not null default '{}',
  waiting_approval boolean not null default false,
  disputes int not null default 0,
  confirmed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (hostel_id, room, stage)
);

-- Owner approves the team's draft: it becomes the published copy.
create or replace function public.approve_layout(p_hostel uuid, p_room int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_owner(p_hostel) or public.is_team()) then raise exception 'only the owner approves a layout'; end if;
  insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items, bunks, disputes, confirmed_at)
  select hostel_id, room, 'published', version, w, h, beds, items, bunks, 0, now()
  from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'draft'
  on conflict (hostel_id, room, stage) do update
    set version = excluded.version, w = excluded.w, h = excluded.h, beds = excluded.beds,
        items = excluded.items, bunks = excluded.bunks, disputes = 0, confirmed_at = now(), updated_at = now();
  update public.layouts set waiting_approval = false where hostel_id = p_hostel and room = p_room and stage = 'draft';
end $$;

-- ---------------------------------------------------------------- app settings (F15 remote switches)

create table public.app_settings (
  key text primary key,
  value text not null default ''
);

insert into public.app_settings (key, value) values ('min_supported_build', '0'), ('maintenance_until', '');

-- ================================================================ Row Level Security

alter table public.profiles enable row level security;
alter table public.hostels enable row level security;
alter table public.hostel_staff enable row level security;
alter table public.rooms enable row level security;
alter table public.beds enable row level security;
alter table public.rate_cards enable row level security;
alter table public.deals enable row level security;
alter table public.holds enable row level security;
alter table public.enquiries enable row level security;
alter table public.stays enable row level security;
alter table public.payments enable row level security;
alter table public.complaints enable row level security;
alter table public.move_requests enable row level security;
alter table public.menus enable row level security;
alter table public.reviews enable row level security;
alter table public.fair_reports enable row level security;
alter table public.fair_cases enable row level security;
alter table public.strikes enable row level security;
alter table public.owner_plans enable row level security;
alter table public.invoices enable row level security;
alter table public.layouts enable row level security;
alter table public.app_settings enable row level security;

-- profiles: you see and edit your own; staff see their residents' and
-- tenants' names via stays/holds rows, not this table. Team sees all.
create policy "own profile" on public.profiles for select using (id = public.uid() or public.is_team());
create policy "create own profile" on public.profiles for insert with check (id = public.uid() and public.is_verified() and not phone_verified and not member and ref_code is null);
create policy "edit own profile" on public.profiles for update using (id = public.uid()) with check (id = public.uid());
create policy "team edits profiles" on public.profiles for all using (public.is_team()) with check (public.is_team());

-- Members, referral codes and the phone check are earned, not self-set.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.id <> old.id or new.member <> old.member or new.ref_code is distinct from old.ref_code or new.phone_verified <> old.phone_verified then
    raise exception 'not allowed';
  end if;
  return new;
end $$;

create trigger guard_profile before update on public.profiles
for each row execute function public.guard_profile();

-- hostels: anyone reads live ones; staff read and edit their own; only the
-- team creates hostels, puts them live or changes the owner.
create policy "live hostels" on public.hostels for select using (status = 'live' or public.is_staff(id) or public.is_team());
create policy "staff edit hostel" on public.hostels for update using (public.is_staff(id)) with check (public.is_staff(id));
create policy "team manages hostels" on public.hostels for all using (public.is_team()) with check (public.is_team());

create or replace function public.guard_hostel() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if new.id <> old.id or new.slug <> old.slug or new.status <> old.status or new.gender <> old.gender
     or new.lat is distinct from old.lat or new.lng is distinct from old.lng then
    raise exception 'ask the Hostelzy team to change this';
  end if;
  return new;
end $$;

create trigger guard_hostel before update on public.hostels
for each row execute function public.guard_hostel();

-- staff list: owners see their team; the owner adds managers; team does all.
create policy "see own team" on public.hostel_staff for select using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "owner adds managers" on public.hostel_staff for insert with check (public.is_owner(hostel_id) and role = 'manager');
create policy "owner removes managers" on public.hostel_staff for delete using (public.is_owner(hostel_id) and role = 'manager');
create policy "team manages staff" on public.hostel_staff for all using (public.is_team()) with check (public.is_team());

-- listing tables: public for live hostels; staff and team write.
create policy "read rooms" on public.rooms for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write rooms" on public.rooms for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read beds" on public.beds for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write beds" on public.beds for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read rates" on public.rate_cards for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write rates" on public.rate_cards for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());
create policy "read deals" on public.deals for select using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write deals" on public.deals for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- holds and enquiries: the tenant's own (verified users only), plus the hostel's staff.
create policy "own holds" on public.holds for select using (tenant_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "place hold" on public.holds for insert with check (tenant_id = public.uid() and public.is_verified() and public.is_live(hostel_id) and status = 'waiting');
create policy "release own hold" on public.holds for update using (tenant_id = public.uid()) with check (tenant_id = public.uid() and status = 'released');
create policy "staff update holds" on public.holds for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

create policy "own enquiries" on public.enquiries for select using (tenant_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "send enquiry" on public.enquiries for insert with check (tenant_id = public.uid() and public.is_verified() and public.is_live(hostel_id) and not contacted);
create policy "staff mark contacted" on public.enquiries for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- stays: staff and team manage; a resident sees their own.
create policy "read stays" on public.stays for select using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "staff write stays" on public.stays for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- payments: payer and the hostel's staff. guard_payment() decides the fields.
create policy "read payments" on public.payments for select using (payer_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "start payment" on public.payments for insert with check (payer_id = public.uid() and public.is_verified() and status in ('pending', 'waiting') and confirmed_by is null and confirmed_at is null);
create policy "update payment" on public.payments for update using (payer_id = public.uid() or public.is_staff(hostel_id) or public.is_team()) with check (payer_id = public.uid() or public.is_staff(hostel_id) or public.is_team());

-- complaints and move requests: the resident's own, plus staff.
create policy "read complaints" on public.complaints for select using (author_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "raise complaint" on public.complaints for insert with check (author_id = public.uid() and public.is_resident(hostel_id) and status = 'Open');
create policy "staff update complaint" on public.complaints for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

create policy "read requests" on public.move_requests for select using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "make request" on public.move_requests for insert with check (user_id = public.uid() and public.is_resident(hostel_id) and status = 'open');
create policy "withdraw request" on public.move_requests for update using (user_id = public.uid()) with check (user_id = public.uid() and status = 'withdrawn');
create policy "staff answer request" on public.move_requests for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- menus: residents and staff read; staff write.
create policy "read menu" on public.menus for select using (public.is_resident(hostel_id) or public.is_staff(hostel_id) or public.is_team());
create policy "staff write menu" on public.menus for all using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- reviews: public for live hostels; only someone with a confirmed stay there
-- writes one (DECISIONS: reviews only from verified users with a stay).
create policy "read reviews" on public.reviews for select using (public.is_live(hostel_id) or author_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
create policy "write review" on public.reviews for insert with check (author_id = public.uid() and public.is_verified() and public.has_stayed(hostel_id) and reply is null);
create policy "owner replies" on public.reviews for update using (public.is_staff(hostel_id) or public.is_team()) with check (public.is_staff(hostel_id) or public.is_team());

-- Fair Play: tenants report; staff see their hostel's cases and reply; team decides.
create policy "own reports" on public.fair_reports for select using (reporter_id = public.uid() or public.is_team());
create policy "report" on public.fair_reports for insert with check (reporter_id = public.uid() and public.is_verified());
create policy "read cases" on public.fair_cases for select using (public.is_staff(hostel_id) or public.is_team());
create policy "owner replies to case" on public.fair_cases for update using (public.is_staff(hostel_id)) with check (public.is_staff(hostel_id));
create policy "team manages cases" on public.fair_cases for all using (public.is_team()) with check (public.is_team());
create policy "read strikes" on public.strikes for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team manages strikes" on public.strikes for all using (public.is_team()) with check (public.is_team());

-- owner plan and invoices: staff read, owners send the UTR, team manages.
create policy "read plan" on public.owner_plans for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team manages plans" on public.owner_plans for all using (public.is_team()) with check (public.is_team());
create policy "read invoices" on public.invoices for select using (public.is_staff(hostel_id) or public.is_team());
create policy "owner sends UTR" on public.invoices for update using (public.is_owner(hostel_id)) with check (public.is_owner(hostel_id));
create policy "team manages invoices" on public.invoices for all using (public.is_team()) with check (public.is_team());

-- layouts: published copies for signed-in, non-anonymous users (women's PGs
-- rule); drafts for the hostel's staff and the team; only the team edits.
create policy "read published layouts" on public.layouts for select using (stage = 'published' and public.is_verified() and public.is_live(hostel_id));
create policy "staff read layouts" on public.layouts for select using (public.is_staff(hostel_id) or public.is_team());
create policy "team edits layouts" on public.layouts for all using (public.is_team()) with check (public.is_team());

-- app settings: everyone reads; team writes.
create policy "read settings" on public.app_settings for select using (true);
create policy "team writes settings" on public.app_settings for all using (public.is_team()) with check (public.is_team());


-- ---------------------------------------------------------------- push tokens (FCM)

create table public.push_tokens (
  token text primary key,
  user_id text not null default public.uid(),
  platform text not null default 'android' check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

-- Each user sees and manages only their own phones' tokens.
create policy "own tokens" on public.push_tokens for select using (user_id = public.uid());
create policy "save token" on public.push_tokens for insert with check (user_id = public.uid() and public.is_verified());
create policy "refresh token" on public.push_tokens for update using (user_id = public.uid()) with check (user_id = public.uid());
create policy "remove token" on public.push_tokens for delete using (user_id = public.uid());

-- ================================================================ safety check

do $$
declare missing text;
begin
  select string_agg(c.relname, ', ') into missing
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if missing is not null then
    raise exception 'Row Level Security is off on: %', missing;
  end if;
end $$;


-- ================================================================
-- 20261002030000_b5_server_rules.sql
-- ================================================================
-- B5: server-side rules. What the app used to decide on the phone now happens
-- in the database, so a modified app can't skip it:
--   1. HZ codes (holds, enquiries) and FP case numbers are issued here.
--   2. Hold rules: the bed must be free, at most 2 open holds per tenant, and a
--      free hold ends after 1 hour (2 for Hostelzy Members).
--   3. Hold expiry: public.expire_holds(), every minute (pg_cron).
--   4. Resident matching: a stay whose phone asked about, held or booked a bed
--      at that hostel on Hostelzy in the 60 days before joining is "via
--      Hostelzy" with its HZ code, whatever the owner picked.
--   5. Fair Play signals: such a resident added more than 3 days after moving
--      in, and a booked HZ hold with nobody added after 3 days, open a case.
--   6. Monthly invoices: public.issue_invoices() on the 1st; public.invoice_sweep()
--      daily for late days and pausing after 15 days.
--   7. Push: rows in public.push_outbox; the send-push Edge Function sends them.
-- Runs after 20261002020000_f13_firebase_ids.sql.

-- ================================================================ 0. server context

-- True for the database's own jobs (pg_cron, SQL editor): no request JWT at
-- all. Every app request through the API carries claims, so the app is never
-- "server", whichever token it sends.
create or replace function public.is_server() returns boolean
language sql stable set search_path = ''
as $$ select nullif(current_setting('request.jwt.claims', true), '') is null $$;

-- Invoice jobs (late days) run as the server, not as the team.
create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

-- ================================================================ 1. codes

create sequence if not exists public.hz_code_seq start 5001;
create sequence if not exists public.fp_case_seq start 200;
create sequence if not exists public.invoice_seq start 1100;

create or replace function public.next_hz_code() returns text
language sql volatile security definer set search_path = ''
as $$ select 'HZ-' || nextval('public.hz_code_seq') $$;

create or replace function public.next_fp_ref() returns text
language sql volatile security definer set search_path = ''
as $$ select 'FP-' || lpad(nextval('public.fp_case_seq')::text, 4, '0') $$;

-- The app never chooses its own code.
create or replace function public.set_hz_code() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.ref := public.next_hz_code();
  return new;
end $$;

drop trigger if exists set_hz_code on public.holds;
create trigger set_hz_code before insert on public.holds
for each row execute function public.set_hz_code();
drop trigger if exists set_hz_code on public.enquiries;
create trigger set_hz_code before insert on public.enquiries
for each row execute function public.set_hz_code();

-- ================================================================ 2. hold rules

create or replace function public.hold_rules() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  b record;
  open_holds int;
  member boolean;
begin
  select x.hostel_id, x.state into b from public.beds x where x.id = new.bed_id;
  if b is null or b.hostel_id <> new.hostel_id then
    raise exception 'that bed is not in this hostel';
  end if;
  if b.state <> 'free' then
    raise exception 'that bed is not free any more';
  end if;
  select count(*) into open_holds from public.holds h
  where h.tenant_id = new.tenant_id and h.status in ('waiting', 'held');
  if open_holds >= 2 then
    raise exception 'you can hold 2 beds at a time; release one first';
  end if;
  new.status := 'waiting';
  new.started_at := now();
  if new.opt = 'free' then
    select coalesce(p.member, false) into member from public.profiles p where p.id = new.tenant_id;
    new.expires_at := now() + case when coalesce(member, false) then interval '2 hours' else interval '1 hour' end;
  else
    new.expires_at := null;   -- paid and advance holds wait for the owner to confirm the payment
  end if;
  return new;
end $$;

drop trigger if exists hold_rules on public.holds;
create trigger hold_rules before insert on public.holds
for each row execute function public.hold_rules();

-- The bed shows as held while a hold is open.
create or replace function public.hold_marks_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.beds set state = 'held' where id = new.bed_id and state = 'free';
  return new;
end $$;

drop trigger if exists hold_marks_bed on public.holds;
create trigger hold_marks_bed after insert on public.holds
for each row execute function public.hold_marks_bed();

-- A released or expired hold frees its bed again (unless another hold is open
-- on it, or the owner has since booked it).
create or replace function public.hold_frees_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status in ('released', 'expired') and old.status in ('waiting', 'held') then
    update public.beds b set state = 'free'
    where b.id = new.bed_id and b.state = 'held'
      and not exists (select 1 from public.holds h where h.bed_id = new.bed_id and h.id <> new.id and h.status in ('waiting', 'held'));
  end if;
  return new;
end $$;

drop trigger if exists hold_frees_bed on public.holds;
create trigger hold_frees_bed after update of status on public.holds
for each row execute function public.hold_frees_bed();

-- ================================================================ 3. hold expiry

create or replace function public.expire_holds() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.holds set status = 'expired'
  where status in ('waiting', 'held') and expires_at is not null and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

-- ================================================================ 4. resident matching

-- The HZ code of this phone's enquiry or hold at hostel h in the 60 days
-- before joining (and the day after), newest first; null when none.
create or replace function public.hz_match(h uuid, p_phone text, joined date)
returns table (ref text, what text, at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select * from (
    select e.ref, 'asked about your hostel'::text, e.created_at
    from public.enquiries e
    where e.hostel_id = h and e.phone = p_phone
      and e.created_at >= joined - interval '60 days' and e.created_at < joined + interval '2 days'
    union all
    select x.ref, case when x.opt = 'free' then 'held a bed' else 'booked a bed' end, x.started_at
    from public.holds x join public.profiles p on p.id = x.tenant_id
    where x.hostel_id = h and p.phone = p_phone and x.status <> 'released'
      and x.started_at >= joined - interval '60 days' and x.started_at < joined + interval '2 days'
  ) m
  where length(p_phone) = 10
  order by 3 desc
  limit 1
$$;

create or replace function public.match_stay() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  m record;
  late int;
begin
  select * into m from public.hz_match(new.hostel_id, new.phone, new.joined_on);
  if m.ref is null then
    if new.via = 'hz' then new.via := 'direct'; end if;
    new.ref := null;
    new.late_days := 0;
    return new;
  end if;
  new.via := 'hz';
  new.ref := m.ref;
  late := current_date - new.joined_on;
  new.late_days := case when late > 3 then late else 0 end;
  if new.late_days > 0 then
    insert into public.fair_cases (ref, hostel_id, title, signal, resident, events)
    values (public.next_fp_ref(), new.hostel_id,
      new.name || ' added ' || new.late_days || ' days after moving in',
      'Hostelzy resident (' || m.ref || ') added after the 3-day limit',
      new.name,
      jsonb_build_array(
        jsonb_build_object('on', to_char(m.at, 'DD Mon'), 'what', 'On Hostelzy', 'detail', 'Tenant ' || m.what),
        jsonb_build_object('on', to_char(new.joined_on, 'DD Mon'), 'what', 'Moved in', 'detail', ''),
        jsonb_build_object('on', to_char(current_date, 'DD Mon'), 'what', 'Added by the owner', 'detail', new.late_days || ' days later', 'flag', true)));
  end if;
  return new;
end $$;

drop trigger if exists match_stay on public.stays;
create trigger match_stay before insert on public.stays
for each row execute function public.match_stay();

-- ================================================================ 5. Fair Play scan

-- A booked HZ hold with no resident added (by that code or the tenant's phone)
-- more than 3 days later. One case per hold. Returns the number of new cases.
create or replace function public.fair_play_scan() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  insert into public.fair_cases (ref, hostel_id, title, signal, events)
  select public.next_fp_ref(), x.hostel_id,
    'Booked on Hostelzy, not added',
    'Hostelzy booking (' || x.ref || ') not added as a resident after 3 days',
    jsonb_build_array(jsonb_build_object('on', to_char(x.started_at, 'DD Mon'), 'what', 'Booked on Hostelzy', 'detail', x.ref))
  from public.holds x
  left join public.profiles p on p.id = x.tenant_id
  where x.status = 'booked' and x.started_at < now() - interval '3 days'
    and not exists (select 1 from public.stays s where s.hostel_id = x.hostel_id and (s.ref = x.ref or (p.phone is not null and s.phone = p.phone)))
    and not exists (select 1 from public.fair_cases c where c.hostel_id = x.hostel_id and c.signal like '%(' || x.ref || ')%');
  get diagnostics n = row_count;
  return n;
end $$;

-- ================================================================ 6. invoices

-- Flat plans by size (DECISIONS 2026-10-02, data.dart planTiers).
create or replace function public.plan_price(beds int) returns int
language sql immutable set search_path = ''
as $$ select case when beds <= 30 then 499 when beds <= 80 then 999 else 1499 end $$;

-- One invoice per hostel per month once its trial has ended, priced by its
-- bed count, minus credit. Safe to run twice. Returns the number issued.
create or replace function public.issue_invoices(p_month date default current_date) returns int
language plpgsql security definer set search_path = ''
as $$
declare
  m date := date_trunc('month', p_month)::date;
  r record;
  beds int;
  amt int;
  n int := 0;
begin
  for r in
    select o.* from public.owner_plans o join public.hostels h on h.id = o.hostel_id
    where h.status = 'live' and o.status <> 'paused' and coalesce(o.trial_ends, m) <= m + 4
      and not exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and date_trunc('month', i.due) = m)
  loop
    select count(*) into beds from public.beds b where b.hostel_id = r.hostel_id;
    amt := greatest(public.plan_price(beds) - r.credit, 0);
    insert into public.invoices (ref, hostel_id, beds, amount, due)
    values ('HZ-INV-' || nextval('public.invoice_seq'), r.hostel_id, beds, amt, m + 4);
    update public.owner_plans set credit = greatest(credit - public.plan_price(beds), 0),
      status = case when status = 'trial' then 'active' else status end
    where hostel_id = r.hostel_id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Daily: days late on unpaid invoices; plans 15+ days late are overdue
-- (deals paused), and active again once nothing is late.
create or replace function public.invoice_sweep() returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.invoices set late = greatest(current_date - due, 0)
  where status in ('due', 'missing');
  update public.owner_plans o set status = 'overdue'
  where o.status = 'active' and exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and i.status in ('due', 'missing') and i.late >= 15);
  update public.owner_plans o set status = 'active'
  where o.status = 'overdue' and not exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and i.status in ('due', 'missing') and i.late >= 15);
end $$;

-- ================================================================ 7. push outbox

create table if not exists public.push_outbox (
  id bigserial primary key,
  user_id text not null,
  title text not null,
  body text not null default '',
  data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error text
);
alter table public.push_outbox enable row level security;
-- No policies: only the send-push function (service role) reads it.

create or replace function public.notify_staff(h uuid, t text, b text, d jsonb) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, t, b, d from public.hostel_staff s where s.hostel_id = h
$$;

create or replace function public.push_on_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bed text;
begin
  if tg_table_name = 'holds' and tg_op = 'INSERT' then
    select r.number || '-' || b.letter into bed from public.beds b join public.rooms r on r.id = b.room_id where b.id = new.bed_id;
    perform public.notify_staff(new.hostel_id, 'New hold on bed ' || coalesce(bed, ''), new.ref || ' · open Today to see it', jsonb_build_object('screen', 'oToday', 'ref', new.ref));
  elsif tg_table_name = 'enquiries' and tg_op = 'INSERT' then
    perform public.notify_staff(new.hostel_id, 'New enquiry from ' || new.name, new.ref || coalesce(' · bed ' || new.bed, ''), jsonb_build_object('screen', 'oToday', 'ref', new.ref));
  elsif tg_table_name = 'complaints' and tg_op = 'INSERT' then
    perform public.notify_staff(new.hostel_id, 'New complaint: ' || new.cat, left(new.body, 120), jsonb_build_object('screen', 'oMore'));
  elsif tg_table_name = 'payments' and tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'waiting' then
      perform public.notify_staff(new.hostel_id, 'Check a payment of ₹' || new.amount, 'UTR ' || coalesce(new.utr, '') || ' · confirm it in Rent', jsonb_build_object('screen', 'oRent'));
    elsif new.status in ('paid', 'missing') then
      insert into public.push_outbox (user_id, title, body, data) values (new.payer_id,
        case when new.status = 'paid' then 'Payment confirmed' else 'Payment not found' end,
        case when new.status = 'paid' then 'Your owner confirmed ₹' || new.amount || '.' else 'Your owner couldn''t find UTR ' || coalesce(new.utr, '') || '. Check it and send again.' end,
        jsonb_build_object('screen', case when new.kind = 'rent' then 'rPay' else 'holds' end));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists push_on_change on public.holds;
create trigger push_on_change after insert on public.holds for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.enquiries;
create trigger push_on_change after insert on public.enquiries for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.complaints;
create trigger push_on_change after insert on public.complaints for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.payments;
create trigger push_on_change after update on public.payments for each row execute function public.push_on_change();

-- ================================================================ who may call what

-- Jobs and helpers run only from the server (pg_cron, the service role),
-- never from the app.
revoke execute on function public.expire_holds(), public.fair_play_scan(), public.issue_invoices(date),
  public.invoice_sweep(), public.next_hz_code(), public.next_fp_ref(), public.notify_staff(uuid, text, text, jsonb),
  public.hz_match(uuid, text, date)
  from public, anon, authenticated;
revoke all on sequence public.hz_code_seq, public.fp_case_seq, public.invoice_seq from public, anon, authenticated;
revoke all on table public.push_outbox from public, anon, authenticated;
revoke all on sequence public.push_outbox_id_seq from public, anon, authenticated;

-- ================================================================ schedules

-- Only where pg_cron is switched on (Supabase: Database → Extensions → pg_cron).
-- Without it, docs/FOUNDER-TODO.md has the one-time SQL.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-expire-holds', '* * * * *', 'select public.expire_holds()');
    perform cron.schedule('hz-fair-play-scan', '30 3 * * *', 'select public.fair_play_scan()');
    perform cron.schedule('hz-invoice-sweep', '0 4 * * *', 'select public.invoice_sweep()');
    perform cron.schedule('hz-issue-invoices', '0 5 1 * *', 'select public.issue_invoices()');
  end if;
  -- Push: call the send-push Edge Function every minute with the secret the
  -- founder keeps in Vault as 'push_secret' (never in this file).
  if exists (select 1 from pg_extension where extname = 'pg_cron') and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule('hz-send-push', '* * * * *', $job$
      select net.http_post(
        url := 'https://oafiaczotlilomlvhphp.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object('content-type', 'application/json',
          'x-hz-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
        body := '{}'::jsonb)
      where exists (select 1 from public.push_outbox where sent_at is null)
    $job$);
  end if;
end $$;


-- ================================================================
-- 20261002040000_b6_realtime.sql
-- ================================================================
-- B6: Realtime for holds, enquiries, payments and complaints, so owner and
-- tenant phones stay in sync. Realtime checks each change against the same
-- RLS policies before sending it, so nobody hears about rows they can't read.
-- Safe to run again.

do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  foreach t in array array['holds', 'enquiries', 'payments', 'complaints'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;


-- ================================================================
-- 20261002050000_b7_photos.sql
-- ================================================================
-- B7: hostel photos in Supabase Storage. Owners and managers upload their
-- hostel's photos (compressed on the phone); tenants see them once the hostel
-- is live. Files: bucket `hostel-photos`, path `<hostel_id>/<uuid>.jpg`.
-- Safe to run again.

insert into storage.buckets (id, name, public)
values ('hostel-photos', 'hostel-photos', true)
on conflict (id) do nothing;

-- Which photo is which, in what order, and the cover.
create table if not exists public.hostel_photos (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  path text not null unique,                      -- inside the bucket
  label text not null default '',                 -- "Front", "3 sharing", "Washroom"…
  ord int not null default 0,
  cover boolean not null default false,
  created_by text default public.uid(),           -- null for the team's SQL editor
  created_at timestamptz not null default now(),
  check (path like hostel_id::text || '/%')
);
create unique index if not exists hostel_photos_one_cover on public.hostel_photos (hostel_id) where cover;

alter table public.hostel_photos enable row level security;

drop policy if exists "read photos" on public.hostel_photos;
create policy "read photos" on public.hostel_photos for select
  using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
drop policy if exists "staff manage photos" on public.hostel_photos;
create policy "staff manage photos" on public.hostel_photos for all
  using (public.is_staff(hostel_id) or public.is_team())
  with check (public.is_staff(hostel_id) or public.is_team());

-- The files: only that hostel's staff (or the team) may add, replace or
-- remove them, and only under their hostel's folder. Reading is public (the
-- bucket is public; file names are random), like any listing photo.
create or replace function public.photo_hostel(name text) returns uuid
language sql immutable set search_path = ''
as $$ select case when split_part(name, '/', 1) ~ '^[0-9a-f-]{36}$' then split_part(name, '/', 1)::uuid end $$;

drop policy if exists "hz staff upload photos" on storage.objects;
create policy "hz staff upload photos" on storage.objects for insert
  with check (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));
drop policy if exists "hz staff change photos" on storage.objects;
create policy "hz staff change photos" on storage.objects for update
  using (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()))
  with check (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));
drop policy if exists "hz staff remove photos" on storage.objects;
create policy "hz staff remove photos" on storage.objects for delete
  using (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));


-- ================================================================
-- 20261002060000_b7_console.sql
-- ================================================================
-- B7: data only the Hostelzy team console uses. Where each hostel is in
-- onboarding, and the owner's phone and visit time (private: the public
-- hostels table never shows them). Safe to run again.

create table if not exists public.hostel_leads (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  owner_phone text not null default '',
  visit_on timestamptz,
  stage text not null default 'lead' check (stage in ('lead', 'visited', 'signed_up', 'data_complete')),
  next_step text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.hostel_leads enable row level security;

drop policy if exists "team only" on public.hostel_leads;
create policy "team only" on public.hostel_leads for all using (public.is_team()) with check (public.is_team());


-- ================================================================
-- 20261002070000_c_delete_account.sql
-- ================================================================
-- C: delete my account. The app confirms with Google first, calls this, then
-- deletes the Firebase user. Removes the person, keeps what others need
-- (an owner's payment and stay records, reviews) without their identity.
-- Safe to run again.

-- Payments: the deletion may detach the payer (nothing else changes).
create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if current_setting('hz.deleting', true) = 'on' and new.payer_id = 'deleted'
     and (to_jsonb(new) - 'payer_id') = (to_jsonb(old) - 'payer_id') then
    return new;
  end if;
  if new.hostel_id <> old.hostel_id or new.payer_id <> old.payer_id or new.kind <> old.kind or new.amount <> old.amount then
    raise exception 'payment details cannot change';
  end if;
  if public.is_staff(old.hostel_id) and old.payer_id <> public.uid() then
    if new.utr is distinct from old.utr or new.note <> old.note then raise exception 'only the payer edits the UTR'; end if;
    if old.status <> 'waiting' or new.status not in ('paid', 'missing') then raise exception 'owner confirms waiting payments only'; end if;
    new.confirmed_by := public.uid();
    new.confirmed_at := now();
  else
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

-- Reviews: the deletion may change only who wrote it ("Former resident").
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if current_setting('hz.deleting', true) = 'on' and new.author_id = 'deleted' and new.author_name = 'Former resident'
     and (to_jsonb(new) - 'author_id' - 'author_name') = (to_jsonb(old) - 'author_id' - 'author_name') then
    return new;
  end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  new.replied_at := now();
  return new;
end $$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = ''
as $$
declare u text := public.uid();
begin
  if u is null then raise exception 'sign in first'; end if;
  if exists (select 1 from public.hostel_staff s join public.hostels h on h.id = s.hostel_id
             where s.user_id = u and s.role = 'owner' and h.status <> 'draft') then
    raise exception 'Owners: ask Hostelzy to close or hand over your hostel first.';
  end if;
  perform set_config('hz.deleting', 'on', true);

  -- open holds end now (their beds are freed by the hold triggers)
  update public.holds set status = 'released' where tenant_id = u and status in ('waiting', 'held');
  update public.holds set tenant_id = 'deleted' where tenant_id = u;
  update public.enquiries set tenant_id = 'deleted', name = 'Deleted user', phone = '', msg = '' where tenant_id = u;
  update public.reviews set author_id = 'deleted', author_name = 'Former resident' where author_id = u;
  update public.complaints set author_id = 'deleted' where author_id = u;
  update public.payments set payer_id = 'deleted' where payer_id = u;
  update public.fair_reports set reporter_id = 'deleted' where reporter_id = u;
  update public.stays set user_id = null where user_id = u;
  delete from public.move_requests where user_id = u;
  delete from public.push_tokens where user_id = u;
  delete from public.hostel_staff where user_id = u;
  delete from public.profiles where id = u;
end $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ================================================================
-- 20261002080000_c_invites.sql
-- ================================================================
-- C: server-issued resident invites. The owner's invite link / QR carries a
-- code made here (never in the app). A resident signs in, enters or opens
-- the code, and the owner approves; only then is a stay created.
-- Safe to run again.

create table if not exists public.invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  created_by text default public.uid(),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists invites_one_active on public.invites (hostel_id) where active;

create table if not exists public.invite_signups (
  id uuid primary key default gen_random_uuid(),
  code text not null references public.invites (code) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null default public.uid(),
  name text not null,
  phone text not null,
  bed text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);
create unique index if not exists invite_signups_one_pending on public.invite_signups (hostel_id, user_id) where status = 'pending';

alter table public.invites enable row level security;
alter table public.invite_signups enable row level security;

drop policy if exists "staff read invites" on public.invites;
create policy "staff read invites" on public.invites for select using (public.is_staff(hostel_id) or public.is_team());
drop policy if exists "read signups" on public.invite_signups;
create policy "read signups" on public.invite_signups for select using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
-- Writes go through the functions below only.

-- The hostel's current invite code, made on first use: "ANJ-7Q2".
create or replace function public.hostel_invite(h uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; prefix text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not (public.is_staff(h) or public.is_team()) then raise exception 'only this hostel''s staff can invite'; end if;
  select code into c from public.invites where hostel_id = h and active;
  if c is not null then return c; end if;
  select upper(rpad(left(regexp_replace(name, '[^A-Za-z]', '', 'g'), 3), 3, 'X')) into prefix from public.hostels where id = h;
  loop
    c := prefix || '-' || substr(abc, 1 + floor(random() * 32)::int, 1) || substr(abc, 1 + floor(random() * 32)::int, 1) || substr(abc, 1 + floor(random() * 32)::int, 1);
    exit when not exists (select 1 from public.invites where code = c);
  end loop;
  insert into public.invites (code, hostel_id) values (c, h);
  return c;
end $$;

-- A new code (the old link stops working), e.g. after it was shared too widely.
create or replace function public.new_hostel_invite(h uuid) returns text
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(h) or public.is_team()) then raise exception 'only this hostel''s staff can invite'; end if;
  update public.invites set active = false where hostel_id = h and active;
  return public.hostel_invite(h);
end $$;

-- A signed-in resident asks to join with a code. Returns the hostel's name.
create or replace function public.join_with_invite(p_code text, p_name text, p_phone text, p_bed text default '') returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hn text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.invites where code = upper(trim(p_code)) and active;
  if i is null then raise exception 'that invite code isn''t valid any more; ask your owner for the new one'; end if;
  if length(trim(p_name)) < 2 or p_phone !~ '^[6-9][0-9]{9}$' then raise exception 'enter your name and 10-digit phone'; end if;
  if exists (select 1 from public.invite_signups where hostel_id = i.hostel_id and user_id = public.uid() and status = 'pending') then
    raise exception 'you already asked; your owner will approve it';
  end if;
  insert into public.invite_signups (code, hostel_id, name, phone, bed) values (i.code, i.hostel_id, trim(p_name), p_phone, trim(coalesce(p_bed, '')));
  select name into hn from public.hostels where id = i.hostel_id;
  perform public.notify_staff(i.hostel_id, trim(p_name) || ' wants to join', 'Approve them in Manage → Residents', jsonb_build_object('screen', 'oInvite'));
  return hn;
end $$;

-- The owner approves (a stay is created, matched as usual) or rejects.
create or replace function public.decide_signup(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare g record;
begin
  select * into g from public.invite_signups where id = p_id and status = 'pending';
  if g is null then raise exception 'already decided'; end if;
  if not (public.is_staff(g.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can decide'; end if;
  update public.invite_signups set status = case when p_approve then 'approved' else 'rejected' end where id = p_id;
  if p_approve then
    insert into public.stays (hostel_id, user_id, name, phone, confirmed) values (g.hostel_id, g.user_id, g.name, g.phone, true);
    insert into public.push_outbox (user_id, title, body, data) values (g.user_id, 'You’re in', 'Your owner approved you. Open Hostelzy to see your stay.', '{"screen":"rHome"}');
  end if;
end $$;

revoke execute on function public.hostel_invite(uuid), public.new_hostel_invite(uuid), public.join_with_invite(text, text, text, text), public.decide_signup(uuid, boolean) from public, anon;
grant execute on function public.hostel_invite(uuid), public.new_hostel_invite(uuid), public.join_with_invite(text, text, text, text), public.decide_signup(uuid, boolean) to authenticated;


-- ================================================================
-- 20261002090000_c_signups_realtime.sql
-- ================================================================
-- C: the owner's "Waiting for you" list (invite sign-ups) updates live too.
-- RLS still decides who hears each change. Safe to run again.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invite_signups') then
    alter publication supabase_realtime add table public.invite_signups;
  end if;
end $$;


-- ================================================================
-- 20261002100000_s1_holds.sql
-- ================================================================
-- S1: holds and bookings are made on the server by the app. One fix to the
-- payment guard: the payer may cancel or resend an open payment, but never
-- touch one that is already paid or cancelled. Safe to run again.

create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  -- C: account deletion may detach the payer (nothing else changes).
  if current_setting('hz.deleting', true) = 'on' and new.payer_id = 'deleted'
     and (to_jsonb(new) - 'payer_id') = (to_jsonb(old) - 'payer_id') then
    return new;
  end if;
  if new.hostel_id <> old.hostel_id or new.payer_id <> old.payer_id or new.kind <> old.kind or new.amount <> old.amount then
    raise exception 'payment details cannot change';
  end if;
  if public.is_staff(old.hostel_id) and old.payer_id <> public.uid() then
    if new.utr is distinct from old.utr or new.note <> old.note then raise exception 'only the payer edits the UTR'; end if;
    if old.status <> 'waiting' or new.status not in ('paid', 'missing') then raise exception 'owner confirms waiting payments only'; end if;
    new.confirmed_by := public.uid();
    new.confirmed_at := now();
  else
    if old.status in ('paid', 'cancelled') then raise exception 'this payment is closed'; end if;
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

-- A booked hold (advance confirmed) books its bed.
create or replace function public.hold_books_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'booked' and old.status <> 'booked' then
    update public.beds set state = 'booked' where id = new.bed_id;
  end if;
  return new;
end $$;

drop trigger if exists hold_books_bed on public.holds;
create trigger hold_books_bed after update of status on public.holds
for each row execute function public.hold_books_bed();
revoke execute on function public.hold_books_bed() from public, anon, authenticated;


-- ================================================================
-- 20261002110000_s2_residents.sql
-- ================================================================
-- S2: the owner's resident list lives on the server (public.stays).
--   1. A current stay books its bed; moving out (left_on) frees it.
--   2. Approving an invite sign-up links the owner's own unconfirmed entry
--      with the same phone (instead of adding a second one).
-- Safe to run again.

create or replace function public.stay_marks_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.bed_id is not null and (new.bed_id is distinct from old.bed_id or (new.left_on is not null and old.left_on is null)) then
    update public.beds b set state = 'free'
    where b.id = old.bed_id
      and not exists (select 1 from public.stays s where s.bed_id = old.bed_id and s.id <> new.id and s.left_on is null)
      and not exists (select 1 from public.holds h where h.bed_id = old.bed_id and h.status in ('waiting', 'held', 'booked'));
  end if;
  if new.bed_id is not null and new.left_on is null then
    update public.beds set state = 'booked' where id = new.bed_id;
  end if;
  return new;
end $$;

drop trigger if exists stay_marks_bed on public.stays;
create trigger stay_marks_bed after insert or update of bed_id, left_on on public.stays
for each row execute function public.stay_marks_bed();
revoke execute on function public.stay_marks_bed() from public, anon, authenticated;

create or replace function public.decide_signup(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare g record; s_id uuid;
begin
  select * into g from public.invite_signups where id = p_id and status = 'pending';
  if g is null then raise exception 'already decided'; end if;
  if not (public.is_staff(g.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can decide'; end if;
  update public.invite_signups set status = case when p_approve then 'approved' else 'rejected' end where id = p_id;
  if p_approve then
    -- The owner may already have added them (same phone, not yet confirmed).
    select id into s_id from public.stays
    where hostel_id = g.hostel_id and phone = g.phone and user_id is null and not confirmed and left_on is null
    order by joined_on desc limit 1;
    if s_id is not null then
      update public.stays set user_id = g.user_id, confirmed = true where id = s_id;
    else
      insert into public.stays (hostel_id, user_id, name, phone, confirmed) values (g.hostel_id, g.user_id, g.name, g.phone, true);
    end if;
    insert into public.push_outbox (user_id, title, body, data) values (g.user_id, 'You’re in', 'Your owner approved you. Open Hostelzy to see your stay.', '{"screen":"rHome"}');
  end if;
end $$;

-- The owner's resident list updates live (RLS still decides who hears what).
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'stays') then
    alter publication supabase_realtime add table public.stays;
  end if;
end $$;


-- ================================================================
-- 20261002120000_s7_invoices.sql
-- ================================================================
-- S7: owner-plan invoices in the app.
--   1. The owner sends a UTR (due/missing → checking) but can't touch a paid
--      invoice; only the team (or the server's jobs) confirms one.
--   2. Invoices update live (Realtime; RLS decides who hears what).
-- Safe to run again.

create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if old.status = 'paid' then raise exception 'this invoice is paid'; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'invoices') then
    alter publication supabase_realtime add table public.invoices;
  end if;
end $$;


-- ================================================================
-- 20261002130000_s4_reviews.sql
-- ================================================================
-- S4: reviews from the app. The app asks "Is the room layout accurate?" with
-- Yes / Mostly / No, so the check allows Mostly too. Safe to run again.

alter table public.reviews drop constraint if exists reviews_layout_check;
alter table public.reviews add constraint reviews_layout_check check (layout in ('Yes', 'Mostly', 'No'));


-- ================================================================
-- 20261002140000_s5_fair_play.sql
-- ================================================================
-- S5: Fair Play from the app.
--   1. The owner's reply to a case the team sent back ("waiting") returns it
--      to the team ("new"). Owners still change nothing else.
--   2. fix_case(): within 48 hours the owner marks the resident Via Hostelzy;
--      the case closes with no strike.
--   3. strike_counts(): how many strikes each live hostel has, for everyone
--      (2 hide deals, 3 hide the listing, and ranking uses them).
-- Safe to run again.

create or replace function public.guard_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or current_setting('hz.fixing', true) = 'on' then return new; end if;
  if old.status = 'waiting' and new.status = 'new' and new.owner_reply is not null then
    if (to_jsonb(new) - 'owner_reply' - 'status') <> (to_jsonb(old) - 'owner_reply' - 'status') then
      raise exception 'owners can only reply; the Hostelzy team decides';
    end if;
    return new;
  end if;
  if (to_jsonb(new) - 'owner_reply') <> (to_jsonb(old) - 'owner_reply') then
    raise exception 'owners can only reply; the Hostelzy team decides';
  end if;
  return new;
end $$;

create or replace function public.fix_case(p_case uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record;
begin
  select * into c from public.fair_cases where id = p_case;
  if c is null or not public.is_staff(c.hostel_id) then raise exception 'only this hostel''s staff can fix it'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is closed'; end if;
  if c.created_at < now() - interval '48 hours' then raise exception 'the 48 hours are over; reply instead'; end if;
  if c.resident is null then raise exception 'there is no resident to fix; reply instead'; end if;
  update public.stays set via = 'hz', late_days = 0
  where hostel_id = c.hostel_id and left_on is null and (name = c.resident or bed_id in (
    select b.id from public.beds b join public.rooms r on r.id = b.room_id
    where b.hostel_id = c.hostel_id and coalesce(r.label, r.number::text) || '-' || b.letter = c.resident));
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set status = 'closed', decision = 'Fixed by the owner within 48 h · no strike' where id = p_case;
  perform set_config('hz.fixing', 'off', true);
end $$;

create or replace function public.strike_counts() returns table (hostel_id uuid, n int)
language sql stable security definer set search_path = ''
as $$
  select s.hostel_id, count(*)::int from public.strikes s
  where public.is_live(s.hostel_id) or public.is_staff(s.hostel_id) or public.is_team()
  group by s.hostel_id
$$;

revoke execute on function public.fix_case(uuid) from public, anon;
grant execute on function public.fix_case(uuid) to authenticated;
grant execute on function public.strike_counts() to anon, authenticated;

-- Cases update live for the owner and the team (RLS decides who hears what).
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'fair_cases') then
    alter publication supabase_realtime add table public.fair_cases;
  end if;
end $$;


-- ================================================================
-- 20261002150000_s8_managers.sql
-- ================================================================
-- S8: managers and owners with more than one hostel.
-- A typed phone number is never proof (phones aren't verified), so a manager
-- joins with a one-time code the owner sends them on WhatsApp:
--   new_manager_invite(hostel, name, phone) → "MGR-XXXXXXXX" (owner only)
--   join_as_manager(code) → the hostel's name (signed in with Google; the
--   code works once, for 7 days); the owner is told.
-- Owners read their hostel's manager invites (name, phone, joined or not).
-- Safe to run again.

create table if not exists public.manager_invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  name text not null,
  phone text not null default '',
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by text,
  used_at timestamptz
);
alter table public.manager_invites enable row level security;
drop policy if exists "owner reads manager invites" on public.manager_invites;
create policy "owner reads manager invites" on public.manager_invites for select using (public.is_owner(hostel_id) or public.is_team());
-- Writes go through the functions below only.

create or replace function public.new_manager_invite(h uuid, p_name text, p_phone text) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not (public.is_owner(h) or public.is_team()) then raise exception 'only the owner adds managers'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'add the manager''s name'; end if;
  loop
    c := 'MGR-';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.manager_invites where code = c);
  end loop;
  insert into public.manager_invites (code, hostel_id, name, phone) values (c, h, trim(p_name), coalesce(p_phone, ''));
  return c;
end $$;

create or replace function public.join_as_manager(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hname text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.manager_invites where code = upper(trim(p_code));
  if i is null or i.used_by is not null or i.expires_at < now() then raise exception 'that manager code isn''t valid any more'; end if;
  update public.manager_invites set used_by = public.uid(), used_at = now() where code = i.code;
  insert into public.hostel_staff (hostel_id, user_id, role) values (i.hostel_id, public.uid(), 'manager') on conflict do nothing;
  select name into hname from public.hostels where id = i.hostel_id;
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, i.name || ' joined as manager', 'They can now run beds, residents, enquiries and complaints at ' || hname || '.', '{"screen":"oMore"}'::jsonb
  from public.hostel_staff s where s.hostel_id = i.hostel_id and s.role = 'owner';
  return hname;
end $$;

revoke execute on function public.new_manager_invite(uuid, text, text), public.join_as_manager(text) from public, anon;
grant execute on function public.new_manager_invite(uuid, text, text), public.join_as_manager(text) to authenticated;


-- ================================================================
-- 20261002160000_f19_layout_fixes.sql
-- ================================================================
-- F19: residents fix room layouts (DECISIONS "Residents fix their room
-- layout"), and owners publish their own layouts (DECISIONS 2026-10-02,
-- F18: owners edit and publish; the team can still draw one).
--   send_layout_fix(hostel, room, layout, note) → id   a confirmed resident;
--       one open fix per room (a new one replaces it), at most 3 open per
--       hostel; the same checks as the editor; the owner is told.
--   withdraw_layout_fix(id)                       the author, while open.
--   decide_layout_fix(id, approve, reason)        the hostel's staff, or the
--       team once it waited 7 days; approve publishes it (the old version is
--       kept in layout_history); the resident is told.
--   publish_layout(hostel, room, layout)             staff: publish straight away.
--   undo_layout_publish(hostel, room)                staff: back to the last version.
--   layout_checks()                               public: per live room, how
--       many different residents' fixes were approved in 6 months, and when.
-- Names: the owner and the team see who sent a fix; tenants never do.
-- Safe to run again.

create table if not exists public.layout_fixes (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  author_id text not null default public.uid(),
  author_name text not null default '',
  author_bed text not null default '',
  layout jsonb not null,
  note text not null default '',
  base_version int not null default 0,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  reason text,
  decided_by text,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists layout_fixes_one_open on public.layout_fixes (hostel_id, room, author_id) where status = 'pending';

create table if not exists public.layout_history (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  version int not null,
  layout jsonb not null,
  replaced_by text,
  replaced_at timestamptz not null default now()
);

alter table public.layout_fixes enable row level security;
alter table public.layout_history enable row level security;
drop policy if exists "read layout fixes" on public.layout_fixes;
create policy "read layout fixes" on public.layout_fixes for select using (author_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
drop policy if exists "staff read layout history" on public.layout_history;
create policy "staff read layout history" on public.layout_history for select using (public.is_staff(hostel_id) or public.is_team());
-- Writes go through the functions below only.

-- The editor's checks, on the server: the room's bed count, an AC unit in an
-- AC room, beds with a resident still there, no unknown kinds of item.
create or replace function public.check_layout(p_hostel uuid, p_room int, l jsonb) returns void
language plpgsql stable security definer set search_path = ''
as $$
declare r record; missing text;
begin
  select * into r from public.rooms where hostel_id = p_hostel and number = p_room;
  if r is null then raise exception 'there is no room % here', p_room; end if;
  if jsonb_typeof(l -> 'beds') <> 'object' or jsonb_typeof(l -> 'items') <> 'array' then raise exception 'that layout isn''t complete'; end if;
  if (select count(*) from jsonb_object_keys(l -> 'beds')) <> r.share then raise exception 'room % is % sharing: place % beds', p_room, r.share, r.share; end if;
  if r.ac and not exists (select 1 from jsonb_array_elements(l -> 'items') i where i ->> 'kind' = 'ac') then raise exception 'an AC room needs an AC unit'; end if;
  if exists (select 1 from jsonb_array_elements(l -> 'items') i where i ->> 'kind' not in ('fan', 'ac', 'window', 'door', 'wash', 'pillar')) then raise exception 'no gates, CCTV or exits on a layout'; end if;
  select b.letter into missing from public.beds b
  where b.room_id = r.id and b.state = 'booked' and not (l -> 'beds') ? b.letter limit 1;
  if missing is not null then raise exception 'bed % has a resident, so it stays', missing; end if;
end $$;

-- Publish [l] for (hostel, room) as a new version; the old one goes to history.
create or replace function public.put_layout(p_hostel uuid, p_room int, l jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare old record; v int;
begin
  select * into old from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
  if found then
    insert into public.layout_history (hostel_id, room, version, layout, replaced_by)
    values (p_hostel, p_room, old.version, jsonb_build_object('w', old.w, 'h', old.h, 'beds', old.beds, 'items', old.items, 'bunks', old.bunks), public.uid());
  end if;
  v := coalesce(old.version, 0) + 1;
  insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items, bunks, disputes, confirmed_at)
  values (p_hostel, p_room, 'published', v, (l ->> 'w')::double precision, (l ->> 'h')::double precision, l -> 'beds', l -> 'items', coalesce(l -> 'bunks', '{}'), 0, now())
  on conflict (hostel_id, room, stage) do update
    set version = excluded.version, w = excluded.w, h = excluded.h, beds = excluded.beds, items = excluded.items,
        bunks = excluded.bunks, disputes = 0, confirmed_at = now(), updated_at = now();
  return v;
end $$;

create or replace function public.send_layout_fix(p_hostel uuid, p_room int, p_layout jsonb, p_note text default '') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s record; me text := public.uid(); n int; fid uuid; who text; base int; first text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select st.*, coalesce(rm.label, rm.number::text) || coalesce('-' || b.letter, '') as bed_label, rm.number as my_room into s
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.hostel_id = p_hostel and st.user_id = me and st.confirmed and st.left_on is null limit 1;
  if s is null then raise exception 'only residents of this hostel can fix its rooms'; end if;
  perform public.check_layout(p_hostel, p_room, p_layout);
  select count(*) into n from public.layout_fixes where hostel_id = p_hostel and author_id = me and status = 'pending' and room <> p_room;
  if n >= 3 then raise exception 'you have 3 fixes waiting here'; end if;
  select version into base from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
  update public.layout_fixes set status = 'withdrawn' where hostel_id = p_hostel and room = p_room and author_id = me and status = 'pending';
  insert into public.layout_fixes (hostel_id, room, author_name, author_bed, layout, note, base_version)
  values (p_hostel, p_room, s.name, coalesce(s.bed_label, ''), p_layout, left(coalesce(trim(p_note), ''), 300), coalesce(base, 0))
  returning id into fid;
  first := split_part(s.name, ' ', 1);
  who := first || case when s.my_room is not null then ' (lives in ' || s.my_room || ')' else '' end;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, who || ' suggested a fix for Room ' || p_room, 'Compare it with the current layout and decide.', jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

create or replace function public.withdraw_layout_fix(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.layout_fixes set status = 'withdrawn' where id = p_id and author_id = public.uid() and status = 'pending';
  if not found then raise exception 'that fix isn''t waiting any more'; end if;
end $$;

create or replace function public.decide_layout_fix(p_id uuid, p_approve boolean, p_reason text default null) returns int
language plpgsql security definer set search_path = ''
as $$
declare f record; v int; oname text;
begin
  select * into f from public.layout_fixes where id = p_id;
  if f is null or f.status <> 'pending' then raise exception 'that fix isn''t waiting any more'; end if;
  if not (public.is_staff(f.hostel_id) or (public.is_team() and f.created_at < now() - interval '7 days')) then
    raise exception 'the owner decides first; the team can after 7 days';
  end if;
  select h.owner_name into oname from public.hostels h where h.id = f.hostel_id;
  if p_approve then
    perform public.check_layout(f.hostel_id, f.room, f.layout);
    v := public.put_layout(f.hostel_id, f.room, f.layout);
    update public.layout_fixes set status = 'approved', decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' approved your fix', 'Room ' || f.room || ' is live for tenants now. Thanks for helping.', jsonb_build_object('screen', 'rRoom', 'room', f.room));
  else
    update public.layout_fixes set status = 'rejected', reason = nullif(left(trim(coalesce(p_reason, '')), 300), ''), decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' didn’t approve your fix', coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'You can send a new fix any time.'), jsonb_build_object('screen', 'rRoom', 'room', f.room));
  end if;
  return v;
end $$;

create or replace function public.publish_layout(p_hostel uuid, p_room int, p_layout jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can publish'; end if;
  perform public.check_layout(p_hostel, p_room, p_layout);
  return public.put_layout(p_hostel, p_room, p_layout);
end $$;

create or replace function public.undo_layout_publish(p_hostel uuid, p_room int) returns int
language plpgsql security definer set search_path = ''
as $$
declare last record;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can undo'; end if;
  select * into last from public.layout_history where hostel_id = p_hostel and room = p_room order by replaced_at desc limit 1;
  if last is null then raise exception 'there is no earlier version'; end if;
  update public.layouts set version = last.version, w = (last.layout ->> 'w')::double precision, h = (last.layout ->> 'h')::double precision,
    beds = last.layout -> 'beds', items = last.layout -> 'items', bunks = coalesce(last.layout -> 'bunks', '{}'), updated_at = now()
  where hostel_id = p_hostel and room = p_room and stage = 'published';
  delete from public.layout_history where id = last.id;
  -- An approved fix that was undone no longer counts as a check.
  update public.layout_fixes set status = 'rejected', reason = 'Undone by the owner'
  where id = (select id from public.layout_fixes where hostel_id = p_hostel and room = p_room and status = 'approved' order by decided_at desc limit 1)
    and decided_at > last.replaced_at - interval '1 second';
  return last.version;
end $$;

create or replace function public.layout_checks() returns table (hostel_id uuid, room int, n int, last_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select f.hostel_id, f.room, count(distinct f.author_id)::int, max(f.decided_at)
  from public.layout_fixes f
  where f.status = 'approved' and f.decided_at > now() - interval '6 months'
    and (public.is_live(f.hostel_id) or public.is_staff(f.hostel_id) or public.is_team())
  group by f.hostel_id, f.room
$$;

revoke execute on function public.check_layout(uuid, int, jsonb), public.put_layout(uuid, int, jsonb) from public, anon, authenticated;
revoke execute on function public.send_layout_fix(uuid, int, jsonb, text), public.withdraw_layout_fix(uuid), public.decide_layout_fix(uuid, boolean, text),
  public.publish_layout(uuid, int, jsonb), public.undo_layout_publish(uuid, int) from public, anon;
grant execute on function public.send_layout_fix(uuid, int, jsonb, text), public.withdraw_layout_fix(uuid), public.decide_layout_fix(uuid, boolean, text),
  public.publish_layout(uuid, int, jsonb), public.undo_layout_publish(uuid, int) to authenticated;
grant execute on function public.layout_checks() to anon, authenticated;

-- Fixes update live for the owner and the resident.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'layout_fixes') then
    alter publication supabase_realtime add table public.layout_fixes;
  end if;
end $$;


-- ================================================================
-- 20261002170000_s6_stay_rewards.sql
-- ================================================================
-- S6: Stay Rewards on the server (F09, DECISIONS "Stay Rewards (F09)" and
-- "Design follow-ups" F09). Amounts are DECISIONS', not new ones:
--   * Member: a first stay through Hostelzy (a confirmed "Via Hostelzy" stay)
--     makes the tenant a Member and gives ₹100 off the next Hostelzy hostel's
--     first month. The next owner gives it at move-in; Hostelzy credits that
--     ₹100 on the owner's next invoice (owner_plans.credit). No cash moves.
--   * Referral: ₹100 each, to the friend and to the one who referred them,
--     after the friend's first month at a Hostelzy hostel.
-- Guardrails (Ideas chat, 2026-10-02):
--   * grants only from these server functions and triggers; the app never writes;
--   * an append-only ledger (who, what, why, source, when): no updates or deletes;
--   * each event is granted once (unique event key);
--   * no cash-out: a tenant's credit only comes off a Hostelzy move-in, and an
--     owner's credit only off a Hostelzy invoice;
--   * the team sees every entry and can reverse one (a reversal row).
-- Safe to run again.

alter table public.profiles add column if not exists referred_by text;
alter table public.profiles add column if not exists member_since timestamptz;

create table if not exists public.reward_ledger (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  kind text not null check (kind in ('member', 'referral_friend', 'referral_referrer', 'spend', 'owner_credit', 'reversal')),
  user_id text,                                   -- the tenant whose balance this is
  hostel_id uuid references public.hostels (id) on delete set null,   -- an owner credit
  amount int not null,                            -- + earned / credited, − spent / reversed
  reason text not null default '',
  source_stay uuid,
  source_user text,
  reverses uuid unique references public.reward_ledger (id),
  created_by text default public.uid(),
  created_at timestamptz not null default now()
);

alter table public.reward_ledger enable row level security;
drop policy if exists "read own rewards" on public.reward_ledger;
create policy "read own rewards" on public.reward_ledger for select
  using (user_id = public.uid() or (hostel_id is not null and public.is_staff(hostel_id)) or public.is_team());
-- No insert/update/delete policies: only the functions below write.

create or replace function public.ledger_append_only() returns trigger
language plpgsql set search_path = ''
as $$ begin raise exception 'the rewards ledger is append-only; reverse an entry instead'; end $$;
drop trigger if exists ledger_append_only on public.reward_ledger;
create trigger ledger_append_only before update or delete on public.reward_ledger
for each row execute function public.ledger_append_only();

-- Members and referral codes are still earned, not self-set: only these
-- functions (hz.rewards) and the team change them.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or current_setting('hz.rewards', true) = 'on' then return new; end if;
  if new.id <> old.id or new.member <> old.member or new.ref_code is distinct from old.ref_code or new.phone_verified <> old.phone_verified
     or new.referred_by is distinct from old.referred_by or new.member_since is distinct from old.member_since then
    raise exception 'not allowed';
  end if;
  return new;
end $$;

-- A tenant's reward balance (₹): earned minus spent and reversed.
create or replace function public.reward_balance(u text) returns int
language sql stable security definer set search_path = ''
as $$ select coalesce(sum(amount), 0)::int from public.reward_ledger where user_id = u $$;

-- Adds [amt] to the owner's next invoice credit.
create or replace function public.credit_owner(h uuid, amt int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.owner_plans (hostel_id, credit) values (h, greatest(amt, 0))
  on conflict (hostel_id) do update set credit = greatest(public.owner_plans.credit + amt, 0);
end $$;

-- A confirmed stay through Hostelzy: spend what the tenant has (₹100 off this
-- first month, credited to this owner), then make them a Member (₹100 for the
-- next stay) if this is their first.
create or replace function public.rewards_on_stay() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bal int;
begin
  if new.user_id is null or not new.confirmed or new.via <> 'hz' or (tg_op = 'UPDATE' and old.confirmed and old.via = 'hz') then
    return new;
  end if;
  perform set_config('hz.rewards', 'on', true);
  bal := public.reward_balance(new.user_id);
  if bal > 0 then
    insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, created_by)
    values ('spend:' || new.id, 'spend', new.user_id, -bal, 'Off the first month at a Hostelzy hostel', new.id, 'server')
    on conflict (event_key) do nothing;
    if found then
      insert into public.reward_ledger (event_key, kind, hostel_id, amount, reason, source_stay, source_user, created_by)
      values ('credit:' || new.id, 'owner_credit', new.hostel_id, bal, 'Member reward given at move-in', new.id, new.user_id, 'server');
      perform public.credit_owner(new.hostel_id, bal);
    end if;
  end if;
  insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, created_by)
  values ('member:' || new.user_id, 'member', new.user_id, 100, 'Member: first stay through Hostelzy', new.id, 'server')
  on conflict (event_key) do nothing;
  update public.profiles set member = true, member_since = coalesce(member_since, now()) where id = new.user_id and not member;
  perform set_config('hz.rewards', 'off', true);
  return new;
end $$;

drop trigger if exists rewards_on_stay on public.stays;
create trigger rewards_on_stay after insert or update of confirmed, via, user_id on public.stays
for each row execute function public.rewards_on_stay();

-- The caller's referral code ("ASHA-4K7Q"), made once.
create or replace function public.my_referral_code() returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; nm text; base text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select ref_code, name into c, nm from public.profiles where id = public.uid();
  if c is not null then return c; end if;
  if nm is null then raise exception 'add your name first'; end if;
  -- "ASHA-4K7Q": up to 5 letters of the first name.
  base := upper(regexp_replace(split_part(nm, ' ', 1), '[^A-Za-z]', '', 'g'));
  base := left(case when length(base) < 3 then rpad(base, 3, 'X') else base end, 5);
  loop
    c := base || '-';
    for i in 1..4 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.profiles where ref_code = c);
  end loop;
  perform set_config('hz.rewards', 'on', true);
  update public.profiles set ref_code = c where id = public.uid();
  perform set_config('hz.rewards', 'off', true);
  return c;
end $$;

-- A new tenant enters a friend's code, before their first stay. Returns the
-- friend's first name.
create or replace function public.use_referral_code(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare r record; me text := public.uid();
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select id, name into r from public.profiles where ref_code = upper(trim(p_code));
  if r.id is null then raise exception 'that code isn''t valid'; end if;
  if r.id = me then raise exception 'that''s your own code'; end if;
  if exists (select 1 from public.profiles where id = me and referred_by is not null) then raise exception 'you already used a code'; end if;
  if exists (select 1 from public.stays where user_id = me and confirmed) then raise exception 'codes are for your first stay'; end if;
  perform set_config('hz.rewards', 'on', true);
  update public.profiles set referred_by = r.id where id = me;
  perform set_config('hz.rewards', 'off', true);
  if not found then raise exception 'add your name first'; end if;
  return split_part(r.name, ' ', 1);
end $$;

-- Daily (pg_cron): referral rewards once the friend's first month at a
-- Hostelzy hostel is done. Returns how many referrals were rewarded.
create or replace function public.referral_sweep() returns int
language plpgsql security definer set search_path = ''
as $$
declare p record; n int := 0;
begin
  for p in
    select pr.id, pr.referred_by, min(s.id::text)::uuid as stay
    from public.profiles pr join public.stays s on s.user_id = pr.id
    where pr.referred_by is not null and s.confirmed and s.via = 'hz' and s.joined_on <= current_date - 30
      and not exists (select 1 from public.reward_ledger l where l.event_key = 'ref-friend:' || pr.id)
    group by pr.id, pr.referred_by
  loop
    insert into public.reward_ledger (event_key, kind, user_id, amount, reason, source_stay, source_user, created_by) values
      ('ref-friend:' || p.id, 'referral_friend', p.id, 100, 'Referral: your first month is done', p.stay, p.referred_by, 'server'),
      ('ref-referrer:' || p.id, 'referral_referrer', p.referred_by, 100, 'Referral: your friend finished their first month', p.stay, p.id, 'server')
    on conflict (event_key) do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Team: reverse one entry (a new row with the opposite amount). An owner
-- credit also comes off the owner's next invoice credit.
create or replace function public.reverse_reward(p_id uuid, p_why text) returns void
language plpgsql security definer set search_path = ''
as $$
declare e record;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team reverses rewards'; end if;
  if length(trim(coalesce(p_why, ''))) < 3 then raise exception 'say why'; end if;
  select * into e from public.reward_ledger where id = p_id;
  if e.id is null then raise exception 'no such entry'; end if;
  if e.kind = 'reversal' then raise exception 'a reversal can''t be reversed'; end if;
  insert into public.reward_ledger (event_key, kind, user_id, hostel_id, amount, reason, source_stay, source_user, reverses)
  values ('reverse:' || e.id, 'reversal', e.user_id, e.hostel_id, -e.amount, 'Reversed: ' || trim(p_why), e.source_stay, e.source_user, e.id);
  if e.kind = 'owner_credit' then perform public.credit_owner(e.hostel_id, -e.amount); end if;
end $$;

revoke execute on function public.reward_balance(text), public.credit_owner(uuid, int), public.referral_sweep() from public, anon, authenticated;
revoke execute on function public.my_referral_code(), public.use_referral_code(text), public.reverse_reward(uuid, text) from public, anon;
grant execute on function public.my_referral_code(), public.use_referral_code(text), public.reverse_reward(uuid, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-referral-sweep', '20 3 * * *', 'select public.referral_sweep()');
  end if;
end $$;


-- ================================================================
-- 20261002180000_f20_reminders.sql
-- ================================================================
-- F20 Reminders: a backup of the user's reminder settings on their profile,
-- so a new phone gets them back. The reminders themselves ring from the
-- phone; this is only the settings (water plan, my reminders, switches).
-- Users edit their own profile already ("edit own profile"); guard_profile
-- doesn't touch this column.

alter table public.profiles add column if not exists reminders jsonb;

alter table public.profiles drop constraint if exists reminders_small;
alter table public.profiles add constraint reminders_small
  check (reminders is null or (jsonb_typeof(reminders) = 'object' and octet_length(reminders::text) <= 16000));


-- ================================================================
-- 20261002190000_f19_extras.sql
-- ================================================================
-- F19 v1 additions (designed 2026-10-02): quick fixes on one item (wrong
-- place / missing / broken / not in this room), one optional photo per fix
-- (seen only by the hostel's staff and the team), owners muting a resident's
-- suggestions, and a "Broken" quick fix as a repair the owner starts or
-- closes. Try mode for visitors is app-only (nothing is saved).
-- Safe to run again.

alter table public.layout_fixes add column if not exists kind text not null default 'layout';
alter table public.layout_fixes drop constraint if exists layout_fixes_kind;
alter table public.layout_fixes add constraint layout_fixes_kind check (kind in ('layout', 'quick'));
alter table public.layout_fixes add column if not exists issue text;
alter table public.layout_fixes drop constraint if exists layout_fixes_issue;
alter table public.layout_fixes add constraint layout_fixes_issue check (issue is null or issue in ('wrong_place', 'missing', 'broken', 'not_here'));
alter table public.layout_fixes add column if not exists item text;
alter table public.layout_fixes add column if not exists photo text;
alter table public.layout_fixes add column if not exists repair text;
alter table public.layout_fixes drop constraint if exists layout_fixes_repair;
alter table public.layout_fixes add constraint layout_fixes_repair check (repair is null or repair in ('working', 'not_broken'));

-- One open layout suggestion per room per resident; quick fixes are separate.
drop index if exists public.layout_fixes_one_open;
create unique index if not exists layout_fixes_one_open on public.layout_fixes (hostel_id, room, author_id) where status = 'pending' and kind = 'layout';

-- Residents whose suggestions an owner turned off. They see "Suggestions are
-- off for this hostel"; they're never told who muted them.
create table if not exists public.layout_fix_mutes (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null,
  name text not null default '',
  muted_by text not null default public.uid(),
  created_at timestamptz not null default now(),
  primary key (hostel_id, user_id)
);
alter table public.layout_fix_mutes enable row level security;
drop policy if exists "read mutes" on public.layout_fix_mutes;
create policy "read mutes" on public.layout_fix_mutes for select
  using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());

-- The photo: private bucket, path `<hostel_id>/<user id>/<uuid>.jpg`.
insert into storage.buckets (id, name, public) values ('fix-photos', 'fix-photos', false) on conflict (id) do nothing;

create or replace function public.fix_photo_ok(p_hostel uuid, p_path text) returns boolean
language sql stable set search_path = ''
as $$ select p_path is null or p_path like p_hostel::text || '/' || public.uid() || '/%' $$;

drop policy if exists "hz residents upload fix photos" on storage.objects;
create policy "hz residents upload fix photos" on storage.objects for insert
  with check (bucket_id = 'fix-photos' and split_part(name, '/', 2) = public.uid() and public.is_resident(public.photo_hostel(name)));
drop policy if exists "hz read fix photos" on storage.objects;
create policy "hz read fix photos" on storage.objects for select
  using (bucket_id = 'fix-photos' and (split_part(name, '/', 2) = public.uid() or public.is_staff(public.photo_hostel(name)) or public.is_team()));

-- The resident sending a fix: a confirmed, current stay here, and not muted.
create or replace function public.fix_author(p_hostel uuid) returns record
language plpgsql stable security definer set search_path = ''
as $$
declare s record;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select st.*, coalesce(rm.label, rm.number::text) || coalesce('-' || b.letter, '') as bed_label, rm.number as my_room into s
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.hostel_id = p_hostel and st.user_id = public.uid() and st.confirmed and st.left_on is null limit 1;
  if s is null then raise exception 'only residents of this hostel can fix its rooms'; end if;
  if exists (select 1 from public.layout_fix_mutes m where m.hostel_id = p_hostel and m.user_id = public.uid()) then
    raise exception 'suggestions are off for this hostel';
  end if;
  return s;
end $$;

drop function if exists public.send_layout_fix(uuid, int, jsonb, text);
create or replace function public.send_layout_fix(p_hostel uuid, p_room int, p_layout jsonb, p_note text default '', p_photo text default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s record; me text := public.uid(); n int; fid uuid; who text; base int;
begin
  s := public.fix_author(p_hostel);
  if not public.fix_photo_ok(p_hostel, p_photo) then raise exception 'that photo isn''t yours'; end if;
  perform public.check_layout(p_hostel, p_room, p_layout);
  select count(*) into n from public.layout_fixes where hostel_id = p_hostel and author_id = me and status = 'pending' and not (kind = 'layout' and room = p_room);
  if n >= 3 then raise exception 'you have 3 fixes waiting here'; end if;
  select version into base from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
  update public.layout_fixes set status = 'withdrawn' where hostel_id = p_hostel and room = p_room and author_id = me and status = 'pending' and kind = 'layout';
  insert into public.layout_fixes (hostel_id, room, author_name, author_bed, layout, note, base_version, photo)
  values (p_hostel, p_room, s.name, coalesce(s.bed_label, ''), p_layout, left(coalesce(trim(p_note), ''), 300), coalesce(base, 0), p_photo)
  returning id into fid;
  who := split_part(s.name, ' ', 1) || case when s.my_room is not null then ' (lives in ' || s.my_room || ')' else '' end;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, who || ' suggested a fix for Room ' || p_room, 'Compare it with the current layout and decide.', jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

-- A quick fix on one item. "Broken" also goes to the owner as a repair.
create or replace function public.send_quick_fix(p_hostel uuid, p_room int, p_item text, p_issue text, p_note text default '', p_photo text default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s record; me text := public.uid(); n int; fid uuid; who text; what text;
begin
  s := public.fix_author(p_hostel);
  if not exists (select 1 from public.rooms r where r.hostel_id = p_hostel and r.number = p_room) then raise exception 'there is no room % here', p_room; end if;
  if p_issue is null or p_issue not in ('wrong_place', 'missing', 'broken', 'not_here') then raise exception 'pick what''s wrong'; end if;
  if coalesce(trim(p_item), '') = '' then raise exception 'pick an item'; end if;
  if not public.fix_photo_ok(p_hostel, p_photo) then raise exception 'that photo isn''t yours'; end if;
  select count(*) into n from public.layout_fixes where hostel_id = p_hostel and author_id = me and status = 'pending';
  if n >= 3 then raise exception 'you have 3 fixes waiting here'; end if;
  insert into public.layout_fixes (hostel_id, room, author_name, author_bed, layout, note, kind, issue, item, photo)
  values (p_hostel, p_room, s.name, coalesce(s.bed_label, ''), '{}'::jsonb, left(coalesce(trim(p_note), ''), 300), 'quick', p_issue, left(trim(p_item), 60), p_photo)
  returning id into fid;
  who := split_part(s.name, ' ', 1) || case when s.my_room is not null then ' (lives in ' || s.my_room || ')' else '' end;
  what := case p_issue when 'broken' then 'Broken: ' || trim(p_item) || ', Room ' || p_room
    when 'missing' then 'Missing: ' || trim(p_item) || ' in Room ' || p_room
    when 'not_here' then 'Not in Room ' || p_room || ': ' || trim(p_item)
    else 'Wrong place: ' || trim(p_item) || ' in Room ' || p_room end;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, what, who || case when p_issue = 'broken' then ' reported it. Start work or mark it not broken.' else ' sent a quick fix.' end, jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

-- Deciding: a quick fix is a note for the owner, so approving it changes no
-- layout (the owner edits the room themselves).
create or replace function public.decide_layout_fix(p_id uuid, p_approve boolean, p_reason text default null) returns int
language plpgsql security definer set search_path = ''
as $$
declare f record; v int; oname text;
begin
  select * into f from public.layout_fixes where id = p_id;
  if f is null or f.status <> 'pending' then raise exception 'that fix isn''t waiting any more'; end if;
  if not (public.is_staff(f.hostel_id) or (public.is_team() and f.created_at < now() - interval '7 days')) then
    raise exception 'the owner decides first; the team can after 7 days';
  end if;
  select h.owner_name into oname from public.hostels h where h.id = f.hostel_id;
  if p_approve then
    if f.kind = 'layout' then
      perform public.check_layout(f.hostel_id, f.room, f.layout);
      v := public.put_layout(f.hostel_id, f.room, f.layout);
    end if;
    update public.layout_fixes set status = 'approved', decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' approved your fix',
      case when f.kind = 'layout' then 'Room ' || f.room || ' is live for tenants now. Thanks for helping.' else 'Thanks for telling them about Room ' || f.room || '.' end,
      jsonb_build_object('screen', 'rRoom', 'room', f.room));
  else
    update public.layout_fixes set status = 'rejected', reason = nullif(left(trim(coalesce(p_reason, '')), 300), ''), decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' didn’t approve your fix', coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'You can send a new fix any time.'), jsonb_build_object('screen', 'rRoom', 'room', f.room));
  end if;
  return v;
end $$;

-- The owner's repair card for a Broken quick fix: Start work, or Not broken.
create or replace function public.set_repair(p_id uuid, p_state text) returns void
language plpgsql security definer set search_path = ''
as $$
declare f record; oname text; thing text;
begin
  select * into f from public.layout_fixes where id = p_id;
  if f is null or f.kind <> 'quick' or f.issue <> 'broken' then raise exception 'that isn''t a repair'; end if;
  if not (public.is_staff(f.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  if f.status <> 'pending' then raise exception 'that repair is already handled'; end if;
  if p_state not in ('working', 'not_broken') then raise exception 'start work or mark it not broken'; end if;
  select h.owner_name into oname from public.hostels h where h.id = f.hostel_id;
  thing := case when f.item ~ '^[A-Z]{2}' then f.item else lower(f.item) end;
  update public.layout_fixes set repair = p_state, status = case when p_state = 'working' then 'approved' else 'rejected' end,
    reason = case when p_state = 'not_broken' then 'Not broken' end, decided_by = public.uid(), decided_at = now() where id = p_id;
  insert into public.push_outbox (user_id, title, body, data)
  values (f.author_id,
    case when p_state = 'working' then coalesce(nullif(oname, ''), 'Your owner') || ' is fixing the ' || thing else coalesce(nullif(oname, ''), 'Your owner') || ' says the ' || thing || ' isn’t broken' end,
    'Room ' || f.room || '.', jsonb_build_object('screen', 'rRoom', 'room', f.room));
end $$;

-- Mute / unmute a resident's suggestions (the hostel's staff only). Muting
-- closes their waiting fixes; nothing tells them who did it.
create or replace function public.mute_fix_author(p_fix uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare f record;
begin
  select * into f from public.layout_fixes where id = p_fix;
  if f is null then raise exception 'that fix is gone'; end if;
  if not (public.is_staff(f.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  insert into public.layout_fix_mutes (hostel_id, user_id, name) values (f.hostel_id, f.author_id, f.author_name)
  on conflict (hostel_id, user_id) do nothing;
  update public.layout_fixes set status = 'rejected', reason = 'Suggestions are off for this hostel', decided_by = public.uid(), decided_at = now()
  where hostel_id = f.hostel_id and author_id = f.author_id and status = 'pending';
end $$;

create or replace function public.unmute_fix_author(p_hostel uuid, p_user text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  delete from public.layout_fix_mutes where hostel_id = p_hostel and user_id = p_user;
end $$;

revoke execute on function public.fix_author(uuid), public.fix_photo_ok(uuid, text) from public, anon, authenticated;
revoke execute on function public.send_layout_fix(uuid, int, jsonb, text, text), public.send_quick_fix(uuid, int, text, text, text, text),
  public.set_repair(uuid, text), public.mute_fix_author(uuid), public.unmute_fix_author(uuid, text) from public, anon;
grant execute on function public.send_layout_fix(uuid, int, jsonb, text, text), public.send_quick_fix(uuid, int, text, text, text, text),
  public.set_repair(uuid, text), public.mute_fix_author(uuid), public.unmute_fix_author(uuid, text) to authenticated;


-- ================================================================
-- 20261002200000_f21_hold_reply_push.sql
-- ================================================================
-- F21 W2: the tenant hears the owner's reply to a hold.
-- After the first hold the app asks for notifications "so the owner's reply
-- reaches you". Until now only staff got a push on a new hold; this sends the
-- tenant one when someone else (the owner or a manager) keeps or declines it.
-- Paid bookings already get "Payment confirmed" from push_on_change.

create or replace function public.push_hold_reply() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bed text; hn text;
begin
  if new.status is distinct from old.status and new.status in ('held', 'released')
     and old.status = 'waiting' and public.uid() is distinct from new.tenant_id then
    select r.number || '-' || b.letter into bed from public.beds b join public.rooms r on r.id = b.room_id where b.id = new.bed_id;
    select h.name into hn from public.hostels h where h.id = new.hostel_id;
    insert into public.push_outbox (user_id, title, body, data) values (new.tenant_id,
      case when new.status = 'held' then 'Bed ' || coalesce(bed, '') || ' is kept for you' else 'Bed ' || coalesce(bed, '') || ' wasn’t kept' end,
      case when new.status = 'held' then coalesce(hn, 'The owner') || ' confirmed your hold. Go and see it.' else coalesce(hn, 'The owner') || ' couldn’t keep it. Pick another bed in Hostelzy.' end,
      '{"screen":"holds"}');
  end if;
  return new;
end $$;

drop trigger if exists push_hold_reply on public.holds;
create trigger push_hold_reply after update on public.holds for each row execute function public.push_hold_reply();


-- ================================================================
-- 20261002210000_f21_complaint_photo.sql
-- ================================================================
-- F21 W3: a complaint can carry one photo ("Add a photo" on Help).
-- Private bucket `complaint-photos`, path `<hostel_id>/<user id>/<name>.jpg`.
-- The resident uploads into their own folder at a hostel they live in; the
-- resident, that hostel's staff and the Hostelzy team can read it.

alter table public.complaints add column if not exists photo text;

create or replace function public.complaint_photo_hostel(p text) returns uuid
language sql immutable set search_path = ''
as $$ select case when split_part(p, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(p, '/', 1)::uuid end $$;

-- The photo on a complaint must be the author's own, at that hostel.
create or replace function public.complaint_photo_ok() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.photo is not null and (public.complaint_photo_hostel(new.photo) is distinct from new.hostel_id
     or split_part(new.photo, '/', 2) <> new.author_id or new.photo !~ '^[^/]+/[^/]+/[^/]+\.jpg$') then
    raise exception 'complaint photo must be your own, at this hostel';
  end if;
  if tg_op = 'UPDATE' and new.photo is distinct from old.photo then
    raise exception 'the photo can''t be changed';
  end if;
  return new;
end $$;
drop trigger if exists complaint_photo_ok on public.complaints;
create trigger complaint_photo_ok before insert or update on public.complaints for each row execute function public.complaint_photo_ok();

insert into storage.buckets (id, name, public) values ('complaint-photos', 'complaint-photos', false) on conflict (id) do nothing;

drop policy if exists "hz residents upload complaint photos" on storage.objects;
create policy "hz residents upload complaint photos" on storage.objects for insert
  with check (bucket_id = 'complaint-photos' and split_part(name, '/', 2) = public.uid() and public.is_resident(public.complaint_photo_hostel(name)));
drop policy if exists "hz read complaint photos" on storage.objects;
create policy "hz read complaint photos" on storage.objects for select
  using (bucket_id = 'complaint-photos' and (split_part(name, '/', 2) = public.uid() or public.is_staff(public.complaint_photo_hostel(name)) or public.is_team()));


-- ================================================================
-- 20261002220000_f23_amenities.sql
-- ================================================================
-- F23: shared things on each floor (fridge, washing machine, RO…) and things
-- inside rooms (a geyser in the room washroom). DECISIONS "Floor amenities +
-- layout-first", founder 2026-10-02.
--   amenities                    one row per thing; anyone reads a live
--       hostel's rows, staff and the team read any. No names here: tenants
--       only ever see "Added by a resident" (by_role).
--   amenity_log                  who added / changed / removed what, and when;
--       the hostel's staff and the team only.
--   save_amenity(hostel, id, floor, kind, name, qty, working, place, rooms) → id
--       null id adds, otherwise changes that row. The hostel's staff or the
--       team; or a confirmed resident (at most 20 changes a day per hostel,
--       not when muted with F19's mute). A resident's change tells the owner.
--   remove_amenity(id)           the same people and limits.
-- Never CCTV, gates or exits (DECISIONS: safety). Safe to run again.

create table if not exists public.amenities (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  floor int not null,
  kind text not null,
  name text not null default '',
  qty int not null default 1,
  working boolean not null default true,
  place text not null default 'floor',
  rooms int[] not null default '{}',
  by_role text not null default 'staff',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists amenities_hostel on public.amenities (hostel_id, floor);

alter table public.amenities drop constraint if exists amenities_kind;
alter table public.amenities add constraint amenities_kind check (kind in
  ('fridge', 'washer', 'ro', 'cooler', 'geyser', 'microwave', 'stove', 'iron', 'tv', 'wifi', 'drying', 'shoes', 'lift', 'dustbin', 'other'));
alter table public.amenities drop constraint if exists amenities_name;
alter table public.amenities add constraint amenities_name check (name = btrim(name) and char_length(name) <= 40 and (kind <> 'other' or name <> ''));
alter table public.amenities drop constraint if exists amenities_qty;
alter table public.amenities add constraint amenities_qty check (qty between 1 and 20);
alter table public.amenities drop constraint if exists amenities_place;
alter table public.amenities add constraint amenities_place check (place in ('floor', 'washroom', 'room'));
alter table public.amenities drop constraint if exists amenities_rooms;
alter table public.amenities add constraint amenities_rooms check ((place = 'floor') = (cardinality(rooms) = 0) and array_position(rooms, null) is null);
alter table public.amenities drop constraint if exists amenities_by_role;
alter table public.amenities add constraint amenities_by_role check (by_role in ('staff', 'resident'));

create table if not exists public.amenity_log (
  id bigserial primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  amenity_id uuid not null,                       -- no foreign key: removed things stay in the log
  action text not null check (action in ('add', 'change', 'remove')),
  what text not null default '',                  -- "Fridge on floor 2", kept after a removal
  by_id text not null,
  by_name text not null default '',
  by_role text not null check (by_role in ('staff', 'resident')),
  at timestamptz not null default now()
);
create index if not exists amenity_log_by on public.amenity_log (hostel_id, by_id, at);

alter table public.amenities enable row level security;
alter table public.amenity_log enable row level security;
drop policy if exists "read amenities" on public.amenities;
create policy "read amenities" on public.amenities for select
  using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
drop policy if exists "staff read amenity log" on public.amenity_log;
create policy "staff read amenity log" on public.amenity_log for select
  using (public.is_staff(hostel_id) or public.is_team());
-- Writes go through the functions below only.

-- The checks, in plain words, for every write (the table's checks back them up).
-- Room items: every room must be a room of this hostel on that floor.
create or replace function public.amenity_check() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bad int;
begin
  new.name := btrim(coalesce(new.name, ''));
  new.place := coalesce(new.place, 'floor');
  new.rooms := coalesce(new.rooms, '{}');
  if lower(coalesce(new.kind, '')) ~ '(cctv|camera|gate|exit)' then raise exception 'no CCTV, gates or exits here, for everyone''s safety'; end if;
  if new.kind is null or new.kind not in ('fridge', 'washer', 'ro', 'cooler', 'geyser', 'microwave', 'stove', 'iron', 'tv', 'wifi', 'drying', 'shoes', 'lift', 'dustbin', 'other') then
    raise exception 'pick a thing from the list';
  end if;
  if new.kind = 'other' and new.name = '' then raise exception 'type a name for it'; end if;
  if char_length(new.name) > 40 then raise exception 'keep the name to 40 letters'; end if;
  if new.qty is null or new.qty not between 1 and 20 then raise exception 'the count is 1 to 20'; end if;
  if new.place not in ('floor', 'washroom', 'room') then raise exception 'pick where it is: on the floor, in the room washroom or in the room'; end if;
  if new.floor is null then raise exception 'pick a floor'; end if;
  if new.place = 'floor' then
    if cardinality(new.rooms) > 0 then raise exception 'a thing on the floor has no rooms'; end if;
  else
    if cardinality(new.rooms) = 0 or array_position(new.rooms, null) is not null then raise exception 'pick at least one room'; end if;
    select x into bad from unnest(new.rooms) x
    where not exists (select 1 from public.rooms r where r.hostel_id = new.hostel_id and r.number = x and r.floor = new.floor)
    limit 1;
    if bad is not null then raise exception 'room % isn''t on floor %', bad, new.floor; end if;
    new.rooms := array(select distinct x from unnest(new.rooms) x order by x);
  end if;
  if tg_op = 'UPDATE' then
    new.id := old.id; new.hostel_id := old.hostel_id; new.created_at := old.created_at; new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists amenity_check on public.amenities;
create trigger amenity_check before insert or update on public.amenities
for each row execute function public.amenity_check();

-- "Fridge on floor 2", "Geyser in 4 room washrooms on floor 2", "TV in room 201".
create or replace function public.amenity_what(a public.amenities) returns text
language sql stable set search_path = ''
as $$
  select case a.kind when 'fridge' then 'Fridge' when 'washer' then 'Washing machine' when 'ro' then 'RO water purifier'
      when 'cooler' then 'Water cooler' when 'geyser' then 'Geyser' when 'microwave' then 'Microwave' when 'stove' then 'Stove'
      when 'iron' then 'Iron + board' when 'tv' then 'TV' when 'wifi' then 'Wi-Fi router' when 'drying' then 'Drying stand'
      when 'shoes' then 'Shoe rack' when 'lift' then 'Lift' when 'dustbin' then 'Dustbin' else a.name end
    || case when a.place = 'floor' then ' on floor ' || a.floor
         when cardinality(a.rooms) = 1 then case when a.place = 'washroom' then ' in the washroom of room ' else ' in room ' end || a.rooms[1]
         else ' in ' || cardinality(a.rooms) || case when a.place = 'washroom' then ' room washrooms' else ' rooms' end || ' on floor ' || a.floor end
$$;

-- Who is changing [p_hostel]'s things: 'staff' (staff or team) or 'resident';
-- anyone else, a muted resident, or a resident over 20 changes today, is refused.
create or replace function public.amenity_author(p_hostel uuid, out role text, out name text)
language plpgsql stable security definer set search_path = ''
as $$
declare me text := public.uid(); n int;
begin
  if me is null then raise exception 'sign in first'; end if;
  if not exists (select 1 from public.hostels h where h.id = p_hostel) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if public.is_staff(p_hostel) or public.is_team() then
    role := 'staff';
    select p.name into name from public.profiles p where p.id = me;
    name := coalesce(name, '');
    return;
  end if;
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select st.name into name from public.stays st
  where st.hostel_id = p_hostel and st.user_id = me and st.confirmed and st.left_on is null limit 1;
  if name is null then raise exception 'only this hostel''s owner and residents can change its shared things'; end if;
  if exists (select 1 from public.layout_fix_mutes m where m.hostel_id = p_hostel and m.user_id = me) then
    raise exception 'your changes are off for this hostel';
  end if;
  select count(*) into n from public.amenity_log l
  where l.hostel_id = p_hostel and l.by_id = me and (l.at at time zone 'Asia/Kolkata')::date = (now() at time zone 'Asia/Kolkata')::date;
  if n >= 20 then raise exception 'you''ve made 20 changes here today; try again tomorrow'; end if;
  role := 'resident';
end $$;

create or replace function public.save_amenity(p_hostel uuid, p_id uuid default null, p_floor int default null, p_kind text default null,
  p_name text default '', p_qty int default 1, p_working boolean default true, p_place text default 'floor', p_rooms int[] default '{}') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare who record; prev public.amenities; a public.amenities; act text; v_title text; v_place text := coalesce(p_place, 'floor');
begin
  who := public.amenity_author(p_hostel);
  if p_id is null then
    insert into public.amenities (hostel_id, floor, kind, name, qty, working, place, rooms, by_role)
    values (p_hostel, p_floor, p_kind, coalesce(p_name, ''), p_qty, coalesce(p_working, true), v_place,
      case when v_place = 'floor' then '{}' else coalesce(p_rooms, '{}') end, who.role)
    returning * into a;
    act := 'add';
  else
    select * into prev from public.amenities where id = p_id and hostel_id = p_hostel;
    if prev.id is null then raise exception 'that thing isn''t there any more'; end if;
    update public.amenities set floor = p_floor, kind = p_kind, name = coalesce(p_name, ''), qty = p_qty, working = coalesce(p_working, true),
      place = v_place, rooms = case when v_place = 'floor' then '{}' else coalesce(p_rooms, '{}') end, by_role = who.role
    where id = p_id returning * into a;
    act := 'change';
  end if;
  insert into public.amenity_log (hostel_id, amenity_id, action, what, by_id, by_name, by_role)
  values (p_hostel, a.id, act, public.amenity_what(a), public.uid(), who.name, who.role);
  if who.role = 'resident' then
    v_title := 'A resident ' || case
      when act = 'add' then 'added ' || case when a.kind = 'ro' or public.amenity_what(a) ~* '^[aeiou]' then 'an ' else 'a ' end || public.amenity_what(a)
      when prev.working and not a.working then 'marked the ' || public.amenity_what(a) || ' not working'
      when not prev.working and a.working then 'marked the ' || public.amenity_what(a) || ' working again'
      else 'changed the ' || public.amenity_what(a) end;
    insert into public.push_outbox (user_id, title, body, data)
    select st.user_id, v_title,
      case when not a.working then 'It shows as not working now. Fix it or correct it in Layouts.' else 'It''s live now. You can correct or remove it in Layouts.' end,
      jsonb_build_object('screen', 'oToday', 'amenity', a.id)
    from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  end if;
  return a.id;
end $$;

create or replace function public.remove_amenity(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare a public.amenities; who record;
begin
  select * into a from public.amenities where id = p_id;
  if a.id is null then raise exception 'that thing isn''t there any more'; end if;
  who := public.amenity_author(a.hostel_id);
  delete from public.amenities where id = p_id;
  insert into public.amenity_log (hostel_id, amenity_id, action, what, by_id, by_name, by_role)
  values (a.hostel_id, a.id, 'remove', public.amenity_what(a), public.uid(), who.name, who.role);
  if who.role = 'resident' then
    insert into public.push_outbox (user_id, title, body, data)
    select st.user_id, 'A resident removed the ' || public.amenity_what(a), 'Add it back in Layouts if it''s still there.',
      jsonb_build_object('screen', 'oToday', 'amenity', a.id)
    from public.hostel_staff st where st.hostel_id = a.hostel_id and st.role = 'owner';
  end if;
end $$;

revoke execute on function public.amenity_check(), public.amenity_what(public.amenities), public.amenity_author(uuid) from public, anon, authenticated;
revoke execute on function public.save_amenity(uuid, uuid, int, text, text, int, boolean, text, int[]), public.remove_amenity(uuid) from public, anon;
grant execute on function public.save_amenity(uuid, uuid, int, text, text, int, boolean, text, int[]), public.remove_amenity(uuid) to authenticated;

-- Shared things update live on the hostel page, the room plan and Layouts.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'amenities') then
    alter publication supabase_realtime add table public.amenities;
  end if;
end $$;


-- ================================================================
-- 20261002230000_food_menu.sql
-- ================================================================
-- Food menu on the server, and meal ratings without names.
--   menus            (F13, one row per weekday) anyone may now read a live
--       hostel's menu: tenants see "Food today" and the week on its page.
--       Residents, staff and the team keep reading any. Staff and the team
--       write (unchanged).
--   meal_ratings     a resident's Good / Okay / Poor for one meal on one day.
--       Nobody reads the rows; staff only get counts from meal_votes().
--   rate_meal(hostel, meal, rating)    a confirmed resident who hasn't left;
--       one answer per meal per day (a second tap changes it).
--   meal_votes(hostel) → (meal, rating, n)    the last 7 days, staff and team.
-- Safe to run again.

drop policy if exists "read menu" on public.menus;
create policy "read menu" on public.menus for select
  using (public.is_live(hostel_id) or public.is_resident(hostel_id) or public.is_staff(hostel_id) or public.is_team());

create table if not exists public.meal_ratings (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null,
  day date not null default (now() at time zone 'Asia/Kolkata')::date,
  meal text not null check (meal in ('b', 'l', 'n')),
  rating text not null check (rating in ('good', 'okay', 'poor')),
  at timestamptz not null default now(),
  primary key (hostel_id, user_id, day, meal)
);
alter table public.meal_ratings enable row level security;
-- No policies: the rows are read and written only by the functions below.

create or replace function public.rate_meal(p_hostel uuid, p_meal text, p_rating text) returns void
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid();
begin
  if me is null then raise exception 'sign in first'; end if;
  if p_meal is null or p_meal not in ('b', 'l', 'n') then raise exception 'pick breakfast, lunch or dinner'; end if;
  if p_rating is null or lower(p_rating) not in ('good', 'okay', 'poor') then raise exception 'pick good, okay or poor'; end if;
  if not exists (select 1 from public.stays st where st.hostel_id = p_hostel and st.user_id = me and st.confirmed and st.left_on is null) then
    raise exception 'only this hostel''s residents can rate its food';
  end if;
  insert into public.meal_ratings (hostel_id, user_id, meal, rating) values (p_hostel, me, p_meal, lower(p_rating))
  on conflict (hostel_id, user_id, day, meal) do update set rating = excluded.rating, at = now();
end $$;

create or replace function public.meal_votes(p_hostel uuid) returns table (meal text, rating text, n int)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner and managers see its food ratings'; end if;
  return query
    select r.meal, r.rating, count(*)::int from public.meal_ratings r
    where r.hostel_id = p_hostel and r.day > (now() at time zone 'Asia/Kolkata')::date - 7
    group by r.meal, r.rating order by r.meal, r.rating;
end $$;

revoke execute on function public.rate_meal(uuid, text, text), public.meal_votes(uuid) from public, anon;
grant execute on function public.rate_meal(uuid, text, text), public.meal_votes(uuid) to authenticated;


-- ================================================================
-- 20261002231000_f24_owner_phone.sql
-- ================================================================
drop function if exists public.owner_contacts(uuid[]);
-- F24 item 1: the owner's number from the server. DECISIONS (F07): a tenant
-- sees it only after they hold a bed, enquire through Hostelzy, or stay there.
--   owner_contacts(hostels[]) → (hostel_id, phone)
--       The owner's own phone (profiles.phone of the hostel's owner), else
--       the number the team noted at onboarding (hostel_leads.owner_phone).
--       Only for hostels where the caller is staff or the team, or has a hold
--       or an enquiry there in the last 60 days, or a stay (now or ended in
--       the last 60 days). Other hostels are left out.
-- Residents' phones stay where they were: staff read them in stays. Safe to run again.

create or replace function public.owner_contacts(p_hostels uuid[]) returns table (hostel_id uuid, phone text)
language sql stable security definer set search_path = ''
as $$
  select h.id,
    coalesce(
      nullif((select regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_phone, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      '')
  from public.hostels h
  where h.id = any(p_hostels)
    and public.uid() is not null
    and (public.is_staff(h.id) or public.is_team()
      or exists (select 1 from public.holds x where x.hostel_id = h.id and x.tenant_id = public.uid() and x.started_at > now() - interval '60 days')
      or exists (select 1 from public.enquiries e where e.hostel_id = h.id and e.tenant_id = public.uid() and e.created_at > now() - interval '60 days')
      or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = public.uid() and (s.left_on is null or s.left_on > current_date - 60)))
$$;

revoke execute on function public.owner_contacts(uuid[]) from public, anon;
grant execute on function public.owner_contacts(uuid[]) to authenticated;


-- ================================================================
-- 20261002232000_f24_onboard.sql
-- ================================================================
-- F24 items 2 and 3: a real hostel onboarded end to end from the team's Add
-- hostel wizard, its owner's account linked, and rooms saved on the server.
--   save_hostel(id, jsonb) → id      the team: creates (null id) or updates a
--       draft: basics, rate card, the owner's number (hostel_leads) and rooms.
--   save_rooms(hostel, jsonb)        staff or the team: the hostel's rooms as
--       a list [{number, label, floor, share, ac, rent, bath}]. Adds and
--       changes rooms and beds; a room or bed with someone in it (a resident,
--       a hold or a booking) is never removed.
--   new_owner_invite(hostel, name, phone) → "OWN-XXXXXXXX"   the team; sent to
--       the owner on WhatsApp, works once, for 7 days.
--   join_as_owner(code) → hostel name   signed in with Google: becomes the
--       hostel's owner (a hostel has one owner account).
--   go_live(hostel)                  the team: rooms, a price for every room
--       type, the owner's account and 8 photos are there → live, "Visited by
--       Hostelzy" today, and the 30-day trial starts (owner_plans).
-- Safe to run again.

alter table public.hostels add column if not exists visited_on date;

create table if not exists public.owner_invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  name text not null default '',
  phone text not null default '',
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by text,
  used_at timestamptz
);
alter table public.owner_invites enable row level security;
drop policy if exists "team reads owner invites" on public.owner_invites;
create policy "team reads owner invites" on public.owner_invites for select using (public.is_team());
-- Writes go through the functions below only.

-- A bed someone is in: booked or held on the board, a live hold, or a resident.
create or replace function public.bed_busy(b uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.beds x where x.id = b and x.state <> 'free')
    or exists (select 1 from public.holds h where h.bed_id = b and h.status in ('waiting', 'held', 'booked'))
    or exists (select 1 from public.stays s where s.bed_id = b and s.left_on is null)
$$;

create or replace function public.save_rooms(p_hostel uuid, p_rooms jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare r jsonb; rid uuid; v_share int; v_number int; busy text; keep int[] := '{}';
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner, managers or the team change its rooms'; end if;
  if jsonb_typeof(coalesce(p_rooms, 'null')) <> 'array' then raise exception 'send the rooms as a list'; end if;
  for r in select * from jsonb_array_elements(p_rooms) loop
    v_number := (r ->> 'number')::int;
    v_share := (r ->> 'share')::int;
    if v_number is null then raise exception 'every room needs a number'; end if;
    if v_share is null or v_share not between 1 and 8 then raise exception 'room % : 1 to 8 beds', v_number; end if;
    if v_number = any(keep) then raise exception 'room % is in the list twice', v_number; end if;
    keep := keep || v_number;
    insert into public.rooms (hostel_id, number, label, floor, share, ac, rent, bath)
    values (p_hostel, v_number, nullif(trim(coalesce(r ->> 'label', '')), ''), coalesce((r ->> 'floor')::int, v_number / 100), v_share,
      coalesce((r ->> 'ac')::boolean, false), greatest(coalesce((r ->> 'rent')::int, 0), 0), coalesce(r ->> 'bath', 'Shared'))
    on conflict (hostel_id, number) do update set label = excluded.label, floor = excluded.floor, share = excluded.share,
      ac = excluded.ac, rent = excluded.rent, bath = excluded.bath
    returning id into rid;
    -- Beds A, B, C… up to the share; extra letters go only when nobody is in them.
    select string_agg(b.letter, ', ' order by b.letter) into busy from public.beds b
    where b.room_id = rid and ascii(b.letter) - 64 > v_share and public.bed_busy(b.id);
    if busy is not null then raise exception 'room %: bed % has someone in it', coalesce(nullif(r ->> 'label', ''), v_number::text), busy; end if;
    delete from public.beds b where b.room_id = rid and ascii(b.letter) - 64 > v_share;
    insert into public.beds (hostel_id, room_id, letter)
    select p_hostel, rid, chr(64 + k) from generate_series(1, v_share) k
    where not exists (select 1 from public.beds b where b.room_id = rid and b.letter = chr(64 + k));
  end loop;
  -- Rooms left out are removed, unless someone is in one of their beds.
  select string_agg(coalesce(x.label, x.number::text), ', ' order by x.number) into busy from public.rooms x
  where x.hostel_id = p_hostel and not (x.number = any(keep))
    and exists (select 1 from public.beds b where b.room_id = x.id and public.bed_busy(b.id));
  if busy is not null then raise exception 'room % has someone in it', busy; end if;
  delete from public.rooms x where x.hostel_id = p_hostel and not (x.number = any(keep));
end $$;

create or replace function public.save_hostel(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare hid uuid := p_id; v_name text := trim(coalesce(p ->> 'name', '')); v_slug text; st text; rc jsonb;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team adds hostels'; end if;
  if v_name = '' then raise exception 'add the hostel name'; end if;
  if hid is null then
    v_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then v_slug := 'hostel'; end if;
    while exists (select 1 from public.hostels where slug = v_slug) loop
      v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
    end loop;
    insert into public.hostels (slug, name, gender, area, status) values (v_slug, v_name, coalesce(p ->> 'gender', 'Men'), coalesce(p ->> 'area', ''), 'draft')
    returning id into hid;
  end if;
  select status into st from public.hostels where id = hid;
  if st is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  update public.hostels set
    name = v_name,
    gender = coalesce(p ->> 'gender', gender),
    area = coalesce(p ->> 'area', area),
    owner_name = coalesce(trim(p ->> 'owner_name'), owner_name),
    food = coalesce((p ->> 'food')::boolean, food),
    ac = coalesce((p ->> 'ac')::boolean, ac),
    only_ac = coalesce((p ->> 'only_ac')::boolean, only_ac),
    tags = coalesce(array(select jsonb_array_elements_text(p -> 'tags')), tags),
    terms = coalesce(p -> 'terms', terms),
    lat = coalesce((p ->> 'lat')::double precision, lat),
    lng = coalesce((p ->> 'lng')::double precision, lng)
  where id = hid;
  insert into public.hostel_leads (hostel_id, owner_phone, stage)
  values (hid, regexp_replace(coalesce(p ->> 'owner_phone', ''), '\D', '', 'g'), 'signed_up')
  on conflict (hostel_id) do update set owner_phone = case when excluded.owner_phone <> '' then excluded.owner_phone else public.hostel_leads.owner_phone end,
    stage = case when public.hostel_leads.stage in ('lead', 'visited') then 'signed_up' else public.hostel_leads.stage end, updated_at = now();
  if p ? 'rates' then
    delete from public.rate_cards where hostel_id = hid;
    for rc in select * from jsonb_array_elements(p -> 'rates') loop
      insert into public.rate_cards (hostel_id, ac, share, rent) values (hid, (rc ->> 'ac')::boolean, (rc ->> 'share')::int, (rc ->> 'rent')::int);
    end loop;
  end if;
  if p ? 'rooms' then perform public.save_rooms(hid, p -> 'rooms'); end if;
  return hid;
end $$;

create or replace function public.new_owner_invite(h uuid, p_name text, p_phone text) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not public.is_team() then raise exception 'only the Hostelzy team links owners'; end if;
  if not exists (select 1 from public.hostels where id = h) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  loop
    c := 'OWN-';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.owner_invites where code = c);
  end loop;
  insert into public.owner_invites (code, hostel_id, name, phone) values (c, h, trim(coalesce(p_name, '')), regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'));
  return c;
end $$;

create or replace function public.join_as_owner(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hname text; me text := public.uid();
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.owner_invites where code = upper(trim(p_code));
  if i is null or i.used_by is not null or i.expires_at < now() then raise exception 'that owner code isn''t valid any more'; end if;
  if exists (select 1 from public.hostel_staff s where s.hostel_id = i.hostel_id and s.role = 'owner' and s.user_id <> me) then
    raise exception 'this hostel already has an owner account';
  end if;
  update public.owner_invites set used_by = me, used_at = now() where code = i.code;
  insert into public.hostel_staff (hostel_id, user_id, role) values (i.hostel_id, me, 'owner')
  on conflict (hostel_id, user_id) do update set role = 'owner';
  update public.profiles set role = 'owner' where id = me;
  select name into hname from public.hostels where id = i.hostel_id;
  return hname;
end $$;

create or replace function public.go_live(h uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare missing text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team puts hostels live'; end if;
  if not exists (select 1 from public.hostels where id = h) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if not exists (select 1 from public.beds where hostel_id = h) then raise exception 'add at least one room with beds'; end if;
  select string_agg(distinct r.share || ' sharing' || case when r.ac then ' AC' else '' end, ', ') into missing
  from public.rooms r where r.hostel_id = h
    and not exists (select 1 from public.rate_cards c where c.hostel_id = h and c.ac = r.ac and c.share = r.share and c.rent > 0);
  if missing is not null then raise exception 'add a price for %', missing; end if;
  if not exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.role = 'owner') then raise exception 'link the owner''s account first'; end if;
  if (select count(*) from public.hostel_photos p where p.hostel_id = h) < 8 then raise exception 'add 8 photos first'; end if;
  update public.hostels set status = 'live', visited_on = coalesce(visited_on, (now() at time zone 'Asia/Kolkata')::date) where id = h;
  insert into public.owner_plans (hostel_id, trial_ends, status) values (h, (now() at time zone 'Asia/Kolkata')::date + 30, 'trial')
  on conflict (hostel_id) do nothing;
  update public.hostel_leads set stage = 'data_complete', next_step = '', updated_at = now() where hostel_id = h;
end $$;

revoke execute on function public.bed_busy(uuid) from public, anon, authenticated;
revoke execute on function public.save_rooms(uuid, jsonb), public.save_hostel(uuid, jsonb), public.new_owner_invite(uuid, text, text),
  public.join_as_owner(text), public.go_live(uuid) from public, anon;
grant execute on function public.save_rooms(uuid, jsonb), public.save_hostel(uuid, jsonb), public.new_owner_invite(uuid, text, text),
  public.join_as_owner(text), public.go_live(uuid) to authenticated;


-- ================================================================
-- 20261002233000_f24_moves.sql
-- ================================================================
-- F24 item 5: notice, moving to another bed and moving out on the server,
-- and the advance refund tracked to the end.
--   give_notice(last_day, reason) → id       a resident; the owner is told.
--   ask_move(to_bed) → id                    a resident; a free bed in the same hostel.
--   withdraw_move(id)                        the resident, while it's open.
--   answer_move(id, accept)                  staff: notice accepted → the bed shows
--       "free from <last day>"; a move accepted → the stay moves to the new bed
--       (its rent from the new room); the resident is told either way.
--   mark_leaving(stay, day)                  staff: the same as an accepted notice.
--   moved_out(stay, day)                     staff: the stay ends, the bed is free and
--       the refund (advance minus what the hostel keeps) is due in 7 days.
--   send_refund(stay, utr)                   staff: marked refunded with the UPI ref.
--   confirm_refund(stay, got)                the former resident: "Yes, I got it" or
--       "Not received" (the owner is told).
-- Safe to run again.

alter table public.stays add column if not exists leaving_on date;
alter table public.stays add column if not exists refund_amount int;
alter table public.stays add column if not exists refund_status text;
alter table public.stays add column if not exists refund_utr text;
alter table public.stays add column if not exists refund_sent_at timestamptz;
alter table public.stays drop constraint if exists stays_refund_status;
alter table public.stays add constraint stays_refund_status check (refund_status is null or refund_status in ('due', 'sent', 'received', 'not_received'));

alter table public.move_requests add column if not exists stay_id uuid references public.stays (id) on delete cascade;
alter table public.move_requests add column if not exists reason text not null default '';
alter table public.move_requests add column if not exists to_bed_id uuid references public.beds (id) on delete set null;
alter table public.move_requests add column if not exists decided_at timestamptz;

-- The caller's current confirmed stay.
create or replace function public.my_current_stay() returns public.stays
language sql stable security definer set search_path = ''
as $$ select * from public.stays s where s.user_id = public.uid() and s.confirmed and s.left_on is null order by s.joined_on desc limit 1 $$;

create or replace function public.tell_owners(h uuid, p_title text, p_body text) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, p_title, p_body, '{"screen":"oToday"}'::jsonb from public.hostel_staff st where st.hostel_id = h and st.role = 'owner'
$$;

create or replace function public.tell_resident(s public.stays, p_title text, p_body text, p_screen text default 'rStay') returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, p_title, p_body, jsonb_build_object('screen', p_screen) where s.user_id is not null
$$;

create or replace function public.give_notice(p_last_day date, p_reason text default '') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.my_current_stay(); rid uuid;
begin
  if s.id is null then raise exception 'only residents give notice'; end if;
  if p_last_day is null or p_last_day < (now() at time zone 'Asia/Kolkata')::date then raise exception 'pick a last day from today on'; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and kind = 'vacate' and status = 'open';
  insert into public.move_requests (hostel_id, user_id, stay_id, kind, last_day, reason)
  values (s.hostel_id, public.uid(), s.id, 'vacate', p_last_day, left(trim(coalesce(p_reason, '')), 200)) returning id into rid;
  perform public.tell_owners(s.hostel_id, s.name || ' gave notice', 'Last day ' || to_char(p_last_day, 'FMDD Mon') || '. Accept it in Hostelzy.');
  return rid;
end $$;

create or replace function public.ask_move(p_to_bed uuid) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.my_current_stay(); b record; rid uuid;
begin
  if s.id is null then raise exception 'only residents ask to move'; end if;
  select x.id, x.hostel_id, coalesce(r.label, r.number::text) || '-' || x.letter as label into b
  from public.beds x join public.rooms r on r.id = x.room_id where x.id = p_to_bed;
  if b.id is null or b.hostel_id <> s.hostel_id then raise exception 'pick a bed in your hostel'; end if;
  if b.id = s.bed_id then raise exception 'that''s your bed now'; end if;
  if public.bed_busy(b.id) then raise exception 'bed % isn''t free', b.label; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and kind = 'swap' and status = 'open';
  insert into public.move_requests (hostel_id, user_id, stay_id, kind, to_bed, to_bed_id)
  values (s.hostel_id, public.uid(), s.id, 'swap', b.label, b.id) returning id into rid;
  perform public.tell_owners(s.hostel_id, s.name || ' asks to move to bed ' || b.label, 'Accept or say no in Hostelzy.');
  return rid;
end $$;

create or replace function public.withdraw_move(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.move_requests set status = 'withdrawn' where id = p_id and user_id = public.uid() and status = 'open';
  if not found then raise exception 'that request isn''t open any more'; end if;
end $$;

-- Notice accepted / marked: the bed shows "free from" the last day.
create or replace function public.set_leaving(s public.stays, p_day date) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.stays set leaving_on = p_day where id = s.id;
  if s.bed_id is not null then update public.beds set state = 'soon', free_from = p_day where id = s.bed_id; end if;
end $$;

create or replace function public.answer_move(p_id uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare m public.move_requests; s public.stays; nb record;
begin
  select * into m from public.move_requests where id = p_id;
  if m.id is null then raise exception 'that request isn''t there any more'; end if;
  if not (public.is_staff(m.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers answer it'; end if;
  if m.status <> 'open' then raise exception 'that request isn''t open any more'; end if;
  select * into s from public.stays where id = m.stay_id;
  if not p_accept then
    update public.move_requests set status = 'declined', decided_at = now() where id = p_id;
    perform public.tell_resident(s, case when m.kind = 'vacate' then 'Your notice needs a word' else 'Your move to bed ' || m.to_bed || ' wasn''t accepted' end,
      'Talk to your owner on WhatsApp.');
    return;
  end if;
  if m.kind = 'vacate' then
    perform public.set_leaving(s, m.last_day);
    perform public.tell_resident(s, 'Notice accepted', 'Your last day is ' || to_char(m.last_day, 'FMDD Mon') || '. Your refund shows in Hostelzy after you move out.');
  else
    if m.to_bed_id is null or public.bed_busy(m.to_bed_id) then raise exception 'bed % isn''t free any more', m.to_bed; end if;
    select r.rent into nb from public.beds b join public.rooms r on r.id = b.room_id where b.id = m.to_bed_id;
    update public.stays set bed_id = m.to_bed_id, rent = coalesce(nb.rent, rent) where id = s.id;
    perform public.tell_resident(s, 'You can move to bed ' || m.to_bed, 'New rent ' || coalesce(nb.rent, s.rent) || ' from next month.');
  end if;
  update public.move_requests set status = 'accepted', decided_at = now() where id = p_id;
end $$;

create or replace function public.staff_stay(p_stay uuid) returns public.stays
language plpgsql security definer set search_path = ''
as $$
declare s public.stays;
begin
  select * into s from public.stays where id = p_stay;
  if s.id is null then raise exception 'that resident isn''t there any more'; end if;
  if not (public.is_staff(s.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers do this'; end if;
  return s;
end $$;

create or replace function public.mark_leaving(p_stay uuid, p_day date) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay);
begin
  if s.left_on is not null then raise exception 'they''ve already moved out'; end if;
  if p_day is null then raise exception 'pick the last day'; end if;
  perform public.set_leaving(s, p_day);
  update public.move_requests set status = 'accepted', decided_at = now() where stay_id = s.id and kind = 'vacate' and status = 'open';
end $$;

create or replace function public.moved_out(p_stay uuid, p_day date default null) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay); kept int; amt int; d date := coalesce(p_day, (now() at time zone 'Asia/Kolkata')::date);
begin
  if s.left_on is not null then raise exception 'they''ve already moved out'; end if;
  select coalesce((h.terms ->> 'maintenance')::int, 0) into kept from public.hostels h where h.id = s.hostel_id;
  amt := greatest(coalesce(s.advance, 0) - coalesce(kept, 0), 0);
  update public.stays set left_on = d, leaving_on = coalesce(leaving_on, d), refund_amount = amt,
    refund_status = case when amt > 0 then 'due' else null end where id = s.id;
  if s.bed_id is not null then update public.beds set free_from = null where id = s.bed_id; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and status = 'open';
  if amt > 0 then
    perform public.tell_resident(s, 'Your refund: ' || amt, 'Due by ' || to_char(d + 7, 'FMDD Mon') || '. Hostelzy asks you when it arrives.', 'rRefund');
  end if;
end $$;

create or replace function public.send_refund(p_stay uuid, p_utr text) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay); u text := regexp_replace(coalesce(p_utr, ''), '\D', '', 'g');
begin
  if s.refund_status is null or s.refund_status not in ('due', 'not_received', 'sent') then raise exception 'there''s no refund due'; end if;
  if u !~ '^[0-9]{12}$' then raise exception 'the UPI reference is 12 digits'; end if;
  update public.stays set refund_status = 'sent', refund_utr = u, refund_sent_at = now() where id = s.id;
  perform public.tell_resident(s, 'Refund of ' || s.refund_amount || ' sent', 'UPI ref ' || u || '. Tell Hostelzy when you get it.', 'rRefund');
end $$;

create or replace function public.confirm_refund(p_stay uuid, p_got boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays;
begin
  select * into s from public.stays where id = p_stay and user_id = public.uid();
  if s.id is null then raise exception 'that isn''t your stay'; end if;
  if s.refund_status <> 'sent' then raise exception 'your owner hasn''t marked it refunded yet'; end if;
  update public.stays set refund_status = case when p_got then 'received' else 'not_received' end where id = s.id;
  if not p_got then
    perform public.tell_owners(s.hostel_id, s.name || ' hasn''t got the refund', 'UPI ref ' || coalesce(s.refund_utr, '') || '. Check your bank and talk to them.');
  end if;
end $$;

revoke execute on function public.my_current_stay(), public.tell_owners(uuid, text, text), public.tell_resident(public.stays, text, text, text),
  public.set_leaving(public.stays, date), public.staff_stay(uuid) from public, anon, authenticated;
revoke execute on function public.give_notice(date, text), public.ask_move(uuid), public.withdraw_move(uuid), public.answer_move(uuid, boolean),
  public.mark_leaving(uuid, date), public.moved_out(uuid, date), public.send_refund(uuid, text), public.confirm_refund(uuid, boolean) from public, anon;
grant execute on function public.give_notice(date, text), public.ask_move(uuid), public.withdraw_move(uuid), public.answer_move(uuid, boolean),
  public.mark_leaving(uuid, date), public.moved_out(uuid, date), public.send_refund(uuid, text), public.confirm_refund(uuid, boolean) to authenticated;


-- ================================================================
-- 20261002233500_f24_values.sql
-- ================================================================
-- F24 item 6: real values instead of made-up ones on the hostel page and in
-- the ranking.
--   enquiries.contacted_at, holds.decided_at   set by the server when the
--       owner first marks an enquiry contacted / answers a hold.
--   hostel_signals() → per live hostel, counts only (anyone may read):
--       reply_minutes / reply_n   median minutes to reply over the last 60
--           days (enquiries contacted, holds answered); shown once n ≥ 3.
--       complaints_30d, residents the hostel's complaints in 30 days and its
--           current residents (the ranking's complaints factor).
--       photos, rooms, layouts      listing completeness.
-- Safe to run again.

alter table public.enquiries add column if not exists contacted_at timestamptz;
alter table public.holds add column if not exists decided_at timestamptz;

create or replace function public.stamp_reply() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'enquiries' then
    if new.contacted and not coalesce(old.contacted, false) and new.contacted_at is null then new.contacted_at := now(); end if;
  elsif new.status is distinct from old.status and old.status = 'waiting' and new.decided_at is null then
    new.decided_at := now();
  end if;
  return new;
end $$;

drop trigger if exists stamp_reply on public.enquiries;
create trigger stamp_reply before update of contacted on public.enquiries for each row execute function public.stamp_reply();
drop trigger if exists stamp_reply on public.holds;
create trigger stamp_reply before update of status on public.holds for each row execute function public.stamp_reply();
revoke execute on function public.stamp_reply() from public, anon, authenticated;

create or replace function public.hostel_signals() returns table (hostel_id uuid, reply_minutes int, reply_n int, complaints_30d int, residents int, photos int, rooms int, layouts int)
language sql stable security definer set search_path = ''
as $$
  with replies as (
    select e.hostel_id, extract(epoch from e.contacted_at - e.created_at) / 60 as m from public.enquiries e
    where e.contacted_at is not null and e.created_at > now() - interval '60 days'
    union all
    select x.hostel_id, extract(epoch from x.decided_at - x.started_at) / 60 from public.holds x
    where x.decided_at is not null and x.started_at > now() - interval '60 days' and x.status <> 'expired'
  ), speed as (
    select r.hostel_id, round(percentile_cont(0.5) within group (order by r.m))::int as minutes, count(*)::int as n from replies r group by r.hostel_id
  )
  select h.id,
    coalesce(sp.minutes, 0),
    coalesce(sp.n, 0),
    (select count(*)::int from public.complaints c where c.hostel_id = h.id and c.created_at > now() - interval '30 days'),
    (select count(*)::int from public.stays s where s.hostel_id = h.id and s.left_on is null),
    (select count(*)::int from public.hostel_photos p where p.hostel_id = h.id),
    (select count(*)::int from public.rooms r where r.hostel_id = h.id),
    (select count(*)::int from public.layouts l where l.hostel_id = h.id and l.stage = 'published')
  from public.hostels h left join speed sp on sp.hostel_id = h.id
  where h.status = 'live'
$$;

grant execute on function public.hostel_signals() to anon, authenticated;


-- ================================================================
-- 20261003010000_f24_shapes.sql
-- ================================================================
-- F24 item 11: room shapes and "Ask Hostelzy to draw it" (done in 48 h).
--   layouts.shape / layouts.outline   the room's shape name and its walls as
--       [[x, y], …] in feet (null = a plain w × h rectangle). Rows from before
--       stay rectangles. put_layout, undo and approve keep them.
--   check_layout                      + the outline is a real polygon inside
--       w × h, and every bed (2.7 × 5.4 ft) stands inside it.
--   shape_requests                    an owner's (or manager's) request to
--       have a room drawn: room, shape, what's different, W × L, up to 3
--       private photos (bucket fix-photos), due 48 h after asking.
--       requested → drawing → sent (the team's drawing) → published | cancelled.
--   request_shape(hostel, room, shape, note, w, h, photos)   staff; replaces an
--       open request for the same room.
--   start_shape_request(id)            team: "Drawing".
--   send_shape_drawing(id, drawing)    team: the drawing goes to the owner
--       ({w, h, shape, outline, beds?, items?}); the owner is told.
--   cancel_shape_request(id)           staff or team.
--   publish_layout                     publishing the room closes its sent request.
-- Reads: the hostel's staff see their requests; the team sees and updates all.
-- Safe to run again.

alter table public.layouts add column if not exists shape text not null default 'Rectangle';
alter table public.layouts add column if not exists outline jsonb;
alter table public.layout_history add column if not exists shape text;

-- Point in polygon (ray casting), feet.
create or replace function public.in_outline(o jsonb, x double precision, y double precision) returns boolean
language plpgsql immutable set search_path = ''
as $$
declare n int := jsonb_array_length(o); i int; j int; xi double precision; yi double precision; xj double precision; yj double precision; inside boolean := false;
begin
  j := n - 1;
  for i in 0 .. n - 1 loop
    xi := (o -> i ->> 0)::double precision; yi := (o -> i ->> 1)::double precision;
    xj := (o -> j ->> 0)::double precision; yj := (o -> j ->> 1)::double precision;
    if ((yi > y) <> (yj > y)) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside := not inside; end if;
    j := i;
  end loop;
  return inside;
end $$;

-- The editor's checks, on the server (F19), plus the room's shape (F24).
create or replace function public.check_layout(p_hostel uuid, p_room int, l jsonb) returns void
language plpgsql stable security definer set search_path = ''
as $$
declare r record; missing text; o jsonb := l -> 'outline'; w double precision; h double precision; b record; bx double precision; by_ double precision;
begin
  select * into r from public.rooms where hostel_id = p_hostel and number = p_room;
  if r is null then raise exception 'there is no room % here', p_room; end if;
  if jsonb_typeof(l -> 'beds') <> 'object' or jsonb_typeof(l -> 'items') <> 'array' then raise exception 'that layout isn''t complete'; end if;
  if (select count(*) from jsonb_object_keys(l -> 'beds')) <> r.share then raise exception 'room % is % sharing: place % beds', p_room, r.share, r.share; end if;
  if r.ac and not exists (select 1 from jsonb_array_elements(l -> 'items') i where i ->> 'kind' = 'ac') then raise exception 'an AC room needs an AC unit'; end if;
  if exists (select 1 from jsonb_array_elements(l -> 'items') i where i ->> 'kind' not in ('fan', 'ac', 'window', 'door', 'wash', 'pillar')) then raise exception 'no gates, CCTV or exits on a layout'; end if;
  select bd.letter into missing from public.beds bd
  where bd.room_id = r.id and bd.state = 'booked' and not (l -> 'beds') ? bd.letter limit 1;
  if missing is not null then raise exception 'bed % has a resident, so it stays', missing; end if;
  if coalesce(l ->> 'shape', 'Rectangle') not in ('Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom') then
    raise exception 'that room shape isn''t known';
  end if;
  if o is not null and jsonb_typeof(o) <> 'null' then
    w := (l ->> 'w')::double precision; h := (l ->> 'h')::double precision;
    if jsonb_typeof(o) <> 'array' or jsonb_array_length(o) < 3 or jsonb_array_length(o) > 40
       or exists (select 1 from jsonb_array_elements(o) p where jsonb_typeof(p) <> 'array' or jsonb_array_length(p) <> 2
                  or (p ->> 0)::double precision not between 0 and w or (p ->> 1)::double precision not between 0 and h) then
      raise exception 'the room''s walls don''t fit its size';
    end if;
    for b in select key, value from jsonb_each(l -> 'beds') loop
      bx := (b.value ->> 0)::double precision; by_ := (b.value ->> 1)::double precision;
      if not (public.in_outline(o, bx + .1, by_ + .1) and public.in_outline(o, bx + 2.6, by_ + .1)
              and public.in_outline(o, bx + .1, by_ + 5.3) and public.in_outline(o, bx + 2.6, by_ + 5.3)) then
        raise exception 'bed % is outside the walls', b.key;
      end if;
    end loop;
  end if;
end $$;

-- Publish [l] as a new version; the old one (with its shape) goes to history.
create or replace function public.put_layout(p_hostel uuid, p_room int, l jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare old record; v int; o jsonb := case when jsonb_typeof(l -> 'outline') = 'array' then l -> 'outline' end;
begin
  select * into old from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
  if found then
    insert into public.layout_history (hostel_id, room, version, layout, replaced_by, shape)
    values (p_hostel, p_room, old.version, jsonb_strip_nulls(jsonb_build_object('w', old.w, 'h', old.h, 'beds', old.beds, 'items', old.items, 'bunks', old.bunks, 'shape', old.shape, 'outline', old.outline)), public.uid(), old.shape);
  end if;
  v := coalesce(old.version, 0) + 1;
  insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items, bunks, shape, outline, disputes, confirmed_at)
  values (p_hostel, p_room, 'published', v, (l ->> 'w')::double precision, (l ->> 'h')::double precision, l -> 'beds', l -> 'items', coalesce(l -> 'bunks', '{}'),
          coalesce(l ->> 'shape', 'Rectangle'), o, 0, now())
  on conflict (hostel_id, room, stage) do update
    set version = excluded.version, w = excluded.w, h = excluded.h, beds = excluded.beds, items = excluded.items,
        bunks = excluded.bunks, shape = excluded.shape, outline = excluded.outline, disputes = 0, confirmed_at = now(), updated_at = now();
  return v;
end $$;

create or replace function public.undo_layout_publish(p_hostel uuid, p_room int) returns int
language plpgsql security definer set search_path = ''
as $$
declare last record;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can undo'; end if;
  select * into last from public.layout_history where hostel_id = p_hostel and room = p_room order by replaced_at desc limit 1;
  if last is null then raise exception 'there is no earlier version'; end if;
  update public.layouts set version = last.version, w = (last.layout ->> 'w')::double precision, h = (last.layout ->> 'h')::double precision,
    beds = last.layout -> 'beds', items = last.layout -> 'items', bunks = coalesce(last.layout -> 'bunks', '{}'),
    shape = coalesce(last.layout ->> 'shape', 'Rectangle'), outline = last.layout -> 'outline', updated_at = now()
  where hostel_id = p_hostel and room = p_room and stage = 'published';
  delete from public.layout_history where id = last.id;
  update public.layout_fixes set status = 'rejected', reason = 'Undone by the owner'
  where id = (select id from public.layout_fixes where hostel_id = p_hostel and room = p_room and status = 'approved' order by decided_at desc limit 1)
    and decided_at > last.replaced_at - interval '1 second';
  return last.version;
end $$;

create or replace function public.approve_layout(p_hostel uuid, p_room int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_owner(p_hostel) or public.is_team()) then raise exception 'only the owner approves a layout'; end if;
  insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items, bunks, shape, outline, disputes, confirmed_at)
  select hostel_id, room, 'published', version, w, h, beds, items, bunks, shape, outline, 0, now()
  from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'draft'
  on conflict (hostel_id, room, stage) do update
    set version = excluded.version, w = excluded.w, h = excluded.h, beds = excluded.beds,
        items = excluded.items, bunks = excluded.bunks, shape = excluded.shape, outline = excluded.outline,
        disputes = 0, confirmed_at = now(), updated_at = now();
  update public.layouts set waiting_approval = false where hostel_id = p_hostel and room = p_room and stage = 'draft';
end $$;

-- ---------------------------------------------------------------- shape requests

create table if not exists public.shape_requests (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  shape text not null default 'Custom',
  note text not null default '',
  w double precision not null default 0,
  h double precision not null default 0,
  photos text[] not null default '{}',
  status text not null default 'requested' check (status in ('requested', 'drawing', 'sent', 'published', 'cancelled')),
  asked_by text not null default public.uid(),
  asked_name text not null default '',
  due_at timestamptz not null default now() + interval '48 hours',
  drawing jsonb,
  sent_by text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists shape_requests_open on public.shape_requests (due_at) where status in ('requested', 'drawing', 'sent');

alter table public.shape_requests enable row level security;
drop policy if exists "staff read shape requests" on public.shape_requests;
create policy "staff read shape requests" on public.shape_requests for select using (public.is_staff(hostel_id) or public.is_team());
drop policy if exists "team updates shape requests" on public.shape_requests;
create policy "team updates shape requests" on public.shape_requests for update using (public.is_team()) with check (public.is_team());
-- Owners and managers write through the functions below.

-- Owners and managers may add request photos under their hostel's folder in
-- the private fix-photos bucket (`<hostel>/<their id>/…`); reading is already
-- the uploader, the hostel's staff and the team.
drop policy if exists "hz staff upload shape photos" on storage.objects;
create policy "hz staff upload shape photos" on storage.objects for insert
  with check (bucket_id = 'fix-photos' and split_part(name, '/', 2) = public.uid() and public.is_staff(public.photo_hostel(name)));

create or replace function public.request_shape(p_hostel uuid, p_room int, p_shape text, p_note text default '', p_w double precision default 0, p_h double precision default 0, p_photos text[] default '{}') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare rid uuid; who text;
begin
  if not public.is_staff(p_hostel) then raise exception 'only this hostel''s owner or manager can ask'; end if;
  if not exists (select 1 from public.rooms where hostel_id = p_hostel and number = p_room) then raise exception 'there is no room % here', p_room; end if;
  if coalesce(p_shape, '') not in ('Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom') then raise exception 'that room shape isn''t known'; end if;
  if coalesce(trim(p_note), '') = '' and coalesce(cardinality(p_photos), 0) = 0 then raise exception 'say what''s different, or add a photo'; end if;
  if coalesce(cardinality(p_photos), 0) > 3 then raise exception '3 photos is the most'; end if;
  if exists (select 1 from unnest(coalesce(p_photos, '{}')) ph where not public.fix_photo_ok(p_hostel, ph)) then raise exception 'that photo isn''t yours'; end if;
  if coalesce(p_w, 0) < 0 or coalesce(p_w, 0) > 60 or coalesce(p_h, 0) < 0 or coalesce(p_h, 0) > 60 then raise exception 'room size is 6 to 60 ft'; end if;
  -- A new request for the room replaces an open one.
  update public.shape_requests set status = 'cancelled' where hostel_id = p_hostel and room = p_room and status in ('requested', 'drawing', 'sent');
  select coalesce(nullif(p.name, ''), '') into who from public.profiles p where p.id::text = public.uid();
  insert into public.shape_requests (hostel_id, room, shape, note, w, h, photos, asked_name)
  values (p_hostel, p_room, p_shape, left(coalesce(trim(p_note), ''), 300), coalesce(p_w, 0), coalesce(p_h, 0), coalesce(p_photos, '{}'), coalesce(who, ''))
  returning id into rid;
  return rid;
end $$;

create or replace function public.start_shape_request(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team draws'; end if;
  update public.shape_requests set status = 'drawing' where id = p_id and status = 'requested';
  if not found then raise exception 'that request isn''t waiting any more'; end if;
end $$;

create or replace function public.send_shape_drawing(p_id uuid, p_drawing jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare q record; o jsonb := p_drawing -> 'outline'; w double precision; h double precision;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team draws'; end if;
  select * into q from public.shape_requests where id = p_id;
  if q is null or q.status not in ('requested', 'drawing', 'sent') then raise exception 'that request isn''t open any more'; end if;
  w := (p_drawing ->> 'w')::double precision; h := (p_drawing ->> 'h')::double precision;
  if w is null or h is null or w < 6 or w > 60 or h < 6 or h > 60 then raise exception 'room size is 6 to 60 ft'; end if;
  if coalesce(p_drawing ->> 'shape', 'Rectangle') not in ('Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom') then raise exception 'that room shape isn''t known'; end if;
  if o is not null and jsonb_typeof(o) <> 'null' and (jsonb_typeof(o) <> 'array' or jsonb_array_length(o) < 3 or jsonb_array_length(o) > 40
     or exists (select 1 from jsonb_array_elements(o) p where jsonb_typeof(p) <> 'array' or jsonb_array_length(p) <> 2
                or (p ->> 0)::double precision not between 0 and w or (p ->> 1)::double precision not between 0 and h)) then
    raise exception 'the room''s walls don''t fit its size';
  end if;
  -- A full layout (with beds) gets the editor's checks now; a shape alone is
  -- fitted with beds in the owner's app and checked when they publish.
  if jsonb_typeof(p_drawing -> 'beds') = 'object' and exists (select 1 from jsonb_object_keys(p_drawing -> 'beds')) then
    perform public.check_layout(q.hostel_id, q.room, p_drawing);
  end if;
  update public.shape_requests set status = 'sent', drawing = p_drawing, sent_by = public.uid(), sent_at = now() where id = p_id;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, 'Hostelzy drew room ' || q.room, 'Check it and publish. Tenants see it straight away.', jsonb_build_object('screen', 'oLayout', 'room', q.room)
  from public.hostel_staff st where st.hostel_id = q.hostel_id;
end $$;

create or replace function public.cancel_shape_request(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare q record;
begin
  select * into q from public.shape_requests where id = p_id;
  if q is null or not (public.is_staff(q.hostel_id) or public.is_team()) then raise exception 'that request isn''t yours'; end if;
  update public.shape_requests set status = 'cancelled' where id = p_id and status in ('requested', 'drawing', 'sent');
end $$;

-- Publishing the room (the owner's own drawing or the team's) closes its sent request.
create or replace function public.publish_layout(p_hostel uuid, p_room int, p_layout jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare v int;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can publish'; end if;
  perform public.check_layout(p_hostel, p_room, p_layout);
  v := public.put_layout(p_hostel, p_room, p_layout);
  update public.shape_requests set status = 'published' where hostel_id = p_hostel and room = p_room and status = 'sent';
  return v;
end $$;

revoke execute on function public.in_outline(jsonb, double precision, double precision) from public, anon, authenticated;
revoke execute on function public.request_shape(uuid, int, text, text, double precision, double precision, text[]), public.start_shape_request(uuid),
  public.send_shape_drawing(uuid, jsonb), public.cancel_shape_request(uuid) from public, anon;
grant execute on function public.request_shape(uuid, int, text, text, double precision, double precision, text[]), public.start_shape_request(uuid),
  public.send_shape_drawing(uuid, jsonb), public.cancel_shape_request(uuid) to authenticated;


-- ================================================================
-- 20261003020000_f24_wave1.sql
-- ================================================================
-- F24 Wave 1: electricity by meter, Trusted tenant on the server (level,
-- first pick of new free beds, "Trusted tenant" on hold requests) and photos
-- on Fair Play cases.
--   meter_readings                 one "Now" reading per room per month. Staff
--       save them with save_meter(hostel, month, ₹ per unit, rows); units since
--       last month are split between the residents in the room. Residents read
--       their own room's rows; staff their hostel's.
--   tenant_level(user) / my_level()  none | member | trusted, from the server:
--       Member (profiles.member) + 6 months in confirmed stays + no rent paid
--       more than 3 days after its due day.
--   holds.trusted                  set when the hold is placed; owners see it.
--   beds.freed_at                  when a bed turned free again (a resident left,
--       a booking ended). For 1 hour only Trusted tenants can hold it.
--   fair_cases.tenant_photo / owner_photo, bucket `case-photos`, case_photo():
--       the tenant's proof (attached by the team) and the owner's photo with
--       their reply. Private: the hostel's staff and the team.
-- The ₹ per unit is the owner's own number, not a Hostelzy amount.
-- Safe to run again.

-- ================================================================ electricity by meter

create table if not exists public.meter_readings (
  room_id uuid not null references public.rooms (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  reading int not null check (reading >= 0),
  rate numeric(6, 2) not null check (rate > 0 and rate <= 100),
  units int,                 -- since last month's reading (null: first reading)
  people int,                -- residents in the room when saved
  each_amt int,              -- ₹ each, rounded up
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  primary key (room_id, month)
);
alter table public.meter_readings enable row level security;
drop policy if exists "read meter readings" on public.meter_readings;
create policy "read meter readings" on public.meter_readings for select using (
  public.is_staff(hostel_id) or public.is_team()
  or exists (select 1 from public.stays s join public.beds b on b.id = s.bed_id
             where s.user_id = public.uid() and s.confirmed and s.left_on is null and b.room_id = meter_readings.room_id)
);
-- Writes go through save_meter only.

-- rows: [{"room": 204, "reading": 1940}, …] (room = the room's number).
create or replace function public.save_meter(p_hostel uuid, p_month date, p_rate numeric, p_rows jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare
  m date := date_trunc('month', p_month)::date;
  e jsonb; rm record; prev int; u int; ppl int; amt int; n int := 0; old_each int; hname text;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or managers add meter readings'; end if;
  if p_rate is null or p_rate <= 0 or p_rate > 100 then raise exception 'type the ₹ per unit'; end if;
  select name into hname from public.hostels where id = p_hostel;
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if (e ->> 'reading') is null then continue; end if;
    select id, coalesce(label, number::text) as label into rm from public.rooms where hostel_id = p_hostel and number = (e ->> 'room')::int;
    if rm.id is null then raise exception 'room % isn''t in this hostel', e ->> 'room'; end if;
    select reading into prev from public.meter_readings where room_id = rm.id and month < m order by month desc limit 1;
    if prev is not null and (e ->> 'reading')::int < prev then
      raise exception 'room %: the reading is lower than last month''s (%)', rm.label, prev;
    end if;
    u := case when prev is null then null else (e ->> 'reading')::int - prev end;
    select count(*) into ppl from public.stays s join public.beds b on b.id = s.bed_id where b.room_id = rm.id and s.left_on is null;
    amt := case when u is null or ppl = 0 then null else ceil(u * p_rate / ppl)::int end;
    select each_amt into old_each from public.meter_readings where room_id = rm.id and month = m;
    insert into public.meter_readings (room_id, hostel_id, month, reading, rate, units, people, each_amt)
    values (rm.id, p_hostel, m, (e ->> 'reading')::int, p_rate, u, ppl, amt)
    on conflict (room_id, month) do update set reading = excluded.reading, rate = excluded.rate, units = excluded.units,
      people = excluded.people, each_amt = excluded.each_amt, created_by = public.uid(), created_at = now();
    -- The room's residents hear about a new or changed amount.
    if amt is not null and amt is distinct from old_each then
      insert into public.push_outbox (user_id, title, body, data)
      select s.user_id, 'Electricity for ' || to_char(m, 'FMMonth') || ': ₹' || amt,
        u || ' units ÷ ' || ppl || ' · ₹' || trim(to_char(p_rate, 'FM999990.##')) || '/unit. It’s on your rent in Hostelzy.', '{"screen":"rPay"}'::jsonb
      from public.stays s join public.beds b on b.id = s.bed_id
      where b.room_id = rm.id and s.left_on is null and s.user_id is not null and s.confirmed;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke execute on function public.save_meter(uuid, date, numeric, jsonb) from public, anon;
grant execute on function public.save_meter(uuid, date, numeric, jsonb) to authenticated;

-- ================================================================ Trusted tenant on the server

-- Rent paid on time: a confirmed rent payment counts as late when it was made
-- more than 3 days after that month's due day (the joining day, or the 1st).
create or replace function public.tenant_level(u text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare mem boolean; days int; late int; lv text;
begin
  select coalesce(p.member, false) into mem from public.profiles p where p.id = u;
  select coalesce(sum(greatest(0, coalesce(s.left_on, (now() at time zone 'Asia/Kolkata')::date) - s.joined_on)), 0) into days
  from public.stays s where s.user_id = u and s.confirmed;
  select count(distinct date_trunc('month', p.created_at)) into late
  from public.payments p join public.stays s on s.id = p.stay_id join public.hostels h on h.id = p.hostel_id
  where p.payer_id = u and p.kind = 'rent' and p.status = 'paid'
    and (p.created_at at time zone 'Asia/Kolkata')::date > make_date(
      extract(year from p.created_at at time zone 'Asia/Kolkata')::int,
      extract(month from p.created_at at time zone 'Asia/Kolkata')::int,
      case when coalesce((h.terms ->> 'dueOnJoining')::boolean, true) then least(extract(day from s.joined_on)::int, 28) else 1 end) + 3;
  lv := case when not coalesce(mem, false) then 'none' when days / 30 >= 6 and late = 0 then 'trusted' else 'member' end;
  return jsonb_build_object('level', lv, 'months', days / 30, 'late', late);
end $$;

create or replace function public.my_level() returns jsonb
language sql stable security definer set search_path = ''
as $$ select public.tenant_level(public.uid()) $$;

revoke execute on function public.tenant_level(text) from public, anon, authenticated;
revoke execute on function public.my_level() from public, anon;
grant execute on function public.my_level() to authenticated;

alter table public.holds add column if not exists trusted boolean not null default false;
alter table public.beds add column if not exists freed_at timestamptz;

-- A bed turns free again (someone moved out, a booking ended): note when.
-- A hold that ends (held → free) doesn't count: that bed was already out there.
create or replace function public.bed_freed() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.state = 'free' and old.state in ('soon', 'booked') then new.freed_at := now(); end if;
  return new;
end $$;
drop trigger if exists bed_freed on public.beds;
create trigger bed_freed before update of state on public.beds for each row execute function public.bed_freed();

-- A new hold: the owner sees "Trusted tenant"; for its first hour a bed that
-- just turned free is for Trusted tenants only.
create or replace function public.hold_level() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare fa timestamptz;
begin
  new.trusted := public.tenant_level(new.tenant_id) ->> 'level' = 'trusted';
  select freed_at into fa from public.beds where id = new.bed_id;
  if not new.trusted and fa is not null and fa > now() - interval '1 hour' then
    raise exception 'Trusted tenants get the first hour on this bed. It opens to you at %',
      lower(to_char((fa + interval '1 hour') at time zone 'Asia/Kolkata', 'FMHH12:MI am'));
  end if;
  return new;
end $$;
drop trigger if exists hold_level on public.holds;
create trigger hold_level before insert on public.holds for each row execute function public.hold_level();

-- ================================================================ Fair Play case photos

alter table public.fair_cases add column if not exists tenant_photo text;
alter table public.fair_cases add column if not exists owner_photo text;

insert into storage.buckets (id, name, public) values ('case-photos', 'case-photos', false) on conflict (id) do nothing;

-- Path `<hostel_id>/<user id>/<name>.jpg` (the same shape as complaint photos).
drop policy if exists "hz upload case photos" on storage.objects;
create policy "hz upload case photos" on storage.objects for insert
  with check (bucket_id = 'case-photos' and split_part(name, '/', 2) = public.uid()
    and (public.is_staff(public.complaint_photo_hostel(name)) or public.is_team()));
drop policy if exists "hz read case photos" on storage.objects;
create policy "hz read case photos" on storage.objects for select
  using (bucket_id = 'case-photos' and (split_part(name, '/', 2) = public.uid() or public.is_team()
    or (public.is_staff(public.complaint_photo_hostel(name))
        and exists (select 1 from public.fair_cases c where c.hostel_id = public.complaint_photo_hostel(name) and (c.tenant_photo = name or c.owner_photo = name)))));

-- The owner adds a photo to their reply, while the case is open.
create or replace function public.case_photo(p_case uuid, p_path text) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record;
begin
  select * into c from public.fair_cases where id = p_case;
  if c.id is null then raise exception 'that case isn''t there any more'; end if;
  if not (public.is_staff(c.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers reply'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is already closed'; end if;
  if public.complaint_photo_hostel(p_path) is distinct from c.hostel_id or split_part(p_path, '/', 2) <> public.uid() or p_path !~ '^[^/]+/[^/]+/[^/]+\.jpg$' then
    raise exception 'the photo must be your own, for this hostel';
  end if;
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set owner_photo = p_path where id = p_case;
  perform set_config('hz.fixing', 'off', true);
end $$;

revoke execute on function public.case_photo(uuid, text) from public, anon;
grant execute on function public.case_photo(uuid, text) to authenticated;


-- ================================================================
-- 20261003030000_f24_item_working.sql
-- ================================================================
-- F24 item 7: Working / Not working on the server.
--   set_item_working(hostel, room, item, working) → the complaint's date (or null)
--       The hostel's staff or the team mark a fan, the AC or a window in a
--       room's layout. Both copies of the layout change (the draft and what
--       tenants see), so tenants see "Fan · not working" / "AC under repair"
--       straight away. The AC also sets rooms.ac_repair and the day it broke
--       (rooms.ac_repair_since), for "Complaint raised <date>".
--       Not working raises one complaint for the hostel (complaints.item says
--       which thing); working again closes it as Fixed.
--   Things on a floor or in rooms (F23 amenities: geyser, fridge…) do the
--   same through a trigger, whoever marks them in save_amenity.
-- Runs after 20261002233500_f24_values.sql. Safe to run again.

alter table public.rooms add column if not exists ac_repair_since date;
alter table public.complaints add column if not exists item text;
create index if not exists complaints_item on public.complaints (hostel_id, item) where item is not null;

-- Opens the item's complaint (once) or closes it. [p_key] names the thing,
-- e.g. 'layout:204:ac1' or 'amenity:<id>'. Returns when the open one was raised.
create or replace function public.item_complaint(p_hostel uuid, p_key text, p_working boolean, p_cat text, p_body text, p_bed text)
returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare at timestamptz;
begin
  if p_working then
    update public.complaints set status = 'Fixed', note = 'Working again'
    where hostel_id = p_hostel and item = p_key and status <> 'Fixed';
    return null;
  end if;
  select c.created_at into at from public.complaints c
  where c.hostel_id = p_hostel and c.item = p_key and c.status <> 'Fixed' order by c.created_at desc limit 1;
  if at is null then
    -- Whoever marked it already knows; the owner hears about a resident's
    -- mark from save_amenity. No second "New complaint" push (push_filter, 4zz3).
    perform set_config('hz.item_complaint', 'on', true);
    insert into public.complaints (hostel_id, author_id, bed, cat, body, item)
    values (p_hostel, coalesce(public.uid(), 'hostelzy'), coalesce(p_bed, ''), p_cat, p_body, p_key)
    returning created_at into at;
    perform set_config('hz.item_complaint', 'off', true);
  end if;
  return at;
end $$;

create or replace function public.set_item_working(p_hostel uuid, p_room int, p_item text, p_working boolean)
returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare
  kind text;
  label text;
  thing text;
  day text := to_char((now() at time zone 'Asia/Kolkata')::date, 'YYYY-MM-DD');
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or manager can change this'; end if;
  select coalesce(r.label, r.number::text) into label from public.rooms r where r.hostel_id = p_hostel and r.number = p_room;
  if label is null then raise exception 'room % isn''t in this hostel', p_room; end if;
  select e ->> 'kind' into kind
  from public.layouts l, jsonb_array_elements(l.items) e
  where l.hostel_id = p_hostel and l.room = p_room and e ->> 'id' = p_item
  limit 1;
  if kind is null then raise exception 'publish this room''s layout first, then mark it'; end if;
  if kind not in ('fan', 'ac', 'window') then raise exception 'only fans, the AC and windows have Working / Not working'; end if;
  update public.layouts l set items = (
    select coalesce(jsonb_agg(case when e ->> 'id' = p_item
      then case when p_working then (e - 'down_since') || '{"working": true}'
                else e || jsonb_build_object('working', false, 'down_since', coalesce(e ->> 'down_since', day)) end
      else e end order by n), '[]'::jsonb)
    from jsonb_array_elements(l.items) with ordinality as x(e, n))
  where l.hostel_id = p_hostel and l.room = p_room;
  thing := case kind when 'ac' then 'AC unit' when 'fan' then 'Fan ' || coalesce(nullif(substr(p_item, 4), ''), '') else 'Window' end;
  if kind = 'ac' then
    update public.rooms set ac_repair = not p_working,
      ac_repair_since = case when p_working then null else coalesce(ac_repair_since, (now() at time zone 'Asia/Kolkata')::date) end
    where hostel_id = p_hostel and number = p_room;
  end if;
  return public.item_complaint(p_hostel, 'layout:' || p_room || ':' || p_item, p_working,
    case kind when 'ac' then 'AC' when 'fan' then 'Fan' else 'Window' end,
    btrim(thing) || ' in room ' || label || ' marked not working.', 'Room ' || label);
end $$;

-- F23 things: marking one not working (by anyone allowed to) raises the
-- complaint; working again closes it.
create or replace function public.amenity_complaint() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.working then return new; end if;
  if tg_op = 'UPDATE' and new.working = old.working then return new; end if;
  perform public.item_complaint(new.hostel_id, 'amenity:' || new.id, new.working,
    case new.kind when 'fridge' then 'Fridge' when 'washer' then 'Washing machine' when 'ro' then 'Water'
      when 'cooler' then 'Water' when 'geyser' then 'Geyser' when 'wifi' then 'Wi-Fi' when 'lift' then 'Lift'
      else 'Other' end,
    public.amenity_what(new) || ' marked not working.',
    case when new.place = 'floor' then 'Floor ' || new.floor else 'Room ' || new.rooms[1] end);
  return new;
end $$;

drop trigger if exists amenity_complaint on public.amenities;
create trigger amenity_complaint after insert or update of working on public.amenities
for each row execute function public.amenity_complaint();

revoke execute on function public.item_complaint(uuid, text, boolean, text, text, text), public.amenity_complaint() from public, anon, authenticated;
revoke execute on function public.set_item_working(uuid, int, text, boolean) from public, anon;
grant execute on function public.set_item_working(uuid, int, text, boolean) to authenticated;


-- ================================================================
-- 20261003031000_f24_walk_in.sql
-- ================================================================
-- F24 item 8: "Hold for a walk-in" on the server.
--   hold_walk_in(bed) → when it ends
--       The hostel's staff (or the team) keep a free (or free-soon) bed for
--       someone who walked in. The bed shows as held to every tenant, so
--       nobody can hold it on Hostelzy meanwhile. Like a free hold it ends
--       after 1 hour (DECISIONS F04) and the bed goes back to what it was.
--   release_walk_in(bed)  the same people end it early.
--   expire_walk_ins()     the server ends them; every minute with pg_cron,
--       and also whenever anyone holds a walk-in bed.
-- Runs after 20261003030000_f24_item_working.sql. Safe to run again.

alter table public.beds add column if not exists walk_in_until timestamptz;
alter table public.beds add column if not exists walk_in_before text;

create or replace function public.expire_walk_ins() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.beds set state = coalesce(walk_in_before, 'free'), walk_in_until = null, walk_in_before = null
  where walk_in_until is not null and walk_in_until <= now() and state = 'held';
  get diagnostics n = row_count;
  -- A bed that changed some other way keeps its state; just forget the walk-in.
  update public.beds set walk_in_until = null, walk_in_before = null
  where walk_in_until is not null and (walk_in_until <= now() or state <> 'held');
  return n;
end $$;

create or replace function public.hold_walk_in(p_bed uuid) returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare b record; until timestamptz := now() + interval '1 hour';
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  select x.id, x.hostel_id, x.state into b from public.beds x where x.id = p_bed;
  if b.id is null then raise exception 'that bed isn''t on Hostelzy'; end if;
  if not (public.is_staff(b.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or manager can hold a bed for a walk-in'; end if;
  perform public.expire_walk_ins();
  update public.beds set state = 'held', walk_in_before = state, walk_in_until = until
  where id = p_bed and state in ('free', 'soon')
    and not exists (select 1 from public.holds h where h.bed_id = p_bed and h.status in ('waiting', 'held'));
  if not found then raise exception 'that bed isn''t free any more'; end if;
  return until;
end $$;

create or replace function public.release_walk_in(p_bed uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare b record;
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  select x.id, x.hostel_id, x.walk_in_until into b from public.beds x where x.id = p_bed;
  if b.id is null then raise exception 'that bed isn''t on Hostelzy'; end if;
  if not (public.is_staff(b.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or manager can release it'; end if;
  update public.beds set state = coalesce(walk_in_before, 'free'), walk_in_until = null, walk_in_before = null
  where id = p_bed and walk_in_until is not null and state = 'held';
end $$;

revoke execute on function public.expire_walk_ins() from public, anon, authenticated;
revoke execute on function public.hold_walk_in(uuid), public.release_walk_in(uuid) from public, anon;
grant execute on function public.hold_walk_in(uuid), public.release_walk_in(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-expire-walk-ins', '* * * * *', 'select public.expire_walk_ins()');
  end if;
end $$;


-- ================================================================
-- 20261003032000_f24_notify_switches.sql
-- ================================================================
-- F24 item 22: the Settings switches are kept on the profile and the server
-- honours them, plus "New free beds" alerts.
--   profiles.notify          {"hold": true, "rent": true, "beds": false}; the
--       user's own (Settings → Notifications).
--   profiles.searched_areas  the last areas the tenant picked in Where? (≤ 5).
--   push_outbox.kind         hold | rent | beds, or null for everything else
--       (always sent). Set by every queued push: from data.kind, or worked
--       out from where the push opens. A push of a kind the user switched off
--       is closed at once ("switched off"), never sent. Nobody gets a push
--       about something they did themselves.
--   New free beds: when a bed in a live hostel turns free, tenants with the
--       switch on who searched that area get one push, at most one a day each
--       (profiles.beds_alert_at). Never the hostel's own staff or residents.
-- send-push checks the switch again before sending (a switch turned off
-- after a push was queued). Runs after 20261003031000_f24_walk_in.sql. Safe to run again.

alter table public.profiles add column if not exists notify jsonb not null default '{"hold": true, "rent": true, "beds": false}';
alter table public.profiles add column if not exists searched_areas text[] not null default '{}';
alter table public.profiles add column if not exists beds_alert_at timestamptz;
alter table public.profiles drop constraint if exists profiles_notify;
alter table public.profiles add constraint profiles_notify check (jsonb_typeof(notify) = 'object');
alter table public.profiles drop constraint if exists profiles_searched_areas;
alter table public.profiles add constraint profiles_searched_areas check (cardinality(searched_areas) <= 5);

alter table public.push_outbox add column if not exists kind text;

-- The user's switch for [p_kind]; on unless they turned it off ("beds" is off unless turned on).
create or replace function public.wants_push(p_user text, p_kind text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select case when p_kind is null then true
    else coalesce((select (p.notify ->> p_kind)::boolean from public.profiles p where p.id = p_user), p_kind <> 'beds') end
$$;

create or replace function public.push_filter() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Never about your own action (the owner's own walk-in, their own repair…).
  if public.uid() is not null and new.user_id = public.uid() then return null; end if;
  -- A complaint raised by marking a thing not working (4zz1) isn't pushed again.
  if current_setting('hz.item_complaint', true) = 'on' and new.title like 'New complaint:%' then return null; end if;
  new.kind := coalesce(new.kind, new.data ->> 'kind', case
    when new.data ->> 'screen' in ('holds', 'hold') then 'hold'
    when new.title like 'New hold on bed%' then 'hold'
    when new.data ->> 'screen' = 'rPay' then 'rent'
  end);
  if new.kind not in ('hold', 'rent', 'beds') then new.kind := null; end if;
  if not public.wants_push(new.user_id, new.kind) then
    new.sent_at := now();
    new.error := 'switched off';
  end if;
  return new;
end $$;

drop trigger if exists push_filter on public.push_outbox;
create trigger push_filter before insert on public.push_outbox
for each row execute function public.push_filter();

-- "New free beds": a bed turned free in a live hostel.
create or replace function public.free_bed_alert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare h record; label text;
begin
  if new.state <> 'free' or (tg_op = 'UPDATE' and old.state = 'free') then return new; end if;
  select x.id, x.name, x.area into h from public.hostels x where x.id = new.hostel_id and x.status = 'live';
  if h.id is null then return new; end if;
  select coalesce(r.label, r.number::text) || '-' || new.letter into label from public.rooms r where r.id = new.room_id;
  with picked as (
    update public.profiles p set beds_alert_at = now()
    where coalesce((p.notify ->> 'beds')::boolean, false)
      and h.area = any (p.searched_areas)
      and (p.beds_alert_at is null or p.beds_alert_at <= now() - interval '1 day')
      and not exists (select 1 from public.hostel_staff s where s.hostel_id = h.id and s.user_id = p.id)
      and not exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = p.id and s.left_on is null)
    returning p.id
  )
  insert into public.push_outbox (user_id, title, body, data, kind)
  select picked.id, 'A bed is free in ' || h.area,
    h.name || ': bed ' || coalesce(label, new.letter) || ' is free now. Hold it free for 1 hour on Hostelzy.',
    jsonb_build_object('screen', 'detail', 'hostel', h.id, 'kind', 'beds'), 'beds'
  from picked;
  return new;
end $$;

drop trigger if exists free_bed_alert on public.beds;
create trigger free_bed_alert after insert or update of state on public.beds
for each row execute function public.free_bed_alert();

revoke execute on function public.push_filter(), public.free_bed_alert(), public.wants_push(text, text) from public, anon, authenticated;


-- ================================================================
-- 20261003033000_f24_team.sql
-- ================================================================
-- F24 item 29: the app's team mode reads real rows.
--   team_members            the Hostelzy team, as the app's Team members list
--       shows it. A team account appears (Active) the first time it opens
--       team tools (team_hello). "Send invite" in the app adds a pending row
--       by name and number; it turns Active when that person, signed in with
--       the same number, opens team tools. Who is on the team is still the
--       Firebase `team` claim (GitHub → Actions → Team member); this table
--       never gives access.
--   team_tracker()          one row per hostel for the onboarding tracker:
--       its stage (hostel_leads.stage, then live / trial / paying from the
--       hostel and its plan), the next step, and when the trial ends.
-- Team only. Runs after 20261003032000_f24_notify_switches.sql. Safe to run again.

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  user_id text unique,
  name text not null default '',
  phone text not null default '',
  email text not null default '',
  role text not null default 'Everything' check (role in ('Everything', 'Visits', 'Layouts', 'Payments')),
  joined_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.team_members enable row level security;
drop policy if exists "team only" on public.team_members;
create policy "team only" on public.team_members for all using (public.is_team()) with check (public.is_team());

-- The signed-in team account says hello: its row is made (or a pending
-- invite with its number is matched) and marked Active.
create or replace function public.team_hello() returns void
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); p record; inv uuid;
begin
  if me is null or not public.is_team() then raise exception 'for the Hostelzy team only'; end if;
  select x.name, x.email, right(regexp_replace(coalesce(x.phone, ''), '\D', '', 'g'), 10) as phone into p from public.profiles x where x.id = me;
  if exists (select 1 from public.team_members t where t.user_id = me) then
    update public.team_members set joined_at = coalesce(joined_at, now()),
      name = case when name = '' then coalesce(p.name, '') else name end,
      email = coalesce(nullif(p.email, ''), email),
      phone = case when phone = '' then coalesce(p.phone, '') else phone end
    where user_id = me;
    return;
  end if;
  select t.id into inv from public.team_members t
  where t.user_id is null and t.phone <> '' and t.phone = coalesce(p.phone, '') order by t.created_at limit 1;
  if inv is not null then
    update public.team_members set user_id = me, joined_at = now(), email = coalesce(p.email, '') where id = inv;
  else
    insert into public.team_members (user_id, name, phone, email, joined_at)
    values (me, coalesce(p.name, ''), coalesce(p.phone, ''), coalesce(p.email, ''), now());
  end if;
end $$;

create or replace function public.team_tracker()
returns table (hostel_id uuid, name text, area text, stage int, next_step text, trial_ends date)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'for the Hostelzy team only'; end if;
  return query
  select h.id, h.name, h.area,
    case
      when h.status = 'live' and o.status in ('active', 'overdue', 'paused') then 6
      when h.status = 'live' and o.hostel_id is not null then 5
      when h.status = 'live' then 4
      else case coalesce(l.stage, 'lead') when 'visited' then 1 when 'signed_up' then 2 when 'data_complete' then 3 else 0 end
    end,
    coalesce(l.next_step, ''),
    o.trial_ends
  from public.hostels h
  left join public.hostel_leads l on l.hostel_id = h.id
  left join public.owner_plans o on o.hostel_id = h.id
  order by h.created_at;
end $$;

revoke execute on function public.team_hello(), public.team_tracker() from public, anon;
grant execute on function public.team_hello(), public.team_tracker() to authenticated;


-- ================================================================
-- 20261003040000_f24_confirm_beds.sql
-- ================================================================
-- F24 item 9: "Still N free beds?" and "Do your room layouts still match?"
-- saved on the server, with a push to staff who haven't confirmed.
--   beds.confirmed_at      the owner's "Yes, all free" (the app writes it for
--       every bed of the hostel; tenants read the newest one as "confirmed by
--       the owner X days ago"). Only the server's clock counts: whatever the
--       app sends, the time stored is now().
--   confirm_layouts(p_hostel)     the owner's "All still correct": every published
--       layout of the hostel gets confirmed_at = now() (staff or team).
--   nudge_confirmations()  daily (pg_cron): a push to the hostel's owner and
--       managers when the free beds weren't confirmed for 3 days (at most one
--       every 3 days), and when a layout wasn't confirmed for 90 days (at most
--       one every 30 days).
-- Safe to run again.

-- ---------------------------------------------------------------- beds

create or replace function public.guard_bed_confirm() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if new.confirmed_at is distinct from old.confirmed_at then
    -- A confirmation is "now", never a date the phone picks; it can't be cleared.
    new.confirmed_at := case when new.confirmed_at is null then old.confirmed_at else now() end;
  end if;
  return new;
end $$;

drop trigger if exists guard_bed_confirm on public.beds;
create trigger guard_bed_confirm before update of confirmed_at on public.beds
for each row execute function public.guard_bed_confirm();
revoke execute on function public.guard_bed_confirm() from public, anon, authenticated;

-- ---------------------------------------------------------------- layouts

create or replace function public.confirm_layouts(p_hostel uuid) returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or managers confirm its layouts'; end if;
  update public.layouts set confirmed_at = now() where hostel_id = p_hostel and stage = 'published';
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.confirm_layouts(uuid) from public, anon;
grant execute on function public.confirm_layouts(uuid) to authenticated;

-- ---------------------------------------------------------------- reminders

create table if not exists public.hostel_nudges (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  kind text not null check (kind in ('beds', 'layouts')),
  sent_at timestamptz not null default now(),
  primary key (hostel_id, kind)
);
alter table public.hostel_nudges enable row level security;
-- No policies: only the daily job uses it.
revoke all on table public.hostel_nudges from public, anon, authenticated;

create or replace function public.nudge_confirmations() returns int
language plpgsql security definer set search_path = ''
as $$
declare r record; n int := 0;
begin
  for r in
    select h.id, h.name,
      (select count(*)::int from public.beds b where b.hostel_id = h.id and b.state = 'free') as free,
      (select max(b.confirmed_at) from public.beds b where b.hostel_id = h.id) as beds_at,
      (select min(coalesce(l.confirmed_at, l.updated_at)) from public.layouts l where l.hostel_id = h.id and l.stage = 'published') as layouts_at
    from public.hostels h
    where h.status = 'live' and exists (select 1 from public.beds b where b.hostel_id = h.id)
  loop
    -- Every 3 days (a little slack for the job's start time).
    if (r.beds_at is null or r.beds_at < now() - interval '3 days')
       and not exists (select 1 from public.hostel_nudges x where x.hostel_id = r.id and x.kind = 'beds' and x.sent_at > now() - interval '71 hours') then
      perform public.notify_staff(r.id,
        'Still ' || r.free || ' free ' || case when r.free = 1 then 'bed' else 'beds' end || '?',
        'Confirm the free beds at ' || r.name || ' in Today. Fresh beds rank higher.',
        '{"screen":"oToday"}');
      insert into public.hostel_nudges (hostel_id, kind, sent_at) values (r.id, 'beds', now())
      on conflict (hostel_id, kind) do update set sent_at = now();
      n := n + 1;
    end if;
    if r.layouts_at is not null and r.layouts_at < now() - interval '90 days'
       and not exists (select 1 from public.hostel_nudges x where x.hostel_id = r.id and x.kind = 'layouts' and x.sent_at > now() - interval '30 days') then
      perform public.notify_staff(r.id, 'Do your room layouts still match?',
        'It''s been 3 months. Check that beds, fans, AC and windows at ' || r.name || ' are where the layouts show them.',
        '{"screen":"oToday"}');
      insert into public.hostel_nudges (hostel_id, kind, sent_at) values (r.id, 'layouts', now())
      on conflict (hostel_id, kind) do update set sent_at = now();
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

revoke execute on function public.nudge_confirmations() from public, anon, authenticated;

-- Daily at 10:00 India time (04:30 UTC), where pg_cron is on (it is, since B5).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-confirm-nudge', '30 4 * * *', 'select public.nudge_confirmations()');
  end if;
end $$;


-- ================================================================
-- 20261003041000_f24_locked_deal.sql
-- ================================================================
-- F24 item 13: "Your price is fixed". The deal a tenant books with is kept on
-- the server, so the owner and the tenant both see what was promised.
--   holds.deal   set by the server when a booking (advance hold) is placed:
--       {"on": [deal ids], "fee": monthly rent, "advance", "maintenance",
--        "notice"} from the hostel's rate card, terms and deals at that moment.
--       Deals don't apply when the hostel has 2+ strikes, when its plan is
--       overdue or paused, or when they cover the other room type. The app
--       turns it into the perks ("₹7,800 monthly · ₹2,000 advance · …").
--   stays.deal   copied from the tenant's booked hold at that hostel (60 days
--       before joining), so the owner's resident list and bed sheet show it.
-- Nobody can write either column from the app; only the team can correct one.
-- Safe to run again.

alter table public.holds add column if not exists deal jsonb;
alter table public.stays add column if not exists deal jsonb;

-- ---------------------------------------------------------------- the deal at booking time

create or replace function public.deal_for_bed(p_hostel uuid, p_bed uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  rm record;
  fee int;
  t jsonb;
  d record;
  paused boolean;
  on_ids text[] := '{}';
begin
  select r.ac, r.share, r.rent into rm from public.beds b join public.rooms r on r.id = b.room_id where b.id = p_bed and b.hostel_id = p_hostel;
  if not found then return null; end if;
  select c.rent into fee from public.rate_cards c where c.hostel_id = p_hostel and c.ac = rm.ac and c.share = rm.share;
  select coalesce(h.terms, '{}'::jsonb) into t from public.hostels h where h.id = p_hostel;
  select x.deals_on, x.target into d from public.deals x where x.hostel_id = p_hostel;
  paused := (select count(*) from public.strikes s where s.hostel_id = p_hostel) >= 2
    or exists (select 1 from public.owner_plans o where o.hostel_id = p_hostel and o.status in ('overdue', 'paused'));
  if d is not null and not paused and coalesce(array_length(d.deals_on, 1), 0) > 0
     and (coalesce(d.target, '') in ('', 'all') or (d.target = 'ac') = rm.ac) then
    on_ids := d.deals_on;
  end if;
  return jsonb_build_object(
    'on', to_jsonb(on_ids),
    'fee', coalesce(fee, rm.rent),
    'advance', coalesce((t ->> 'advance')::int, 3000),
    'maintenance', coalesce((t ->> 'maintenance')::int, 1000),
    'notice', coalesce((t ->> 'noticeDays')::int, 30),
    'at', now());
end $$;

revoke execute on function public.deal_for_bed(uuid, uuid) from public, anon, authenticated;

-- Bookings lock the deal; free holds don't carry one. The app never sets it.
create or replace function public.hold_deal() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.deal := case when new.opt = 'advance' then public.deal_for_bed(new.hostel_id, new.bed_id) end;
  elsif not (public.is_team() or public.is_server()) then
    new.deal := old.deal;
  end if;
  return new;
end $$;

drop trigger if exists hold_deal on public.holds;
create trigger hold_deal before insert or update on public.holds
for each row execute function public.hold_deal();
revoke execute on function public.hold_deal() from public, anon, authenticated;

-- ---------------------------------------------------------------- the stay keeps it

create or replace function public.stay_deal() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and not (public.is_team() or public.is_server()) then
    new.deal := old.deal;
  elsif tg_op = 'INSERT' and not (public.is_team() or public.is_server()) then
    new.deal := null;
  end if;
  if new.deal is null and (tg_op = 'INSERT' or new.user_id is distinct from old.user_id) then
    select x.deal into new.deal
    from public.holds x left join public.profiles p on p.id = x.tenant_id
    where x.hostel_id = new.hostel_id and x.status = 'booked' and x.deal is not null
      and ((length(new.phone) = 10 and p.phone = new.phone) or (new.user_id is not null and x.tenant_id = new.user_id))
      and x.started_at >= new.joined_on - interval '60 days' and x.started_at < new.joined_on + interval '2 days'
    order by x.started_at desc
    limit 1;
  end if;
  return new;
end $$;

drop trigger if exists stay_deal on public.stays;
create trigger stay_deal before insert or update on public.stays
for each row execute function public.stay_deal();
revoke execute on function public.stay_deal() from public, anon, authenticated;


-- ================================================================
-- 20261003042000_f24_did_you_join.sql
-- ================================================================
-- F24 item 14: "Did you join?" saved as a Fair Play signal.
-- After a hold ends the tenant answers Yes / Not yet / Still deciding.
--   join_answers   one answer per ended hold; the tenant may change it.
--       Written only through answer_joined(hold, answer), for the tenant's own
--       released or expired hold. Read by the Hostelzy team (console Fair Play,
--       next to the hostel's cases and reports) and by the tenant who wrote it
--       (so the app doesn't ask again). Owners and managers never see it.
-- Safe to run again.

create table if not exists public.join_answers (
  hold_id uuid primary key references public.holds (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  tenant_id text not null,
  answer text not null check (answer in ('yes', 'not_yet', 'deciding')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists join_answers_hostel on public.join_answers (hostel_id, updated_at desc);

alter table public.join_answers enable row level security;
drop policy if exists "team and own read join answers" on public.join_answers;
create policy "team and own read join answers" on public.join_answers for select
  using (public.is_team() or tenant_id = public.uid());
revoke all on table public.join_answers from public, anon, authenticated;
grant select on table public.join_answers to authenticated;

create or replace function public.answer_joined(p_hold uuid, p_answer text) returns void
language plpgsql security definer set search_path = ''
as $$
declare x record;
begin
  if p_answer not in ('yes', 'not_yet', 'deciding') then raise exception 'answer yes, not yet or still deciding'; end if;
  select h.hostel_id, h.tenant_id, h.status into x from public.holds h where h.id = p_hold;
  if not found or x.tenant_id is distinct from public.uid() then raise exception 'only the tenant of this hold answers'; end if;
  if x.status not in ('released', 'expired') then raise exception 'ask after the hold ends'; end if;
  insert into public.join_answers (hold_id, hostel_id, tenant_id, answer) values (p_hold, x.hostel_id, x.tenant_id, p_answer)
  on conflict (hold_id) do update set answer = excluded.answer, updated_at = now();
end $$;

revoke execute on function public.answer_joined(uuid, text) from public, anon;
grant execute on function public.answer_joined(uuid, text) to authenticated;

-- Account deletion detaches holds (tenant_id → 'deleted'); the answers follow.
create or replace function public.join_answers_follow() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.join_answers set tenant_id = new.tenant_id where hold_id = new.id;
  return new;
end $$;

drop trigger if exists join_answers_follow on public.holds;
create trigger join_answers_follow after update of tenant_id on public.holds
for each row when (new.tenant_id is distinct from old.tenant_id) execute function public.join_answers_follow();
revoke execute on function public.join_answers_follow() from public, anon, authenticated;


-- ================================================================
-- 20261003050000_f24_server_rules.sql
-- ================================================================
-- F24 Wave 3a: server rules (items 17, 19, 20, 21).
--   17. Owner-only areas (DECISIONS F14): the plan and its invoices, Hostelzy
--       credits, deals, rates (the rate card and a room's rent / AC) and Fair
--       Play cases and strikes belong to the owner. Managers keep beds,
--       residents, enquiries, complaints, menus and layouts.
--         rate_cards, deals      only the owner (or the team) writes.
--         rooms                  a manager can't change a room's rent or AC.
--         owner_plans, invoices, fair_cases, strikes, owner credits in
--         reward_ledger          only the owner (and the team) reads.
--         fair_cases             only the owner replies or fixes (also inside
--                                fix_case, by a trigger).
--   19. An AC room needs an AC unit in its layout (DECISIONS 2026-10-02):
--       also when a room becomes AC (Manage → Rates, Rooms and floors), not
--       only when its layout is published. A room whose published layout has
--       no AC unit can't be made AC; a room with no layout yet can.
--   20. Ranking (DECISIONS F10, F08):
--         hostel_flags() → per live hostel: beds, featured (80+ beds plan:
--             more than 80 beds, the ₹1,499 tier, while the plan isn't 15+
--             days late), deals_paused.
--         hostel_signals().complaints_30d counts only residents' complaints:
--             not the owner's, a manager's or the team's own "Not working"
--             marks (4zz1), nor anything the hostel's staff raised.
--   21. Deals pause while the owner's plan is 15+ days late (DECISIONS F10):
--         deals_paused(h) — an unpaid invoice 15+ days past its due day.
--         Tenants can't read the deals row then (walk-in prices only); the
--         owner and managers still can. hostel_flags() says so to everyone.
--       Pushes (push_outbox; data.kind so the Settings switches apply):
--         new invoice → the owner ("plan", always sent);
--         money_pushes() daily 9 am IST (pg_cron): plan 5 days late → the
--             owner; 15 days late → "deals paused" → the owner; rent due today
--             (the hostel's terms: the joining date, or the 1st) → each
--             resident on the app ("rent", their Rent switch).
-- Runs after 20261003042000_f24_did_you_join.sql (and 20261003020000_f24_wave1.sql, case photos). Safe to run again.

-- ================================================================ 17. owner-only areas

drop policy if exists "staff write rates" on public.rate_cards;
drop policy if exists "owner writes rates" on public.rate_cards;
create policy "owner writes rates" on public.rate_cards for all
  using (public.is_owner(hostel_id) or public.is_team()) with check (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "staff write deals" on public.deals;
drop policy if exists "owner writes deals" on public.deals;
create policy "owner writes deals" on public.deals for all
  using (public.is_owner(hostel_id) or public.is_team()) with check (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read plan" on public.owner_plans;
create policy "read plan" on public.owner_plans for select using (public.is_owner(hostel_id) or public.is_team());
drop policy if exists "read invoices" on public.invoices;
create policy "read invoices" on public.invoices for select using (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read cases" on public.fair_cases;
create policy "read cases" on public.fair_cases for select using (public.is_owner(hostel_id) or public.is_team());
drop policy if exists "owner replies to case" on public.fair_cases;
create policy "owner replies to case" on public.fair_cases for update using (public.is_owner(hostel_id)) with check (public.is_owner(hostel_id));
drop policy if exists "read strikes" on public.strikes;
create policy "read strikes" on public.strikes for select using (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read own rewards" on public.reward_ledger;
create policy "read own rewards" on public.reward_ledger for select
  using (user_id = public.uid() or public.is_team()
    or (hostel_id is not null and (public.is_owner(hostel_id) or (kind <> 'owner_credit' and public.is_staff(hostel_id)))));

-- Fair Play case photos (20261003020000_f24_wave1.sql): the owner's too.
drop policy if exists "hz upload case photos" on storage.objects;
create policy "hz upload case photos" on storage.objects for insert
  with check (bucket_id = 'case-photos' and split_part(name, '/', 2) = public.uid()
    and (public.is_owner(public.complaint_photo_hostel(name)) or public.is_team()));
drop policy if exists "hz read case photos" on storage.objects;
create policy "hz read case photos" on storage.objects for select
  using (bucket_id = 'case-photos' and (split_part(name, '/', 2) = public.uid() or public.is_team()
    or (public.is_owner(public.complaint_photo_hostel(name))
        and exists (select 1 from public.fair_cases c where c.hostel_id = public.complaint_photo_hostel(name) and (c.tenant_photo = name or c.owner_photo = name)))));

-- fix_case() and case_photo() are security definer; this keeps a manager out of them too.
create or replace function public.owner_only_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() or public.is_owner(old.hostel_id) then return new; end if;
  raise exception 'only the owner handles Fair Play';
end $$;
drop trigger if exists owner_only_case on public.fair_cases;
create trigger owner_only_case before update on public.fair_cases
for each row execute function public.owner_only_case();

-- ================================================================ 17 + 19. rooms: rent, AC

create or replace function public.guard_room_rates() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and (new.rent is distinct from old.rent or new.ac is distinct from old.ac)
     and not (public.is_server() or public.is_team() or public.is_owner(new.hostel_id)) then
    raise exception 'only the owner changes rates and AC rooms';
  end if;
  if new.ac and (tg_op = 'INSERT' or not old.ac)
     and exists (select 1 from public.layouts l where l.hostel_id = new.hostel_id and l.room = new.number and l.stage = 'published')
     and not exists (select 1 from public.layouts l, jsonb_array_elements(l.items) i
                     where l.hostel_id = new.hostel_id and l.room = new.number and l.stage = 'published' and i ->> 'kind' = 'ac') then
    raise exception 'room %: an AC room needs an AC unit. Add it in the room''s layout and publish, then make it AC', coalesce(new.label, new.number::text);
  end if;
  return new;
end $$;
drop trigger if exists guard_room_rates on public.rooms;
create trigger guard_room_rates before insert or update of ac, rent on public.rooms
for each row execute function public.guard_room_rates();

-- ================================================================ 21. deals pause

-- An unpaid invoice 15+ days past its due day (India time).
create or replace function public.deals_paused(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.invoices i where i.hostel_id = h and i.status <> 'paid'
    and (now() at time zone 'Asia/Kolkata')::date - i.due >= 15)
$$;

drop policy if exists "read deals" on public.deals;
create policy "read deals" on public.deals for select
  using ((public.is_live(hostel_id) and not public.deals_paused(hostel_id)) or public.is_staff(hostel_id) or public.is_team());

-- ================================================================ 20. ranking

create or replace function public.hostel_flags() returns table (hostel_id uuid, beds int, featured boolean, deals_paused boolean)
language sql stable security definer set search_path = ''
as $$
  select x.id, x.beds,
    x.beds > 80 and coalesce(o.status, 'trial') in ('trial', 'active') and not x.paused,
    x.paused
  from (
    select h.id, (select count(*)::int from public.beds b where b.hostel_id = h.id) as beds, public.deals_paused(h.id) as paused
    from public.hostels h where h.status = 'live'
  ) x left join public.owner_plans o on o.hostel_id = x.id
$$;

-- Same as 20261002233500_f24_values.sql, but complaints_30d counts only
-- complaints from the hostel's residents (not the owner's own marks).
create or replace function public.hostel_signals() returns table (hostel_id uuid, reply_minutes int, reply_n int, complaints_30d int, residents int, photos int, rooms int, layouts int)
language sql stable security definer set search_path = ''
as $$
  with replies as (
    select e.hostel_id, extract(epoch from e.contacted_at - e.created_at) / 60 as m from public.enquiries e
    where e.contacted_at is not null and e.created_at > now() - interval '60 days'
    union all
    select x.hostel_id, extract(epoch from x.decided_at - x.started_at) / 60 from public.holds x
    where x.decided_at is not null and x.started_at > now() - interval '60 days' and x.status <> 'expired'
  ), speed as (
    select r.hostel_id, round(percentile_cont(0.5) within group (order by r.m))::int as minutes, count(*)::int as n from replies r group by r.hostel_id
  )
  select h.id,
    coalesce(sp.minutes, 0),
    coalesce(sp.n, 0),
    (select count(*)::int from public.complaints c where c.hostel_id = h.id and c.created_at > now() - interval '30 days'
       and not exists (select 1 from public.hostel_staff st where st.hostel_id = h.id and st.user_id = c.author_id)
       and (c.item is null or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = c.author_id))),
    (select count(*)::int from public.stays s where s.hostel_id = h.id and s.left_on is null),
    (select count(*)::int from public.hostel_photos p where p.hostel_id = h.id),
    (select count(*)::int from public.rooms r where r.hostel_id = h.id),
    (select count(*)::int from public.layouts l where l.hostel_id = h.id and l.stage = 'published')
  from public.hostels h left join speed sp on sp.hostel_id = h.id
  where h.status = 'live'
$$;

-- ================================================================ 21. pushes

alter table public.invoices add column if not exists pushed int[] not null default '{}';
alter table public.stays add column if not exists rent_reminded_on date;

create or replace function public.notify_owner(h uuid, t text, b text, d jsonb) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, t, b, d from public.hostel_staff s where s.hostel_id = h and s.role = 'owner'
$$;

create or replace function public.invoice_push() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.notify_owner(new.hostel_id, 'New Hostelzy invoice: ₹' || new.amount,
    new.ref || ' · due ' || to_char(new.due, 'FMDD Mon') || '. Pay by UPI from Manage › Your plan.',
    jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', new.ref));
  return new;
end $$;
drop trigger if exists invoice_push on public.invoices;
create trigger invoice_push after insert on public.invoices
for each row execute function public.invoice_push();

-- Daily, 9 am India time. Safe to run twice a day: each push goes once.
create or replace function public.money_pushes() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  i record;
  late int;
  n int := 0;
begin
  for i in select * from public.invoices where status in ('due', 'missing') and today - due >= 5 loop
    late := today - i.due;
    if late >= 15 and not (15 = any(i.pushed)) then
      perform public.notify_owner(i.hostel_id, 'Deals paused: plan ' || late || ' days late',
        'Tenants see walk-in prices only. Pay ₹' || i.amount || ' (' || i.ref || ') to switch your deals back on.',
        jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', i.ref));
      update public.invoices set pushed = pushed || array[5, 15] where id = i.id;
      n := n + 1;
    elsif late < 15 and not (5 = any(i.pushed)) then
      perform public.notify_owner(i.hostel_id, 'Your Hostelzy plan is ' || late || ' days late',
        'Pay ₹' || i.amount || ' by ' || to_char(i.due + 15, 'FMDD Mon') || ' to keep your deals showing.',
        jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', i.ref));
      update public.invoices set pushed = pushed || 5 where id = i.id;
      n := n + 1;
    end if;
  end loop;

  -- Rent due today: the joining date's day each month (the month's last day
  -- when it's shorter), or the 1st, by the hostel's terms. Not on the joining
  -- day itself, and not when this month's rent is already sent or paid.
  with due as (
    update public.stays s set rent_reminded_on = today
    from public.hostels h
    where h.id = s.hostel_id and s.user_id is not null and s.confirmed and s.left_on is null
      and s.joined_on < today and s.rent_reminded_on is distinct from today
      and extract(day from today)::int = case when coalesce((h.terms ->> 'dueOnJoining')::boolean, true)
        then least(extract(day from s.joined_on)::int, extract(day from (date_trunc('month', today) + interval '1 month - 1 day'))::int)
        else 1 end
      and not exists (select 1 from public.payments p where p.hostel_id = s.hostel_id and p.payer_id = s.user_id
        and p.kind = 'rent' and p.status in ('waiting', 'paid') and p.created_at > now() - interval '20 days')
    returning s.user_id, s.rent, h.name
  )
  insert into public.push_outbox (user_id, title, body, data)
  select d.user_id, 'Rent due today',
    case when d.rent > 0 then '₹' || d.rent || ' to ' || d.name || '. Pay by UPI from Pay rent.' else 'Your rent at ' || d.name || ' is due today. Pay by UPI from Pay rent.' end,
    jsonb_build_object('screen', 'rPay', 'kind', 'rent')
  from due d;
  get diagnostics late = row_count;
  return n + late;
end $$;

revoke execute on function public.owner_only_case(), public.guard_room_rates(), public.notify_owner(uuid, text, text, jsonb),
  public.invoice_push(), public.money_pushes() from public, anon, authenticated;
grant execute on function public.deals_paused(uuid), public.hostel_flags(), public.hostel_signals() to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-money-pushes', '25 3 * * *', 'select public.money_pushes()');
  end if;
end $$;


-- ================================================================
-- 20261003060000_f24_enquiries_reviews.sql
-- ================================================================
-- F24 Wave 4a (audit §3): enquiries and reviews on the server.
--   F05  one open enquiry per tenant + hostel + bed (asking again reuses the code)
--   F08  one review per stay (30-day and exit), the 30-day review opens after
--        30 days of a confirmed stay, the author can edit it, the owner replies
--        once, anyone can report a review for abuse and the team can hide it
--   F13 S4  "Is the room layout right? No" flags that room's layout
-- Safe to run again. Existing duplicate rows are kept, never deleted: older
-- duplicate enquiries are marked `dup_of`, older duplicate reviews are hidden.

-- ================================================================ F05 enquiries

alter table public.enquiries add column if not exists dup_of uuid references public.enquiries (id) on delete set null;

-- Duplicates from before: the newest open one stays open, older ones point at it.
with ranked as (
  select id, first_value(id) over w as keep, row_number() over w as n
  from public.enquiries
  where not contacted and dup_of is null and tenant_id <> 'deleted'
  window w as (partition by hostel_id, tenant_id, coalesce(bed, '') order by created_at desc, id)
)
update public.enquiries e set dup_of = r.keep from ranked r where e.id = r.id and r.n > 1;

create unique index if not exists enquiries_one_open on public.enquiries (hostel_id, tenant_id, coalesce(bed, ''))
  where not contacted and dup_of is null and tenant_id <> 'deleted';

-- The app's way in: returns the tenant's open enquiry for this hostel + bed
-- (or one the owner answered in the last 60 days), else records a new one.
create or replace function public.send_enquiry(p_hostel uuid, p_name text, p_phone text, p_bed text default null, p_source text default '', p_msg text default '')
returns text
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); r text;
begin
  if me is null or not public.is_verified() then raise exception 'sign in first'; end if;
  if not public.is_live(p_hostel) then raise exception 'this hostel isn''t on Hostelzy yet'; end if;
  select e.ref into r from public.enquiries e
  where e.hostel_id = p_hostel and e.tenant_id = me and coalesce(e.bed, '') = coalesce(p_bed, '') and e.dup_of is null
    and (not e.contacted or e.created_at > now() - interval '60 days')
  order by (not e.contacted) desc, e.created_at desc limit 1;
  if r is not null then return r; end if;
  insert into public.enquiries (hostel_id, tenant_id, ref, name, phone, bed, source, msg)
  values (p_hostel, me, 'new', coalesce(nullif(btrim(p_name), ''), 'Hostelzy user'), coalesce(p_phone, ''), p_bed, coalesce(p_source, ''), coalesce(p_msg, ''))
  returning ref into r;
  return r;
end $$;

revoke execute on function public.send_enquiry(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.send_enquiry(uuid, text, text, text, text, text) to authenticated;

-- ================================================================ F08 reviews

alter table public.reviews add column if not exists stay_id uuid references public.stays (id) on delete set null;
alter table public.reviews add column if not exists room int;                -- the author's room when posted (S4 layout flag)
alter table public.reviews add column if not exists edited_at timestamptz;
alter table public.reviews add column if not exists hidden boolean not null default false;
alter table public.reviews add column if not exists hidden_why text;

-- Who may change what on a review:
--   the server (SQL editor, jobs) and the team: anything (the team hides reviews)
--   account deletion: only who wrote it ("Former resident")
--   the author: their stars, words and answers (marked edited)
--   the hostel's staff: one reply, once
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare mine constant text[] := array['stars', 'body', 'cats', 'layout', 'advance', 'again', 'edited_at'];
begin
  if public.is_server() or public.is_team() then return new; end if;
  if current_setting('hz.deleting', true) = 'on' and new.author_id = 'deleted' and new.author_name = 'Former resident'
     and (to_jsonb(new) - 'author_id' - 'author_name') = (to_jsonb(old) - 'author_id' - 'author_name') then
    return new;
  end if;
  if old.author_id = public.uid() then
    if old.hidden then raise exception 'this review was hidden by Hostelzy'; end if;
    if (to_jsonb(new) - mine) <> (to_jsonb(old) - mine) then raise exception 'you can change only your stars and words'; end if;
    new.edited_at := now();
    return new;
  end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  if old.reply is not null then raise exception 'you already replied to this review'; end if;
  if coalesce(btrim(new.reply), '') = '' then raise exception 'write a reply first'; end if;
  new.replied_at := now();
  return new;
end $$;

-- Backfill: each review's stay and room (the author's confirmed stay there).
update public.reviews r set stay_id = s.id, room = s.number
from (
  select distinct on (st.hostel_id, st.user_id) st.id, st.hostel_id, st.user_id, rm.number
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.confirmed and st.user_id is not null
  order by st.hostel_id, st.user_id, (st.left_on is null) desc, st.joined_on desc
) s
where r.stay_id is null and s.hostel_id = r.hostel_id and s.user_id = r.author_id;

-- Older duplicates for the same stay are hidden (kept for the record).
with ranked as (
  select id, row_number() over (partition by stay_id, kind order by created_at desc, id) as n
  from public.reviews where stay_id is not null
)
update public.reviews r set stay_id = null, hidden = true, hidden_why = 'Duplicate review for the same stay'
from ranked x where r.id = x.id and x.n > 1;

create unique index if not exists reviews_one_per_stay on public.reviews (stay_id, kind) where stay_id is not null;

-- A new review: a confirmed stay at this hostel, 30 days in for the 30-day
-- review, one of each kind per stay, never by the hostel's own staff.
create or replace function public.review_rules() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare s record;
begin
  if public.is_server() or public.is_team() then return new; end if;
  if public.is_staff(new.hostel_id) then raise exception 'owners can''t review their own hostel'; end if;
  select st.id, st.joined_on, rm.number into s
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.hostel_id = new.hostel_id and st.user_id = public.uid() and st.confirmed
  order by (st.left_on is null) desc, st.joined_on desc limit 1;
  if s.id is null then raise exception 'only residents with a confirmed stay can review'; end if;
  if new.kind = 'stay' and s.joined_on > current_date - 30 then
    raise exception 'reviews open after 30 days of your stay, on %', to_char(s.joined_on + 30, 'FMDD Mon');
  end if;
  if exists (select 1 from public.reviews x where x.stay_id = s.id and x.kind = new.kind) then
    raise exception 'you already reviewed this stay';
  end if;
  new.stay_id := s.id;
  new.room := s.number;
  new.hidden := false;
  new.hidden_why := null;
  new.edited_at := null;
  return new;
end $$;

drop trigger if exists review_rules on public.reviews;
create trigger review_rules before insert on public.reviews
for each row execute function public.review_rules();

-- Hidden reviews leave the hostel's page; the author and the team still see them.
drop policy if exists "read reviews" on public.reviews;
create policy "read reviews" on public.reviews for select
  using ((not hidden and (public.is_live(hostel_id) or public.is_staff(hostel_id))) or author_id = public.uid() or public.is_team());
drop policy if exists "author edits review" on public.reviews;
create policy "author edits review" on public.reviews for update using (author_id = public.uid()) with check (author_id = public.uid());

-- ---------------------------------------------------------------- report abuse

create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  reporter_id text not null default public.uid(),
  why text not null,
  status text not null default 'open' check (status in ('open', 'hidden', 'kept')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (review_id, reporter_id)
);
alter table public.review_reports enable row level security;
drop policy if exists "read review reports" on public.review_reports;
create policy "read review reports" on public.review_reports for select using (reporter_id = public.uid() or public.is_team());

-- Anyone signed in who can see a review can report it (once); the team decides.
create or replace function public.report_review(p_review uuid, p_why text) returns void
language plpgsql security definer set search_path = ''
as $$
declare r public.reviews;
begin
  if public.uid() is null or not public.is_verified() then raise exception 'sign in first'; end if;
  if coalesce(btrim(p_why), '') = '' then raise exception 'say what is wrong'; end if;
  select * into r from public.reviews where id = p_review;
  if r.id is null or r.hidden or not (public.is_live(r.hostel_id) or public.is_staff(r.hostel_id)) then raise exception 'review not found'; end if;
  if r.author_id = public.uid() then raise exception 'you can edit your own review instead'; end if;
  insert into public.review_reports (review_id, hostel_id, reporter_id, why)
  values (r.id, r.hostel_id, public.uid(), left(btrim(p_why), 200))
  on conflict (review_id, reporter_id) do nothing;
end $$;

-- The team hides a reported review (or keeps it); every open report on it closes.
create or replace function public.decide_review_report(p_review uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team decides reports'; end if;
  update public.reviews set hidden = p_hide, hidden_why = case when p_hide then 'Reported for abuse' end where id = p_review;
  update public.review_reports set status = case when p_hide then 'hidden' else 'kept' end, decided_at = now()
  where review_id = p_review and status = 'open';
end $$;

revoke execute on function public.report_review(uuid, text), public.decide_review_report(uuid, boolean) from public, anon;
grant execute on function public.report_review(uuid, text), public.decide_review_report(uuid, boolean) to authenticated;
revoke execute on function public.review_rules() from public, anon, authenticated;

-- ================================================================ F13 S4 layout flag

-- "Is the room layout right? No" on a 30-day review adds a dispute to the
-- author's room; changing the answer (or the team hiding the review) takes it
-- back. Publishing the room again resets the count (publish/approve_layout).
create or replace function public.review_layout_flag() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  was boolean := tg_op = 'UPDATE' and old.layout = 'No' and not old.hidden and old.room is not null;
  now_no boolean := new.layout = 'No' and not new.hidden and new.room is not null;
begin
  if was = now_no then return null; end if;
  update public.layouts set disputes = greatest(0, disputes + case when now_no then 1 else -1 end)
  where hostel_id = new.hostel_id and room = new.room and stage = 'published';
  return null;
end $$;

revoke execute on function public.review_layout_flag() from public, anon, authenticated;

drop trigger if exists review_layout_flag on public.reviews;
create trigger review_layout_flag after insert or update of layout, hidden on public.reviews
for each row execute function public.review_layout_flag();

-- Flags for reviews posted before this ran (since the room was last published).
update public.layouts l set disputes = greatest(l.disputes, (
  select count(*)::int from public.reviews r
  where r.hostel_id = l.hostel_id and r.room = l.room and r.layout = 'No' and not r.hidden
    and r.created_at > coalesce(l.confirmed_at, '-infinity'::timestamptz)))
where l.stage = 'published';


-- ================================================================
-- 20261003070000_f24_wave4b.sql
-- ================================================================
-- F24 Wave 4b (gap audit §3, F12 + F24 item 27): room layouts on the server.
--
-- 1. Women's PGs: the whole floor only after a hold (DECISIONS F12).
--      sees_floor(h)   the hostel's staff, the team, its residents, and a
--          tenant with a hold there (asked, held or booked).
--      layouts         the "read published layouts" policy: for a Women PG it
--          also needs sees_floor, so nobody else can read all its rooms.
--      room_layout(hostel, room)   one room's published layout for the Room
--          tab, for any signed-in (Google) user (room layouts stay visible,
--          DECISIONS F12). In a Women PG, before a hold, at most 6 different
--          rooms a day per hostel (layout_peeks), so the floor can't be pieced
--          together; then "hold a bed to see more rooms here".
-- 2. One editor at a time (F12 spec).
--      layout_locks    (hostel, room) → who is editing, until when (10 min).
--      lock_layout(hostel, room) → (name, mine, until)   staff / team: take it,
--          or refresh your own; while someone else holds it, their name.
--      unlock_layout(hostel, room)   let it go (leaving the editor).
--      Publishing or undoing (a new version of the published copy) by anyone
--      else while the lock is held fails: "<name> is editing this room".
-- 3. "Tell me when it's ready" (F24 item 27).
--      layout_waits    a tenant waits for a room's first layout.
--      wait_for_layout(hostel, room)   signed-in user, live hostel.
--      When the room's layout is published, everyone waiting gets one push
--      (kind "hold": Settings → Holds and bookings) and the wait closes.
-- Runs after 20261003033000_f24_team.sql. Safe to run again.

-- ---------------------------------------------------------------- 1. women's PGs

create or replace function public.is_womens(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.gender = 'Women') $$;

create or replace function public.sees_floor(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select public.is_staff(h) or public.is_team()
    or exists (select 1 from public.stays s where s.hostel_id = h and s.user_id = public.uid() and s.left_on is null)
    or exists (select 1 from public.holds x where x.hostel_id = h and x.tenant_id = public.uid() and x.status in ('waiting', 'held', 'booked'))
$$;

drop policy if exists "read published layouts" on public.layouts;
create policy "read published layouts" on public.layouts for select
  using (stage = 'published' and public.is_verified() and public.is_live(hostel_id) and (not public.is_womens(hostel_id) or public.sees_floor(hostel_id)));

create table if not exists public.layout_peeks (
  user_id text not null,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  day date not null default current_date,
  primary key (user_id, hostel_id, day, room)
);
alter table public.layout_peeks enable row level security;
-- No policies: only room_layout writes and reads it.

create or replace function public.room_layout(p_hostel uuid, p_room int) returns setof public.layouts
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); n int;
begin
  if not public.is_verified() then raise exception 'sign in with Google to see room layouts'; end if;
  if not (public.is_live(p_hostel) or public.sees_floor(p_hostel)) then return; end if;
  if not exists (select 1 from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published') then return; end if;
  if public.is_womens(p_hostel) and not public.sees_floor(p_hostel)
     and not exists (select 1 from public.layout_peeks where user_id = me and hostel_id = p_hostel and day = current_date and room = p_room) then
    select count(*) into n from public.layout_peeks where user_id = me and hostel_id = p_hostel and day = current_date;
    if n >= 6 then raise exception 'hold a bed to see more rooms here'; end if;
    insert into public.layout_peeks (user_id, hostel_id, room) values (me, p_hostel, p_room) on conflict do nothing;
  end if;
  return query select * from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
end $$;

-- ---------------------------------------------------------------- 2. one editor at a time

create table if not exists public.layout_locks (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  user_id text not null,
  name text not null default '',
  until timestamptz not null,
  primary key (hostel_id, room)
);
alter table public.layout_locks enable row level security;
drop policy if exists "staff read layout locks" on public.layout_locks;
create policy "staff read layout locks" on public.layout_locks for select using (public.is_staff(hostel_id) or public.is_team());
-- Writes go through lock_layout / unlock_layout only.

create or replace function public.lock_layout(p_hostel uuid, p_room int) returns table (name text, mine boolean, until timestamptz)
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); who text; l record;
begin
  if me is null or not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can edit its rooms'; end if;
  select coalesce(nullif(split_part(trim(p.name), ' ', 1), ''), '') into who from public.profiles p where p.id = me;
  who := coalesce(nullif(who, ''), case when public.is_owner(p_hostel) then 'The owner' when public.is_staff(p_hostel) then 'A manager' else 'The Hostelzy team' end);
  insert into public.layout_locks as k (hostel_id, room, user_id, name, until)
  values (p_hostel, p_room, me, who, now() + interval '10 minutes')
  on conflict (hostel_id, room) do update set user_id = excluded.user_id, name = excluded.name, until = excluded.until
    where k.user_id = excluded.user_id or k.until <= now();
  if found then return query select who, true, now() + interval '10 minutes'; return; end if;
  select * into l from public.layout_locks k where k.hostel_id = p_hostel and k.room = p_room;
  return query select l.name, false, l.until;
end $$;

create or replace function public.unlock_layout(p_hostel uuid, p_room int) returns void
language sql security definer set search_path = ''
as $$ delete from public.layout_locks where hostel_id = p_hostel and room = p_room and user_id = public.uid() $$;

-- A new version of the published copy (publish, an approved fix, undo) only
-- from whoever holds the room's lock, or when nobody does.
create or replace function public.layout_lock_guard() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare l record;
begin
  if new.stage <> 'published' or public.uid() is null then return new; end if;
  if tg_op = 'UPDATE' and new.version = old.version then return new; end if;
  select * into l from public.layout_locks k where k.hostel_id = new.hostel_id and k.room = new.room and k.until > now() and k.user_id <> public.uid();
  if found then raise exception '% is editing this room. Try again when they''re done.', l.name; end if;
  return new;
end $$;

drop trigger if exists layout_lock_guard on public.layouts;
create trigger layout_lock_guard before insert or update on public.layouts
for each row execute function public.layout_lock_guard();

-- ---------------------------------------------------------------- 3. "Tell me when it's ready"

create table if not exists public.layout_waits (
  user_id text not null default public.uid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  room int not null,
  created_at timestamptz not null default now(),
  told_at timestamptz,
  primary key (user_id, hostel_id, room)
);
alter table public.layout_waits enable row level security;
drop policy if exists "read own layout waits" on public.layout_waits;
create policy "read own layout waits" on public.layout_waits for select using (user_id = public.uid());
-- Writes go through wait_for_layout only.

create or replace function public.wait_for_layout(p_hostel uuid, p_room int) returns void
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid();
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  if not public.is_live(p_hostel) then raise exception 'this hostel isn''t on Hostelzy now'; end if;
  if not exists (select 1 from public.rooms r where r.hostel_id = p_hostel and r.number = p_room) then raise exception 'there is no room % here', p_room; end if;
  if exists (select 1 from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published') then raise exception 'this room''s layout is ready'; end if;
  if (select count(*) from public.layout_waits w where w.user_id = me and w.told_at is null) >= 30 then raise exception 'you''re waiting for 30 rooms already'; end if;
  insert into public.layout_waits (user_id, hostel_id, room) values (me, p_hostel, p_room)
  on conflict (user_id, hostel_id, room) do update set created_at = now(), told_at = null;
end $$;

create or replace function public.layout_ready_push() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare h record; label text;
begin
  if new.stage <> 'published' or (tg_op = 'UPDATE' and new.version = old.version) then return new; end if;
  select x.id, x.name into h from public.hostels x where x.id = new.hostel_id and x.status = 'live';
  if h.id is null then return new; end if;
  select coalesce(r.label, r.number::text) into label from public.rooms r where r.hostel_id = new.hostel_id and r.number = new.room;
  insert into public.push_outbox (user_id, title, body, data, kind)
  select w.user_id, 'Room ' || coalesce(label, new.room::text) || '’s layout is ready',
    h.name || ': see where each bed, fan and window is, then hold your bed.',
    jsonb_build_object('screen', 'detail', 'hostel', h.id, 'room', new.room, 'kind', 'hold'), 'hold'
  from public.layout_waits w where w.hostel_id = new.hostel_id and w.room = new.room and w.told_at is null;
  update public.layout_waits set told_at = now() where hostel_id = new.hostel_id and room = new.room and told_at is null;
  return new;
end $$;

drop trigger if exists layout_ready_push on public.layouts;
create trigger layout_ready_push after insert or update on public.layouts
for each row execute function public.layout_ready_push();

-- ---------------------------------------------------------------- grants

revoke execute on function public.layout_lock_guard(), public.layout_ready_push() from public, anon, authenticated;
revoke execute on function public.room_layout(uuid, int), public.lock_layout(uuid, int), public.unlock_layout(uuid, int), public.wait_for_layout(uuid, int) from public, anon;
grant execute on function public.room_layout(uuid, int), public.lock_layout(uuid, int), public.unlock_layout(uuid, int), public.wait_for_layout(uuid, int) to authenticated;
grant execute on function public.is_womens(uuid), public.sees_floor(uuid) to anon, authenticated;


-- ================================================================
-- 20261003080000_f24_fair_play.sql
-- ================================================================
-- F24 item 18: Fair Play hardening (DECISIONS F07: 3 strikes — 1 warning,
-- 2 deals hidden for 30 days, 3 removed; a fix within 48 hours closes the
-- case with no strike, and three such fixes in 6 months = one warning).
--   fair_play_accepts       the owner's "I agree" to the Fair Play rules, once
--       per account (accept_fair_play()). Read by the owner and the team.
--   hostels.live_since      the day the hostel went live (set by the server).
--   stays.via = 'before'    "Joined before Hostelzy": only for someone who
--       moved in on or before the go-live day, set by the owner while the
--       hostel isn't live yet (onboarding) and after that by the team only.
--       These residents never count as off-app joins.
--   strike_state(h) / fair_standing()   the hostel's strikes now: strike 2
--       hides deals for 30 days from the day it was given, then they come
--       back; strikes themselves keep counting (DECISIONS sets no expiry for
--       them). Strike 3 removes the hostel: is_live() is false, so tenants
--       can't read it, its rooms, beds or deals, or hold or enquire there;
--       its owner and the team still see it, and its plan stops.
--   give_strike(case)       the team's strike, with the right words.
--   fix_case(case)          as before, and the third fix in 6 months is a
--       warning (a strike, reason 'fixes').
--   holds.declined          the owner or a manager turned a hold down.
--   fair_signals(hostel)    the six collusion signals (F07), team only.
--   fair_reports.status     tenant reports: new → case (report_case()) or
--       closed by the team in the console.
-- Safe to run again.

-- ---------------------------------------------------------------- 1. rules accepted

create table if not exists public.fair_play_accepts (
  user_id text primary key,
  accepted_at timestamptz not null default now()
);
alter table public.fair_play_accepts enable row level security;
drop policy if exists "own or team read accepts" on public.fair_play_accepts;
create policy "own or team read accepts" on public.fair_play_accepts for select using (user_id = public.uid() or public.is_team());
revoke all on table public.fair_play_accepts from public, anon, authenticated;
grant select on table public.fair_play_accepts to authenticated;

create or replace function public.accept_fair_play() returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare at timestamptz;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  insert into public.fair_play_accepts (user_id) values (public.uid()) on conflict (user_id) do nothing;
  select a.accepted_at into at from public.fair_play_accepts a where a.user_id = public.uid();
  return at;
end $$;
revoke execute on function public.accept_fair_play() from public, anon;
grant execute on function public.accept_fair_play() to authenticated;

-- ---------------------------------------------------------------- 2. joined before Hostelzy

alter table public.hostels add column if not exists live_since date;
update public.hostels set live_since = coalesce(visited_on, created_at::date) where status = 'live' and live_since is null;

create or replace function public.hostel_live_since() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.live_since is distinct from old.live_since and not (public.is_team() or public.is_server()) then
    raise exception 'ask the Hostelzy team to change this';
  end if;
  if new.status = 'live' and new.live_since is null then new.live_since := (now() at time zone 'Asia/Kolkata')::date; end if;
  return new;
end $$;
drop trigger if exists hostel_live_since on public.hostels;
create trigger hostel_live_since before insert or update on public.hostels
for each row execute function public.hostel_live_since();
revoke execute on function public.hostel_live_since() from public, anon, authenticated;

-- Runs after match_stay (names sort), so it sees the final "via".
create or replace function public.stay_joined_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare ls date; hname text;
begin
  if new.via is distinct from 'before' then return new; end if;
  if tg_op = 'UPDATE' and old.via = 'before' and new.joined_on is not distinct from old.joined_on then return new; end if;
  select h.live_since, h.name into ls, hname from public.hostels h where h.id = new.hostel_id;
  if ls is null then return new; end if;
  if new.joined_on > ls then
    raise exception 'only residents who moved in by % (when % went live) joined before Hostelzy', to_char(ls, 'FMDD Mon YYYY'), hname;
  end if;
  if not (public.is_team() or public.is_server()) then
    raise exception 'after go-live, only the Hostelzy team marks a resident as joined before Hostelzy';
  end if;
  return new;
end $$;
drop trigger if exists stay_joined_before on public.stays;
create trigger stay_joined_before before insert or update on public.stays
for each row execute function public.stay_joined_before();
revoke execute on function public.stay_joined_before() from public, anon, authenticated;

-- ---------------------------------------------------------------- 3–4. strikes now

alter table public.strikes add column if not exists reason text not null default 'case';
alter table public.strikes drop constraint if exists strikes_reason;
alter table public.strikes add constraint strikes_reason check (reason in ('case', 'fixes'));

-- n strikes; strike 2 hides deals for 30 days from the day it was given.
create or replace function public.strike_state(h uuid) returns table (n int, hidden_until timestamptz, removed boolean, last_reason text)
language sql stable security definer set search_path = ''
as $$
  select count(*)::int,
    case when count(*) = 2 then (select s.created_at from public.strikes s where s.hostel_id = h order by s.created_at offset 1 limit 1) + interval '30 days' end,
    count(*) >= 3,
    (select s.reason from public.strikes s where s.hostel_id = h order by s.created_at desc limit 1)
  from public.strikes x where x.hostel_id = h
$$;

create or replace function public.is_removed(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select (select count(*) from public.strikes s where s.hostel_id = h) >= 3 $$;

create or replace function public.deals_hidden(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((select st.removed or coalesce(st.hidden_until > now(), false) from public.strike_state(h) st), false) $$;

create or replace function public.strike_label(n int) returns text
language sql immutable set search_path = ''
as $$ select case when n <= 1 then 'warning' when n = 2 then 'deals hidden for 30 days' else 'removed from Hostelzy' end $$;

-- Strike 3: tenants can't see the hostel any more. Its owner and the team can.
create or replace function public.is_live(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.status = 'live') and not public.is_removed(h) $$;

drop policy if exists "live hostels" on public.hostels;
create policy "live hostels" on public.hostels for select
  using ((status = 'live' and not public.is_removed(id)) or public.is_staff(id) or public.is_team());

-- Everyone: the strike state of hostels they can see; the owner and the team
-- also for a removed one (so the owner sees why).
create or replace function public.fair_standing() returns table (hostel_id uuid, n int, deals_hidden boolean, hidden_until timestamptz, removed boolean, last_reason text)
language sql stable security definer set search_path = ''
as $$
  select h.hostel_id, st.n, st.removed or coalesce(st.hidden_until > now(), false), st.hidden_until, st.removed, st.last_reason
  from (select distinct s.hostel_id from public.strikes s) h
  cross join lateral public.strike_state(h.hostel_id) st
  where public.is_live(h.hostel_id) or public.is_owner(h.hostel_id) or public.is_team()
$$;
grant execute on function public.fair_standing() to anon, authenticated;

-- A third strike stops the plan (no more invoices).
create or replace function public.strike_effects() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_removed(new.hostel_id) then
    update public.owner_plans set status = 'paused' where hostel_id = new.hostel_id;
  end if;
  return new;
end $$;
drop trigger if exists strike_effects on public.strikes;
create trigger strike_effects after insert on public.strikes
for each row execute function public.strike_effects();
revoke execute on function public.strike_effects() from public, anon, authenticated;

-- The team decides a strike: the case says which one and what it means.
create or replace function public.give_strike(p_case uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare c record; k int; words text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team decides a strike'; end if;
  select * into c from public.fair_cases where id = p_case;
  if c.id is null then raise exception 'that case isn''t there any more'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is already decided'; end if;
  insert into public.strikes (hostel_id, case_id, reason) values (c.hostel_id, p_case, 'case');
  select count(*)::int into k from public.strikes where hostel_id = c.hostel_id;
  words := 'Strike ' || least(k, 3) || ' · ' || public.strike_label(k);
  update public.fair_cases set status = 'decided', decision = words where id = p_case;
  return words;
end $$;
revoke execute on function public.give_strike(uuid) from public, anon;
grant execute on function public.give_strike(uuid) to authenticated;

-- Deals at booking time follow the strikes now (2 strikes: hidden 30 days).
create or replace function public.deal_for_bed(p_hostel uuid, p_bed uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  rm record;
  fee int;
  t jsonb;
  d record;
  paused boolean;
  on_ids text[] := '{}';
begin
  select r.ac, r.share, r.rent into rm from public.beds b join public.rooms r on r.id = b.room_id where b.id = p_bed and b.hostel_id = p_hostel;
  if not found then return null; end if;
  select c.rent into fee from public.rate_cards c where c.hostel_id = p_hostel and c.ac = rm.ac and c.share = rm.share;
  select coalesce(h.terms, '{}'::jsonb) into t from public.hostels h where h.id = p_hostel;
  select x.deals_on, x.target into d from public.deals x where x.hostel_id = p_hostel;
  paused := public.deals_hidden(p_hostel)
    or exists (select 1 from public.owner_plans o where o.hostel_id = p_hostel and o.status in ('overdue', 'paused'));
  if d is not null and not paused and coalesce(array_length(d.deals_on, 1), 0) > 0
     and (coalesce(d.target, '') in ('', 'all') or (d.target = 'ac') = rm.ac) then
    on_ids := d.deals_on;
  end if;
  return jsonb_build_object(
    'on', to_jsonb(on_ids),
    'fee', coalesce(fee, rm.rent),
    'advance', coalesce((t ->> 'advance')::int, 3000),
    'maintenance', coalesce((t ->> 'maintenance')::int, 1000),
    'notice', coalesce((t ->> 'noticeDays')::int, 30),
    'at', now());
end $$;
revoke execute on function public.deal_for_bed(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- 7. three fixes in 6 months

alter table public.fair_cases add column if not exists fixed_at timestamptz;
alter table public.fair_cases add column if not exists fix_counted boolean not null default false;
select set_config('hz.fixing', 'on', false);
update public.fair_cases set fixed_at = created_at where fixed_at is null and decision like 'Fixed by the owner%';
select set_config('hz.fixing', 'off', false);

create or replace function public.fix_case(p_case uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record; three uuid[];
begin
  select * into c from public.fair_cases where id = p_case;
  -- Managers are stopped by Wave 3a's owner_only_case trigger ("only the owner handles Fair Play").
  if c is null or not public.is_staff(c.hostel_id) then raise exception 'only this hostel''s staff can fix it'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is closed'; end if;
  if c.created_at < now() - interval '48 hours' then raise exception 'the 48 hours are over; reply instead'; end if;
  if c.resident is null then raise exception 'there is no resident to fix; reply instead'; end if;
  update public.stays set via = 'hz', late_days = 0
  where hostel_id = c.hostel_id and left_on is null and (name = c.resident or bed_id in (
    select b.id from public.beds b join public.rooms r on r.id = b.room_id
    where b.hostel_id = c.hostel_id and coalesce(r.label, r.number::text) || '-' || b.letter = c.resident));
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set status = 'closed', decision = 'Fixed by the owner within 48 h · no strike', fixed_at = now() where id = p_case;
  -- Three fixes in 6 months (not yet counted) = one warning.
  select array_agg(x.id) into three from (
    select f.id from public.fair_cases f
    where f.hostel_id = c.hostel_id and f.fixed_at > now() - interval '6 months' and not f.fix_counted
    order by f.fixed_at limit 3) x;
  if coalesce(array_length(three, 1), 0) >= 3 then
    update public.fair_cases set fix_counted = true where id = any(three);
    insert into public.strikes (hostel_id, case_id, reason) values (c.hostel_id, p_case, 'fixes');
  end if;
  perform set_config('hz.fixing', 'off', true);
end $$;
revoke execute on function public.fix_case(uuid) from public, anon;
grant execute on function public.fix_case(uuid) to authenticated;

-- ---------------------------------------------------------------- 5. the six signals

alter table public.holds add column if not exists declined boolean not null default false;

-- The owner or a manager (not the tenant) turned the hold down.
create or replace function public.hold_declined() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'released' and old.status in ('waiting', 'held') and public.uid() is distinct from old.tenant_id
     and public.is_staff(old.hostel_id) then
    new.declined := true;
  elsif not (public.is_team() or public.is_server()) then
    new.declined := old.declined;
  end if;
  return new;
end $$;
drop trigger if exists hold_declined on public.holds;
create trigger hold_declined before update on public.holds
for each row execute function public.hold_declined();
revoke execute on function public.hold_declined() from public, anon, authenticated;

-- One row per hostel and signal (F07): how many, and a short line for the team.
create or replace function public.fair_signals(p_hostel uuid default null)
returns table (hostel_id uuid, signal text, label text, n int, detail text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team sees Fair Play signals'; end if;
  return query
  with hs as (
    select h.id from public.hostels h where p_hostel is null or h.id = p_hostel
  ),
  -- 1. held or enquired on Hostelzy, then added as Direct (same name, another number)
  s1 as (
    select s.hostel_id, count(distinct s.id)::int as n, string_agg(distinct s.name, ', ') as d
    from public.stays s
    where s.via = 'direct' and s.joined_on > current_date - 90
      and (exists (select 1 from public.enquiries e where e.hostel_id = s.hostel_id and lower(trim(e.name)) = lower(trim(s.name))
                     and e.created_at >= s.joined_on - interval '60 days' and e.created_at < s.joined_on + interval '2 days')
        or exists (select 1 from public.holds x join public.profiles p on p.id = x.tenant_id
                     where x.hostel_id = s.hostel_id and p.name <> '' and lower(trim(p.name)) = lower(trim(s.name))
                     and x.started_at >= s.joined_on - interval '60 days' and x.started_at < s.joined_on + interval '2 days'))
    group by s.hostel_id
  ),
  -- 2. a hold ended and the same bed went to a Direct resident within 7 days
  s2 as (
    select x.hostel_id, count(distinct s.id)::int as n,
      string_agg(distinct coalesce(r.label, r.number::text) || '-' || b.letter, ', ') as d
    from public.holds x
    join public.stays s on s.bed_id = x.bed_id and s.hostel_id = x.hostel_id
    join public.beds b on b.id = x.bed_id join public.rooms r on r.id = b.room_id
    where x.status in ('released', 'expired') and x.started_at > now() - interval '90 days' and s.via = 'direct'
      and s.joined_on >= x.started_at::date
      and s.joined_on <= (coalesce(x.decided_at, x.expires_at, x.started_at) + interval '7 days')::date
    group by x.hostel_id
  ),
  -- 3. the tenant said "Yes, I joined" 3+ days ago and was never added
  s3 as (
    select j.hostel_id,
      count(*) filter (where not exists (
        select 1 from public.stays s where s.hostel_id = j.hostel_id
          and (s.user_id = j.tenant_id or (x.ref is not null and s.ref = x.ref) or (coalesce(p.phone, '') <> '' and s.phone = p.phone))))::int as n,
      count(*)::int as yes
    from public.join_answers j join public.holds x on x.id = j.hold_id left join public.profiles p on p.id = j.tenant_id
    where j.answer = 'yes' and j.updated_at < now() - interval '3 days' and j.updated_at > now() - interval '90 days'
    group by j.hostel_id
  ),
  -- 4. a Direct resident paying less than the walk-in price while deals are on
  s4 as (
    select s.hostel_id, count(*)::int as n, string_agg(s.name || ' ₹' || s.rent || ' (walk-in ₹' || c.rent || ')', ', ') as d
    from public.stays s
    join public.beds b on b.id = s.bed_id join public.rooms r on r.id = b.room_id
    join public.rate_cards c on c.hostel_id = s.hostel_id and c.ac = r.ac and c.share = r.share
    join public.deals dl on dl.hostel_id = s.hostel_id and coalesce(array_length(dl.deals_on, 1), 0) > 0
    where s.via = 'direct' and s.left_on is null and s.rent > 0 and s.rent < c.rent
    group by s.hostel_id
  ),
  -- 5. holds declined while Direct residents are added (30 days)
  s5 as (
    select h.id as hostel_id,
      (select count(*)::int from public.holds x where x.hostel_id = h.id and x.declined and coalesce(x.decided_at, x.started_at) > now() - interval '30 days') as declined,
      (select count(*)::int from public.stays s where s.hostel_id = h.id and s.via = 'direct' and s.joined_on > current_date - 30) as added
    from hs h
  ),
  -- 6. tenant reports (90 days)
  s6 as (
    select f.hostel_id, count(*)::int as n, count(*) filter (where f.status = 'new')::int as open,
      string_agg(distinct f.why, ' · ') as d
    from public.fair_reports f where f.created_at > now() - interval '90 days'
    group by f.hostel_id
  )
  select h.id, 'direct_after_app', 'Held or enquired, then added as Direct', coalesce(s1.n, 0), coalesce(s1.d, '')
  from hs h left join s1 on s1.hostel_id = h.id
  union all
  select h.id, 'bed_after_cancel', 'Hold cancelled, same bed taken in 7 days', coalesce(s2.n, 0), coalesce('Beds ' || s2.d, '')
  from hs h left join s2 on s2.hostel_id = h.id
  union all
  select h.id, 'joined_not_added', 'Tenant said “Yes, I joined”, never added', coalesce(s3.n, 0),
    case when s3.yes is null then '' else s3.yes || ' said yes, ' || s3.n || ' not added' end
  from hs h left join s3 on s3.hostel_id = h.id
  union all
  select h.id, 'direct_deal_price', 'Direct resident paying the deal price', coalesce(s4.n, 0), coalesce(s4.d, '')
  from hs h left join s4 on s4.hostel_id = h.id
  union all
  select h.id, 'declines_while_filling', 'Declining holds while occupancy rises',
    case when s5.declined >= 2 and s5.added >= 2 then s5.declined else 0 end,
    s5.declined || ' declined, ' || s5.added || ' added directly in 30 days'
  from hs h join s5 on s5.hostel_id = h.id
  union all
  select h.id, 'tenant_reports', 'Tenant reports', coalesce(s6.n, 0), coalesce(s6.open || ' open · ' || s6.d, '')
  from hs h left join s6 on s6.hostel_id = h.id;
end $$;
revoke execute on function public.fair_signals(uuid) from public, anon;
grant execute on function public.fair_signals(uuid) to authenticated;

-- ---------------------------------------------------------------- 6. tenant reports in the console

alter table public.fair_reports add column if not exists status text not null default 'new';
alter table public.fair_reports add column if not exists case_id uuid references public.fair_cases (id) on delete set null;
alter table public.fair_reports drop constraint if exists fair_reports_status;
alter table public.fair_reports add constraint fair_reports_status check (status in ('new', 'case', 'closed'));

drop policy if exists "report" on public.fair_reports;
create policy "report" on public.fair_reports for insert
  with check (reporter_id = public.uid() and public.is_verified() and status = 'new' and case_id is null);
drop policy if exists "team closes reports" on public.fair_reports;
create policy "team closes reports" on public.fair_reports for update using (public.is_team()) with check (public.is_team());

-- "Open a case": the owner sees the case (never who reported it).
create or replace function public.report_case(p_report uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare f record; cid uuid; cref text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team opens a case'; end if;
  select * into f from public.fair_reports where id = p_report;
  if f.id is null then raise exception 'that report isn''t there any more'; end if;
  if f.status <> 'new' then raise exception 'this report is already handled'; end if;
  insert into public.fair_cases (ref, hostel_id, title, signal, events)
  values (public.next_fp_ref(), f.hostel_id, 'Tenant report',
    'Tenant report: ' || lower(left(f.why, 1)) || substr(f.why, 2),
    jsonb_build_array(jsonb_build_object('on', to_char(f.created_at, 'DD Mon'), 'what', 'A tenant told Hostelzy', 'detail', f.why, 'flag', true)))
  returning id, ref into cid, cref;
  update public.fair_reports set status = 'case', case_id = cid where id = p_report;
  return cref;
end $$;
revoke execute on function public.report_case(uuid) from public, anon;
grant execute on function public.report_case(uuid) to authenticated;


-- ================================================================
-- 20261003090000_f24_wave4c.sql
-- ================================================================
-- F24 Wave 4c: the rest of Wave A items 1, 2 and 4.
--   Item 1, owner's WhatsApp: an owner may chat on a different number than
--     they take calls on.
--       profiles.whatsapp            the owner's own (Settings › WhatsApp), '' = same as phone.
--       hostel_leads.owner_whatsapp  the one the team notes in the Add hostel wizard.
--       owner_contacts(hostels[]) → (hostel_id, phone, whatsapp)   same people
--         as before; whatsapp is the owner's own, else the team's note, else ''.
--   Item 2, onboard a real hostel:
--       save_hostel also saves "rules" (house rules: gate time, visitors…) and
--         "amenities" (the wizard's list) when sent. The pin (lat, lng) is the
--         one the team dropped at the gate.
--       go_live also needs that pin: "drop the map pin at the gate".
--       hostels.amenities            the wizard's amenities (Wi-Fi, Power backup…).
--   Item 4, meal times: menus.breakfast_time / lunch_time / dinner_time,
--     'HH:MM-HH:MM' (24 h) or '' (not set: the app keeps its usual times).
--       save_meal_times(hostel, {"b": "07:30-09:30", "l": …, "n": …})   staff or
--         the team; the same times go on every day of the week.
-- Safe to run again.

-- ------------------------------------------------------------ item 1

alter table public.profiles add column if not exists whatsapp text not null default '';
alter table public.profiles drop constraint if exists profiles_whatsapp;
alter table public.profiles add constraint profiles_whatsapp check (whatsapp ~ '^([0-9]{10})?$');
alter table public.hostel_leads add column if not exists owner_whatsapp text not null default '';

drop function if exists public.owner_contacts(uuid[]);
create function public.owner_contacts(p_hostels uuid[]) returns table (hostel_id uuid, phone text, whatsapp text)
language sql stable security definer set search_path = ''
as $$
  select h.id,
    coalesce(
      nullif((select regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_phone, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      ''),
    coalesce(
      nullif((select p.whatsapp from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_whatsapp, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      '')
  from public.hostels h
  where h.id = any(p_hostels)
    and public.uid() is not null
    and (public.is_staff(h.id) or public.is_team()
      or exists (select 1 from public.holds x where x.hostel_id = h.id and x.tenant_id = public.uid() and x.started_at > now() - interval '60 days')
      or exists (select 1 from public.enquiries e where e.hostel_id = h.id and e.tenant_id = public.uid() and e.created_at > now() - interval '60 days')
      or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = public.uid() and (s.left_on is null or s.left_on > current_date - 60)))
$$;
revoke execute on function public.owner_contacts(uuid[]) from public, anon;
grant execute on function public.owner_contacts(uuid[]) to authenticated;

-- ------------------------------------------------------------ item 2

alter table public.hostels add column if not exists amenities text[] not null default '{}';

create or replace function public.save_hostel(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare hid uuid := p_id; v_name text := trim(coalesce(p ->> 'name', '')); v_slug text; st text; rc jsonb; v_wa text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team adds hostels'; end if;
  if v_name = '' then raise exception 'add the hostel name'; end if;
  if p ? 'lat' and ((p ->> 'lat')::double precision not between 17.0 and 18.0 or (p ->> 'lng')::double precision not between 78.0 and 79.0) then
    raise exception 'the map pin isn''t in Hyderabad';
  end if;
  v_wa := regexp_replace(coalesce(p ->> 'owner_whatsapp', ''), '\D', '', 'g');
  if v_wa <> '' and length(v_wa) <> 10 then raise exception 'the owner''s WhatsApp needs 10 digits'; end if;
  if hid is null then
    v_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then v_slug := 'hostel'; end if;
    while exists (select 1 from public.hostels where slug = v_slug) loop
      v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
    end loop;
    insert into public.hostels (slug, name, gender, area, status) values (v_slug, v_name, coalesce(p ->> 'gender', 'Men'), coalesce(p ->> 'area', ''), 'draft')
    returning id into hid;
  end if;
  select status into st from public.hostels where id = hid;
  if st is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  update public.hostels set
    name = v_name,
    gender = coalesce(p ->> 'gender', gender),
    area = coalesce(p ->> 'area', area),
    owner_name = coalesce(trim(p ->> 'owner_name'), owner_name),
    food = coalesce((p ->> 'food')::boolean, food),
    ac = coalesce((p ->> 'ac')::boolean, ac),
    only_ac = coalesce((p ->> 'only_ac')::boolean, only_ac),
    tags = coalesce(array(select jsonb_array_elements_text(p -> 'tags')), tags),
    terms = coalesce(p -> 'terms', terms),
    lat = coalesce((p ->> 'lat')::double precision, lat),
    lng = coalesce((p ->> 'lng')::double precision, lng),
    rules = case when jsonb_typeof(p -> 'rules') = 'array' then
      (select coalesce(jsonb_agg(jsonb_build_object('k', trim(r ->> 'k'), 'v', trim(coalesce(r ->> 'v', '')))), '[]') from jsonb_array_elements(p -> 'rules') r where trim(coalesce(r ->> 'k', '')) <> '')
      else rules end,
    amenities = case when jsonb_typeof(p -> 'amenities') = 'array' then
      array(select distinct trim(a) from jsonb_array_elements_text(p -> 'amenities') a where trim(a) <> '')
      else amenities end
  where id = hid;
  insert into public.hostel_leads (hostel_id, owner_phone, owner_whatsapp, stage)
  values (hid, regexp_replace(coalesce(p ->> 'owner_phone', ''), '\D', '', 'g'), v_wa, 'signed_up')
  on conflict (hostel_id) do update set owner_phone = case when excluded.owner_phone <> '' then excluded.owner_phone else public.hostel_leads.owner_phone end,
    owner_whatsapp = case when p ? 'owner_whatsapp' then excluded.owner_whatsapp else public.hostel_leads.owner_whatsapp end,
    stage = case when public.hostel_leads.stage in ('lead', 'visited') then 'signed_up' else public.hostel_leads.stage end, updated_at = now();
  if p ? 'rates' then
    delete from public.rate_cards where hostel_id = hid;
    for rc in select * from jsonb_array_elements(p -> 'rates') loop
      insert into public.rate_cards (hostel_id, ac, share, rent) values (hid, (rc ->> 'ac')::boolean, (rc ->> 'share')::int, (rc ->> 'rent')::int);
    end loop;
  end if;
  if p ? 'rooms' then perform public.save_rooms(hid, p -> 'rooms'); end if;
  return hid;
end $$;

-- go_live as before, plus the pin dropped at the gate.
create or replace function public.go_live(h uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare missing text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team puts hostels live'; end if;
  if not exists (select 1 from public.hostels where id = h) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if not exists (select 1 from public.beds where hostel_id = h) then raise exception 'add at least one room with beds'; end if;
  select string_agg(distinct r.share || ' sharing' || case when r.ac then ' AC' else '' end, ', ') into missing
  from public.rooms r where r.hostel_id = h
    and not exists (select 1 from public.rate_cards c where c.hostel_id = h and c.ac = r.ac and c.share = r.share and c.rent > 0);
  if missing is not null then raise exception 'add a price for %', missing; end if;
  if not exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.role = 'owner') then raise exception 'link the owner''s account first'; end if;
  if (select count(*) from public.hostel_photos p where p.hostel_id = h) < 8 then raise exception 'add 8 photos first'; end if;
  if exists (select 1 from public.hostels x where x.id = h and (x.lat is null or x.lng is null)) then raise exception 'drop the map pin at the gate'; end if;
  update public.hostels set status = 'live', visited_on = coalesce(visited_on, (now() at time zone 'Asia/Kolkata')::date) where id = h;
  insert into public.owner_plans (hostel_id, trial_ends, status) values (h, (now() at time zone 'Asia/Kolkata')::date + 30, 'trial')
  on conflict (hostel_id) do nothing;
  update public.hostel_leads set stage = 'data_complete', next_step = '', updated_at = now() where hostel_id = h;
end $$;

revoke execute on function public.save_hostel(uuid, jsonb), public.go_live(uuid) from public, anon;
grant execute on function public.save_hostel(uuid, jsonb), public.go_live(uuid) to authenticated;

-- ------------------------------------------------------------ item 4

alter table public.menus add column if not exists breakfast_time text not null default '';
alter table public.menus add column if not exists lunch_time text not null default '';
alter table public.menus add column if not exists dinner_time text not null default '';
alter table public.menus drop constraint if exists menus_times;
alter table public.menus add constraint menus_times check (
  breakfast_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$'
  and lunch_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$'
  and dinner_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$');

create or replace function public.save_meal_times(p_hostel uuid, p jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare b text := coalesce(p ->> 'b', ''); l text := coalesce(p ->> 'l', ''); n text := coalesce(p ->> 'n', ''); t text;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner, managers or the team set its meal times'; end if;
  foreach t in array array[b, l, n] loop
    if t <> '' and (t !~ '^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$' or split_part(t, '-', 2) <= split_part(t, '-', 1)) then
      raise exception 'a meal ends after it starts';
    end if;
  end loop;
  insert into public.menus (hostel_id, day, breakfast_time, lunch_time, dinner_time)
  select p_hostel, d, b, l, n from generate_series(0, 6) d
  on conflict (hostel_id, day) do update set breakfast_time = excluded.breakfast_time, lunch_time = excluded.lunch_time, dinner_time = excluded.dinner_time;
end $$;
revoke execute on function public.save_meal_times(uuid, jsonb) from public, anon;
grant execute on function public.save_meal_times(uuid, jsonb) to authenticated;


-- ================================================================
-- 20261003100000_f24_rates_confirm.sql
-- ================================================================
-- F24 Wave 4d (audit §3, F03 rules): "Confirmed by the owner · date" on rates,
-- and a monthly "Are your rates still right?".
--   rate_cards.confirmed_at   when the owner last stood by this price. Only the
--       server's clock counts: set to now() when a rate card is added or its
--       rent changes, and by confirm_rates(). Whatever the app sends is
--       ignored (the team and the server itself may set it). Rate cards that
--       existed before this ran stay unconfirmed (null): we don't know when
--       their price was last checked, and tenants never see an invented date.
--   confirm_rates(p_hostel)   the owner's "Rates still right" on Today: every
--       rate card of the hostel gets confirmed_at = now(). Owner (or team)
--       only, like rates themselves (Wave 3a, DECISIONS F14).
--   nudge_rates()             daily (pg_cron, 10:15 India time): a push to the
--       hostel's owner when its oldest rate wasn't confirmed for 30 days (or
--       never), at most one every 30 days. data.kind 'rates' (always sent).
-- Tenants read confirmed_at with the rate card: "Confirmed by the owner ·
-- 12 Sep", or "Not confirmed in over a month" after 31 days.
-- Runs after 20261003050000_f24_server_rules.sql. Safe to run again.

alter table public.rate_cards add column if not exists confirmed_at timestamptz;

create or replace function public.guard_rate_confirm() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not (public.is_team() or public.is_server()) or new.confirmed_at is null then new.confirmed_at := now(); end if;
    return new;
  end if;
  if new.rent is distinct from old.rent then
    -- A new price is the owner's price today.
    new.confirmed_at := now();
  elsif current_setting('hz.rates_confirm', true) = 'on' then
    new.confirmed_at := now();
  elsif not (public.is_team() or public.is_server()) then
    new.confirmed_at := old.confirmed_at;
  end if;
  return new;
end $$;

drop trigger if exists guard_rate_confirm on public.rate_cards;
create trigger guard_rate_confirm before insert or update on public.rate_cards
for each row execute function public.guard_rate_confirm();
revoke execute on function public.guard_rate_confirm() from public, anon, authenticated;

create or replace function public.confirm_rates(p_hostel uuid) returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  if not (public.is_owner(p_hostel) or public.is_team()) then raise exception 'only the owner confirms rates'; end if;
  perform set_config('hz.rates_confirm', 'on', true);
  update public.rate_cards set confirmed_at = now() where hostel_id = p_hostel;
  get diagnostics n = row_count;
  perform set_config('hz.rates_confirm', 'off', true);
  return n;
end $$;

revoke execute on function public.confirm_rates(uuid) from public, anon;
grant execute on function public.confirm_rates(uuid) to authenticated;

-- ---------------------------------------------------------------- monthly push

create table if not exists public.rate_nudges (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  sent_at timestamptz not null default now()
);
alter table public.rate_nudges enable row level security;
-- No policies: only the daily job uses it.
revoke all on table public.rate_nudges from public, anon, authenticated;

create or replace function public.nudge_rates() returns int
language plpgsql security definer set search_path = ''
as $$
declare r record; n int := 0;
begin
  for r in
    select h.id, h.name,
      bool_or(c.confirmed_at is null) as never,
      min(c.confirmed_at) as oldest
    from public.hostels h join public.rate_cards c on c.hostel_id = h.id
    where h.status = 'live'
    group by h.id, h.name
  loop
    -- Monthly (a little slack for the job's start time).
    if (r.never or r.oldest < now() - interval '30 days')
       and not exists (select 1 from public.rate_nudges x where x.hostel_id = r.id and x.sent_at > now() - interval '29 days 23 hours') then
      perform public.notify_owner(r.id, 'Are your rates still right?',
        'Confirm the prices at ' || r.name || ' in Today. Tenants see when you last did.',
        jsonb_build_object('screen', 'oToday', 'kind', 'rates'));
      insert into public.rate_nudges (hostel_id, sent_at) values (r.id, now())
      on conflict (hostel_id) do update set sent_at = now();
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

revoke execute on function public.nudge_rates() from public, anon, authenticated;

-- Daily at 10:15 India time (04:45 UTC), where pg_cron is on (it is, since B5).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-rates-nudge', '45 4 * * *', 'select public.nudge_rates()');
  end if;
end $$;


-- ================================================================
-- 20261003110000_f24_strike_deals.sql
-- ================================================================
-- F24 #18 follow-up: strike 2 hides a hostel's deals from tenants on the server too.
-- Until now only the app hid them (deals_paused covered a late plan, not strikes).
-- Tenants and guests can't read the deals row while deals_hidden(h) is true
-- (strike 2's 30 days, or strike 3); the owner, managers and the team still can.
drop policy if exists "read deals" on public.deals;
create policy "read deals" on public.deals for select
  using ((public.is_live(hostel_id) and not public.deals_paused(hostel_id) and not public.deals_hidden(hostel_id))
    or public.is_staff(hostel_id) or public.is_team());

-- F24 #15: "Layouts checked by N residents" on the hostel page: how many
-- different residents had a layout fix approved in the last 6 months, per hostel
-- (layout_checks() counts per room, and one resident can check several rooms).
create or replace function public.hostel_layout_checks() returns table (hostel_id uuid, n int)
language sql stable security definer set search_path = ''
as $$
  select f.hostel_id, count(distinct f.author_id)::int
  from public.layout_fixes f
  where f.status = 'approved' and f.decided_at > now() - interval '6 months'
    and (public.is_live(f.hostel_id) or public.is_staff(f.hostel_id) or public.is_team())
  group by f.hostel_id
$$;
grant execute on function public.hostel_layout_checks() to anon, authenticated;


-- ================================================================
-- 20261003120000_perf_indexes.sql
-- ================================================================
-- Performance: indexes for every foreign key and every user-id column the app and the
-- RLS policies filter on (is_staff(), my stays/holds/enquiries/payments…). No behaviour
-- change: only lookups get faster as the tables grow. Safe to run again (if not exists).

-- Foreign keys (joins and per-hostel lists).
create index if not exists beds_hostel_id_idx on public.beds (hostel_id);
create index if not exists enquiries_dup_of_idx on public.enquiries (dup_of);
create index if not exists fair_cases_hostel_id_idx on public.fair_cases (hostel_id);
create index if not exists fair_reports_case_id_idx on public.fair_reports (case_id);
create index if not exists fair_reports_hostel_id_idx on public.fair_reports (hostel_id);
create index if not exists holds_bed_id_idx on public.holds (bed_id);
create index if not exists holds_hostel_id_idx on public.holds (hostel_id);
create index if not exists invite_signups_code_idx on public.invite_signups (code);
create index if not exists invoices_hostel_id_idx on public.invoices (hostel_id);
create index if not exists layout_history_hostel_id_idx on public.layout_history (hostel_id);
create index if not exists layout_peeks_hostel_id_idx on public.layout_peeks (hostel_id);
create index if not exists layout_waits_hostel_id_idx on public.layout_waits (hostel_id);
create index if not exists manager_invites_hostel_id_idx on public.manager_invites (hostel_id);
create index if not exists meter_readings_hostel_id_idx on public.meter_readings (hostel_id);
create index if not exists move_requests_hostel_id_idx on public.move_requests (hostel_id);
create index if not exists move_requests_stay_id_idx on public.move_requests (stay_id);
create index if not exists move_requests_to_bed_id_idx on public.move_requests (to_bed_id);
create index if not exists owner_invites_hostel_id_idx on public.owner_invites (hostel_id);
create index if not exists payments_hold_id_idx on public.payments (hold_id);
create index if not exists payments_hostel_id_idx on public.payments (hostel_id);
create index if not exists payments_stay_id_idx on public.payments (stay_id);
create index if not exists review_reports_hostel_id_idx on public.review_reports (hostel_id);
create index if not exists reviews_hostel_id_idx on public.reviews (hostel_id);
create index if not exists reward_ledger_hostel_id_idx on public.reward_ledger (hostel_id);
create index if not exists shape_requests_hostel_id_idx on public.shape_requests (hostel_id);
create index if not exists stays_bed_id_idx on public.stays (bed_id);
create index if not exists stays_hostel_id_idx on public.stays (hostel_id);
create index if not exists strikes_case_id_idx on public.strikes (case_id);
create index if not exists strikes_hostel_id_idx on public.strikes (hostel_id);

-- The signed-in user's own rows (RLS checks and "my …" lists).
create index if not exists hostel_staff_user_id_idx on public.hostel_staff (user_id);
create index if not exists stays_user_id_idx on public.stays (user_id);
create index if not exists holds_tenant_id_idx on public.holds (tenant_id);
create index if not exists enquiries_tenant_id_idx on public.enquiries (tenant_id);
create index if not exists payments_payer_id_idx on public.payments (payer_id);
create index if not exists reviews_author_id_idx on public.reviews (author_id);
create index if not exists complaints_author_id_idx on public.complaints (author_id);
create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);
create index if not exists push_outbox_user_id_idx on public.push_outbox (user_id);
create index if not exists reward_ledger_user_id_idx on public.reward_ledger (user_id);
create index if not exists layout_fixes_author_id_idx on public.layout_fixes (author_id);
create index if not exists move_requests_user_id_idx on public.move_requests (user_id);
create index if not exists join_answers_tenant_id_idx on public.join_answers (tenant_id);
create index if not exists invite_signups_user_id_idx on public.invite_signups (user_id);
create index if not exists meal_ratings_user_id_idx on public.meal_ratings (user_id);

-- Server jobs: the push sender looks for unsent pushes; hold expiry scans active holds.
create index if not exists push_outbox_unsent_idx on public.push_outbox (created_at) where sent_at is null;
create index if not exists holds_status_expires_idx on public.holds (status, expires_at);


-- ================================================================
-- 20261006100000_f26_open_layouts.sql
-- ================================================================
-- F26 (founder 2026-10-05, DECISIONS "Layouts open to all"): every published
-- room layout of a live hostel is open to everyone: guests, signed-in tenants,
-- women's PGs included. No hold needed, no daily room limit.
--   layouts         "read published layouts": no women's-PG check and no
--       sign-in check (guests see layouts too).
--   room_layout(hostel, room)   one room's published layout, for anyone; no
--       hold check, no 6-rooms-a-day limit (layout_peeks is dropped).
--   sees_floor(h) and is_womens(h) are no longer used by any rule; they are
--       dropped.
-- The safety rule stays in the editors and the server's checks: layouts never
-- hold gates, CCTV, exits or residents' names.
-- Runs after 20261003070000_f24_wave4b.sql and 20261003120000_perf_indexes.sql.
-- Safe to run again.

drop policy if exists "read published layouts" on public.layouts;
create policy "read published layouts" on public.layouts for select
  using (stage = 'published' and public.is_live(hostel_id));

create or replace function public.room_layout(p_hostel uuid, p_room int) returns setof public.layouts
language sql stable security definer set search_path = ''
as $$
  select l.* from public.layouts l
  where l.hostel_id = p_hostel and l.room = p_room and l.stage = 'published'
    and (public.is_live(p_hostel) or public.is_staff(p_hostel) or public.is_team())
$$;

drop table if exists public.layout_peeks;
drop function if exists public.sees_floor(uuid);
drop function if exists public.is_womens(uuid);

revoke execute on function public.room_layout(uuid, int) from public;
grant execute on function public.room_layout(uuid, int) to anon, authenticated;

commit;
