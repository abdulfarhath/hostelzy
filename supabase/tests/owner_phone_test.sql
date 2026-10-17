-- F24 item 1: the owner's number only after a hold, an enquiry or a stay.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2500000-0000-0000-0000-000000000001', 'op-one', 'Phone One PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('a2500000-0000-0000-0000-000000000002', 'op-two', 'Phone Two PG', 'Women', 'Kondapur', 'live', 'Lata');
insert into public.profiles (id, name, phone) values ('fb-op-owner', 'Ravi', '98765 43210'), ('fb-op-mgr', 'Manoj', '9000011111');
insert into public.hostel_staff values
  ('a2500000-0000-0000-0000-000000000001', 'fb-op-owner', 'owner'),
  ('a2500000-0000-0000-0000-000000000001', 'fb-op-mgr', 'manager');
insert into public.hostel_leads (hostel_id, owner_phone) values ('a2500000-0000-0000-0000-000000000002', '91234 56789');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a2510000-0000-0000-0000-000000000001', 'a2500000-0000-0000-0000-000000000001', 101, 1, 2, 9000);
insert into public.beds (id, hostel_id, room_id, letter) values ('a2520000-0000-0000-0000-000000000001', 'a2500000-0000-0000-0000-000000000001', 'a2510000-0000-0000-0000-000000000001', 'A');
-- seed past holds as they are (the hold rules only check new ones)
set session_replication_role = replica;
insert into public.holds (hostel_id, bed_id, tenant_id, opt, status) values ('a2500000-0000-0000-0000-000000000001', 'a2520000-0000-0000-0000-000000000001', 'fb-op-holder', 'free', 'expired');
insert into public.holds (hostel_id, bed_id, tenant_id, opt, status, started_at) values ('a2500000-0000-0000-0000-000000000001', 'a2520000-0000-0000-0000-000000000001', 'fb-op-old', 'free', 'expired', now() - interval '90 days');
set session_replication_role = origin;
insert into public.enquiries (hostel_id, tenant_id, ref, name, phone) values ('a2500000-0000-0000-0000-000000000002', 'fb-op-asker', 'HZ-9001', 'Asha', '9000022222');
insert into public.stays (hostel_id, user_id, name, confirmed, left_on) values
  ('a2500000-0000-0000-0000-000000000001', 'fb-op-res', 'Priya', true, null),
  ('a2500000-0000-0000-0000-000000000001', 'fb-op-gone', 'Old Resident', true, current_date - 120);

create temp table q (who text, got text);
grant all on q to anon, authenticated;
create function pg_temp.ask(who text) returns text language sql as $$
  select coalesce(string_agg(h.slug || '=' || c.phone, ' ' order by h.slug), '')
  from public.owner_contacts(array['a2500000-0000-0000-0000-000000000001', 'a2500000-0000-0000-0000-000000000002']::uuid[]) c
  join public.hostels h on h.id = c.hostel_id
$$;

-- a stranger sees nothing; anon can't call it
select test.act('authenticated', 'fb-op-stranger');
select test.eq(pg_temp.ask('x'), '');
select test.act('anon', null);
select test.blocked($$select * from public.owner_contacts(array['a2500000-0000-0000-0000-000000000001']::uuid[])$$);
-- F26 #7: an ended hold no longer shows it (it locks again when the hold ends)
select test.act('authenticated', 'fb-op-holder');
select test.eq(pg_temp.ask('x'), '');
select test.act('authenticated', 'fb-op-old');
select test.eq(pg_temp.ask('x'), '');
-- F26 #7: an enquiry no longer shows it either
select test.act('authenticated', 'fb-op-asker');
select test.eq(pg_temp.ask('x'), '');
-- residents now, not ones who left long ago
select test.act('authenticated', 'fb-op-res');
select test.eq(pg_temp.ask('x'), 'op-one=9876543210');
select test.act('authenticated', 'fb-op-gone');
select test.eq(pg_temp.ask('x'), '');
-- staff: their own hostel; the team: every hostel
select test.act('authenticated', 'fb-op-mgr');
select test.eq(pg_temp.ask('x'), 'op-one=9876543210');
select test.act('authenticated', 'fb-op-hq', true);
select test.eq(pg_temp.ask('x'), 'op-one=9876543210 op-two=9123456789');

\o
select 'ALL OWNER PHONE TESTS PASSED';
