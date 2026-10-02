-- S5 Fair Play: runs after the other tests (uses their helpers and the S1/S2 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.stays (hostel_id, name, phone, via) values ('e0000000-0000-0000-0000-000000000001', 'Late Larry', '9876500009', 'direct');
insert into public.fair_cases (ref, hostel_id, title, signal, resident) values
  ('FP-9001', 'e0000000-0000-0000-0000-000000000001', 'Larry added late', 'Signal', 'Late Larry'),
  ('FP-9002', 'e0000000-0000-0000-0000-000000000001', 'Report', 'Tenant report', null);

-- the owner fixes FP-9001: Larry is Via Hostelzy, the case closes; another owner can't
select test.act('authenticated', 'fb-other');
select test.fails($$select public.fix_case((select id from public.fair_cases where ref = 'FP-9001'))$$, 'only this hostel');
select test.act('authenticated', 'fb-sai');
select public.fix_case((select id from public.fair_cases where ref = 'FP-9001'));
select test.fails($$select public.fix_case((select id from public.fair_cases where ref = 'FP-9001'))$$, 'closed');
select test.fails($$select public.fix_case((select id from public.fair_cases where ref = 'FP-9002'))$$, 'no resident');
-- the owner can't close a case themselves
select test.fails($$update public.fair_cases set status = 'closed' where ref = 'FP-9002'$$, 'only reply');
reset role;
select test.eq((select via from public.stays where name = 'Late Larry'), 'hz');
select test.eq((select status || ' · ' || decision from public.fair_cases where ref = 'FP-9001'), 'closed · Fixed by the owner within 48 h · no strike');

-- FP-9002: the team asks for more; the owner's reply sends it back to the team
select test.act('authenticated', 'fb-team', true);
update public.fair_cases set status = 'waiting' where ref = 'FP-9002';
select test.act('authenticated', 'fb-sai');
update public.fair_cases set owner_reply = 'He moved in on the 3rd', status = 'new' where ref = 'FP-9002';
reset role;
select test.eq((select status || ' ' || owner_reply from public.fair_cases where ref = 'FP-9002'), 'new He moved in on the 3rd');

-- a strike: everyone sees the count for a live hostel
select test.act('authenticated', 'fb-team', true);
insert into public.strikes (hostel_id, case_id) select hostel_id, id from public.fair_cases where ref = 'FP-9002';
select test.act('anon', null);
select test.eq((select n::text from public.strike_counts() where hostel_id = 'e0000000-0000-0000-0000-000000000001'), '1');
select test.rows('select count(*) from public.strikes', 0);   -- the rows themselves stay private

reset role;
\o
select 'ALL FAIR PLAY TESTS PASSED';
