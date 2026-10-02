-- S1 holds and bookings as the app makes them: runs after the other tests (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

insert into public.hostels (id, slug, name, gender, area, status) values ('e0000000-0000-0000-0000-000000000001', 'sai', 'Sai PG', 'Men', 'Ameerpet', 'live');
insert into public.hostel_staff values ('e0000000-0000-0000-0000-000000000001', 'fb-sai', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('e1000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 101, 1, 2, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('e2000000-0000-0000-0000-00000000000a', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'A'),
  ('e2000000-0000-0000-0000-00000000000b', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'B');

-- the tenant books bed A with the advance: the server issues the HZ code, the bed shows held
select test.act('authenticated', 'fb-booker');
insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-00000000000a', 'advance');
create temp table h1 as select id, ref, status, expires_at from public.holds where bed_id = 'e2000000-0000-0000-0000-00000000000a';
select test.eq((select (ref ~ '^HZ-[0-9]+$')::text || ' ' || status || ' ' || (expires_at is null)::text from h1), 'true waiting true');
insert into public.payments (hostel_id, hold_id, kind, amount, note) select 'e0000000-0000-0000-0000-000000000001', id, 'advance', 3000, ref from h1;
-- a second hold on the same bed is refused
select test.act('authenticated', 'fb-other');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-00000000000a', 'free')$$, 'not free');

-- UTR, owner confirms, the hold becomes booked
select test.act('authenticated', 'fb-booker');
update public.payments set utr = '123456789012', status = 'waiting' where hold_id = (select id from h1);
select test.act('authenticated', 'fb-sai');
update public.payments set status = 'paid' where hold_id = (select id from h1);
update public.holds set status = 'booked' where id = (select id from h1);
-- the payer can't cancel a paid advance afterwards
select test.act('authenticated', 'fb-booker');
select test.fails($$update public.payments set status = 'cancelled' where hold_id = (select id from h1)$$, 'closed');

-- a free hold on bed B, released by the tenant: the bed is free again and its open advance is cancelled
insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-00000000000b', 'free');
create temp table h2 as select id, expires_at from public.holds where bed_id = 'e2000000-0000-0000-0000-00000000000b';
select test.eq((select (expires_at > now())::text from h2), 'true');
update public.holds set status = 'released' where id = (select id from h2);
reset role;
select test.eq((select string_agg(letter || ':' || state, ',' order by letter) from public.beds where room_id = 'e1000000-0000-0000-0000-000000000001'), 'A:booked,B:free');
select test.eq((select status from public.payments where hold_id = (select id from h1)), 'paid');

reset role;
\o
select 'ALL HOLD TESTS PASSED';
