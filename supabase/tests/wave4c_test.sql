-- F24 Wave 4c: owner's WhatsApp, the wizard's pin / rules / amenities, meal times.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
create temp table w4 (k text primary key, v text);
grant all on w4 to anon, authenticated;
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a4c00000-0000-0000-0000-000000000001', 'w4-one', 'Wave One PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.profiles (id, name, phone) values ('fb-w4-owner', 'Ravi', '9876543210'), ('fb-w4-mgr', 'Manoj', '9000011111');
insert into public.hostel_staff values
  ('a4c00000-0000-0000-0000-000000000001', 'fb-w4-owner', 'owner'),
  ('a4c00000-0000-0000-0000-000000000001', 'fb-w4-mgr', 'manager');
insert into public.stays (hostel_id, user_id, name, confirmed) values ('a4c00000-0000-0000-0000-000000000001', 'fb-w4-res', 'Priya', true);

-- item 1: the owner's own WhatsApp number; 10 digits or nothing
select test.act('authenticated', 'fb-w4-res');
select test.eq((select phone || '|' || whatsapp from public.owner_contacts(array['a4c00000-0000-0000-0000-000000000001']::uuid[])), '9876543210|');
select test.act('authenticated', 'fb-w4-owner');
select test.fails($$update public.profiles set whatsapp = '12345' where id = 'fb-w4-owner'$$, 'profiles_whatsapp');
update public.profiles set whatsapp = '9123412345' where id = 'fb-w4-owner';
select test.act('authenticated', 'fb-w4-res');
select test.eq((select phone || '|' || whatsapp from public.owner_contacts(array['a4c00000-0000-0000-0000-000000000001']::uuid[])), '9876543210|9123412345');
select test.act('authenticated', 'fb-w4-stranger');
select test.rows($$select count(*) from public.owner_contacts(array['a4c00000-0000-0000-0000-000000000001']::uuid[])$$, 0);

-- item 2: the team's draft keeps the pin, rules, amenities and the owner's WhatsApp
select test.act('authenticated', 'fb-w4-hq', true);
select test.fails($$select public.save_hostel(null, '{"name": "Far PG", "lat": 12.97, "lng": 77.59}')$$, 'isn''t in Hyderabad');
select test.fails($$select public.save_hostel(null, '{"name": "Short PG", "owner_whatsapp": "12345"}')$$, 'needs 10 digits');
insert into w4 select 'h', public.save_hostel(null, '{"name": "Pin PG", "area": "Kondapur", "owner_phone": "9000033333", "owner_whatsapp": "90000 44444",
  "rules": [{"k": "Gate closes", "v": "10:30 pm"}, {"k": "Visitors", "v": ""}, {"k": " ", "v": "x"}],
  "amenities": ["Wi-Fi", "Lift", "Wi-Fi", " "],
  "rates": [{"ac": false, "share": 2, "rent": 8000}], "rooms": [{"number": 101, "floor": 1, "share": 2, "rent": 8000}]}');
select test.eq((select rules::text from public.hostels where id = (select v from w4 where k = 'h')::uuid), '[{"k": "Gate closes", "v": "10:30 pm"}, {"k": "Visitors", "v": ""}]');
select test.eq((select array_to_string(amenities, ',') from public.hostels where id = (select v from w4 where k = 'h')::uuid), 'Lift,Wi-Fi');
select test.eq((select owner_phone || '|' || owner_whatsapp from public.hostel_leads where hostel_id = (select v from w4 where k = 'h')::uuid), '9000033333|9000044444');
-- leaving them out keeps them
select public.save_hostel((select v from w4 where k = 'h')::uuid, '{"name": "Pin PG"}');
select test.eq((select jsonb_array_length(rules) || ' ' || cardinality(amenities) from public.hostels where id = (select v from w4 where k = 'h')::uuid), '2 2');
select test.eq((select owner_whatsapp from public.hostel_leads where hostel_id = (select v from w4 where k = 'h')::uuid), '9000044444');
-- go live needs the pin dropped at the gate
reset role;
insert into public.hostel_staff values ((select v from w4 where k = 'h')::uuid, 'fb-w4-owner2', 'owner');
insert into public.hostel_photos (hostel_id, path, label) select (select v from w4 where k = 'h')::uuid, (select v from w4 where k = 'h') || '/p' || k || '.jpg', 'Front' from generate_series(1, 8) k;
select test.act('authenticated', 'fb-w4-hq', true);
select test.fails($$select public.go_live((select v from w4 where k = 'h')::uuid)$$, 'drop the map pin at the gate');
select public.save_hostel((select v from w4 where k = 'h')::uuid, '{"name": "Pin PG", "lat": 17.4622, "lng": 78.3568}');
select public.go_live((select v from w4 where k = 'h')::uuid);
select test.eq((select status || ' ' || lat::text from public.hostels where id = (select v from w4 where k = 'h')::uuid), 'live 17.4622');
select test.eq((select status from public.owner_plans where hostel_id = (select v from w4 where k = 'h')::uuid), 'trial');

-- item 4: meal times, the same on every day; staff only; end after start
select test.act('authenticated', 'fb-w4-res');
select test.fails($$select public.save_meal_times('a4c00000-0000-0000-0000-000000000001', '{"b": "07:00-09:00"}')$$, 'set its meal times');
select test.act('authenticated', 'fb-w4-mgr');
select test.fails($$select public.save_meal_times('a4c00000-0000-0000-0000-000000000001', '{"b": "09:00-07:00"}')$$, 'ends after it starts');
select test.fails($$select public.save_meal_times('a4c00000-0000-0000-0000-000000000001', '{"b": "7 am"}')$$, 'ends after it starts');
select public.save_meal_times('a4c00000-0000-0000-0000-000000000001', '{"b": "07:00-09:00", "l": "", "n": "20:30-22:00"}');
select test.act('authenticated', 'fb-w4-res');
select test.rows($$select count(*) from public.menus where hostel_id = 'a4c00000-0000-0000-0000-000000000001' and breakfast_time = '07:00-09:00' and lunch_time = '' and dinner_time = '20:30-22:00'$$, 7);
-- the menu itself is untouched by the times
select test.rows($$select count(*) from public.menus where hostel_id = 'a4c00000-0000-0000-0000-000000000001' and breakfast <> ''$$, 0);
select test.act('anon', null);
select test.blocked($$select public.save_meal_times('a4c00000-0000-0000-0000-000000000001', '{}')$$);

\o
select 'ALL WAVE 4C TESTS PASSED';
