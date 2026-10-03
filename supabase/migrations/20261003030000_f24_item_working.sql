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
