-- F24 Wave 3a: owner-only areas (17), AC unit on rate/room changes (19),
-- featured spot and resident-only complaints in the ranking (20), deals pause
-- and money pushes (21).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, terms) values
  ('a5000000-0000-0000-0000-000000000001', 'w3-one', 'Wave Three PG', 'Men', 'Madhapur', 'live', 'Ravi',
   '{"advance":3000,"maintenance":1000,"noticeDays":30,"dueOnJoining":true,"electricityExtra":true}'),
  ('a5000000-0000-0000-0000-000000000002', 'w3-big', 'Big Wave PG', 'Men', 'Madhapur', 'live', 'Lata',
   '{"advance":3000,"maintenance":1000,"noticeDays":30,"dueOnJoining":false,"electricityExtra":true}');
insert into public.hostel_staff values
  ('a5000000-0000-0000-0000-000000000001', 'fb-w3-owner', 'owner'),
  ('a5000000-0000-0000-0000-000000000001', 'fb-w3-mgr', 'manager'),
  ('a5000000-0000-0000-0000-000000000002', 'fb-w3-big', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent, ac) values
  ('a5100000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000001', 101, 1, 2, 8000, false),
  ('a5100000-0000-0000-0000-000000000002', 'a5000000-0000-0000-0000-000000000001', 102, 1, 2, 8000, false),
  ('a5100000-0000-0000-0000-000000000003', 'a5000000-0000-0000-0000-000000000001', 103, 1, 2, 8000, false);
insert into public.beds (hostel_id, room_id, letter)
select 'a5000000-0000-0000-0000-000000000001', r.id, l from public.rooms r, unnest(array['A', 'B']) l
where r.hostel_id = 'a5000000-0000-0000-0000-000000000001';
-- 101 has a published layout with no AC unit; 102 has one with an AC unit; 103 has none.
insert into public.layouts (hostel_id, room, stage, w, h, items) values
  ('a5000000-0000-0000-0000-000000000001', 101, 'published', 12, 14, '[{"id":"fan1","kind":"fan","x":5,"y":5,"w":2,"h":2}]'),
  ('a5000000-0000-0000-0000-000000000001', 102, 'published', 12, 14, '[{"id":"ac1","kind":"ac","x":1,"y":0,"w":3,"h":1}]');
insert into public.rate_cards values ('a5000000-0000-0000-0000-000000000001', false, 2, 8000);
insert into public.deals (hostel_id, deals_on, target) values ('a5000000-0000-0000-0000-000000000001', '{monthly}', 'all');
insert into public.owner_plans (hostel_id, status, trial_ends) values
  ('a5000000-0000-0000-0000-000000000001', 'active', current_date - 60),
  ('a5000000-0000-0000-0000-000000000002', 'active', current_date - 60);
insert into public.fair_cases (hostel_id, ref, title, signal, status, resident) values
  ('a5000000-0000-0000-0000-000000000001', 'FP-W3-1', 'Teja · 101-A', 'test', 'new', 'Teja');
insert into public.strikes (hostel_id) values ('a5000000-0000-0000-0000-000000000001');

-- ================================================================ 17. owner-only areas
-- A manager can't change rates or deals ...
select test.act('authenticated', 'fb-w3-mgr');
select test.blocked($$insert into public.rate_cards values ('a5000000-0000-0000-0000-000000000001', true, 2, 9000)$$);
select test.blocked($$update public.rate_cards set rent = 1 where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$);
select test.blocked($$update public.deals set deals_on = '{}' where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$);
select test.blocked($$delete from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$);
select test.fails($$update public.rooms set rent = 1 where number = 101 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 'only the owner changes rates');
select test.fails($$update public.rooms set ac = true where number = 103 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 'only the owner changes rates');
-- ... but still reads them, and still runs the rooms (a room's bath, a new room)
select test.rows($$select count(*) from public.rate_cards where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$update public.rooms set bath = 'Attached' where number = 101 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
-- ... and can't read the plan, invoices, Fair Play cases or strikes, nor fix a case
select test.rows($$select count(*) from public.owner_plans where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 0);
select test.rows($$select count(*) from public.fair_cases where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 0);
select test.rows($$select count(*) from public.strikes where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 0);
reset role;
select test.fails(format($$select set_config('request.jwt.claims', %L, true), public.fix_case(id) from public.fair_cases where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$,
  jsonb_build_object('sub', 'fb-w3-mgr', 'role', 'authenticated', 'iss', 'https://securetoken.google.com/hostelzy', 'aud', 'hostelzy', 'firebase', jsonb_build_object('sign_in_provider', 'google.com'))::text), 'only the owner handles Fair Play');
-- The owner does all of it
select test.act('authenticated', 'fb-w3-owner');
select test.rows($$insert into public.rate_cards values ('a5000000-0000-0000-0000-000000000001', true, 2, 9500)$$, 1);
select test.rows($$update public.deals set target = 'ac' where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$update public.rooms set rent = 8200 where number = 101 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$select count(*) from public.owner_plans where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$select count(*) from public.fair_cases where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$select count(*) from public.strikes where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$update public.fair_cases set owner_reply = 'He walked in' where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);

-- ================================================================ 19. AC unit on a room change
-- 101's layout has no AC unit: it can't become AC; 102's has one; 103 has no layout yet.
select test.fails($$update public.rooms set ac = true, rent = 9500 where number = 101 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 'room 101: an AC room needs an AC unit');
select test.rows($$update public.rooms set ac = true, rent = 9500 where number = 102 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.rows($$update public.rooms set ac = true, rent = 9500 where number = 103 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
-- also through save_rooms (Rooms and floors), and for the team
select test.fails($$select public.save_rooms('a5000000-0000-0000-0000-000000000001', '[{"number":101,"floor":1,"share":2,"ac":true,"rent":9500},{"number":102,"floor":1,"share":2,"ac":true,"rent":9500},{"number":103,"floor":1,"share":2,"ac":true,"rent":9500}]')$$, 'needs an AC unit');
select test.act('authenticated', 'fb-w3-team', true);
select test.fails($$update public.rooms set ac = true where number = 101 and hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 'needs an AC unit');
-- a manager's save_rooms that keeps rent and AC as they are still works
select test.act('authenticated', 'fb-w3-mgr');
select public.save_rooms('a5000000-0000-0000-0000-000000000001', '[{"number":101,"floor":1,"share":2,"ac":false,"rent":8200},{"number":102,"floor":1,"share":2,"ac":true,"rent":9500},{"number":103,"floor":1,"share":2,"ac":true,"rent":9500},{"number":104,"floor":1,"share":2,"ac":false,"rent":8200}]');
select test.rows($$select count(*) from public.rooms where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 4);

-- ================================================================ 20. featured spot, resident complaints
reset role;
select set_config('request.jwt.claims', '', false);
-- Big Wave: 81 beds (more than 80 → the ₹1,499 plan, featured).
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('a5100000-0000-0000-0000-000000000009', 'a5000000-0000-0000-0000-000000000002', 101, 1, 8, 6000);
insert into public.beds (hostel_id, room_id, letter)
select 'a5000000-0000-0000-0000-000000000002', 'a5100000-0000-0000-0000-000000000009', 'B' || g from generate_series(1, 81) g;
select test.act('anon', null);
select test.eq((select beds || ' ' || featured || ' ' || deals_paused from public.hostel_flags() where hostel_id = 'a5000000-0000-0000-0000-000000000002'), '81 true false');
select test.eq((select beds || ' ' || featured from public.hostel_flags() where hostel_id = 'a5000000-0000-0000-0000-000000000001'), '8 false');
-- 80 beds is the ₹999 plan: not featured
reset role;
delete from public.beds where hostel_id = 'a5000000-0000-0000-0000-000000000002' and letter = 'B81';
select test.act('anon', null);
select test.eq((select featured::text from public.hostel_flags() where hostel_id = 'a5000000-0000-0000-0000-000000000002'), 'false');
reset role;
insert into public.beds (hostel_id, room_id, letter) values ('a5000000-0000-0000-0000-000000000002', 'a5100000-0000-0000-0000-000000000009', 'B81');

-- The owner's own "Not working" doesn't count; a resident's complaint does.
insert into public.stays (hostel_id, user_id, name, confirmed, joined_on, rent) values
  ('a5000000-0000-0000-0000-000000000001', 'fb-w3-res', 'Teja', true, current_date - 40, 8000);
select test.act('authenticated', 'fb-w3-owner');
select public.set_item_working('a5000000-0000-0000-0000-000000000001', 101, 'fan1', false);
select test.act('authenticated', 'fb-w3-res');
insert into public.complaints (hostel_id, bed, cat, body) values ('a5000000-0000-0000-0000-000000000001', '101-A', 'Wi-Fi', 'Slow');
select test.act('anon', null);
select test.eq((select complaints_30d::text from public.hostel_signals() where hostel_id = 'a5000000-0000-0000-0000-000000000001'), '1');
reset role;
select test.rows($$select count(*) from public.complaints where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 2);

-- ================================================================ 21. new invoice push, deals pause, money pushes
reset role;
select set_config('request.jwt.claims', '', false);
delete from public.push_outbox;
insert into public.invoices (ref, hostel_id, beds, amount, due) values
  ('HZ-INV-W3-1', 'a5000000-0000-0000-0000-000000000001', 8, 499, (now() at time zone 'Asia/Kolkata')::date - 6),
  ('HZ-INV-W3-2', 'a5000000-0000-0000-0000-000000000002', 81, 1499, (now() at time zone 'Asia/Kolkata')::date - 16);
-- only the owners hear about the invoice, not the manager
select test.rows($$select count(*) from public.push_outbox where title = 'New Hostelzy invoice: ₹499' and user_id = 'fb-w3-owner' and data ->> 'kind' = 'plan' and kind is null$$, 1);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-mgr'$$, 0);
select test.rows($$select count(*) from public.push_outbox where title = 'New Hostelzy invoice: ₹1,499' or title = 'New Hostelzy invoice: ₹1499'$$, 1);
-- a manager can't read the invoice; the owner can
select test.act('authenticated', 'fb-w3-mgr');
select test.rows($$select count(*) from public.invoices where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 0);
select test.act('authenticated', 'fb-w3-owner');
select test.rows($$select count(*) from public.invoices where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);

-- Big Wave is 16 days late: deals paused, featured spot gone; a tenant can't read its deals.
reset role;
insert into public.deals (hostel_id, deals_on, target) values ('a5000000-0000-0000-0000-000000000002', '{monthly}', 'all');
select test.act('authenticated', 'fb-w3-tenant');
select test.eq((select featured || ' ' || deals_paused from public.hostel_flags() where hostel_id = 'a5000000-0000-0000-0000-000000000002'), 'false true');
select test.eq(public.deals_paused('a5000000-0000-0000-0000-000000000002')::text, 'true');
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000002'$$, 0);
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000001'$$, 1);
select test.act('anon', null);
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000002'$$, 0);
-- its owner still sees them
select test.act('authenticated', 'fb-w3-big');
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000002'$$, 1);

-- Money pushes: 6 days late → reminder; 16 days → deals paused; rent due today.
reset role;
select set_config('request.jwt.claims', '', false);
-- Teja joined a year ago today (rent due today); Arun's hostel bills on the 1st.
update public.stays set joined_on = ((now() at time zone 'Asia/Kolkata')::date - interval '1 year')::date where user_id = 'fb-w3-res';
insert into public.stays (hostel_id, user_id, name, confirmed, joined_on, rent) values
  ('a5000000-0000-0000-0000-000000000002', 'fb-w3-res2', 'Arun', true, current_date - 100, 6000),
  ('a5000000-0000-0000-0000-000000000001', 'fb-w3-paid', 'Kiran', true, ((now() at time zone 'Asia/Kolkata')::date - interval '2 years')::date, 8000);
insert into public.payments (hostel_id, payer_id, kind, amount, status) values ('a5000000-0000-0000-0000-000000000001', 'fb-w3-paid', 'rent', 8000, 'waiting');
delete from public.push_outbox;
select public.money_pushes();
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-owner' and title = 'Your Hostelzy plan is 6 days late' and data ->> 'screen' = 'oPlan'$$, 1);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-big' and title = 'Deals paused: plan 16 days late'$$, 1);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-mgr'$$, 0);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-res' and title = 'Rent due today' and kind = 'rent' and body = '₹8000 to Wave Three PG. Pay by UPI from Pay rent.'$$, 1);
select test.eq((select count(*)::text from public.push_outbox where user_id = 'fb-w3-res2'),
  case when extract(day from (now() at time zone 'Asia/Kolkata')::date) = 1 then '1' else '0' end);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-paid'$$, 0);
-- twice in a day: nothing new
select public.money_pushes();
select test.rows($$select count(*) from public.push_outbox where title like 'Your Hostelzy plan%' or title like 'Deals paused%'$$, 2);
select test.rows($$select count(*) from public.push_outbox where title = 'Rent due today' and user_id = 'fb-w3-res'$$, 1);
-- the Rent switch off: closed, never sent
update public.stays set rent_reminded_on = null;
insert into public.profiles (id, name, notify) values ('fb-w3-res', 'Teja', '{"rent": false}') on conflict (id) do update set notify = excluded.notify;
delete from public.push_outbox;
select public.money_pushes();
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-res' and sent_at is null$$, 0);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w3-res' and error = 'switched off'$$, 1);
-- paid: deals back on
update public.invoices set status = 'paid' where ref = 'HZ-INV-W3-2';
select test.act('anon', null);
select test.rows($$select count(*) from public.deals where hostel_id = 'a5000000-0000-0000-0000-000000000002'$$, 1);
select test.eq((select featured || ' ' || deals_paused from public.hostel_flags() where hostel_id = 'a5000000-0000-0000-0000-000000000002'), 'true false');

reset role;
\o
select 'ALL WAVE 3A TESTS PASSED';
