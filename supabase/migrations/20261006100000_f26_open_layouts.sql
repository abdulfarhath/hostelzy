-- F26 (founder 2026-10-05, DECISIONS "Layouts open to all"): every published
-- room layout of a live hostel is open to everyone: guests, signed-in tenants,
-- women's PGs included. No hold needed, no daily room limit.
--   layouts         "read published layouts": no women's-PG check and no
--       sign-in check (guests see layouts too).
--   room_layout(hostel, room)   one room's published layout, for anyone; no
--       hold check, no 6-rooms-a-day limit (layout_peeks is dropped).
--   sees_floor(h) and is_womens(h) are no longer used by any rule; they are
--       dropped.
-- The safety rule stays in the editors and the server's checks: layouts never
-- hold gates, CCTV, exits or residents' names.
-- Runs after 20261003070000_f24_wave4b.sql and 20261003120000_perf_indexes.sql.
-- Safe to run again.

drop policy if exists "read published layouts" on public.layouts;
create policy "read published layouts" on public.layouts for select
  using (stage = 'published' and public.is_live(hostel_id));

create or replace function public.room_layout(p_hostel uuid, p_room int) returns setof public.layouts
language sql stable security definer set search_path = ''
as $$
  select l.* from public.layouts l
  where l.hostel_id = p_hostel and l.room = p_room and l.stage = 'published'
    and (public.is_live(p_hostel) or public.is_staff(p_hostel) or public.is_team())
$$;

drop table if exists public.layout_peeks;
drop function if exists public.sees_floor(uuid);
drop function if exists public.is_womens(uuid);

revoke execute on function public.room_layout(uuid, int) from public;
grant execute on function public.room_layout(uuid, int) to anon, authenticated;
