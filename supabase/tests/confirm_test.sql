-- F24 item 9: free beds and layouts confirmed on the server; the 3-day push.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2800000-0000-0000-0000-000000000001', 'cf-one', 'Confirm PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.hostel_staff values ('a2800000-0000-0000-0000-000000000001', 'fb-cf-owner', 'owner'), ('a2800000-0000-0000-0000-000000000001', 'fb-cf-mgr', 'manager');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a2810000-0000-0000-0000-000000000001', 'a2800000-0000-0000-0000-000000000001', 101, 1, 2, 8000);
insert into public.beds (id, hostel_id, room_id, letter, state) values
  ('a2820000-0000-0000-0000-000000000001', 'a2800000-0000-0000-0000-000000000001', 'a2810000-0000-0000-0000-000000000001', 'A', 'free'),
  ('a2820000-0000-0000-0000-000000000002', 'a2800000-0000-0000-0000-000000000001', 'a2810000-0000-0000-0000-000000000001', 'B', 'booked');
insert into public.layouts (hostel_id, room, stage, w, h, confirmed_at) values ('a2800000-0000-0000-0000-000000000001', 101, 'published', 12, 10, now() - interval '100 days');

-- never confirmed: one push each to the owner and the manager, not again the next day
select test.server();
select test.eq((select count(*)::text from public.hostel_nudges where hostel_id = 'a2800000-0000-0000-0000-000000000001'), '0');
select public.nudge_confirmations();
select test.rows($$select count(*) from public.push_outbox where title = 'Still 1 free bed?' and user_id in ('fb-cf-owner', 'fb-cf-mgr')$$, 2);
select test.rows($$select count(*) from public.push_outbox where title = 'Do your room layouts still match?' and user_id in ('fb-cf-owner', 'fb-cf-mgr')$$, 2);
select test.rows($$select count(*) from public.hostel_nudges where hostel_id = 'a2800000-0000-0000-0000-000000000001'$$, 2);
create temp table before_again as select count(*) as n from public.push_outbox;
select public.nudge_confirmations();
select test.eq((select (count(*) - (select n from before_again))::text from public.push_outbox), '0');

-- the owner says "Yes, all free": the server's time is stored, whatever the phone sends
select test.act('authenticated', 'fb-cf-owner');
update public.beds set confirmed_at = '2020-01-01' where hostel_id = 'a2800000-0000-0000-0000-000000000001';
select test.eq((select count(*)::text from public.beds where hostel_id = 'a2800000-0000-0000-0000-000000000001' and confirmed_at > now() - interval '1 minute'), '2');
-- it can't be cleared, and strangers can't confirm
update public.beds set confirmed_at = null where hostel_id = 'a2800000-0000-0000-0000-000000000001';
select test.eq((select count(*)::text from public.beds where hostel_id = 'a2800000-0000-0000-0000-000000000001' and confirmed_at is not null), '2');
select test.act('authenticated', 'fb-cf-stranger');
select test.blocked($$update public.beds set confirmed_at = now() where hostel_id = 'a2800000-0000-0000-0000-000000000001'$$);
-- tenants (even signed out) read it
select test.act('anon', null);
select test.eq((select (max(confirmed_at) > now() - interval '1 minute')::text from public.beds where hostel_id = 'a2800000-0000-0000-0000-000000000001'), 'true');

-- layouts: staff only; the job is the server's
select test.act('authenticated', 'fb-cf-stranger');
select test.fails($$select public.confirm_layouts('a2800000-0000-0000-0000-000000000001')$$, 'only this hostel''s owner or managers');
select test.fails($$select public.nudge_confirmations()$$, 'permission denied');
select test.act('authenticated', 'fb-cf-mgr');
select test.eq(public.confirm_layouts('a2800000-0000-0000-0000-000000000001')::text, '1');

-- 3 days later the beds need confirming again; the layouts are fresh
select test.server();
update public.beds set confirmed_at = now() - interval '4 days' where hostel_id = 'a2800000-0000-0000-0000-000000000001';
update public.hostel_nudges set sent_at = now() - interval '72 hours' where hostel_id = 'a2800000-0000-0000-0000-000000000001';
select test.eq(public.nudge_confirmations()::text, '1');

reset role;
\o
select 'ALL CONFIRM TESTS PASSED';
