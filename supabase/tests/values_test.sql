-- F24 item 6: reply speed and the ranking's counts, from real rows.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2700000-0000-0000-0000-000000000001', 'val-one', 'Value PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('a2700000-0000-0000-0000-000000000002', 'val-draft', 'Draft PG', 'Men', 'Madhapur', 'draft', 'Ravi');
insert into public.hostel_staff values ('a2700000-0000-0000-0000-000000000001', 'fb-val-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a2710000-0000-0000-0000-000000000001', 'a2700000-0000-0000-0000-000000000001', 101, 1, 3, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('a2720000-0000-0000-0000-000000000001', 'a2700000-0000-0000-0000-000000000001', 'a2710000-0000-0000-0000-000000000001', 'A'),
  ('a2720000-0000-0000-0000-000000000002', 'a2700000-0000-0000-0000-000000000001', 'a2710000-0000-0000-0000-000000000001', 'B');
insert into public.enquiries (id, hostel_id, tenant_id, ref, name, phone, created_at) values
  ('a2730000-0000-0000-0000-000000000001', 'a2700000-0000-0000-0000-000000000001', 'fb-t1', 'HZ-1', 'A', '9000000001', now() - interval '30 minutes'),
  ('a2730000-0000-0000-0000-000000000002', 'a2700000-0000-0000-0000-000000000001', 'fb-t2', 'HZ-2', 'B', '9000000002', now() - interval '10 minutes');
set session_replication_role = replica;
insert into public.holds (id, hostel_id, bed_id, tenant_id, opt, status, started_at) values
  ('a2740000-0000-0000-0000-000000000001', 'a2700000-0000-0000-0000-000000000001', 'a2720000-0000-0000-0000-000000000001', 'fb-t3', 'free', 'waiting', now() - interval '50 minutes');
set session_replication_role = origin;
insert into public.complaints (hostel_id, author_id, cat, body) values ('a2700000-0000-0000-0000-000000000001', 'fb-r', 'Wi-Fi', 'Slow');

-- not enough replies yet: 0
select test.act('anon', null);
select test.eq((select reply_minutes || ' ' || reply_n from public.hostel_signals() where hostel_id = 'a2700000-0000-0000-0000-000000000001'), '0 0');
select test.rows($$select count(*) from public.hostel_signals() where hostel_id = 'a2700000-0000-0000-0000-000000000002'$$, 0);
-- the owner replies: the server stamps the time once
select test.act('authenticated', 'fb-val-owner');
update public.enquiries set contacted = true where hostel_id = 'a2700000-0000-0000-0000-000000000001';
reset role;
update public.holds set status = 'held' where id = 'a2740000-0000-0000-0000-000000000001';
select test.rows($$select count(*) from public.enquiries where contacted_at is not null$$, 2);
select test.rows($$select count(*) from public.holds where decided_at is not null and id = 'a2740000-0000-0000-0000-000000000001'$$, 1);
select test.act('anon', null);
select test.eq((select reply_minutes || ' ' || reply_n || ' ' || complaints_30d || ' ' || rooms || ' ' || photos || ' ' || layouts from public.hostel_signals() where hostel_id = 'a2700000-0000-0000-0000-000000000001'), '50 1 1 1 0 0');   -- F26: hold replies only

\o
select 'ALL VALUE TESTS PASSED';
