-- F26 #7, #9, #21: owner contact only with a live hold, hold seen / declined,
-- UNVERIFIED (listed) hostels, the waitlist push, claims and area counts.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, lat, lng) values
  ('f2600000-0000-0000-0000-000000000001', 'f26-live', 'F26 Live PG', 'Men', 'Miyapur', 'live', 'Ravi', 17.4, 78.4),
  ('f2600000-0000-0000-0000-000000000002', 'f26-listed', 'F26 Listed PG', 'Men', 'Miyapur', 'listed', '', 17.4, 78.4),
  ('f2600000-0000-0000-0000-000000000003', 'f26-draft', 'F26 Draft PG', 'Men', 'Miyapur', 'draft', '', null, null);
update public.hostels set rent_min = 7000, rent_max = 9000 where id = 'f2600000-0000-0000-0000-000000000002';
insert into public.profiles (id, name, phone) values ('fb-f26-owner', 'Ravi', '9876500001');
insert into public.hostel_staff values ('f2600000-0000-0000-0000-000000000001', 'fb-f26-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('f2610000-0000-0000-0000-000000000001', 'f2600000-0000-0000-0000-000000000001', 101, 1, 2, 9000),
  ('f2610000-0000-0000-0000-000000000002', 'f2600000-0000-0000-0000-000000000002', 101, 1, 2, 9000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('f2620000-0000-0000-0000-000000000001', 'f2600000-0000-0000-0000-000000000001', 'f2610000-0000-0000-0000-000000000001', 'A'),
  ('f2620000-0000-0000-0000-000000000002', 'f2600000-0000-0000-0000-000000000001', 'f2610000-0000-0000-0000-000000000001', 'B'),
  ('f2620000-0000-0000-0000-000000000003', 'f2600000-0000-0000-0000-000000000002', 'f2610000-0000-0000-0000-000000000002', 'A');
insert into public.hostel_photos (hostel_id, path) values ('f2600000-0000-0000-0000-000000000002', 'f2600000-0000-0000-0000-000000000002/front.jpg');

create function pg_temp.ask() returns text language sql as $$
  select coalesce(string_agg(h.slug || '=' || c.phone, ' ' order by h.slug), '')
  from public.owner_contacts(array['f2600000-0000-0000-0000-000000000001', 'f2600000-0000-0000-0000-000000000002']::uuid[]) c
  join public.hostels h on h.id = c.hostel_id
$$;

-- ------------------------------------------------------------ #7 contact with a live hold only
select test.act('authenticated', 'fb-f26-t1');
select test.eq(pg_temp.ask(), '');
insert into public.holds (hostel_id, bed_id, opt) values ('f2600000-0000-0000-0000-000000000001', 'f2620000-0000-0000-0000-000000000001', 'free');
select test.eq(pg_temp.ask(), 'f26-live=9876500001');
-- the hold ends: locked again (no 60-day carry-over)
reset role;
update public.holds set status = 'expired' where tenant_id = 'fb-f26-t1';
select test.act('authenticated', 'fb-f26-t1');
select test.eq(pg_temp.ask(), '');
-- an enquiry no longer opens it
reset role;
insert into public.enquiries (hostel_id, tenant_id, ref, name, phone) values ('f2600000-0000-0000-0000-000000000001', 'fb-f26-t1', 'HZ-F261', 'T', '9000026001');
select test.act('authenticated', 'fb-f26-t1');
select test.eq(pg_temp.ask(), '');

-- ------------------------------------------------------------ #9 seen and declined
select test.act('authenticated', 'fb-f26-t2');
insert into public.holds (hostel_id, bed_id, opt) values ('f2600000-0000-0000-0000-000000000001', 'f2620000-0000-0000-0000-000000000002', 'free');
reset role;
select set_config('hz.h2', (select id::text from public.holds where tenant_id = 'fb-f26-t2'), false);
-- only the hostel's staff mark it seen; the tenant can't
select test.act('authenticated', 'fb-f26-t2');
select test.eq(public.hold_seen(array[current_setting('hz.h2')::uuid])::text, '0');
select test.act('authenticated', 'fb-f26-owner');
select test.eq(public.hold_seen(array[current_setting('hz.h2')::uuid])::text, '1');
select test.eq(public.hold_seen(array[current_setting('hz.h2')::uuid])::text, '0');
select test.act('authenticated', 'fb-f26-t2');
select test.rows($$select count(*) from public.holds where seen_at is not null and not declined$$, 1);
-- the owner says no: declined (a tenant's own release isn't)
select test.act('authenticated', 'fb-f26-owner');
update public.holds set status = 'released' where id = current_setting('hz.h2')::uuid;
select test.act('authenticated', 'fb-f26-t2');
select test.rows($$select count(*) from public.holds where declined$$, 1);
select test.eq(pg_temp.ask(), '');

-- ------------------------------------------------------------ #21 listed hostels
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where slug in ('f26-listed', 'f26-live', 'f26-draft')$$, 2);
select test.eq((select rent_min || '-' || rent_max from public.hostels where slug = 'f26-listed'), '7000-9000');
select test.rows($$select count(*) from public.hostel_photos where hostel_id = 'f2600000-0000-0000-0000-000000000002'$$, 1);
-- no rooms, beds or holds
select test.rows($$select count(*) from public.rooms where hostel_id = 'f2600000-0000-0000-0000-000000000002'$$, 0);
select test.rows($$select count(*) from public.beds where hostel_id = 'f2600000-0000-0000-0000-000000000002'$$, 0);
select test.eq((select verified || ' ' || listed from public.area_counts() where area = 'Miyapur'), '1 1');
select test.act('authenticated', 'fb-f26-t3');
select test.blocked($$insert into public.holds (hostel_id, bed_id, opt) values ('f2600000-0000-0000-0000-000000000002', 'f2620000-0000-0000-0000-000000000003', 'free')$$);
-- the waitlist and claims: own rows, listed hostels only
insert into public.verify_waitlist (hostel_id) values ('f2600000-0000-0000-0000-000000000002');
select test.blocked($$insert into public.verify_waitlist (hostel_id) values ('f2600000-0000-0000-0000-000000000001')$$);
select test.blocked($$insert into public.verify_waitlist (hostel_id, user_id) values ('f2600000-0000-0000-0000-000000000002', 'fb-someone')$$);
insert into public.claim_requests (hostel_id, name, phone) values ('f2600000-0000-0000-0000-000000000002', 'Suresh', '9123400001');
select test.blocked($$insert into public.claim_requests (hostel_id, name, phone) values ('f2600000-0000-0000-0000-000000000001', 'Suresh', '9123400001')$$);
select test.blocked($$update public.claim_requests set status = 'done'$$);
select test.act('authenticated', 'fb-f26-t4');
select test.rows($$select count(*) from public.claim_requests$$, 0);
select test.rows($$select count(*) from public.verify_waitlist$$, 0);
-- only the team lists; a range is needed; a photo before it goes public
select test.fails($$select public.list_hostel(null, '{"name": "X", "rent_min": 7000, "rent_max": 9000}')$$, 'only the Hostelzy team');
select test.act('authenticated', 'fb-f26-hq', true);
select test.rows($$select count(*) from public.claim_requests where hostel_id = 'f2600000-0000-0000-0000-000000000002'$$, 1);
select test.rows($$update public.claim_requests set status = 'done' where hostel_id = 'f2600000-0000-0000-0000-000000000002'$$, 1);
select test.fails($$select public.list_hostel(null, '{"name": "X", "rent_min": 9000, "rent_max": 7000}')$$, 'expected rent range');
select test.fails($$select public.list_hostel('f2600000-0000-0000-0000-000000000003', '{"name": "F26 Draft PG", "rent_min": 6000, "rent_max": 8000, "list": true}')$$, 'add a photo first');
select test.fails($$select public.list_hostel('f2600000-0000-0000-0000-000000000001', '{"name": "F26 Live PG", "rent_min": 6000, "rent_max": 8000}')$$, 'already verified');
select set_config('hz.new', public.list_hostel(null, '{"name": "Sri Balaji PG", "area": "Miyapur", "rent_min": 6500, "rent_max": 8500}')::text, false);
select test.eq((select status || ' ' || rent_min from public.hostels where id = current_setting('hz.new')::uuid), 'draft 6500');
insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.new')::uuid, current_setting('hz.new') || '/a.jpg');
select public.list_hostel(current_setting('hz.new')::uuid, '{"name": "Sri Balaji PG", "rent_min": 6500, "rent_max": 8500, "list": true}');
select test.eq((select status from public.hostels where id = current_setting('hz.new')::uuid), 'listed');

-- go_live verifies a listed hostel and pushes its waitlist once
reset role;
insert into public.rate_cards (hostel_id, ac, share, rent) values ('f2600000-0000-0000-0000-000000000002', false, 2, 9000);
insert into public.hostel_staff values ('f2600000-0000-0000-0000-000000000002', 'fb-f26-owner2', 'owner');
insert into public.hostel_photos (hostel_id, path) select 'f2600000-0000-0000-0000-000000000002', 'f2600000-0000-0000-0000-000000000002/p' || g || '.jpg' from generate_series(1, 7) g;
select test.act('authenticated', 'fb-f26-hq', true);
select public.go_live('f2600000-0000-0000-0000-000000000002');
reset role;
select test.eq((select status from public.hostels where id = 'f2600000-0000-0000-0000-000000000002'), 'live');
select test.eq((select count(*) || ' ' || min(data ->> 'kind') || ' ' || bool_and(sent_at is null) from public.push_outbox where user_id = 'fb-f26-t3' and title = 'F26 Listed PG is verified'), '1 beds true');
select test.rows($$select count(*) from public.verify_waitlist where notified_at is not null and user_id = 'fb-f26-t3'$$, 1);

\o
select 'ALL F26 LISTINGS TESTS PASSED';
