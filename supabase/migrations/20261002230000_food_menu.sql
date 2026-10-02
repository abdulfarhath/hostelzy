-- Food menu on the server, and meal ratings without names.
--   menus            (F13, one row per weekday) anyone may now read a live
--       hostel's menu: tenants see "Food today" and the week on its page.
--       Residents, staff and the team keep reading any. Staff and the team
--       write (unchanged).
--   meal_ratings     a resident's Good / Okay / Poor for one meal on one day.
--       Nobody reads the rows; staff only get counts from meal_votes().
--   rate_meal(hostel, meal, rating)    a confirmed resident who hasn't left;
--       one answer per meal per day (a second tap changes it).
--   meal_votes(hostel) → (meal, rating, n)    the last 7 days, staff and team.
-- Safe to run again.

drop policy if exists "read menu" on public.menus;
create policy "read menu" on public.menus for select
  using (public.is_live(hostel_id) or public.is_resident(hostel_id) or public.is_staff(hostel_id) or public.is_team());

create table if not exists public.meal_ratings (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null,
  day date not null default (now() at time zone 'Asia/Kolkata')::date,
  meal text not null check (meal in ('b', 'l', 'n')),
  rating text not null check (rating in ('good', 'okay', 'poor')),
  at timestamptz not null default now(),
  primary key (hostel_id, user_id, day, meal)
);
alter table public.meal_ratings enable row level security;
-- No policies: the rows are read and written only by the functions below.

create or replace function public.rate_meal(p_hostel uuid, p_meal text, p_rating text) returns void
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid();
begin
  if me is null then raise exception 'sign in first'; end if;
  if p_meal is null or p_meal not in ('b', 'l', 'n') then raise exception 'pick breakfast, lunch or dinner'; end if;
  if p_rating is null or lower(p_rating) not in ('good', 'okay', 'poor') then raise exception 'pick good, okay or poor'; end if;
  if not exists (select 1 from public.stays st where st.hostel_id = p_hostel and st.user_id = me and st.confirmed and st.left_on is null) then
    raise exception 'only this hostel''s residents can rate its food';
  end if;
  insert into public.meal_ratings (hostel_id, user_id, meal, rating) values (p_hostel, me, p_meal, lower(p_rating))
  on conflict (hostel_id, user_id, day, meal) do update set rating = excluded.rating, at = now();
end $$;

create or replace function public.meal_votes(p_hostel uuid) returns table (meal text, rating text, n int)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner and managers see its food ratings'; end if;
  return query
    select r.meal, r.rating, count(*)::int from public.meal_ratings r
    where r.hostel_id = p_hostel and r.day > (now() at time zone 'Asia/Kolkata')::date - 7
    group by r.meal, r.rating order by r.meal, r.rating;
end $$;

revoke execute on function public.rate_meal(uuid, text, text), public.meal_votes(uuid) from public, anon;
grant execute on function public.rate_meal(uuid, text, text), public.meal_votes(uuid) to authenticated;
