-- F29 Part 1 · Notify (S40): the owner or a manager sends a current resident a
-- short note as a Hostelzy notification. The app has called this RPC since wave 1.
create or replace function public.notify_resident(p_stay uuid, p_note text) returns void
language plpgsql security definer set search_path = ''
as $$
declare s record; note text := trim(coalesce(p_note, ''));
begin
  select st.id, st.hostel_id, st.user_id, st.left_on, h.name into s
  from public.stays st join public.hostels h on h.id = st.hostel_id where st.id = p_stay;
  if s.id is null then raise exception 'no such resident'; end if;
  if not public.is_staff(s.hostel_id) then raise exception 'only this hostel''s owner or managers'; end if;
  if s.left_on is not null then raise exception 'this resident has left'; end if;
  if s.user_id is null then raise exception 'not on the app yet'; end if;
  if length(note) < 1 or length(note) > 200 then raise exception 'note must be 1-200 characters'; end if;
  insert into public.push_outbox (user_id, title, body, data, kind)
  values (s.user_id, s.name, note, '{"screen":"rHome"}'::jsonb, 'note');
end $$;
revoke all on function public.notify_resident(uuid, text) from public, anon;
grant execute on function public.notify_resident(uuid, text) to authenticated;
