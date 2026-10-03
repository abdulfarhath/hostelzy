-- F25: where each shared thing is on its floor, for the floor maps (tenant
-- picker Plan, owner Beds › Floor plan). DECISIONS "Bring back the building and
-- floor screens", founder 2026-10-03; spec docs/features/F25-restore-missing-screens.md.
--   amenities.pos_x, pos_y       0–100 across the floor map's corridor (x left →
--       right, y top-row side → bottom-row side). Both null = not placed yet:
--       the app lists it under "Not placed yet" and never guesses a spot.
--       Only shared things on the floor (place = 'floor') have a spot.
--   place_amenity(id, x, y)      the hostel's owner or manager, or the team,
--       sets the spot (null, null takes it off the map). Logged like any change.
-- Moving a thing to another floor, or into rooms, clears its spot.
-- Never CCTV, gates or exits (those kinds can't exist, see F23). Safe to run again.

alter table public.amenities add column if not exists pos_x smallint;
alter table public.amenities add column if not exists pos_y smallint;

alter table public.amenities drop constraint if exists amenities_pos;
alter table public.amenities add constraint amenities_pos check (
  (pos_x is null) = (pos_y is null)
  and (pos_x is null or (pos_x between 0 and 100 and pos_y between 0 and 100 and place = 'floor'))
);

-- A thing that changes floor, or moves into rooms, loses its old spot.
create or replace function public.amenity_pos_reset() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.floor is distinct from old.floor or new.place <> 'floor' then
    new.pos_x := null;
    new.pos_y := null;
  end if;
  return new;
end $$;

drop trigger if exists amenity_pos_reset on public.amenities;
create trigger amenity_pos_reset before update on public.amenities
for each row execute function public.amenity_pos_reset();

create or replace function public.place_amenity(p_id uuid, p_x int default null, p_y int default null) returns void
language plpgsql security definer set search_path = ''
as $$
declare a public.amenities; v_name text;
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  select * into a from public.amenities where id = p_id;
  if a.id is null then raise exception 'that thing isn''t there any more'; end if;
  if not (public.is_staff(a.hostel_id) or public.is_team()) then
    raise exception 'only the owner or a manager can place things on the floor';
  end if;
  if a.place <> 'floor' then raise exception 'only shared things on the floor have a spot on the map'; end if;
  if (p_x is null) <> (p_y is null) then raise exception 'pick a spot on the floor'; end if;
  if p_x is not null and (p_x not between 0 and 100 or p_y not between 0 and 100) then
    raise exception 'pick a spot inside the floor';
  end if;
  update public.amenities set pos_x = p_x, pos_y = p_y, updated_at = now() where id = p_id returning * into a;
  select p.name into v_name from public.profiles p where p.id = public.uid();
  insert into public.amenity_log (hostel_id, amenity_id, action, what, by_id, by_name, by_role)
  values (a.hostel_id, a.id, 'change',
    public.amenity_what(a) || case when p_x is null then ', taken off the map' else ', placed on the map' end,
    public.uid(), coalesce(v_name, ''), 'staff');
end $$;

revoke execute on function public.amenity_pos_reset() from public, anon, authenticated;
revoke execute on function public.place_amenity(uuid, int, int) from public, anon;
grant execute on function public.place_amenity(uuid, int, int) to authenticated;
