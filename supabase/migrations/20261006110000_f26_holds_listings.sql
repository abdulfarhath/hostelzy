-- F26 #7, #9, #21: owner contact only through a live hold, hold steps, and
-- UNVERIFIED (team-listed) hostels.
--   #7 owner_contacts(hostels[])   the owner's number only to the hostel's
--        staff, the team, a tenant with a LIVE hold there (waiting / held
--        before it ends, or booked) and a resident (now, or left in the last
--        60 days, for the refund). No enquiry clause, no 60-day carry-over of
--        ended holds: it locks again when a hold expires or is declined.
--        hostel_signals(): reply speed from hold replies only (enquiries are
--        history; the app no longer writes them).
--   #9 holds.seen_at     when the hostel's owner or manager first opened the
--        hold (Today / bed sheet): hold_seen(holds[]). The tenant's steps say
--        "Owner reviewing" only after it.
--      holds.declined    true when someone other than the tenant released it
--        (the owner said no), so the tenant sees "Declined", not "Released".
--   #21 hostels.status 'listed'   UNVERIFIED: public name, area, photos and an
--        expected rent range (rent_min / rent_max); no rooms, beds, prices,
--        layouts, deals, reviews, holds or owner contact (those stay on
--        is_live(), which is 'live' only). The team lists one with
--        list_hostel(); go_live() verifies it as before and pushes everyone on
--        its verify_waitlist ("Tell me when verified", data.kind 'beds').
--      claim_requests   "Are you the owner? Claim this hostel": name + phone;
--        the team calls back (console › Claims).
--      area_counts()    per area: verified (live) and listed (unverified).
-- Safe to run again.

-- ------------------------------------------------------------ #9 hold steps

alter table public.holds add column if not exists seen_at timestamptz;
alter table public.holds add column if not exists declined boolean not null default false;

-- Same as 20261002233500_f24_values.sql, plus the "declined" mark.
create or replace function public.stamp_reply() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'enquiries' then
    if new.contacted and not coalesce(old.contacted, false) and new.contacted_at is null then new.contacted_at := now(); end if;
  else
    if new.status is distinct from old.status and old.status = 'waiting' and new.decided_at is null then
      new.decided_at := now();
    end if;
    if new.status = 'released' and old.status in ('waiting', 'held') and public.uid() is distinct from new.tenant_id then
      new.declined := true;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.stamp_reply() from public, anon, authenticated;

-- The owner (or a manager) opened these holds: stamped once. Returns how many.
create or replace function public.hold_seen(p_holds uuid[]) returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.holds x set seen_at = now()
  where x.id = any(p_holds) and x.seen_at is null and x.status = 'waiting' and public.is_staff(x.hostel_id);
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.hold_seen(uuid[]) from public, anon;
grant execute on function public.hold_seen(uuid[]) to authenticated;

-- ------------------------------------------------------------ #7 owner contact

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
      or (public.is_live(h.id) and (
        exists (select 1 from public.holds x where x.hostel_id = h.id and x.tenant_id = public.uid()
                and (x.status = 'booked' or (x.status in ('waiting', 'held') and (x.expires_at is null or x.expires_at > now()))))
        or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = public.uid() and (s.left_on is null or s.left_on > current_date - 60)))))
$$;
revoke execute on function public.owner_contacts(uuid[]) from public, anon;
grant execute on function public.owner_contacts(uuid[]) to authenticated;

-- Same as 20261003050000_f24_server_rules.sql, but reply speed comes from hold
-- replies only.
create or replace function public.hostel_signals() returns table (hostel_id uuid, reply_minutes int, reply_n int, complaints_30d int, residents int, photos int, rooms int, layouts int)
language sql stable security definer set search_path = ''
as $$
  with replies as (
    select x.hostel_id, extract(epoch from x.decided_at - x.started_at) / 60 as m from public.holds x
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
grant execute on function public.hostel_signals() to anon, authenticated;

-- ------------------------------------------------------------ #21 listed hostels

alter table public.hostels drop constraint if exists hostels_status_check;
alter table public.hostels add constraint hostels_status_check check (status in ('draft', 'listed', 'live', 'paused'));
alter table public.hostels add column if not exists rent_min int;
alter table public.hostels add column if not exists rent_max int;
alter table public.hostels drop constraint if exists hostels_rent_range;
alter table public.hostels add constraint hostels_rent_range check (
  (rent_min is null and rent_max is null) or (rent_min between 1000 and 100000 and rent_max between rent_min and 100000));

-- Listed (unverified) hostels are public, like live ones; is_live() stays
-- 'live' only, so their rooms, beds, prices, layouts, deals, reviews and holds
-- stay closed.
create or replace function public.is_public(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.status in ('live', 'listed')) and not public.is_removed(h) $$;

drop policy if exists "live hostels" on public.hostels;
create policy "live hostels" on public.hostels for select
  using ((status in ('live', 'listed') and not public.is_removed(id)) or public.is_staff(id) or public.is_team());

drop policy if exists "read photos" on public.hostel_photos;
create policy "read photos" on public.hostel_photos for select
  using (public.is_public(hostel_id) or public.is_staff(hostel_id) or public.is_team());

-- The team lists a hostel before it is verified: name, gender, area, the pin
-- (optional) and the expected rent range. p.list = true makes it public
-- (needs one photo first); a live hostel can't go back to listed.
create or replace function public.list_hostel(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare hid uuid := p_id; v_name text := trim(coalesce(p ->> 'name', '')); v_slug text; st text;
  v_min int := (p ->> 'rent_min')::int; v_max int := (p ->> 'rent_max')::int;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team lists hostels'; end if;
  if v_name = '' then raise exception 'add the hostel name'; end if;
  if v_min is null or v_max is null or v_min < 1000 or v_max < v_min or v_max > 100000 then raise exception 'add the expected rent range'; end if;
  if p ? 'lat' and ((p ->> 'lat')::double precision not between 17.0 and 18.0 or (p ->> 'lng')::double precision not between 78.0 and 79.0) then
    raise exception 'the map pin isn''t in Hyderabad';
  end if;
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
  if st = 'live' then raise exception 'this hostel is already verified'; end if;
  update public.hostels set
    name = v_name,
    gender = coalesce(p ->> 'gender', gender),
    area = coalesce(p ->> 'area', area),
    lat = coalesce((p ->> 'lat')::double precision, lat),
    lng = coalesce((p ->> 'lng')::double precision, lng),
    rent_min = v_min, rent_max = v_max
  where id = hid;
  if coalesce((p ->> 'list')::boolean, false) then
    if not exists (select 1 from public.hostel_photos x where x.hostel_id = hid) then raise exception 'add a photo first'; end if;
    update public.hostels set status = 'listed' where id = hid;
  end if;
  return hid;
end $$;
revoke execute on function public.list_hostel(uuid, jsonb) from public, anon;
grant execute on function public.list_hostel(uuid, jsonb) to authenticated;

-- "Tell me when verified": the tenant's own rows; the team can read them.
create table if not exists public.verify_waitlist (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null default public.uid(),
  created_at timestamptz not null default now(),
  notified_at timestamptz,
  primary key (hostel_id, user_id)
);
create index if not exists verify_waitlist_user_id_idx on public.verify_waitlist (user_id);
alter table public.verify_waitlist enable row level security;
drop policy if exists "own waitlist" on public.verify_waitlist;
create policy "own waitlist" on public.verify_waitlist for select using (user_id = public.uid() or public.is_team());
drop policy if exists "join waitlist" on public.verify_waitlist;
create policy "join waitlist" on public.verify_waitlist for insert
  with check (user_id = public.uid() and notified_at is null and exists (select 1 from public.hostels h where h.id = hostel_id and h.status = 'listed'));
drop policy if exists "leave waitlist" on public.verify_waitlist;
create policy "leave waitlist" on public.verify_waitlist for delete using (user_id = public.uid());
grant select, insert, delete on public.verify_waitlist to authenticated;

-- "Are you the owner? Claim this hostel": the team calls them back.
create table if not exists public.claim_requests (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null default public.uid(),
  name text not null check (length(trim(name)) between 2 and 80),
  phone text not null check (phone ~ '^[0-9]{10}$'),
  status text not null default 'new' check (status in ('new', 'done', 'rejected')),
  created_at timestamptz not null default now()
);
create index if not exists claim_requests_hostel_id_idx on public.claim_requests (hostel_id);
create index if not exists claim_requests_user_id_idx on public.claim_requests (user_id);
create unique index if not exists claim_requests_one_open on public.claim_requests (hostel_id, user_id) where status = 'new';
alter table public.claim_requests enable row level security;
drop policy if exists "own claims" on public.claim_requests;
create policy "own claims" on public.claim_requests for select using (user_id = public.uid() or public.is_team());
drop policy if exists "send claim" on public.claim_requests;
create policy "send claim" on public.claim_requests for insert
  with check (user_id = public.uid() and status = 'new' and exists (select 1 from public.hostels h where h.id = hostel_id and h.status = 'listed'));
drop policy if exists "team decides claims" on public.claim_requests;
create policy "team decides claims" on public.claim_requests for update using (public.is_team()) with check (public.is_team());
grant select, insert, update on public.claim_requests to authenticated;

-- Explore header: "Madhapur · 12 verified · 84 listed".
create or replace function public.area_counts() returns table (area text, verified int, listed int)
language sql stable security definer set search_path = ''
as $$
  select h.area, (count(*) filter (where h.status = 'live'))::int, (count(*) filter (where h.status = 'listed'))::int
  from public.hostels h where h.status in ('live', 'listed') and not public.is_removed(h.id)
  group by h.area
$$;
grant execute on function public.area_counts() to anon, authenticated;

-- go_live as in 20261003090000_f24_wave4c.sql, plus a push to everyone who
-- tapped "Tell me when verified" (always sent: they asked for it).
create or replace function public.go_live(h uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare missing text; hn text;
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
  update public.hostels set status = 'live', visited_on = coalesce(visited_on, (now() at time zone 'Asia/Kolkata')::date) where id = h
  returning name into hn;
  insert into public.owner_plans (hostel_id, trial_ends, status) values (h, (now() at time zone 'Asia/Kolkata')::date + 30, 'trial')
  on conflict (hostel_id) do nothing;
  update public.hostel_leads set stage = 'data_complete', next_step = '', updated_at = now() where hostel_id = h;
  insert into public.push_outbox (user_id, title, body, data, kind)
  select w.user_id, hn || ' is verified', 'See its free beds and hold one on Hostelzy.',
    jsonb_build_object('kind', 'beds', 'screen', 'detail', 'hostel', h), 'waitlist'
  from public.verify_waitlist w where w.hostel_id = h and w.notified_at is null;
  update public.verify_waitlist set notified_at = now() where hostel_id = h and notified_at is null;
end $$;
revoke execute on function public.go_live(uuid) from public, anon;
grant execute on function public.go_live(uuid) to authenticated;

