-- F29 Part 1: notify_resident(): staff only, current residents on the app, 1-200 chars.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, lat, lng) values
  ('f2960000-0000-0000-0000-000000000001', 'nr-pg', 'Notify PG', 'Men', 'Kondapur', 'live', 'Suresh', 17.46, 78.36);
insert into public.profiles (id, name, phone) values ('fb-nr-owner', 'Suresh N', '9876526001'), ('fb-nr-t1', 'Ravi N', '9876526011');
insert into public.hostel_staff values ('f2960000-0000-0000-0000-000000000001', 'fb-nr-owner', 'owner');
insert into public.stays (id, hostel_id, user_id, name, confirmed) values
  ('f2963000-0000-0000-0000-000000000001', 'f2960000-0000-0000-0000-000000000001', 'fb-nr-t1', 'Ravi N', true),
  ('f2963000-0000-0000-0000-000000000002', 'f2960000-0000-0000-0000-000000000001', null, 'Kiran N', true);
insert into public.stays (id, hostel_id, user_id, name, confirmed, left_on) values
  ('f2963000-0000-0000-0000-000000000003', 'f2960000-0000-0000-0000-000000000001', 'fb-nr-t1', 'Ravi N', true, current_date - 1);

select test.act('anon', null);
select test.blocked($$select public.notify_resident('f2963000-0000-0000-0000-000000000001', 'Hi')$$);
select test.act('authenticated', 'fb-nr-t1');
select test.fails($$select public.notify_resident('f2963000-0000-0000-0000-000000000001', 'Hi')$$, 'owner or managers');
select test.act('authenticated', 'fb-nr-owner');
select test.fails($$select public.notify_resident('f2963000-0000-0000-0000-000000000002', 'Hi')$$, 'not on the app');
select test.fails($$select public.notify_resident('f2963000-0000-0000-0000-000000000003', 'Hi')$$, 'has left');
select test.fails($$select public.notify_resident('f2963000-0000-0000-0000-000000000001', '   ')$$, '1-200');
select test.fails($$select public.notify_resident('f2963000-0000-0000-0000-000000000001', repeat('x', 201))$$, '1-200');
select test.fails($$select public.notify_resident('00000000-0000-0000-0000-000000000000', 'Hi')$$, 'no such resident');
select public.notify_resident('f2963000-0000-0000-0000-000000000001', '  Water off at 3 pm  ');
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-nr-t1' and title = 'Notify PG' and body = 'Water off at 3 pm' and data = '{"screen":"rHome"}'::jsonb$$, 1);
\o
select 'ALL NOTIFY_RESIDENT TESTS PASSED';
