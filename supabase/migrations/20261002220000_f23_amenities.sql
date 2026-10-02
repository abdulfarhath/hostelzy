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
