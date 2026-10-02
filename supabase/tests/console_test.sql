-- B7 team console data: runs after rls_test.sql (uses its test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;

-- onboarding stage, owner phone and visit time are for the team only
insert into public.hostel_leads (hostel_id, owner_phone, stage) values ('10000000-0000-0000-0000-000000000002', '9000000007', 'visited');
select test.act('authenticated', 'fb-team', true);
select test.rows('select count(*) from public.hostel_leads', 1);
select test.rows($$update public.hostel_leads set stage = 'signed_up'$$, 1);
select test.act('authenticated', 'fb-owner-draft');
select test.rows('select count(*) from public.hostel_leads', 0);
select test.blocked($$update public.hostel_leads set stage = 'data_complete'$$);
select test.act('anon', null);
select test.rows('select count(*) from public.hostel_leads', 0);

reset role;
\o
select 'ALL CONSOLE TESTS PASSED';
