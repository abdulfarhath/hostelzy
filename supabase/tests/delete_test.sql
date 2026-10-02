-- C account deletion: runs after rls_test.sql and b5_test.sql (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

insert into public.hostels (id, slug, name, gender, area, status) values
  ('c0000000-0000-0000-0000-000000000001', 'del-pg', 'Del PG', 'Men', 'Ameerpet', 'live');
insert into public.hostel_staff values ('c0000000-0000-0000-0000-000000000001', 'fb-del-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 1, 0, 2, 7000);
insert into public.beds (id, hostel_id, room_id, letter) values ('c2000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'A');
insert into public.profiles (id, phone, name) values ('fb-del', '9555555555', 'Delia');
insert into public.push_tokens (token, user_id) values ('tok-del', 'fb-del');

select test.act('authenticated', 'fb-del');
insert into public.holds (hostel_id, bed_id, opt) values ('c0000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 'free');
insert into public.enquiries (hostel_id, ref, name, phone, msg) values ('c0000000-0000-0000-0000-000000000001', 'x', 'Delia', '9555555555', 'Hi');
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.payments (id, hostel_id, payer_id, kind, amount) values ('c3000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'fb-del', 'advance', 3000);
insert into public.reviews (hostel_id, author_id, author_name, stars) values ('c0000000-0000-0000-0000-000000000001', 'fb-del', 'Delia K.', 4);
insert into public.stays (hostel_id, user_id, name) values ('c0000000-0000-0000-0000-000000000001', 'fb-del', 'Delia');

-- nobody signed in can't call it; anon can't either
select test.act('anon', null);
select test.fails('select public.delete_my_account()', 'permission denied');
-- an owner of a live hostel is asked to hand it over first
select test.act('authenticated', 'fb-del-owner');
select test.fails('select public.delete_my_account()', 'Owners: ask Hostelzy');

-- the tenant deletes: identity gone, others' records kept without it
select test.act('authenticated', 'fb-del');
select public.delete_my_account();
select test.server();
select test.eq((select count(*)::text from public.profiles where id = 'fb-del'), '0');
select test.eq((select count(*)::text from public.push_tokens where user_id = 'fb-del'), '0');
select test.eq((select status || ' ' || tenant_id from public.holds where bed_id = 'c2000000-0000-0000-0000-000000000001'), 'released deleted');
select test.eq((select state from public.beds where id = 'c2000000-0000-0000-0000-000000000001'), 'free');
select test.eq((select name || '|' || phone || '|' || msg from public.enquiries where hostel_id = 'c0000000-0000-0000-0000-000000000001'), 'Deleted user||');
select test.eq((select payer_id || ' ' || amount from public.payments where id = 'c3000000-0000-0000-0000-000000000001'), 'deleted 3000');
select test.eq((select author_name from public.reviews where hostel_id = 'c0000000-0000-0000-0000-000000000001'), 'Former resident');
select test.eq((select coalesce(user_id, 'none') || ' ' || name from public.stays where hostel_id = 'c0000000-0000-0000-0000-000000000001'), 'none Delia');
-- the payer guard still holds for everyone else
select test.act('authenticated', 'fb-del-owner');
select test.fails($$update public.payments set payer_id = 'deleted', amount = 1 where id = 'c3000000-0000-0000-0000-000000000001'$$, 'cannot change');

reset role;
\o
select 'ALL DELETE TESTS PASSED';
