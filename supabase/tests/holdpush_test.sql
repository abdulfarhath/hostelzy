-- F21 W2: the tenant gets a push when the owner keeps or declines a hold (runs after holds_test.sql).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('e2000000-0000-0000-0000-0000000021c1', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'X'),
  ('e2000000-0000-0000-0000-0000000021d1', 'e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'Y');

-- a free hold on C, kept by the owner: the tenant hears it
select test.act('authenticated', 'fb-holdpush');
insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-0000000021c1', 'free');
select test.act('authenticated', 'fb-sai');
update public.holds set status = 'held' where bed_id = 'e2000000-0000-0000-0000-0000000021c1' and status = 'waiting';
reset role;
select test.eq((select string_agg(title || ' | ' || body || ' | ' || (data->>'screen'), ';') from public.push_outbox where user_id = 'fb-holdpush'), 'Bed 101-X is kept for you | Sai PG confirmed your hold. Go and see it. | holds');

-- a free hold on D, released by the tenant themself: no push to them
select test.act('authenticated', 'fb-holdpush');
insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-0000000021d1', 'free');
update public.holds set status = 'released' where bed_id = 'e2000000-0000-0000-0000-0000000021d1' and status = 'waiting';
reset role;
select test.eq((select count(*)::text from public.push_outbox where user_id = 'fb-holdpush'), '1');

-- declined by the owner: "wasn't kept"
select test.act('authenticated', 'fb-holdpush');
insert into public.holds (hostel_id, bed_id, opt) values ('e0000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-0000000021d1', 'free');
select test.act('authenticated', 'fb-sai');
update public.holds set status = 'released' where bed_id = 'e2000000-0000-0000-0000-0000000021d1' and status = 'waiting';
reset role;
select test.eq((select title from public.push_outbox where user_id = 'fb-holdpush' order by id desc limit 1), 'Bed 101-Y wasn’t kept');

reset role;
\o
select 'ALL HOLD PUSH TESTS PASSED';
