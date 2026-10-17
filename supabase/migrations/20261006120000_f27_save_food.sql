-- F27 Save food: "Are you eating?" per meal, the owner's headcount, plates saved.
--   meal_rsvp            one row per resident, day and meal (b | l | n): eating or
--       skipping. No row = eating (the default; nobody goes hungry by mistake).
--       A resident writes only their own rows, for their confirmed stay, for
--       today … 6 days ahead, and only before the meal's cut-off (after it the
--       choice is locked). Staff and the team read their hostel's rows.
--   hostels.meal_cutoff_hours   2, 3 (default) or 4: how long before a meal
--       its count closes. Set by the owner or a manager (set_meal_cutoff).
--   meal_cutoff_at(hostel, day, meal)   the meal's start (menu meal time, else
--       the usual 7:30 / 12:30 / 20:00, India time) minus the cut-off hours.
--   rsvp_meals(hostel, [{day, meal, eating}])   the resident's answers, all or
--       nothing ("the count for that meal has closed").
--   food_board(hostel, from, days) → jsonb   for a resident of the hostel, its
--       staff or the team: cut-off hours, counts per meal (residents, skipping),
--       the caller's own answers, plates saved (you this week, you, the hostel
--       this month, the hostel, Hostelzy) and, for staff only, today's
--       skippers by name and bed.
--   hostel_plates(hostels[]) → (hostel_id, n)   anyone: plates saved by each
--       live hostel (no names), for "Cooks to count · N plates saved".
--   Plates saved = skips whose cut-off has passed (1 skip = 1 plate).
--   food_pushes() every 5 minutes (pg_cron): residents who haven't answered
--       get "Dinner at 8 · Eating?" 1 h before the cut-off (never 10 pm – 7 am:
--       then at 9 pm the evening before), with Eating / Skip buttons; the
--       owner and managers get "Dinner headcount: 34 of 40" at the cut-off
--       (not at night). Only for meals on the hostel's menu.
--   Pushes of kind "food" follow the user's Settings switch "Meals"
--       (profiles.notify.food, on unless turned off).
-- Runs after 20261006110000_f26_holds_listings.sql. Safe to run again.

alter table public.hostels add column if not exists meal_cutoff_hours int not null default 3;
alter table public.hostels drop constraint if exists hostels_meal_cutoff;
alter table public.hostels add constraint hostels_meal_cutoff check (meal_cutoff_hours between 2 and 4);

create table if not exists public.meal_rsvp (
  user_id text not null,
  day date not null,
  meal text not null check (meal in ('b', 'l', 'n')),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  stay_id uuid references public.stays (id) on delete set null,
  eating boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, day, meal)
);
create index if not exists meal_rsvp_hostel_day on public.meal_rsvp (hostel_id, day);
alter table public.meal_rsvp enable row level security;

-- Which meal pushes went out (so each goes once).
create table if not exists public.meal_push_log (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  day date not null,
  meal text not null,
  what text not null check (what in ('ask', 'count')),
  at timestamptz not null default now(),
  primary key (hostel_id, day, meal, what)
);
alter table public.meal_push_log enable row level security;
-- No policies: only food_pushes() writes and reads it.

-- India date today.
create or replace function public.ist_today() returns date
language sql stable set search_path = ''
as $$ select (now() at time zone 'Asia/Kolkata')::date $$;

-- The meal's start time at the hostel on [p_day] (its menu time, else the usual one).
create or replace function public.meal_start(p_hostel uuid, p_day date, p_meal text) returns time
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select nullif(split_part(case p_meal when 'b' then m.breakfast_time when 'l' then m.lunch_time else m.dinner_time end, '-', 1), '')::time
     from public.menus m where m.hostel_id = p_hostel and m.day = extract(isodow from p_day)::int - 1),
    case p_meal when 'b' then time '07:30' when 'l' then time '12:30' else time '20:00' end)
$$;

create or replace function public.meal_cutoff_at(p_hostel uuid, p_day date, p_meal text) returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select ((p_day + public.meal_start(p_hostel, p_day, p_meal)) at time zone 'Asia/Kolkata')
    - make_interval(hours => coalesce((select h.meal_cutoff_hours from public.hostels h where h.id = p_hostel), 3))
$$;

-- The caller's confirmed stay at the hostel (null: not a resident there).
create or replace function public.my_stay_at(p_hostel uuid) returns uuid
language sql stable security definer set search_path = ''
as $$
  select s.id from public.stays s
  where s.hostel_id = p_hostel and s.user_id = public.uid() and s.confirmed and s.left_on is null
  order by s.joined_on desc limit 1
$$;

-- May the caller still answer for this meal? Their own confirmed stay, today … +6, before the cut-off.
create or replace function public.can_rsvp(p_hostel uuid, p_day date, p_meal text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select public.uid() is not null
    and p_meal in ('b', 'l', 'n')
    and p_day between public.ist_today() and public.ist_today() + 6
    and public.my_stay_at(p_hostel) is not null
    and now() < public.meal_cutoff_at(p_hostel, p_day, p_meal)
$$;

drop policy if exists "read meal rsvp" on public.meal_rsvp;
create policy "read meal rsvp" on public.meal_rsvp for select
  using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
drop policy if exists "answer meal" on public.meal_rsvp;
create policy "answer meal" on public.meal_rsvp for insert
  with check (user_id = public.uid() and public.can_rsvp(hostel_id, day, meal));
drop policy if exists "change answer" on public.meal_rsvp;
create policy "change answer" on public.meal_rsvp for update
  using (user_id = public.uid() and public.can_rsvp(hostel_id, day, meal))
  with check (user_id = public.uid() and public.can_rsvp(hostel_id, day, meal));
-- No delete: an answer is changed, never removed (the count stays honest).

create or replace function public.rsvp_meals(p_hostel uuid, p jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); st uuid; a jsonb; d date; m text; n int := 0;
begin
  if me is null then raise exception 'sign in first'; end if;
  st := public.my_stay_at(p_hostel);
  if st is null then raise exception 'only this hostel''s residents can say if they''re eating'; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) > 21 then raise exception 'send up to 21 meals at a time'; end if;
  for a in select * from jsonb_array_elements(p) loop
    d := (a ->> 'day')::date;
    m := a ->> 'meal';
    if m is null or m not in ('b', 'l', 'n') then raise exception 'pick breakfast, lunch or dinner'; end if;
    if d is null or d < public.ist_today() or d > public.ist_today() + 6 then raise exception 'pick a day in the next 7 days'; end if;
    if not public.can_rsvp(p_hostel, d, m) then raise exception 'the count for that meal has closed'; end if;
    insert into public.meal_rsvp (user_id, day, meal, hostel_id, stay_id, eating, updated_at)
    values (me, d, m, p_hostel, st, coalesce((a ->> 'eating')::boolean, true), now())
    on conflict (user_id, day, meal) do update
      set eating = excluded.eating, hostel_id = excluded.hostel_id, stay_id = excluded.stay_id, updated_at = now();
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.set_meal_cutoff(p_hostel uuid, p_hours int) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or managers set when the count closes'; end if;
  if p_hours is null or p_hours not between 2 and 4 then raise exception 'pick 2, 3 or 4 hours'; end if;
  update public.hostels set meal_cutoff_hours = p_hours where id = p_hostel;
end $$;

-- Plates saved: skips whose cut-off has passed.
create or replace function public.plate_saved(r public.meal_rsvp) returns boolean
language sql stable security definer set search_path = ''
as $$ select not r.eating and now() >= public.meal_cutoff_at(r.hostel_id, r.day, r.meal) $$;

create or replace function public.food_board(p_hostel uuid, p_from date, p_days int) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare me text := public.uid(); staff boolean; days int := least(greatest(coalesce(p_days, 7), 1), 14); today date := public.ist_today();
  wk date := public.ist_today() - (extract(isodow from public.ist_today())::int - 1);
  mon date := date_trunc('month', public.ist_today())::date;
  out jsonb;
begin
  if me is null then raise exception 'sign in first'; end if;
  staff := public.is_staff(p_hostel) or public.is_team();
  if not staff and public.my_stay_at(p_hostel) is null then raise exception 'only this hostel''s residents and staff see its meals'; end if;
  select jsonb_build_object(
    'cutoff', (select h.meal_cutoff_hours from public.hostels h where h.id = p_hostel),
    'counts', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'meal', m.meal,
        'residents', (select count(*) from public.stays s where s.hostel_id = p_hostel and s.confirmed and s.joined_on <= d.day and (s.left_on is null or s.left_on > d.day)),
        'skipping', (select count(*) from public.meal_rsvp r join public.stays s on s.hostel_id = p_hostel and s.user_id = r.user_id and s.confirmed and s.joined_on <= d.day and (s.left_on is null or s.left_on > d.day)
                     where r.hostel_id = p_hostel and r.day = d.day and r.meal = m.meal and not r.eating))
        order by d.day, m.ord)
      from (select (p_from + g)::date as day from generate_series(0, days - 1) g) d
      cross join (values ('b', 1), ('l', 2), ('n', 3)) m(meal, ord)), '[]'::jsonb),
    'mine', coalesce((
      select jsonb_agg(jsonb_build_object('day', r.day, 'meal', r.meal, 'eating', r.eating) order by r.day, r.meal)
      from public.meal_rsvp r where r.user_id = me and r.hostel_id = p_hostel and r.day between p_from and p_from + days - 1), '[]'::jsonb),
    'saved', jsonb_build_object(
      'you_week', (select count(*) from public.meal_rsvp r where r.user_id = me and r.day between wk and wk + 6 and public.plate_saved(r)),
      'you', (select count(*) from public.meal_rsvp r where r.user_id = me and public.plate_saved(r)),
      'hostel_month', (select count(*) from public.meal_rsvp r where r.hostel_id = p_hostel and r.day >= mon and public.plate_saved(r)),
      'hostel', (select count(*) from public.meal_rsvp r where r.hostel_id = p_hostel and public.plate_saved(r)),
      'hostelzy', (select count(*) from public.meal_rsvp r where public.plate_saved(r))),
    -- Names only for the hostel's own staff, only today, only their residents.
    'skippers', case when staff then coalesce((
      select jsonb_agg(jsonb_build_object('day', r.day, 'meal', r.meal, 'name', s.name,
        'bed', coalesce((select coalesce(ro.label, ro.number::text) || '-' || b.letter from public.beds b join public.rooms ro on ro.id = b.room_id where b.id = s.bed_id), ''))
        order by r.meal, s.name)
      from public.meal_rsvp r join public.stays s on s.hostel_id = p_hostel and s.user_id = r.user_id and s.confirmed and s.left_on is null
      where r.hostel_id = p_hostel and r.day = today and not r.eating), '[]'::jsonb) else '[]'::jsonb end
  ) into out;
  return out;
end $$;

create or replace function public.hostel_plates(p_hostels uuid[]) returns table (hostel_id uuid, n int)
language sql stable security definer set search_path = ''
as $$
  select r.hostel_id, count(*)::int from public.meal_rsvp r
  join public.hostels h on h.id = r.hostel_id and h.status = 'live'
  where r.hostel_id = any(p_hostels) and public.plate_saved(r)
  group by r.hostel_id
$$;

-- ------------------------------------------------------------ pushes

-- The ask goes 1 h before the cut-off, but never 10 pm – 7 am (then 9 pm the evening before).
create or replace function public.meal_ask_at(p_cut timestamptz) returns timestamptz
language sql stable set search_path = ''
as $$
  select case
    when extract(hour from ((p_cut - interval '1 hour') at time zone 'Asia/Kolkata')) < 7
      then ((((p_cut - interval '1 hour') at time zone 'Asia/Kolkata')::date - 1) + time '21:00') at time zone 'Asia/Kolkata'
    when extract(hour from ((p_cut - interval '1 hour') at time zone 'Asia/Kolkata')) >= 22
      then ((((p_cut - interval '1 hour') at time zone 'Asia/Kolkata')::date) + time '21:00') at time zone 'Asia/Kolkata'
    else p_cut - interval '1 hour' end
$$;

-- "8", "8:30" and "5:00 pm" in India time.
create or replace function public.meal_clock(t timestamptz, p_short boolean) returns text
language sql stable set search_path = ''
as $$
  select case when p_short and extract(minute from t at time zone 'Asia/Kolkata') = 0
    then to_char(t at time zone 'Asia/Kolkata', 'FMHH12')
    when p_short then to_char(t at time zone 'Asia/Kolkata', 'FMHH12:MI')
    else to_char(t at time zone 'Asia/Kolkata', 'FMHH12:MI') || ' ' || lower(to_char(t at time zone 'Asia/Kolkata', 'am')) end
$$;

create or replace function public.food_pushes() returns int
language plpgsql security definer set search_path = ''
as $$
declare x record; sent int := 0; k int;
begin
  for x in
    select h.id as hostel, h.name, d.day, m.meal, m.word,
      public.meal_cutoff_at(h.id, d.day, m.meal) as cut,
      (d.day + public.meal_start(h.id, d.day, m.meal)) at time zone 'Asia/Kolkata' as starts,
      trim(case m.meal when 'b' then mn.breakfast when 'l' then mn.lunch else mn.dinner end) as dish
    from public.hostels h
    cross join (values (public.ist_today()), (public.ist_today() + 1)) d(day)
    cross join (values ('b', 'Breakfast'), ('l', 'Lunch'), ('n', 'Dinner')) m(meal, word)
    join public.menus mn on mn.hostel_id = h.id and mn.day = extract(isodow from d.day)::int - 1
    where h.status = 'live'
      and trim(case m.meal when 'b' then mn.breakfast when 'l' then mn.lunch else mn.dinner end) <> ''
  loop
    -- Residents who haven't answered: 1 h before the cut-off.
    if now() >= public.meal_ask_at(x.cut) and now() < x.cut then
      insert into public.meal_push_log (hostel_id, day, meal, what) values (x.hostel, x.day, x.meal, 'ask')
      on conflict do nothing;
      get diagnostics k = row_count;
      if k > 0 then
        insert into public.push_outbox (user_id, title, body, data, kind)
        select s.user_id, x.word || ' at ' || public.meal_clock(x.starts, true) || ' · Eating?',
          x.dish || '. Tap Skip if you won’t be here. Closes at ' || public.meal_clock(x.cut, false) || '.',
          jsonb_build_object('screen', 'rHome', 'kind', 'food', 'ask', 'food', 'hostel', x.hostel, 'day', x.day, 'meal', x.meal), 'food'
        from public.stays s
        where s.hostel_id = x.hostel and s.confirmed and s.left_on is null and s.user_id is not null
          and not exists (select 1 from public.meal_rsvp r where r.user_id = s.user_id and r.day = x.day and r.meal = x.meal);
        get diagnostics k = row_count;
        sent := sent + k;
      end if;
    end if;
    -- Staff: the count at the cut-off (within 30 min, never at night).
    if now() >= x.cut and now() < x.cut + interval '30 minutes'
       and extract(hour from now() at time zone 'Asia/Kolkata') between 7 and 21 then
      insert into public.meal_push_log (hostel_id, day, meal, what) values (x.hostel, x.day, x.meal, 'count')
      on conflict do nothing;
      get diagnostics k = row_count;
      if k > 0 then
        insert into public.push_outbox (user_id, title, body, data, kind)
        select st.user_id, x.word || ' headcount: ' || (c.res - c.skip) || ' of ' || c.res,
          c.skip || ' skipping. Cook for ' || (c.res - c.skip) || '.',
          jsonb_build_object('screen', 'oMeals', 'kind', 'food', 'hostel', x.hostel), 'food'
        from public.hostel_staff st
        cross join lateral (
          select (select count(*) from public.stays s where s.hostel_id = x.hostel and s.confirmed and s.joined_on <= x.day and (s.left_on is null or s.left_on > x.day))::int as res,
            (select count(*) from public.meal_rsvp r join public.stays s on s.hostel_id = x.hostel and s.user_id = r.user_id and s.confirmed and s.left_on is null
             where r.hostel_id = x.hostel and r.day = x.day and r.meal = x.meal and not r.eating)::int as skip) c
        where st.hostel_id = x.hostel and c.res > 0;
        get diagnostics k = row_count;
        sent := sent + k;
      end if;
    end if;
  end loop;
  return sent;
end $$;

-- The push filter learns kind "food" (the Settings switch "Meals", on unless turned off).
create or replace function public.push_filter() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Never about your own action (the owner's own walk-in, their own repair…).
  if public.uid() is not null and new.user_id = public.uid() then return null; end if;
  -- A complaint raised by marking a thing not working (4zz1) isn't pushed again.
  if current_setting('hz.item_complaint', true) = 'on' and new.title like 'New complaint:%' then return null; end if;
  new.kind := coalesce(new.kind, new.data ->> 'kind', case
    when new.data ->> 'screen' in ('holds', 'hold') then 'hold'
    when new.title like 'New hold on bed%' then 'hold'
    when new.data ->> 'screen' = 'rPay' then 'rent'
  end);
  if new.kind not in ('hold', 'rent', 'beds', 'food') then new.kind := null; end if;
  if not public.wants_push(new.user_id, new.kind) then
    new.sent_at := now();
    new.error := 'switched off';
  end if;
  return new;
end $$;

revoke execute on function public.food_pushes(), public.push_filter(), public.meal_ask_at(timestamptz), public.meal_clock(timestamptz, boolean) from public, anon, authenticated;
revoke execute on function public.rsvp_meals(uuid, jsonb), public.set_meal_cutoff(uuid, int), public.food_board(uuid, date, int),
  public.can_rsvp(uuid, date, text), public.my_stay_at(uuid) from public, anon;
grant execute on function public.rsvp_meals(uuid, jsonb), public.set_meal_cutoff(uuid, int), public.food_board(uuid, date, int),
  public.can_rsvp(uuid, date, text), public.my_stay_at(uuid) to authenticated;
grant execute on function public.hostel_plates(uuid[]), public.meal_cutoff_at(uuid, date, text), public.meal_start(uuid, date, text),
  public.ist_today(), public.plate_saved(public.meal_rsvp) to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-food-pushes', '*/5 * * * *', 'select public.food_pushes()');
  end if;
end $$;
