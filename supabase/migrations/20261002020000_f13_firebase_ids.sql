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
