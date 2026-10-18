-- F28 Part 2 (wave 2): anyone signed in adds a hostel; partners add many.
--   hostels.source            team | resident | partner | places | osm | web
--   hostels.added_by          the adder's uid (resident / partner path)
--   hostels.place_id, source_seen_at   kept for the Places import (wave 3)
--   hostels.rent_confirmed_at a human confirmed the rent (wave 4 shows it only within 60 days)
--   hostels.owner_phone_hint  '' for added hostels: the owner's number goes straight to hostel_leads.owner_phone
--                             (team-only); hostel_owner_phone(h) (Build 3's, stubbed here) reads it wherever it is
--   hostels.partner_code      which partner listed it (₹20 after the team check)
--   hostels.owner_asked_at    when the adder sent the claim link to the owner ("Ask again" after 3 days)
--   partners                  code, name, phone, upi, active (team makes codes in the console)
--   add_hostel(p)             signed in; dedupe (same owner phone, or same name within 150 m) → {duplicate:true};
--                             one in-progress hostel per resident; partners any number
--   my_added_hostel()         the adder's latest hostel with the 5 steps' dates, the reward and the payout
--   asked_owner(h)            stamps owner_asked_at
--   set_adder_upi(upi)        the adder's UPI id for the payout (profiles.payout_upi)
--   reward kinds              hostel_added ₹200 (when the hostel goes live), hostel_listed ₹20 (partner, after the team
--                             check); together capped at ₹2,000 a month, queued to the next month (pay_month)
--   console (Build 3)         new_partner(name, phone, upi) → code · partners_due() · check_partner_hostel(h) ·
--                             payouts_due() · mark_payout_paid(ledger_id, utr)
-- Money amounts are DECISIONS 2026-10-18 (hub, ₹: the founder can change them later).
-- Safe to run again.

-- ------------------------------------------------------------ hostels columns

alter table public.hostels add column if not exists source text not null default 'team';
alter table public.hostels drop constraint if exists hostels_source_check;
alter table public.hostels add constraint hostels_source_check check (source in ('team', 'resident', 'partner', 'places', 'osm', 'web'));
alter table public.hostels add column if not exists added_by text;
alter table public.hostels add column if not exists place_id text;
create unique index if not exists hostels_place_id_key on public.hostels (place_id) where place_id is not null;
alter table public.hostels add column if not exists source_seen_at timestamptz;
alter table public.hostels add column if not exists rent_confirmed_at timestamptz;
alter table public.hostels add column if not exists owner_phone_hint text not null default '';
alter table public.hostels add column if not exists partner_code text;
alter table public.hostels add column if not exists owner_asked_at timestamptz;
create index if not exists hostels_added_by_idx on public.hostels (added_by) where added_by is not null;

-- ------------------------------------------------------------ partners

create table if not exists public.partners (
  code text primary key,
  name text not null check (length(trim(name)) between 2 and 80),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  upi text not null default '',
  active boolean not null default true,
  created_by text default public.uid(),
  created_at timestamptz not null default now()
);
alter table public.partners enable row level security;
drop policy if exists "team partners" on public.partners;
create policy "team partners" on public.partners for all using (public.is_team()) with check (public.is_team());
grant select, insert, update on public.partners to authenticated;

-- The team makes a partner code in the console: "HZ-PART-7".
create or replace function public.new_partner(p_name text, p_phone text, p_upi text default '') returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; n int;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team adds partners'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'add the partner''s name'; end if;
  if coalesce(p_phone, '') !~ '^[6-9][0-9]{9}$' then raise exception 'the partner''s phone needs 10 digits'; end if;
  select count(*) into n from public.partners;
  loop
    n := n + 1;
    c := 'HZ-PART-' || n;
    exit when not exists (select 1 from public.partners where code = c);
  end loop;
  insert into public.partners (code, name, phone, upi) values (c, trim(p_name), p_phone, trim(coalesce(p_upi, '')));
  return c;
end $$;
revoke execute on function public.new_partner(text, text, text) from public, anon;
grant execute on function public.new_partner(text, text, text) to authenticated;

-- ------------------------------------------------------------ rewards: kinds, cap, payouts

alter table public.reward_ledger drop constraint if exists reward_ledger_kind_check;
alter table public.reward_ledger add constraint reward_ledger_kind_check
  check (kind in ('member', 'referral_friend', 'referral_referrer', 'spend', 'owner_credit', 'reversal', 'hostel_added', 'hostel_listed'));
-- The month the payout is due (IST). Beyond the ₹2,000 cap it moves to a later month.
alter table public.reward_ledger add column if not exists pay_month date;

-- The team paid a reward by UPI (console › Payments). One row per ledger entry.
create table if not exists public.reward_payouts (
  ledger_id uuid primary key references public.reward_ledger (id) on delete cascade,
  utr text not null default '',
  paid_by text default public.uid(),
  paid_at timestamptz not null default now()
);
alter table public.reward_payouts enable row level security;
drop policy if exists "team payouts" on public.reward_payouts;
create policy "team payouts" on public.reward_payouts for all using (public.is_team()) with check (public.is_team());
grant select, insert on public.reward_payouts to authenticated;

alter table public.profiles add column if not exists payout_upi text not null default '';

-- The first month (this one or later) where p_amount still fits under the
-- ₹2,000 cap for hostel_added + hostel_listed together.
create or replace function public.reward_cap_month(p_amount int) returns date
language plpgsql stable security definer set search_path = ''
as $$
declare m date := date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date; used int;
begin
  loop
    select coalesce(sum(amount), 0) into used from public.reward_ledger
    where kind in ('hostel_added', 'hostel_listed') and pay_month = m;
    exit when used + p_amount <= 2000;
    m := (m + interval '1 month')::date;
  end loop;
  return m;
end $$;
revoke execute on function public.reward_cap_month(int) from public, anon, authenticated;

-- A resident-added hostel goes live: ₹200 to the adder, once; a push tells them.
create or replace function public.hostel_live_reward() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare m date;
begin
  if new.status = 'live' and old.status is distinct from 'live' and new.source = 'resident' and new.added_by is not null then
    m := public.reward_cap_month(200);
    insert into public.reward_ledger (event_key, kind, user_id, hostel_id, amount, reason, pay_month, created_by)
    values ('added:' || new.id, 'hostel_added', new.added_by, new.id, 200, new.name || ' verified', m, 'server')
    on conflict (event_key) do nothing;
    if found then
      insert into public.push_outbox (user_id, title, body, data)
      values (new.added_by, new.name || ' is verified', '₹200 is yours. Hostelzy pays it by UPI' || case when m > date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date then ' in ' || to_char(m, 'Month') else '' end || '. Open Your hostel to add your UPI ID.',
        jsonb_build_object('screen', 'myAdd', 'hostel', new.id));
    end if;
  end if;
  return new;
end $$;
drop trigger if exists hostel_live_reward on public.hostels;
create trigger hostel_live_reward after update of status on public.hostels
for each row execute function public.hostel_live_reward();
revoke execute on function public.hostel_live_reward() from public, anon, authenticated;

-- Console › Listed › Partners: the team ticks "checked" on a partner-listed hostel → ₹20 to the partner, once.
create or replace function public.check_partner_hostel(p_hostel uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare h record; m date;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team checks listings'; end if;
  select * into h from public.hostels where id = p_hostel;
  if h.id is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if h.source <> 'partner' or h.partner_code is null then raise exception 'not a partner listing'; end if;
  if h.status not in ('listed', 'live') then raise exception 'list it first'; end if;
  m := public.reward_cap_month(20);
  insert into public.reward_ledger (event_key, kind, user_id, hostel_id, amount, reason, pay_month, created_by)
  values ('listed:' || h.id, 'hostel_listed', h.added_by, h.id, 20, h.name || ' listed · partner ' || h.partner_code, m, 'server')
  on conflict (event_key) do nothing;
end $$;
revoke execute on function public.check_partner_hostel(uuid) from public, anon;
grant execute on function public.check_partner_hostel(uuid) to authenticated;

-- Console › Listed › Partners: each partner's listed count and ₹ due / paid.
create or replace function public.partners_due() returns table (code text, name text, phone text, upi text, active boolean, listed int, checked int, due int, paid int)
language sql stable security definer set search_path = ''
as $$
  select p.code, p.name, p.phone, p.upi, p.active,
    (select count(*)::int from public.hostels h where h.partner_code = p.code),
    (select count(*)::int from public.reward_ledger l join public.hostels h on h.id = l.hostel_id where h.partner_code = p.code and l.kind = 'hostel_listed'),
    (select coalesce(sum(l.amount), 0)::int from public.reward_ledger l join public.hostels h on h.id = l.hostel_id
       where h.partner_code = p.code and l.kind = 'hostel_listed' and not exists (select 1 from public.reward_payouts x where x.ledger_id = l.id)),
    (select coalesce(sum(l.amount), 0)::int from public.reward_ledger l join public.hostels h on h.id = l.hostel_id
       where h.partner_code = p.code and l.kind = 'hostel_listed' and exists (select 1 from public.reward_payouts x where x.ledger_id = l.id))
  from public.partners p
  where public.is_team()
  order by p.created_at
$$;
revoke execute on function public.partners_due() from public, anon;
grant execute on function public.partners_due() to authenticated;

-- Console › Payments: ₹200 / ₹20 payouts not paid yet, with the UPI id to pay.
create or replace function public.payouts_due() returns table (ledger_id uuid, kind text, amount int, pay_month date, hostel text, user_id text, who text, upi text, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select l.id, l.kind, l.amount, l.pay_month, h.name, l.user_id,
    coalesce(nullif(pr.name, ''), pa.name, ''),
    coalesce(nullif(pr.payout_upi, ''), pa.upi, ''),
    l.created_at
  from public.reward_ledger l
  left join public.hostels h on h.id = l.hostel_id
  left join public.profiles pr on pr.id = l.user_id
  left join public.partners pa on pa.code = h.partner_code and l.kind = 'hostel_listed'
  where public.is_team() and l.kind in ('hostel_added', 'hostel_listed')
    and not exists (select 1 from public.reward_payouts x where x.ledger_id = l.id)
  order by l.pay_month, l.created_at
$$;
revoke execute on function public.payouts_due() from public, anon;
grant execute on function public.payouts_due() to authenticated;

create or replace function public.mark_payout_paid(p_ledger uuid, p_utr text default '') returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team marks payouts'; end if;
  if not exists (select 1 from public.reward_ledger where id = p_ledger and kind in ('hostel_added', 'hostel_listed')) then raise exception 'no such payout'; end if;
  insert into public.reward_payouts (ledger_id, utr) values (p_ledger, trim(coalesce(p_utr, ''))) on conflict (ledger_id) do nothing;
end $$;
revoke execute on function public.mark_payout_paid(uuid, text) from public, anon;
grant execute on function public.mark_payout_paid(uuid, text) to authenticated;

-- The adder's UPI id for the payout (asked once in S93 after the owner agrees).
create or replace function public.set_adder_upi(p_upi text) returns void
language plpgsql security definer set search_path = ''
as $$
declare u text := trim(coalesce(p_upi, ''));
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  if u !~ '^[A-Za-z0-9._-]{2,}@[A-Za-z][A-Za-z0-9]{1,}$' then raise exception 'that UPI id doesn''t look right'; end if;
  insert into public.profiles (id, payout_upi) values (public.uid(), u)
  on conflict (id) do update set payout_upi = excluded.payout_upi;
end $$;
revoke execute on function public.set_adder_upi(text) from public, anon;
grant execute on function public.set_adder_upi(text) to authenticated;

-- ------------------------------------------------------------ adding a hostel

-- The adder of a listed hostel (may add up to 3 gate photos).
create or replace function public.is_adder(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.added_by = public.uid() and x.status = 'listed') $$;

drop policy if exists "adder adds photos" on public.hostel_photos;
create policy "adder adds photos" on public.hostel_photos for insert
  with check (public.is_adder(hostel_id) and created_by = public.uid()
    and (select count(*) from public.hostel_photos x where x.hostel_id = hostel_photos.hostel_id) < 3);
drop policy if exists "hz adder upload photos" on storage.objects;
create policy "hz adder upload photos" on storage.objects for insert
  with check (bucket_id = 'hostel-photos' and public.is_adder(public.photo_hostel(name)));

-- The owner's phone wherever the team has it (the draft hint, the lead row or
-- the owner's profile). Same body as Build 3's 20261018120000_f28_import.sql,
-- which runs after this and wins; here so add_hostel() works on its own.
-- Definer-only: no grant to app roles.
create or replace function public.hostel_owner_phone(h uuid) returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    nullif(regexp_replace((select coalesce(x.owner_phone_hint, '') from public.hostels x where x.id = h), '\D', '', 'g'), ''),
    nullif((select regexp_replace(l.owner_phone, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h), ''),
    nullif((select regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') from public.hostel_staff st join public.profiles p on p.id = st.user_id
            where st.hostel_id = h and st.role = 'owner' order by p.created_at limit 1), ''),
    '')
$$;
revoke execute on function public.hostel_owner_phone(uuid) from public, anon, authenticated;

-- Metres between two points (haversine).
create or replace function public.metres_between(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision) returns double precision
language sql immutable set search_path = ''
as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

-- "Add a hostel" (S92). p: name, gender, lat, lng, area, rent (resident) or
-- rent_min + rent_max (partner), share, food, owner_name, owner_phone,
-- partner_code. Returns {duplicate: false, hostel_id} or, when the same
-- owner phone or the same name within 150 m is already on Hostelzy,
-- {duplicate: true, hostel_id, name} and makes nothing.
create or replace function public.add_hostel(p jsonb) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  me text := public.uid();
  v_name text := regexp_replace(trim(coalesce(p ->> 'name', '')), '\s+', ' ', 'g');
  v_key text; v_gender text := coalesce(p ->> 'gender', 'Men'); v_area text := trim(coalesce(p ->> 'area', ''));
  v_lat double precision := (p ->> 'lat')::double precision; v_lng double precision := (p ->> 'lng')::double precision;
  v_owner text := regexp_replace(trim(coalesce(p ->> 'owner_name', '')), '\s+', ' ', 'g');
  v_phone text := regexp_replace(coalesce(p ->> 'owner_phone', ''), '\D', '', 'g');
  v_code text := nullif(upper(trim(coalesce(p ->> 'partner_code', ''))), '');
  v_min int; v_max int; v_share int := coalesce((p ->> 'share')::int, 0); v_food boolean := coalesce((p ->> 'food')::boolean, false);
  v_slug text; hid uuid; dup record;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  if length(v_name) < 2 or length(v_name) > 80 then raise exception 'add the hostel name'; end if;
  if v_gender not in ('Men', 'Women', 'Co-living') then raise exception 'pick Men, Women or Co-living'; end if;
  if v_lat is null or v_lng is null or v_lat not between 17.0 and 18.0 or v_lng not between 78.0 and 79.0 then raise exception 'drop the pin at the gate'; end if;
  if length(v_owner) < 2 then raise exception 'add the owner''s name'; end if;
  if v_phone !~ '^[6-9][0-9]{9}$' then raise exception 'the owner''s phone needs 10 digits'; end if;
  if v_code is not null then
    if not exists (select 1 from public.partners where code = v_code and active) then raise exception 'that partner code isn''t valid'; end if;
    v_min := (p ->> 'rent_min')::int; v_max := (p ->> 'rent_max')::int;
  else
    v_min := (p ->> 'rent')::int; v_max := v_min;
  end if;
  if v_min is null or v_max is null or v_min < 1000 or v_max < v_min or v_max > 100000 then raise exception 'add the rent (₹1,000 to ₹1,00,000)'; end if;
  if v_share not between 1 and 4 then raise exception 'pick the sharing'; end if;
  if v_code is null and exists (select 1 from public.hostels where added_by = me and source = 'resident' and status = 'listed') then
    raise exception 'you already have a hostel in progress';
  end if;
  -- Dedupe: same owner phone, or same name within 150 m, of a hostel tenants can see.
  v_key := regexp_replace(lower(v_name), '[^a-z0-9]', '', 'g');
  select h.id, h.name into dup from public.hostels h
  where h.status in ('listed', 'live') and (
    public.hostel_owner_phone(h.id) = v_phone
    or (regexp_replace(lower(h.name), '[^a-z0-9]', '', 'g') = v_key and h.lat is not null and h.lng is not null
        and public.metres_between(h.lat, h.lng, v_lat, v_lng) <= 150))
  order by h.status = 'live' desc, h.created_at
  limit 1;
  if dup.id is not null then
    return jsonb_build_object('duplicate', true, 'hostel_id', dup.id, 'name', dup.name);
  end if;
  v_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
  if v_slug = '' then v_slug := 'hostel'; end if;
  while exists (select 1 from public.hostels where slug = v_slug) loop
    v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
  end loop;
  insert into public.hostels (slug, name, gender, area, lat, lng, status, source, added_by, rent_min, rent_max, rent_confirmed_at, owner_name, owner_phone_hint, partner_code, food, tags)
  values (v_slug, v_name, v_gender, v_area, v_lat, v_lng, 'listed', case when v_code is null then 'resident' else 'partner' end, me, v_min, v_max, now(),
    v_owner, '', v_code, v_food,
    array[v_share || case when v_share = 4 then '+ sharing' else ' sharing' end] || case when v_food then array['Food included'] else '{}'::text[] end)
  returning id into hid;
  -- The owner's full number: team-only (hostel_leads has RLS "team only").
  insert into public.hostel_leads (hostel_id, owner_phone, next_step)
  values (hid, v_phone, 'Added by a ' || case when v_code is null then 'resident' else 'partner ' || v_code end || ' · owner to claim')
  on conflict (hostel_id) do update set owner_phone = excluded.owner_phone, next_step = excluded.next_step, updated_at = now();
  return jsonb_build_object('duplicate', false, 'hostel_id', hid);
end $$;
revoke execute on function public.add_hostel(jsonb) from public, anon;
grant execute on function public.add_hostel(jsonb) to authenticated;

-- "Send to your owner" was tapped: the steps show "Owner asked" and "Ask again" after 3 days.
create or replace function public.asked_owner(p_hostel uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.hostels set owner_asked_at = now() where id = p_hostel and added_by = public.uid();
  if not found then raise exception 'not your hostel'; end if;
end $$;
revoke execute on function public.asked_owner(uuid) from public, anon;
grant execute on function public.asked_owner(uuid) to authenticated;

-- S93 "Your hostel on Hostelzy": the adder's latest hostel and its steps.
-- Added ✓ → Owner asked (owner_asked_at) → Owner agreed (a claim for it) →
-- Verified (live) → ₹200 paid (reward_payouts). Null when nothing was added.
-- The owner's phone comes back only to the adder (they typed it).
create or replace function public.my_added_hostel() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'id', h.id, 'name', h.name, 'gender', h.gender, 'area', h.area, 'status', h.status, 'source', h.source, 'partner_code', h.partner_code,
    'rent_min', h.rent_min, 'rent_max', h.rent_max, 'lat', h.lat, 'lng', h.lng,
    'created_at', h.created_at, 'owner_asked_at', h.owner_asked_at,
    'owner_agreed_at', (select min(c.created_at) from public.claim_requests c where c.hostel_id = h.id and c.status <> 'rejected'),
    'live_at', case when h.status = 'live' then coalesce(h.live_since, h.visited_on, current_date) end,
    'removed', public.is_removed(h.id),
    'reward', (select l.amount from public.reward_ledger l where l.hostel_id = h.id and l.kind in ('hostel_added', 'hostel_listed') and l.user_id = public.uid() limit 1),
    'pay_month', (select l.pay_month from public.reward_ledger l where l.hostel_id = h.id and l.kind in ('hostel_added', 'hostel_listed') and l.user_id = public.uid() limit 1),
    'paid_at', (select x.paid_at from public.reward_payouts x join public.reward_ledger l on l.id = x.ledger_id
                where l.hostel_id = h.id and l.kind in ('hostel_added', 'hostel_listed') and l.user_id = public.uid() limit 1),
    'upi', coalesce((select pr.payout_upi from public.profiles pr where pr.id = public.uid()), ''),
    'photos', (select count(*) from public.hostel_photos p where p.hostel_id = h.id),
    'owner_name', h.owner_name,
    'owner_phone', coalesce((select l.owner_phone from public.hostel_leads l where l.hostel_id = h.id), ''))
  from public.hostels h
  where h.added_by = public.uid() and public.uid() is not null
  order by h.created_at desc
  limit 1
$$;
revoke execute on function public.my_added_hostel() from public, anon;
grant execute on function public.my_added_hostel() to authenticated;
