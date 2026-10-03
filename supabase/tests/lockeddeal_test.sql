-- F24 item 13: the deal a booking was made with is kept on the server.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, terms) values
  ('a2900000-0000-0000-0000-000000000001', 'ld-one', 'Deal PG', 'Men', 'Madhapur', 'live', 'Ravi', '{"advance": 3000, "maintenance": 1000, "noticeDays": 30}');
insert into public.hostel_staff values ('a2900000-0000-0000-0000-000000000001', 'fb-ld-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent, ac) values
  ('a2910000-0000-0000-0000-000000000001', 'a2900000-0000-0000-0000-000000000001', 101, 1, 2, 8000, false),
  ('a2910000-0000-0000-0000-000000000002', 'a2900000-0000-0000-0000-000000000001', 201, 2, 2, 9500, true);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('a2920000-0000-0000-0000-000000000001', 'a2900000-0000-0000-0000-000000000001', 'a2910000-0000-0000-0000-000000000001', 'A'),
  ('a2920000-0000-0000-0000-000000000002', 'a2900000-0000-0000-0000-000000000001', 'a2910000-0000-0000-0000-000000000001', 'B'),
  ('a2920000-0000-0000-0000-000000000003', 'a2900000-0000-0000-0000-000000000001', 'a2910000-0000-0000-0000-000000000002', 'A');
insert into public.rate_cards values ('a2900000-0000-0000-0000-000000000001', false, 2, 7800);
insert into public.deals (hostel_id, deals_on, target) values ('a2900000-0000-0000-0000-000000000001', '{monthly,advance}', 'non');
insert into public.profiles (id, name, phone, role) values ('fb-ld-tenant', 'Teja', '9876500011', 'tenant');

-- a booking locks the deal; the phone can't write its own
select test.act('authenticated', 'fb-ld-tenant');
insert into public.holds (hostel_id, bed_id, opt, deal) values ('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000001', 'advance', '{"on": ["first"], "fee": 1}');
select test.eq((select (deal -> 'on')::text || ' ' || (deal ->> 'fee') || ' ' || (deal ->> 'advance') || ' ' || (deal ->> 'notice') from public.holds where bed_id = 'a2920000-0000-0000-0000-000000000001'), '["monthly", "advance"] 7800 3000 30');
-- the AC room isn't covered by a non-AC deal; the tenant can't change it later
insert into public.holds (hostel_id, bed_id, opt) values ('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000003', 'advance');
select test.eq((select (deal -> 'on')::text || ' ' || (deal ->> 'fee') from public.holds where bed_id = 'a2920000-0000-0000-0000-000000000003'), '[] 9500');
update public.holds set status = 'released', deal = '{"on": ["laundry"]}' where bed_id = 'a2920000-0000-0000-0000-000000000003';
select test.eq((select (deal -> 'on')::text from public.holds where bed_id = 'a2920000-0000-0000-0000-000000000003'), '[]');
-- a free hold carries none
insert into public.holds (hostel_id, bed_id, opt) values ('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000002', 'free');
select test.eq((select coalesce(deal::text, 'none') from public.holds where bed_id = 'a2920000-0000-0000-0000-000000000002'), 'none');

-- the owner confirms the advance; the stay they add keeps the deal
select test.act('authenticated', 'fb-ld-owner');
update public.holds set status = 'booked', deal = null where bed_id = 'a2920000-0000-0000-0000-000000000001';
select test.eq((select (deal ->> 'fee') from public.holds where bed_id = 'a2920000-0000-0000-0000-000000000001'), '7800');
update public.holds set status = 'released' where bed_id = 'a2920000-0000-0000-0000-000000000002';
insert into public.stays (hostel_id, bed_id, name, phone, rent, advance, deal) values ('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000001', 'Teja', '9876500011', 7800, 2000, '{"on": ["laundry"]}');
select test.eq((select (deal -> 'on')::text from public.stays where name = 'Teja' and hostel_id = 'a2900000-0000-0000-0000-000000000001'), '["monthly", "advance"]');
-- the owner can't change it afterwards
update public.stays set deal = '{"on": []}', rent = 7800 where name = 'Teja' and hostel_id = 'a2900000-0000-0000-0000-000000000001';
select test.eq((select (deal -> 'on')::text from public.stays where name = 'Teja' and hostel_id = 'a2900000-0000-0000-0000-000000000001'), '["monthly", "advance"]');
-- a walk-in gets none
insert into public.stays (hostel_id, bed_id, name, phone, rent) values ('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000002', 'Walk', '9876500099', 8000);
select test.eq((select coalesce(deal::text, 'none') from public.stays where name = 'Walk' and hostel_id = 'a2900000-0000-0000-0000-000000000001'), 'none');

-- 2 strikes: no deal perks on a new booking
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.strikes (hostel_id) values ('a2900000-0000-0000-0000-000000000001'), ('a2900000-0000-0000-0000-000000000001');
select test.eq((select (public.deal_for_bed('a2900000-0000-0000-0000-000000000001', 'a2920000-0000-0000-0000-000000000002') -> 'on')::text), '[]');

reset role;
\o
select 'ALL LOCKED DEAL TESTS PASSED';
