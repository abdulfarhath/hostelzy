-- F27 Save food: answers before the cut-off only, counts, plates saved, the
-- owner's cut-off, names only for staff, the public chip and the pushes.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('f2700000-0000-0000-0000-000000000001', 'f27-live', 'F27 Live PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('f2700000-0000-0000-0000-000000000002', 'f27-other', 'F27 Other PG', 'Men', 'Madhapur', 'live', 'Lata');
insert into public.hostel_staff values
  ('f2700000-0000-0000-0000-000000000001', 'fb-f27-owner', 'owner'),
  ('f2700000-0000-0000-0000-000000000001', 'fb-f27-mgr', 'manager'),
  ('f2700000-0000-0000-0000-000000000002', 'fb-f27-other', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('f2710000-0000-0000-0000-000000000001', 'f2700000-0000-0000-0000-000000000001', 204, 2, 3, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('f2720000-0000-0000-0000-000000000001', 'f2700000-0000-0000-0000-000000000001', 'f2710000-0000-0000-0000-000000000001', 'B');
insert into public.stays (hostel_id, bed_id, user_id, name, confirmed, left_on, joined_on) values
  ('f2700000-0000-0000-0000-000000000001', 'f2720000-0000-0000-0000-000000000001', 'fb-f27-res', 'Rahul V', true, null, current_date - 30),
  ('f2700000-0000-0000-0000-000000000001', null, 'fb-f27-res2', 'Arjun R', true, null, current_date - 30),
  ('f2700000-0000-0000-0000-000000000001', null, 'fb-f27-new', 'Not Confirmed', false, null, current_date - 30),
  ('f2700000-0000-0000-0000-000000000001', null, 'fb-f27-left', 'Moved Out', true, current_date - 3, current_date - 90),
  ('f2700000-0000-0000-0000-000000000002', null, 'fb-f27-ores', 'Other Res', true, null, current_date - 30);
-- A menu every day; today's breakfast is at midnight, so its count closed last night.
insert into public.menus (hostel_id, day, breakfast, lunch, dinner)
select 'f2700000-0000-0000-0000-000000000001', d, 'Idli', 'Rice, dal', 'Chapati, dal' from generate_series(0, 6) d;
update public.menus set breakfast_time = '00:00-00:30'
where hostel_id = 'f2700000-0000-0000-0000-000000000001' and day = extract(isodow from public.ist_today())::int - 1;

create function pg_temp.ans(d int, m text, e boolean) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('day', public.ist_today() + d, 'meal', m, 'eating', e))
$$;

-- ------------------------------------------------------------ defaults and the cut-off
select test.eq((select meal_cutoff_hours from public.hostels where id = 'f2700000-0000-0000-0000-000000000001')::text, '3');
select test.eq(public.meal_start('f2700000-0000-0000-0000-000000000001', public.ist_today() + 1, 'n')::text, '20:00:00');
-- 8 pm dinner, 3 h: closes 5 pm India time
select test.eq(to_char(public.meal_cutoff_at('f2700000-0000-0000-0000-000000000001', public.ist_today() + 1, 'n') at time zone 'Asia/Kolkata', 'HH24:MI'), '17:00');

-- ------------------------------------------------------------ a resident answers
select test.act('authenticated', 'fb-f27-res');
select test.eq(public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false))::text, '1');
-- one row per meal: a second tap changes it
select test.eq(public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', true))::text, '1');
select test.eq(public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false) || pg_temp.ans(3, 'b', false))::text, '2');
select test.rows($$select count(*) from public.meal_rsvp where user_id = 'fb-f27-res'$$, 2);
-- locked after the cut-off (server-enforced), the whole batch fails
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(0, 'b', false))$$, 'has closed');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(4, 'l', false) || pg_temp.ans(0, 'b', false))$$, 'has closed');
select test.rows($$select count(*) from public.meal_rsvp where user_id = 'fb-f27-res'$$, 2);
-- also straight into the table
select test.blocked($$insert into public.meal_rsvp (user_id, day, meal, hostel_id, eating) values ('fb-f27-res', public.ist_today(), 'b', 'f2700000-0000-0000-0000-000000000001', false)$$);
select test.blocked($$update public.meal_rsvp set eating = true, day = public.ist_today() where user_id = 'fb-f27-res' and meal = 'b'$$);
-- not before today, not after 6 days, not someone else's row
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(-1, 'n', false))$$, 'next 7 days');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(7, 'n', false))$$, 'next 7 days');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'x', false))$$, 'breakfast, lunch or dinner');
select test.blocked($$insert into public.meal_rsvp (user_id, day, meal, hostel_id, eating) values ('fb-f27-res2', public.ist_today() + 2, 'n', 'f2700000-0000-0000-0000-000000000001', false)$$);
-- only confirmed residents who haven't left, of THIS hostel
select test.act('authenticated', 'fb-f27-new');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false))$$, 'residents can say');
select test.act('authenticated', 'fb-f27-left');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false))$$, 'residents can say');
select test.act('authenticated', 'fb-f27-ores');
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false))$$, 'residents can say');
select test.act('anon', null);
select test.fails($$select public.rsvp_meals('f2700000-0000-0000-0000-000000000001', pg_temp.ans(2, 'n', false))$$, 'sign in first');

-- ------------------------------------------------------------ who reads what
select test.act('authenticated', 'fb-f27-res2');
select test.rows($$select count(*) from public.meal_rsvp$$, 0);
select test.act('authenticated', 'fb-f27-mgr');
select test.rows($$select count(*) from public.meal_rsvp$$, 2);
select test.act('authenticated', 'fb-f27-other');
select test.rows($$select count(*) from public.meal_rsvp$$, 0);
select test.fails($$select public.food_board('f2700000-0000-0000-0000-000000000001', public.ist_today(), 7)$$, 'residents and staff see');
select test.act('anon', null);
select test.rows($$select count(*) from public.meal_rsvp$$, 0);

-- ------------------------------------------------------------ counts and plates saved
-- An answer given before today's breakfast closed (written as the server would have taken it).
reset role;
insert into public.meal_rsvp (user_id, day, meal, hostel_id, eating) values
  ('fb-f27-res', public.ist_today(), 'b', 'f2700000-0000-0000-0000-000000000001', false),
  ('fb-f27-res2', public.ist_today(), 'b', 'f2700000-0000-0000-0000-000000000001', false),
  ('fb-f27-ores', public.ist_today(), 'b', 'f2700000-0000-0000-0000-000000000002', true);
select test.act('authenticated', 'fb-f27-res');
select set_config('hz.b', public.food_board('f2700000-0000-0000-0000-000000000001', public.ist_today(), 7)::text, false);
select test.eq(current_setting('hz.b')::jsonb ->> 'cutoff', '3');
select test.eq(jsonb_array_length(current_setting('hz.b')::jsonb -> 'counts')::text, '21');
-- today's breakfast: 2 residents (not the unconfirmed one, not the one who left), both skipping
select test.eq((select c::text from jsonb_array_elements(current_setting('hz.b')::jsonb -> 'counts') c where c ->> 'meal' = 'b' and (c ->> 'day')::date = public.ist_today()),
  jsonb_build_object('day', public.ist_today(), 'meal', 'b', 'residents', 2, 'skipping', 2)::text);
select test.eq((select c ->> 'skipping' from jsonb_array_elements(current_setting('hz.b')::jsonb -> 'counts') c where c ->> 'meal' = 'n' and (c ->> 'day')::date = public.ist_today() + 2), '1');
select test.eq(jsonb_array_length(current_setting('hz.b')::jsonb -> 'mine')::text, '3');
-- saved = skips whose cut-off passed: today's breakfast only (the future skips aren't saved yet)
select test.eq(current_setting('hz.b')::jsonb -> 'saved' ->> 'you', '1');
select test.eq(current_setting('hz.b')::jsonb -> 'saved' ->> 'you_week', '1');
select test.eq(current_setting('hz.b')::jsonb -> 'saved' ->> 'hostel', '2');
select test.eq(current_setting('hz.b')::jsonb -> 'saved' ->> 'hostel_month', '2');
select test.eq(current_setting('hz.b')::jsonb -> 'saved' ->> 'hostelzy', '2');
-- a resident never sees names
select test.eq(current_setting('hz.b')::jsonb ->> 'skippers', '[]');
-- staff see their own residents' names and beds, today only
select test.act('authenticated', 'fb-f27-owner');
select set_config('hz.o', public.food_board('f2700000-0000-0000-0000-000000000001', public.ist_today(), 7)::text, false);
select test.eq((select string_agg((x ->> 'name') || ' ' || (x ->> 'bed'), ', ' order by x ->> 'name') from jsonb_array_elements(current_setting('hz.o')::jsonb -> 'skippers') x), 'Arjun R , Rahul V 204-B');
-- the public chip: counts only, no names, live hostels
select test.act('anon', null);
select test.eq((select string_agg(n::text, ',') from public.hostel_plates(array['f2700000-0000-0000-0000-000000000001', 'f2700000-0000-0000-0000-000000000002']::uuid[])), '2');

-- ------------------------------------------------------------ the owner's cut-off
select test.act('authenticated', 'fb-f27-mgr');
select public.set_meal_cutoff('f2700000-0000-0000-0000-000000000001', 4);
select test.eq((select meal_cutoff_hours from public.hostels where id = 'f2700000-0000-0000-0000-000000000001')::text, '4');
select test.fails($$select public.set_meal_cutoff('f2700000-0000-0000-0000-000000000001', 5)$$, '2, 3 or 4');
select test.fails($$select public.set_meal_cutoff('f2700000-0000-0000-0000-000000000001', 1)$$, '2, 3 or 4');
select test.act('authenticated', 'fb-f27-res');
select test.fails($$select public.set_meal_cutoff('f2700000-0000-0000-0000-000000000001', 2)$$, 'owner or managers');
select test.blocked($$update public.hostels set meal_cutoff_hours = 2 where id = 'f2700000-0000-0000-0000-000000000001'$$);
select test.act('authenticated', 'fb-f27-owner');
select public.set_meal_cutoff('f2700000-0000-0000-0000-000000000001', 3);

-- ------------------------------------------------------------ pushes
select test.eq(to_char(public.meal_ask_at('2026-10-06 17:00+05:30') at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI'), '2026-10-06 16:00');
-- breakfast at 7:30 closes 4:30 am: asked at 9 pm the evening before, not at 3:30 am
select test.eq(to_char(public.meal_ask_at('2026-10-07 04:30+05:30') at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI'), '2026-10-06 21:00');
select test.eq(to_char(public.meal_ask_at('2026-10-06 23:30+05:30') at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI'), '2026-10-06 21:00');
select test.eq(public.meal_clock('2026-10-06 20:00+05:30', true), '8');
select test.eq(public.meal_clock('2026-10-06 17:00+05:30', false), '5:00 pm');

-- Lunch starts 3 h 20 min from now: its count closes in 20 min, so residents who haven't answered get the ask.
reset role;
select set_config('hz.at', to_char((now() + interval '3 hours 20 minutes') at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI'), false);
update public.menus set lunch_time = split_part(current_setting('hz.at'), ' ', 2) || '-23:59'
where hostel_id = 'f2700000-0000-0000-0000-000000000001' and day = extract(isodow from split_part(current_setting('hz.at'), ' ', 1)::date)::int - 1;
-- Rahul already answered for that lunch; Arjun hasn't.
insert into public.meal_rsvp (user_id, day, meal, hostel_id, eating) values
  ('fb-f27-res', split_part(current_setting('hz.at'), ' ', 1)::date, 'l', 'f2700000-0000-0000-0000-000000000001', true)
on conflict (user_id, day, meal) do update set eating = true;
delete from public.push_outbox;
select public.food_pushes();
select test.rows($$select count(*) from public.push_outbox where kind = 'food' and data ->> 'meal' = 'l' and data ->> 'ask' = 'food'$$, 1);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f27-res2' and title like 'Lunch at % · Eating?' and body like 'Rice, dal. Tap Skip if you won’t be here. Closes at %'$$, 1);
-- once only
select public.food_pushes();
select test.rows($$select count(*) from public.push_outbox where data ->> 'meal' = 'l' and data ->> 'ask' = 'food'$$, 1);
-- the Settings switch "Meals" off: closed at once, never sent
update public.profiles set notify = notify || '{"food": false}' where id = 'fb-f27-res2';
insert into public.profiles (id, name, phone, notify) values ('fb-f27-res2', 'Arjun R', '9000027002', '{"food": false}') on conflict (id) do nothing;
insert into public.push_outbox (user_id, title, body, data) values ('fb-f27-res2', 'Dinner at 8 · Eating?', 'x', '{"kind": "food"}');
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f27-res2' and title = 'Dinner at 8 · Eating?' and error = 'switched off'$$, 1);

-- Dinner started 2 h 50 min from now 10 min ago: closed 10 min ago, the staff get the headcount (daytime only).
select set_config('hz.at', to_char((now() + interval '2 hours 50 minutes') at time zone 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI'), false);
update public.menus set dinner_time = split_part(current_setting('hz.at'), ' ', 2) || '-23:59'
where hostel_id = 'f2700000-0000-0000-0000-000000000001' and day = extract(isodow from split_part(current_setting('hz.at'), ' ', 1)::date)::int - 1;
select public.food_pushes();
do $$
begin
  if extract(hour from now() at time zone 'Asia/Kolkata') between 7 and 21 then
    perform test.rows($q$select count(*) from public.push_outbox where data ->> 'screen' = 'oMeals' and title like 'Dinner headcount: % of 2'$q$, 2);
  else
    perform test.rows($q$select count(*) from public.push_outbox where data ->> 'screen' = 'oMeals'$q$, 0);
  end if;
end $$;
reset role;
\o
select 'ALL F27 SAVE FOOD TESTS PASSED';
