-- S8 managers: runs after the other tests (uses their helpers and the S1 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

-- only the owner makes a manager code
select test.act('authenticated', 'fb-other');
select test.fails($$select public.new_manager_invite('e0000000-0000-0000-0000-000000000001', 'Ravi', '9876500011')$$, 'only the owner');
select test.act('authenticated', 'fb-sai');
create temp table m1 as select public.new_manager_invite('e0000000-0000-0000-0000-000000000001', 'Ravi Manager', '9876500011') as code;
select test.eq((select (code ~ '^MGR-[A-Z2-9]{8}$')::text from m1), 'true');

-- the manager joins once with it; the code doesn't work again; anonymous can't
select test.act('authenticated', 'fb-anon2', false, 'anonymous');
select test.fails(format($$select public.join_as_manager(%L)$$, (select code from m1)), 'sign in with Google');
select test.act('authenticated', 'fb-ravi');
select test.eq(public.join_as_manager(lower((select code from m1))), 'Sai PG');
select test.act('authenticated', 'fb-mallory');
select test.fails(format($$select public.join_as_manager(%L)$$, (select code from m1)), 'isn''t valid');
-- the manager is staff now (sees the hostel's stays), but can't read the invites
select test.act('authenticated', 'fb-ravi');
select test.eq(public.is_staff('e0000000-0000-0000-0000-000000000001')::text, 'true');
select test.rows('select count(*) from public.manager_invites', 0);
-- the owner sees who joined, and was told
select test.act('authenticated', 'fb-sai');
select test.eq((select name || ' ' || used_by from public.manager_invites), 'Ravi Manager fb-ravi');
reset role;
select test.eq((select title from public.push_outbox where user_id = 'fb-sai' and title like '%manager'), 'Ravi Manager joined as manager');

reset role;
\o
select 'ALL MANAGER TESTS PASSED';
