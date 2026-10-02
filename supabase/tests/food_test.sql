-- Food menu and meal ratings: runs after the other tests (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2400000-0000-0000-0000-000000000001', 'food-live', 'Food Live PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('a2400000-0000-0000-0000-000000000002', 'food-draft', 'Food Draft PG', 'Women', 'Kondapur', 'draft', 'Lata');
insert into public.hostel_staff values
  ('a2400000-0000-0000-0000-000000000001', 'fb-fd-owner', 'owner'),
  ('a2400000-0000-0000-0000-000000000002', 'fb-fd-draft', 'owner');
insert into public.stays (hostel_id, user_id, name, confirmed, left_on) values
  ('a2400000-0000-0000-0000-000000000001', 'fb-fd-res', 'Priya Sharma', true, null),
  ('a2400000-0000-0000-0000-000000000001', 'fb-fd-res2', 'Kiran Rao', true, null),
  ('a2400000-0000-0000-0000-000000000001', 'fb-fd-new', 'Not Confirmed', false, null),
  ('a2400000-0000-0000-0000-000000000001', 'fb-fd-left', 'Moved Out', true, current_date - 3),
  ('a2400000-0000-0000-0000-000000000002', 'fb-fd-dres', 'Draft Resident', true, null);

-- the owner saves the week (all 7 days at once, again to change it)
select test.act('authenticated', 'fb-fd-owner');
insert into public.menus (hostel_id, day, breakfast, lunch, dinner)
select 'a2400000-0000-0000-0000-000000000001', d, 'Idli ' || d, 'Rice ' || d, 'Chapati ' || d from generate_series(0, 6) d
on conflict (hostel_id, day) do update set breakfast = excluded.breakfast, lunch = excluded.lunch, dinner = excluded.dinner;
insert into public.menus (hostel_id, day, breakfast) values ('a2400000-0000-0000-0000-000000000001', 0, 'Dosa')
on conflict (hostel_id, day) do update set breakfast = excluded.breakfast;
select test.eq((select breakfast from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000001' and day = 0), 'Dosa');
select test.act('authenticated', 'fb-fd-draft');
insert into public.menus (hostel_id, day, breakfast) values ('a2400000-0000-0000-0000-000000000002', 0, 'Upma');
-- not someone else's hostel
select test.blocked($$insert into public.menus (hostel_id, day, breakfast) values ('a2400000-0000-0000-0000-000000000001', 1, 'Poori')$$);
-- a resident can't change it
select test.act('authenticated', 'fb-fd-res');
select test.blocked($$update public.menus set breakfast = 'x' where hostel_id = 'a2400000-0000-0000-0000-000000000001'$$);

-- reading: anyone sees a live hostel's menu; a draft hostel's only its own people
select test.act('anon', null);
select test.rows($$select count(*) from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000001'$$, 7);
select test.rows($$select count(*) from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000002'$$, 0);
select test.act('authenticated', 'fb-fd-res');
select test.rows($$select count(*) from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000002'$$, 0);
select test.act('authenticated', 'fb-fd-dres');
select test.rows($$select count(*) from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000002'$$, 1);
select test.act('authenticated', 'fb-fd-draft');
select test.rows($$select count(*) from public.menus where hostel_id = 'a2400000-0000-0000-0000-000000000002'$$, 1);

-- ratings: confirmed residents only, one per meal per day
select test.act('authenticated', 'fb-fd-res');
select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'Good');
select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'poor');
select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'l', 'okay');
select test.act('authenticated', 'fb-fd-res2');
select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'good');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'x', 'good')$$, 'pick breakfast, lunch or dinner');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'great')$$, 'pick good, okay or poor');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000002', 'b', 'good')$$, 'only this hostel''s residents');
select test.act('authenticated', 'fb-fd-new');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'good')$$, 'only this hostel''s residents');
select test.act('authenticated', 'fb-fd-left');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'good')$$, 'only this hostel''s residents');
select test.act('authenticated', 'fb-fd-owner');
select test.fails($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'good')$$, 'only this hostel''s residents');
select test.act('anon', null);
select test.blocked($$select public.rate_meal('a2400000-0000-0000-0000-000000000001', 'b', 'good')$$);

-- nobody reads the rows, not even the owner
select test.act('authenticated', 'fb-fd-res');
select test.rows($$select count(*) from public.meal_ratings$$, 0);
select test.act('authenticated', 'fb-fd-owner');
select test.rows($$select count(*) from public.meal_ratings$$, 0);
select test.blocked($$insert into public.meal_ratings (hostel_id, user_id, meal, rating) values ('a2400000-0000-0000-0000-000000000001', 'fb-fd-owner', 'b', 'good')$$);

-- the owner and the team get counts, no names
select test.eq((select string_agg(meal || ':' || rating || '=' || n, ' ') from public.meal_votes('a2400000-0000-0000-0000-000000000001')), 'b:good=1 b:poor=1 l:okay=1');
select test.act('authenticated', 'fb-fd-hq', true);
select test.eq((select sum(n)::text from public.meal_votes('a2400000-0000-0000-0000-000000000001')), '3');
select test.act('authenticated', 'fb-fd-res');
select test.fails($$select * from public.meal_votes('a2400000-0000-0000-0000-000000000001')$$, 'only this hostel''s owner and managers');
select test.act('authenticated', 'fb-fd-draft');
select test.fails($$select * from public.meal_votes('a2400000-0000-0000-0000-000000000001')$$, 'only this hostel''s owner and managers');

-- older than a week drops out
reset role;
update public.meal_ratings set day = day - 7 where user_id = 'fb-fd-res2';
select test.act('authenticated', 'fb-fd-owner');
select test.eq((select string_agg(meal || ':' || rating || '=' || n, ' ') from public.meal_votes('a2400000-0000-0000-0000-000000000001')), 'b:poor=1 l:okay=1');

\o
select 'ALL FOOD TESTS PASSED';
