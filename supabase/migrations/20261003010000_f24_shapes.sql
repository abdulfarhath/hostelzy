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
