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
