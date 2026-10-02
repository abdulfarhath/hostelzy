-- S2 residents: runs after the other tests (uses their test.* helpers and the S1 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('e2000000-0000-0000-0000-00000000000c', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'C');

-- the owner adds a resident on bed C: the bed is booked; a tenant can't add one
select test.act('authenticated', 'fb-sai');
insert into public.stays (hostel_id, bed_id, name, phone, rent, advance) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-00000000000c', 'Kiran Rao', '9876500001', 8000, 3000);
select test.rows($$select count(*) from public.stays where hostel_id = 'e0000000-0000-0000-0000-000000000001'$$, 1);
select test.act('authenticated', 'fb-other');
select test.blocked($$insert into public.stays (hostel_id, name) values ('e0000000-0000-0000-0000-000000000001', 'x')$$);
select test.rows($$select count(*) from public.stays where hostel_id = 'e0000000-0000-0000-0000-000000000001'$$, 0);
reset role;
select test.eq((select state from public.beds where id = 'e2000000-0000-0000-0000-00000000000c'), 'booked');

-- Kiran joins with the invite code; approving links the owner's entry (no second stay)
select test.act('authenticated', 'fb-sai');
create temp table c2 as select public.hostel_invite('e0000000-0000-0000-0000-000000000001') as code;
select test.act('authenticated', 'fb-kiran');
select public.join_with_invite((select code from c2), 'Kiran Rao', '9876500001');
select test.act('authenticated', 'fb-sai');
select public.decide_signup((select id from public.invite_signups where user_id = 'fb-kiran'), true);
reset role;
select test.eq((select count(*)::text || ' ' || bool_and(confirmed)::text || ' ' || max(user_id) from public.stays where hostel_id = 'e0000000-0000-0000-0000-000000000001'), '1 true fb-kiran');

-- moving out frees the bed
select test.act('authenticated', 'fb-sai');
update public.stays set left_on = current_date where hostel_id = 'e0000000-0000-0000-0000-000000000001';
reset role;
select test.eq((select state from public.beds where id = 'e2000000-0000-0000-0000-00000000000c'), 'free');

reset role;
\o
select 'ALL RESIDENT TESTS PASSED';
