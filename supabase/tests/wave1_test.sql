-- F24 Wave 1: electricity by meter, Trusted tenant level, first hour on new free beds, case photos.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, terms) values
  ('a3000000-0000-0000-0000-000000000001', 'w1-one', 'Meter PG', 'Men', 'Madhapur', 'live', 'Ravi', '{"advance": 3000, "maintenance": 1000}'),
  ('a3000000-0000-0000-0000-000000000002', 'w1-two', 'Other PG', 'Men', 'Madhapur', 'live', 'Lata', '{}');
insert into public.hostel_staff values ('a3000000-0000-0000-0000-000000000001', 'fb-w1-owner', 'owner'), ('a3000000-0000-0000-0000-000000000002', 'fb-w1-other', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('a3010000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 204, 2, 4, 7600),
  ('a3010000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 205, 2, 2, 8000);
insert into public.beds (id, hostel_id, room_id, letter, state) values
  ('a3020000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'A', 'booked'),
  ('a3020000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'B', 'booked'),
  ('a3020000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'C', 'booked'),
  ('a3020000-0000-0000-0000-000000000004', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'D', 'booked'),
  ('a3020000-0000-0000-0000-000000000005', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000002', 'A', 'free');
insert into public.profiles (id, phone, name, member) values ('fb-w1-res', '9000000401', 'Rahul', false), ('fb-w1-new', '9000000402', 'Asha', false), ('fb-w1-old', '9000000403', 'Teja', true);
insert into public.stays (id, hostel_id, bed_id, user_id, name, rent, advance, confirmed, joined_on) values
  ('a3030000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000001', 'fb-w1-res', 'Rahul', 7600, 3000, true, current_date - 20),
  ('a3030000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000002', null, 'Arjun', 7600, 3000, false, current_date - 20),
  ('a3030000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000003', null, 'Sai', 7600, 3000, false, current_date - 20),
  ('a3030000-0000-0000-0000-000000000004', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000004', null, 'Vamsi', 7600, 3000, false, current_date - 20);

-- ------------------------------------------------------------ electricity by meter
select test.act('authenticated', 'fb-w1-other');
select test.fails($$select public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 8, '[{"room": 204, "reading": 1870}]')$$, 'only this hostel''s owner or managers');
select test.act('authenticated', 'fb-w1-owner');
select test.fails($$select public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 0, '[{"room": 204, "reading": 1870}]')$$, 'the ₹ per unit');
select test.fails($$select public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 8, '[{"room": 999, "reading": 1870}]')$$, 'isn''t in this hostel');
-- last month: a first reading has no units yet
select test.eq(public.save_meter('a3000000-0000-0000-0000-000000000001', (date_trunc('month', current_date) - interval '1 month')::date, 8, '[{"room": 204, "reading": 1870}, {"room": 205, "reading": 640}]')::text, '2');
select test.eq((select coalesce(units::text, '-') || ' ' || coalesce(each_amt::text, '-') from public.meter_readings where room_id = 'a3010000-0000-0000-0000-000000000001'), '- -');
-- this month: 70 units ÷ 4 residents × ₹8 = ₹140 each; a room left out isn't saved
select test.fails($$select public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 8, '[{"room": 204, "reading": 1800}]')$$, 'lower than last month');
select test.eq(public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 8, '[{"room": 204, "reading": 1940}, {"room": 205}]')::text, '1');
select test.eq((select units || ' ' || people || ' ' || each_amt || ' ' || rate from public.meter_readings where room_id = 'a3010000-0000-0000-0000-000000000001' and month = date_trunc('month', current_date)::date), '70 4 140 8.00');
-- saving again with the same amount doesn't tell residents twice
select public.save_meter('a3000000-0000-0000-0000-000000000001', current_date, 8, '[{"room": 204, "reading": 1940}]');
reset role;
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-w1-res' and title like 'Electricity for %: ₹140'$$, 1);
-- the resident reads their own room; others can't; writes only through save_meter
select test.act('authenticated', 'fb-w1-res');
select test.rows($$select count(*) from public.meter_readings$$, 2);
select test.fails($$insert into public.meter_readings (room_id, hostel_id, month, reading, rate) values ('a3010000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', date_trunc('month', current_date)::date, 1, 1)$$, 'row-level security');
select test.act('authenticated', 'fb-w1-new');
select test.rows($$select count(*) from public.meter_readings$$, 0);

-- ------------------------------------------------------------ Trusted tenant level
select test.act('authenticated', 'fb-w1-new');
select test.eq(public.my_level() ->> 'level', 'none');
reset role;
-- 7 months in a confirmed stay, a Member, rent always on time → trusted
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values ('a3000000-0000-0000-0000-000000000003', 'w1-past', 'Past PG', 'Men', 'Madhapur', 'live', 'Mohan');
insert into public.stays (id, hostel_id, user_id, name, rent, advance, confirmed, via, joined_on, left_on) values
  ('a3030000-0000-0000-0000-000000000009', 'a3000000-0000-0000-0000-000000000003', 'fb-w1-old', 'Teja', 7000, 3000, true, 'hz', current_date - 240, current_date - 30);
select test.act('authenticated', 'fb-w1-old');
select test.eq(public.my_level()::text, '{"late": 0, "level": "trusted", "months": 7}');
-- one rent paid 10 days after the due day → member only
reset role;
insert into public.payments (hostel_id, payer_id, stay_id, kind, amount, status, created_at) values
  ('a3000000-0000-0000-0000-000000000003', 'fb-w1-old', 'a3030000-0000-0000-0000-000000000009', 'rent', 7000, 'paid',
   make_date(extract(year from current_date - 90)::int, extract(month from current_date - 90)::int, least(extract(day from current_date - 240)::int, 28)) + 10);
select test.act('authenticated', 'fb-w1-old');
select test.eq(public.my_level() ->> 'level', 'member');
reset role;
delete from public.payments where payer_id = 'fb-w1-old';
-- tenant_level is internal
select test.act('authenticated', 'fb-w1-old');
select test.fails($$select public.tenant_level('fb-w1-res')$$, 'permission denied');

-- ------------------------------------------------------------ first hour on a bed that just turned free
-- Rahul moves out: bed 204-A turns free; only a Trusted tenant may hold it for an hour
select test.act('authenticated', 'fb-w1-owner');
select public.moved_out('a3030000-0000-0000-0000-000000000001');
reset role;
select test.eq((select state || ' ' || (freed_at > now() - interval '1 minute')::text from public.beds where id = 'a3020000-0000-0000-0000-000000000001'), 'free true');
select test.eq((select coalesce(freed_at::text, '-') from public.beds where id = 'a3020000-0000-0000-0000-000000000005'), '-');
select test.act('authenticated', 'fb-w1-new');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000001', 'free')$$, 'Trusted tenants get the first hour');
-- a bed that was free all along is open to everyone; not marked Trusted
insert into public.holds (hostel_id, bed_id, opt) values ('a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000005', 'free');
select test.act('authenticated', 'fb-w1-old');
insert into public.holds (hostel_id, bed_id, opt) values ('a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000001', 'free');
reset role;
select test.eq((select string_agg(tenant_id || ':' || trusted, ',' order by tenant_id) from public.holds where hostel_id = 'a3000000-0000-0000-0000-000000000001'), 'fb-w1-new:false,fb-w1-old:true');
-- an hour later anyone can hold a newly freed bed
update public.beds set state = 'booked' where id = 'a3020000-0000-0000-0000-000000000002';
update public.beds set state = 'free' where id = 'a3020000-0000-0000-0000-000000000002';
update public.beds set freed_at = now() - interval '61 minutes' where id = 'a3020000-0000-0000-0000-000000000002';
select test.act('authenticated', 'fb-w1-res');
insert into public.holds (hostel_id, bed_id, opt) values ('a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000002', 'free');

-- ------------------------------------------------------------ Fair Play case photos
reset role;
insert into public.fair_cases (id, ref, hostel_id, title, signal, resident, status, tenant_photo) values
  ('a3040000-0000-0000-0000-000000000001', 'FP-W1', 'a3000000-0000-0000-0000-000000000001', 'Teja was added as Walked in', 'held then direct', 'Teja Naidu', 'waiting', 'a3000000-0000-0000-0000-000000000001/fb-w1-old/1.jpg');
insert into storage.objects (bucket_id, name) values ('case-photos', 'a3000000-0000-0000-0000-000000000001/fb-w1-old/1.jpg'), ('case-photos', 'a3000000-0000-0000-0000-000000000001/fb-w1-old/2.jpg');
-- the owner reads the tenant's photo on their case, not other photos in the folder
select test.act('authenticated', 'fb-w1-owner');
select test.rows($$select count(*) from storage.objects where bucket_id = 'case-photos'$$, 1);
select test.act('authenticated', 'fb-w1-other');
select test.rows($$select count(*) from storage.objects where bucket_id = 'case-photos'$$, 0);
select test.fails($$select public.case_photo('a3040000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001/fb-w1-other/1.jpg')$$, 'only this hostel''s owner or managers');
-- the owner uploads into their own folder and adds it to the reply
select test.act('authenticated', 'fb-w1-owner');
insert into storage.objects (bucket_id, name) values ('case-photos', 'a3000000-0000-0000-0000-000000000001/fb-w1-owner/9.jpg');
select test.fails($$insert into storage.objects (bucket_id, name) values ('case-photos', 'a3000000-0000-0000-0000-000000000002/fb-w1-owner/9.jpg')$$, 'row-level security');
select test.fails($$select public.case_photo('a3040000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001/fb-w1-old/2.jpg')$$, 'must be your own');
select public.case_photo('a3040000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001/fb-w1-owner/9.jpg');
select test.eq((select owner_photo from public.fair_cases where ref = 'FP-W1'), 'a3000000-0000-0000-0000-000000000001/fb-w1-owner/9.jpg');
-- owners still can't set the tenant's photo themselves
select test.fails($$update public.fair_cases set tenant_photo = null where ref = 'FP-W1'$$, 'owners can only reply');
reset role;
select set_config('hz.fixing', 'on', false);
update public.fair_cases set status = 'closed' where ref = 'FP-W1';
select set_config('hz.fixing', 'off', false);
select test.act('authenticated', 'fb-w1-owner');
select test.fails($$select public.case_photo('a3040000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001/fb-w1-owner/9.jpg')$$, 'already closed');
reset role;
\o
select 'ALL WAVE 1 TESTS PASSED';
