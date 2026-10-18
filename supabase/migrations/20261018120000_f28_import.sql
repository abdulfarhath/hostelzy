-- F28 wave 3 (Part 3, plus the console side of Parts 2 and 4): hostels found
-- at scale and the team's call lists.
--   hostels.source            team | resident | partner | places | osm | web
--   hostels.added_by          the Firebase uid of the resident / partner who
--                             added it (Build 2 fills it)
--   hostels.place_id          Google place id ("osm:n123" for OpenStreetMap);
--                             the import dedupes on it
--   hostels.source_seen_at    when the import last saw the place (Places
--                             fields are refreshed after 30 days)
--   hostels.rent_confirmed_at when a human confirmed the rent (List button,
--                             Add a hostel, "Rent confirmed today")
--   hostels.owner_phone_hint  the owner's phone as the import / the web form
--                             heard it. Postgres has no column RLS, so the
--                             hint stays on a row only while it is a DRAFT
--                             (drafts are invisible to the public). The moment
--                             a row is listed or live, the trigger below moves
--                             it to hostel_leads.owner_phone (team-only table)
--                             and blanks the column. hostel_owner_phone(h)
--                             reads whichever holds it (team / definer only).
--   hostels.source_photos     Google photo resource names (up to 3); the media
--                             URL needs the key, so nothing public is stored
--   hostels.removed_at        "Not a PG / Closed": kept so the import doesn't
--                             add it again; hidden from every list
--   hostels.call_after        "Call later": back in To call after this
--   self_list_requests        W8 "List your PG" form (anon RPC, 3 per phone a
--                             day) → a draft with source 'web' → To call
--   list_draft / draft_not_pg / rent_confirmed   console › Listed buttons
--   call_list('to_call' | 'to_refresh')         the two console segments, with
--                             the team-only phone (Export CSV)
--   claim_adders()            console › Claims: "added by Ravi (resident) ·
--                             owner phone matches ✓/✗"
--   listed_rent_visible       a listed hostel's rent only within 60 days of a
--                             human confirmation (Part 4: "Rent on request")
-- Build 2's migration adds the same six hostels columns; both use
-- add column if not exists. Safe to run again.

-- ------------------------------------------------------------ hostels columns

alter table public.hostels add column if not exists source text not null default 'team';
alter table public.hostels drop constraint if exists hostels_source_check;
alter table public.hostels add constraint hostels_source_check check (source in ('team', 'resident', 'partner', 'places', 'osm', 'web'));
alter table public.hostels add column if not exists added_by text;
alter table public.hostels add column if not exists place_id text;
alter table public.hostels add column if not exists source_seen_at timestamptz;
alter table public.hostels add column if not exists rent_confirmed_at timestamptz;
alter table public.hostels add column if not exists owner_phone_hint text not null default '';
alter table public.hostels add column if not exists source_photos text[] not null default '{}';
alter table public.hostels add column if not exists removed_at timestamptz;
alter table public.hostels add column if not exists call_after timestamptz;
create unique index if not exists hostels_place_id_key on public.hostels (place_id) where place_id is not null;
create index if not exists hostels_status_source_idx on public.hostels (status, source);

-- ------------------------------------------------------------ the owner's phone stays team-only

create or replace function public.keep_phone_hint_private() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare ph text := regexp_replace(coalesce(new.owner_phone_hint, ''), '\D', '', 'g');
begin
  if new.status <> 'draft' and ph <> '' then
    insert into public.hostel_leads (hostel_id, owner_phone, stage) values (new.id, ph, 'lead')
    on conflict (hostel_id) do update
      set owner_phone = case when public.hostel_leads.owner_phone = '' then excluded.owner_phone else public.hostel_leads.owner_phone end,
          updated_at = now();
    update public.hostels set owner_phone_hint = '' where id = new.id;
  end if;
  return null;
end $$;
revoke execute on function public.keep_phone_hint_private() from public, anon, authenticated;
drop trigger if exists hostels_phone_hint on public.hostels;
create trigger hostels_phone_hint after insert or update of status, owner_phone_hint on public.hostels
  for each row execute function public.keep_phone_hint_private();

-- The owner's phone wherever the team has it: the draft hint, the lead row, or
-- the owner's own profile. Definer-only: no grant to app roles. Build 2's
-- add_hostel() can dedupe "same owner phone" with it.
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

-- ------------------------------------------------------------ W8: owner self-serve requests

create table if not exists public.self_list_requests (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid references public.hostels (id) on delete set null,
  hostel_name text not null check (length(trim(hostel_name)) between 3 and 80),
  name text not null check (length(trim(name)) between 2 and 80),
  phone text not null check (phone ~ '^[0-9]{10}$'),
  area text not null check (length(trim(area)) between 2 and 40),
  rent_min int not null check (rent_min between 1000 and 100000),
  rent_max int not null check (rent_max between rent_min and 100000),
  gender text not null check (gender in ('Men', 'Women', 'Co-living')),
  food boolean not null default false,
  photos text[] not null default '{}',                -- paths in the self-list bucket
  status text not null default 'new' check (status in ('new', 'done')),
  created_at timestamptz not null default now()
);
create index if not exists self_list_requests_phone_idx on public.self_list_requests (phone, created_at);
create index if not exists self_list_requests_hostel_id_idx on public.self_list_requests (hostel_id);
alter table public.self_list_requests enable row level security;
drop policy if exists "team reads requests" on public.self_list_requests;
create policy "team reads requests" on public.self_list_requests for select using (public.is_team());
drop policy if exists "team closes requests" on public.self_list_requests;
create policy "team closes requests" on public.self_list_requests for update using (public.is_team()) with check (public.is_team());
revoke all on public.self_list_requests from anon;
grant select, update on public.self_list_requests to authenticated;

-- The owner's 1–3 photos from the web form: a private bucket, anyone may put
-- a small image under web/<uuid>/, only the team reads.
insert into storage.buckets (id, name, public) values ('self-list', 'self-list', false) on conflict (id) do nothing;
drop policy if exists "hz self-list upload" on storage.objects;
create policy "hz self-list upload" on storage.objects for insert
  with check (bucket_id = 'self-list' and name ~ '^web/[0-9a-f-]{36}/[0-9a-z]{1,20}\.(jpg|jpeg|png|webp)$');
drop policy if exists "hz team reads self-list" on storage.objects;
create policy "hz team reads self-list" on storage.objects for select
  using (bucket_id = 'self-list' and public.is_team());

-- "List your PG on Hostelzy, free": p = {hostel_name, name, phone, area,
-- rent_min, rent_max, gender, food, photos[]}. Anonymous; at most 3 a day per
-- phone. Makes a draft (source 'web') unless a hostel with the same name in
-- the same area already exists, then the request points at that one. Returns
-- the request id. The page says "We'll call you within 2 days", nothing more.
create or replace function public.self_list_request(p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_hostel text := trim(coalesce(p ->> 'hostel_name', ''));
  v_name text := trim(coalesce(p ->> 'name', ''));
  v_phone text := regexp_replace(coalesce(p ->> 'phone', ''), '\D', '', 'g');
  v_area text := trim(coalesce(p ->> 'area', ''));
  v_min int := (p ->> 'rent_min')::int;
  v_max int := (p ->> 'rent_max')::int;
  v_gender text := coalesce(p ->> 'gender', 'Men');
  v_food boolean := coalesce((p ->> 'food')::boolean, false);
  v_photos text[] := coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(p -> 'photos', '[]'::jsonb)) x
                               where x ~ '^web/[0-9a-f-]{36}/[0-9a-z]{1,20}\.(jpg|jpeg|png|webp)$'), '{}');
  hid uuid; rid uuid; v_slug text;
begin
  if length(v_hostel) < 3 then raise exception 'add the hostel name'; end if;
  if length(v_name) < 2 then raise exception 'add your name'; end if;
  if v_phone !~ '^[6-9][0-9]{9}$' then raise exception 'add a 10-digit phone number'; end if;
  if length(v_area) < 2 then raise exception 'add the area'; end if;
  if v_min is null or v_max is null or v_min < 1000 or v_max < v_min or v_max > 100000 then raise exception 'add the rent range'; end if;
  if v_gender not in ('Men', 'Women', 'Co-living') then raise exception 'pick Men, Women or Co-living'; end if;
  if (select count(*) from public.self_list_requests r where r.phone = v_phone and r.created_at > now() - interval '1 day') >= 3 then
    raise exception 'that''s 3 requests today from this number; we''ll call you';
  end if;
  v_photos := v_photos[1:3];
  select h.id into hid from public.hostels h
    where h.removed_at is null and lower(h.name) = lower(v_hostel) and lower(h.area) = lower(v_area)
    order by (h.status = 'live') desc, h.created_at limit 1;
  if hid is null then
    v_slug := trim(both '-' from regexp_replace(lower(v_hostel), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then v_slug := 'hostel'; end if;
    while exists (select 1 from public.hostels where slug = v_slug) loop
      v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
    end loop;
    insert into public.hostels (slug, name, gender, area, food, status, source, rent_min, rent_max, owner_phone_hint, source_seen_at)
    values (v_slug, v_hostel, v_gender, v_area, v_food, 'draft', 'web', v_min, v_max, v_phone, now())
    returning id into hid;
  elsif exists (select 1 from public.hostels h where h.id = hid and h.status = 'draft' and h.owner_phone_hint = '') then
    update public.hostels set owner_phone_hint = v_phone where id = hid;
  end if;
  insert into public.self_list_requests (hostel_id, hostel_name, name, phone, area, rent_min, rent_max, gender, food, photos)
  values (hid, v_hostel, v_name, v_phone, v_area, v_min, v_max, v_gender, v_food, v_photos)
  returning id into rid;
  return rid;
end $$;
grant execute on function public.self_list_request(jsonb) to anon, authenticated;

-- ------------------------------------------------------------ console › Listed buttons

-- To call › List: the draft goes UNVERIFIED with the rent the owner just gave.
-- A human confirmed the rent, so rent_confirmed_at = now(). No photo needed
-- (Places / OSM drafts have none yet; the team adds one in Listed).
create or replace function public.list_draft(p_id uuid, p_rent_min int, p_rent_max int, p_gender text, p_food boolean) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare st text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team lists hostels'; end if;
  select status into st from public.hostels where id = p_id and removed_at is null;
  if st is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if st = 'live' then raise exception 'this hostel is already verified'; end if;
  if p_rent_min is null or p_rent_max is null or p_rent_min < 1000 or p_rent_max < p_rent_min or p_rent_max > 100000 then raise exception 'add the expected rent range'; end if;
  if p_gender is null or p_gender not in ('Men', 'Women', 'Co-living') then raise exception 'pick Men, Women or Co-living'; end if;
  update public.hostels set rent_min = p_rent_min, rent_max = p_rent_max, gender = p_gender, food = coalesce(p_food, food),
    status = 'listed', rent_confirmed_at = now(), call_after = null
  where id = p_id;
  update public.self_list_requests set status = 'done' where hostel_id = p_id and status = 'new';
  return p_id;
end $$;
revoke execute on function public.list_draft(uuid, int, int, text, boolean) from public, anon;
grant execute on function public.list_draft(uuid, int, int, text, boolean) to authenticated;

-- To call › Not a PG, To refresh › Closed: off Explore, out of every list, and
-- the import never adds it again. A verified (live) hostel is paused in
-- Hostels instead.
create or replace function public.draft_not_pg(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare st text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team removes hostels'; end if;
  select status into st from public.hostels where id = p_id;
  if st is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if st = 'live' then raise exception 'this hostel is verified: pause it in Hostels'; end if;
  update public.hostels set status = 'draft', removed_at = now(), call_after = null where id = p_id;
  update public.self_list_requests set status = 'done' where hostel_id = p_id and status = 'new';
end $$;
revoke execute on function public.draft_not_pg(uuid) from public, anon;
grant execute on function public.draft_not_pg(uuid) to authenticated;

-- To call › Call later: back in the list after 3 days.
create or replace function public.call_later(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team'; end if;
  update public.hostels set call_after = now() + interval '3 days' where id = p_id and status = 'draft';
end $$;
revoke execute on function public.call_later(uuid) from public, anon;
grant execute on function public.call_later(uuid) to authenticated;

-- To refresh › Rent confirmed today.
create or replace function public.rent_confirmed(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team confirms rents'; end if;
  if not exists (select 1 from public.hostels where id = p_id and status = 'listed' and rent_min is not null) then
    raise exception 'that hostel isn''t listed with a rent';
  end if;
  update public.hostels set rent_confirmed_at = now() where id = p_id;
end $$;
revoke execute on function public.rent_confirmed(uuid) from public, anon;
grant execute on function public.rent_confirmed(uuid) to authenticated;

-- The two call lists, with the team-only phone.
--   to_call     drafts from Places / OSM / the web form, not removed; "Call
--               later" rows come last, after their date
--   to_refresh  listed hostels whose rent nobody confirmed in 50 days
drop function if exists public.call_list(text);
create function public.call_list(p_kind text)
returns table (id uuid, name text, area text, gender text, food boolean, source text, status text, phone text,
               rent_min int, rent_max int, rent_confirmed_at timestamptz, created_at timestamptz, call_after timestamptz,
               lat double precision, lng double precision, photos text[], adder text)
language sql stable security definer set search_path = ''
as $$
  select h.id, h.name, h.area, h.gender, h.food, h.source, h.status, public.hostel_owner_phone(h.id),
    h.rent_min, h.rent_max, h.rent_confirmed_at, h.created_at, h.call_after, h.lat, h.lng,
    coalesce((select array_agg(distinct ph) from public.self_list_requests r, unnest(r.photos) ph where r.hostel_id = h.id), '{}'),
    coalesce((select r.name from public.self_list_requests r where r.hostel_id = h.id order by r.created_at desc limit 1), '')
  from public.hostels h
  where public.is_team() and h.removed_at is null
    and ((p_kind = 'to_call' and h.status = 'draft' and h.source in ('places', 'osm', 'web'))
      or (p_kind = 'to_refresh' and h.status = 'listed' and h.rent_min is not null
          and (h.rent_confirmed_at is null or h.rent_confirmed_at < now() - interval '50 days')))
  order by (h.call_after is not null and h.call_after > now()), h.call_after, h.rent_confirmed_at nulls first, h.created_at
$$;
revoke execute on function public.call_list(text) from public, anon;
grant execute on function public.call_list(text) to authenticated;

-- console › Claims: who added the hostel and whether the claimant's phone is
-- the owner's phone we have.
drop function if exists public.claim_adders();
create function public.claim_adders() returns table (claim_id uuid, source text, adder text, phone_match boolean)
language sql stable security definer set search_path = ''
as $$
  select c.id, h.source,
    coalesce(nullif((select p.name from public.profiles p where p.id = h.added_by), ''),
             nullif((select r.name from public.self_list_requests r where r.hostel_id = h.id order by r.created_at desc limit 1), ''), ''),
    public.hostel_owner_phone(h.id) <> '' and public.hostel_owner_phone(h.id) = regexp_replace(c.phone, '\D', '', 'g')
  from public.claim_requests c join public.hostels h on h.id = c.hostel_id
  where public.is_team() and c.status = 'new'
$$;
revoke execute on function public.claim_adders() from public, anon;
grant execute on function public.claim_adders() to authenticated;

-- ------------------------------------------------------------ Part 4: rent only when fresh

-- A listed hostel's rent shows only within 60 days of a human confirmation;
-- a verified hostel's rates are live data, always visible.
drop view if exists public.listed_rent_visible;
create view public.listed_rent_visible with (security_invoker = true) as
  select h.id, h.status, h.rent_confirmed_at,
    (h.status = 'live' or h.rent_confirmed_at > now() - interval '60 days') as rent_visible,
    case when h.status = 'live' or h.rent_confirmed_at > now() - interval '60 days' then h.rent_min end as rent_min,
    case when h.status = 'live' or h.rent_confirmed_at > now() - interval '60 days' then h.rent_max end as rent_max
  from public.hostels h
  where h.status in ('listed', 'live');
grant select on public.listed_rent_visible to anon, authenticated;
