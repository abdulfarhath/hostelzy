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
