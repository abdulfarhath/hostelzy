-- F24 Wave 2a: Working / Not working (7), walk-in holds (8), notification
-- switches and New free beds (22), team tracker and members (29).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a3000000-0000-0000-0000-000000000001', 'w2-one', 'Wave Two PG', 'Men', 'Ameerpet', 'live', 'Ravi'),
  ('a3000000-0000-0000-0000-000000000002', 'w2-draft', 'Wave Draft PG', 'Men', 'SR Nagar', 'draft', 'Lata');
insert into public.profiles (id, name, phone) values ('fb-w2-owner', 'Ravi', '9876543210'), ('fb-w2-mgr', 'Manoj', '9000011111');
insert into public.hostel_staff values
  ('a3000000-0000-0000-0000-000000000001', 'fb-w2-owner', 'owner'),
  ('a3000000-0000-0000-0000-000000000001', 'fb-w2-mgr', 'manager');
insert into public.rooms (id, hostel_id, number, floor, share, rent, ac) values
  ('a3100000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 204, 2, 3, 9000, true);
insert into public.beds (id, hostel_id, room_id, letter, state) values
  ('a3200000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000001', 'A', 'free'),
  ('a3200000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000001', 'B', 'booked'),
  ('a3200000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', 'a3100000-0000-0000-0000-000000000001', 'C', 'soon');
insert into public.layouts (hostel_id, room, stage, w, h, items) values
  ('a3000000-0000-0000-0000-000000000001', 204, 'published', 12, 14,
   '[{"id":"ac1","kind":"ac","x":1,"y":0,"w":3,"h":1,"working":true},{"id":"fan1","kind":"fan","x":5,"y":5,"w":2,"h":2,"working":true},{"id":"door1","kind":"door","x":0,"y":5,"w":1,"h":3}]');

-- ================================================================ 7. Working / Not working
select test.act('authenticated', 'fb-w2-stranger');
select test.fails($$select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'ac1', false)$$, 'only this hostel');
select test.act('anon', null);
select test.blocked($$select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'ac1', false)$$);
select test.act('authenticated', 'fb-w2-owner');
select test.fails($$select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'door1', false)$$, 'only fans, the AC and windows');
select test.fails($$select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'fan9', false)$$, 'publish this room');
select test.eq(public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'ac1', false)::date::text, (now() at time zone 'Asia/Kolkata')::date::text);
-- twice: still one complaint, same date
select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'ac1', false);
select test.rows($$select count(*) from public.complaints where hostel_id = 'a3000000-0000-0000-0000-000000000001' and item = 'layout:204:ac1' and status = 'Open' and cat = 'AC' and bed = 'Room 204'$$, 1);
-- a tenant sees it on the room: AC under repair since today, the item not working
select test.act('authenticated', 'fb-w2-tenant');
select test.eq((select ac_repair || ' ' || (ac_repair_since = (now() at time zone 'Asia/Kolkata')::date) from public.rooms where number = 204 and hostel_id = 'a3000000-0000-0000-0000-000000000001'), 'true true');
select test.eq((select e ->> 'working' from public.layouts l, jsonb_array_elements(l.items) e where l.hostel_id = 'a3000000-0000-0000-0000-000000000001' and e ->> 'id' = 'ac1'), 'false');
-- the owner doesn't get a push about their own mark; the manager doesn't get a second one
reset role;
select test.rows($$select count(*) from public.push_outbox where title like 'New complaint: AC%'$$, 0);
-- working again: complaint Fixed, room back to normal
select test.act('authenticated', 'fb-w2-mgr');
select test.eq(coalesce(public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'ac1', true)::text, 'none'), 'none');
reset role;
select test.rows($$select count(*) from public.complaints where item = 'layout:204:ac1' and status = 'Fixed' and note = 'Working again'$$, 1);
select test.eq((select ac_repair || ' ' || coalesce(ac_repair_since::text, '-') from public.rooms where number = 204 and hostel_id = 'a3000000-0000-0000-0000-000000000001'), 'false -');
select test.eq((select (e ? 'down_since')::text || ' ' || (e ->> 'working') from public.layouts l, jsonb_array_elements(l.items) e where l.hostel_id = 'a3000000-0000-0000-0000-000000000001' and e ->> 'id' = 'ac1'), 'false true');
-- a fan: complaint "Fan 1 in room 204"
select test.act('authenticated', 'fb-w2-owner');
select public.set_item_working('a3000000-0000-0000-0000-000000000001', 204, 'fan1', false);
reset role;
select test.rows($$select count(*) from public.complaints where item = 'layout:204:fan1' and body = 'Fan 1 in room 204 marked not working.' and status = 'Open'$$, 1);
-- F23 things: a geyser marked not working raises a complaint; working again closes it
select test.act('authenticated', 'fb-w2-owner');
select public.save_amenity('a3000000-0000-0000-0000-000000000001', null, 2, 'geyser', '', 1, false, 'washroom', '{204}');
reset role;
select test.rows($$select count(*) from public.complaints where hostel_id = 'a3000000-0000-0000-0000-000000000001' and item like 'amenity:%' and cat = 'Geyser' and status = 'Open' and body = 'Geyser in the washroom of room 204 marked not working.'$$, 1);
select test.act('authenticated', 'fb-w2-owner');
select public.save_amenity('a3000000-0000-0000-0000-000000000001', (select id from public.amenities where kind = 'geyser' and hostel_id = 'a3000000-0000-0000-0000-000000000001'), 2, 'geyser', '', 1, true, 'washroom', '{204}');
reset role;
select test.rows($$select count(*) from public.complaints where hostel_id = 'a3000000-0000-0000-0000-000000000001' and item like 'amenity:%' and status = 'Fixed'$$, 1);

-- ================================================================ 8. walk-in holds
select test.act('authenticated', 'fb-w2-tenant');
select test.fails($$select public.hold_walk_in('a3200000-0000-0000-0000-000000000001')$$, 'only this hostel');
select test.act('authenticated', 'fb-w2-owner');
select test.fails($$select public.hold_walk_in('a3200000-0000-0000-0000-000000000002')$$, 'isn''t free');
select test.eq((public.hold_walk_in('a3200000-0000-0000-0000-000000000001') > now() + interval '59 minutes')::text, 'true');
select test.fails($$select public.hold_walk_in('a3200000-0000-0000-0000-000000000001')$$, 'isn''t free');
-- tenants see it held and can't hold it on Hostelzy
select test.act('authenticated', 'fb-w2-tenant');
select test.eq((select state from public.beds where id = 'a3200000-0000-0000-0000-000000000001'), 'held');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('a3000000-0000-0000-0000-000000000001', 'a3200000-0000-0000-0000-000000000001', 'free')$$, 'not free');
select test.blocked($$select public.release_walk_in('a3200000-0000-0000-0000-000000000001')$$);
-- the owner releases it early
select test.act('authenticated', 'fb-w2-mgr');
select public.release_walk_in('a3200000-0000-0000-0000-000000000001');
select test.eq((select state || ' ' || coalesce(walk_in_until::text, '-') from public.beds where id = 'a3200000-0000-0000-0000-000000000001'), 'free -');
-- a free-soon bed held, then ended by the server after the hour: back to free soon
select public.hold_walk_in('a3200000-0000-0000-0000-000000000003');
reset role;
update public.beds set walk_in_until = now() - interval '1 minute' where id = 'a3200000-0000-0000-0000-000000000003';
select test.server();
select test.eq(public.expire_walk_ins()::text, '1');
select test.eq((select state || ' ' || coalesce(walk_in_until::text, '-') from public.beds where id = 'a3200000-0000-0000-0000-000000000003'), 'soon -');
select test.act('authenticated', 'fb-w2-tenant');
select test.blocked($$select public.expire_walk_ins()$$);

-- ================================================================ 22. switches and New free beds
reset role;
insert into public.profiles (id, name, phone, notify, searched_areas) values
  ('fb-w2-hunter', 'Asha', '9000033333', '{"hold": false, "rent": true, "beds": true}', '{Ameerpet,Madhapur}'),
  ('fb-w2-quiet', 'Kiran', '9000044444', '{"hold": true, "rent": true, "beds": false}', '{Ameerpet}'),
  ('fb-w2-far', 'Dev', '9000055555', '{"hold": true, "rent": true, "beds": true}', '{Gachibowli}');
delete from public.push_outbox;
-- the server's pushes: a switched-off kind is closed, never sent
select test.server();
insert into public.push_outbox (user_id, title, body, data) values
  ('fb-w2-hunter', 'Bed 101-A is kept for you', '', '{"screen":"holds"}'),
  ('fb-w2-hunter', 'Rent due in 3 days', '', '{"screen":"rPay"}'),
  ('fb-w2-hunter', 'Your owner approved your fix', '', '{"screen":"rRoom"}'),
  ('fb-w2-nobody', 'Bed 101-B is kept for you', '', '{"screen":"holds"}');
select test.eq((select string_agg(coalesce(kind, '-') || ':' || coalesce(error, 'send'), ' ' order by id) from public.push_outbox), 'hold:switched off rent:send -:send hold:send');
select test.rows($$select count(*) from public.push_outbox where sent_at is null$$, 3);
-- never a push about your own action
reset role;
select set_config('request.jwt.claims', jsonb_build_object('sub', 'fb-w2-owner', 'iss', 'https://securetoken.google.com/hostelzy', 'aud', 'hostelzy')::text, false);
insert into public.push_outbox (user_id, title) values ('fb-w2-owner', 'New hold on bed 204-A'), ('fb-w2-mgr', 'New hold on bed 204-A');
select test.server();
select test.eq((select string_agg(user_id || ':' || kind, ' ') from public.push_outbox where title = 'New hold on bed 204-A'), 'fb-w2-mgr:hold');
-- a bed turns free in Ameerpet: only the tenant with the switch on who searched there
delete from public.push_outbox;
update public.beds set state = 'held' where id = 'a3200000-0000-0000-0000-000000000001';
update public.beds set state = 'free' where id = 'a3200000-0000-0000-0000-000000000001';
select test.eq((select string_agg(user_id || ' · ' || title || ' · ' || body, ' | ') from public.push_outbox where kind = 'beds'), 'fb-w2-hunter · A bed is free in Ameerpet · Wave Two PG: bed 204-A is free now. Hold it free for 1 hour on Hostelzy.');
-- at most one a day
update public.beds set state = 'free' where id = 'a3200000-0000-0000-0000-000000000003';
select test.rows($$select count(*) from public.push_outbox where kind = 'beds'$$, 1);
-- a draft hostel never alerts
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a3100000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000002', 101, 1, 2, 8000);
update public.profiles set beds_alert_at = null, searched_areas = '{SR Nagar}' where id = 'fb-w2-hunter';
insert into public.beds (hostel_id, room_id, letter) values ('a3000000-0000-0000-0000-000000000002', 'a3100000-0000-0000-0000-000000000002', 'A');
select test.rows($$select count(*) from public.push_outbox where kind = 'beds'$$, 1);
-- the user saves their own switches and areas; at most 5 areas
select test.act('authenticated', 'fb-w2-quiet');
select test.rows($$update public.profiles set notify = '{"hold": true, "rent": false, "beds": true}', searched_areas = '{Kondapur}' where id = 'fb-w2-quiet'$$, 1);
select test.blocked($$update public.profiles set notify = '{"hold": false}' where id = 'fb-w2-hunter'$$);
select test.fails($$update public.profiles set searched_areas = '{a,b,c,d,e,f}' where id = 'fb-w2-quiet'$$, 'profiles_searched_areas');

-- ================================================================ 29. team
select test.act('authenticated', 'fb-w2-owner');
select test.fails($$select public.team_hello()$$, 'for the Hostelzy team only');
select test.fails($$select * from public.team_tracker()$$, 'for the Hostelzy team only');
select test.rows($$select count(*) from public.team_members$$, 0);
reset role;
insert into public.profiles (id, name, email, phone) values ('fb-w2-founder', 'Farhath', 'f@example.com', '9059790014'), ('fb-w2-helper', 'Sana', 's@example.com', '98480 22338');
select test.act('authenticated', 'fb-w2-founder', true);
select public.team_hello();
select public.team_hello();
insert into public.team_members (name, phone, role) values ('Sana', '9848022338', 'Visits');
select test.eq((select string_agg(name || ':' || role || ':' || (joined_at is not null), ' ' order by created_at) from public.team_members), 'Farhath:Everything:true Sana:Visits:false');
select test.act('authenticated', 'fb-w2-helper', true);
select public.team_hello();
select test.eq((select string_agg(name || ':' || role || ':' || (joined_at is not null) || ':' || email, ' ' order by created_at) from public.team_members), 'Farhath:Everything:true:f@example.com Sana:Visits:true:s@example.com');
-- tracker: stages from leads, then live / trial / paying
reset role;
insert into public.hostel_leads (hostel_id, stage, next_step) values ('a3000000-0000-0000-0000-000000000002', 'visited', 'Owner to decide by Fri');
select test.act('authenticated', 'fb-w2-founder', true);
select test.eq((select stage || ' ' || next_step from public.team_tracker() where hostel_id = 'a3000000-0000-0000-0000-000000000002'), '1 Owner to decide by Fri');
select test.eq((select stage::text from public.team_tracker() where hostel_id = 'a3000000-0000-0000-0000-000000000001'), '4');
reset role;
insert into public.owner_plans (hostel_id, trial_ends) values ('a3000000-0000-0000-0000-000000000001', current_date + 30);
select test.act('authenticated', 'fb-w2-founder', true);
select test.eq((select stage || ' ' || (trial_ends = current_date + 30) from public.team_tracker() where hostel_id = 'a3000000-0000-0000-0000-000000000001'), '5 true');
reset role;
update public.owner_plans set status = 'active' where hostel_id = 'a3000000-0000-0000-0000-000000000001';
select test.act('authenticated', 'fb-w2-founder', true);
select test.eq((select stage::text from public.team_tracker() where hostel_id = 'a3000000-0000-0000-0000-000000000001'), '6');

reset role;
\o
select 'ALL WAVE 2A TESTS PASSED';
