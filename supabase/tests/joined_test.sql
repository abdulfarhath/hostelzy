-- F24 item 14: "Did you join?" answers, for the Hostelzy team only.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a3000000-0000-0000-0000-000000000001', 'dj-one', 'Join PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.hostel_staff values ('a3000000-0000-0000-0000-000000000001', 'fb-dj-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a3010000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 101, 1, 2, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('a3020000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'A'),
  ('a3020000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'a3010000-0000-0000-0000-000000000001', 'B');
set session_replication_role = replica;
insert into public.holds (id, hostel_id, bed_id, tenant_id, opt, status) values
  ('a3040000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000001', 'fb-dj-t', 'free', 'expired'),
  ('a3040000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'a3020000-0000-0000-0000-000000000002', 'fb-dj-t', 'free', 'waiting');
set session_replication_role = origin;

-- only the tenant, only after the hold ends, only the three answers
select test.act('authenticated', 'fb-dj-other');
select test.fails($$select public.answer_joined('a3040000-0000-0000-0000-000000000001', 'yes')$$, 'only the tenant of this hold');
select test.act('authenticated', 'fb-dj-t');
select test.fails($$select public.answer_joined('a3040000-0000-0000-0000-000000000002', 'yes')$$, 'after the hold ends');
select test.fails($$select public.answer_joined('a3040000-0000-0000-0000-000000000001', 'no')$$, 'answer yes, not yet or still deciding');
select public.answer_joined('a3040000-0000-0000-0000-000000000001', 'deciding');
select public.answer_joined('a3040000-0000-0000-0000-000000000001', 'not_yet');
select test.blocked($$insert into public.join_answers (hold_id, hostel_id, tenant_id, answer) values ('a3040000-0000-0000-0000-000000000002', 'a3000000-0000-0000-0000-000000000001', 'fb-dj-t', 'yes')$$);
-- the tenant sees their own answer
select test.rows($$select count(*) from public.join_answers where answer = 'not_yet'$$, 1);
-- the owner never does; the team does
select test.act('authenticated', 'fb-dj-owner');
select test.rows($$select count(*) from public.join_answers$$, 0);
select test.act('authenticated', 'fb-dj-team', true);
select test.rows($$select count(*) from public.join_answers where hostel_id = 'a3000000-0000-0000-0000-000000000001'$$, 1);

-- account deletion detaches it
reset role;
select set_config('request.jwt.claims', '', false);
update public.holds set tenant_id = 'deleted' where tenant_id = 'fb-dj-t';
select test.eq((select tenant_id from public.join_answers where hold_id = 'a3040000-0000-0000-0000-000000000001'), 'deleted');

reset role;
\o
select 'ALL DID-YOU-JOIN TESTS PASSED';
