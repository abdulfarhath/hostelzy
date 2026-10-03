-- F24 #18 follow-up: strike 2 hides deals from tenants on the server.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a9900000-0000-0000-0000-000000000001', 'sd-one', 'Strike Deals PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.hostel_staff values ('a9900000-0000-0000-0000-000000000001', 'fb-sd-owner', 'owner');
insert into public.deals (hostel_id, deals_on, target) values ('a9900000-0000-0000-0000-000000000001', '{monthly}', 'all');

-- No strikes: a tenant reads the deals.
select test.act('authenticated', 'fb-sd-tenant');
select test.rows($$select count(*) from public.deals where hostel_id = 'a9900000-0000-0000-0000-000000000001'$$, 1);

-- Strike 2, today: hidden from tenants and guests, not from the owner.
reset role;
insert into public.strikes (hostel_id, created_at) values
  ('a9900000-0000-0000-0000-000000000001', now() - interval '40 days'),
  ('a9900000-0000-0000-0000-000000000001', now());
select test.act('authenticated', 'fb-sd-tenant');
select test.rows($$select count(*) from public.deals where hostel_id = 'a9900000-0000-0000-0000-000000000001'$$, 0);
select test.act('anon', null);
select test.rows($$select count(*) from public.deals where hostel_id = 'a9900000-0000-0000-0000-000000000001'$$, 0);
select test.act('authenticated', 'fb-sd-owner');
select test.rows($$select count(*) from public.deals where hostel_id = 'a9900000-0000-0000-0000-000000000001'$$, 1);

-- 30 days later the deals are back for tenants.
reset role;
update public.strikes set created_at = created_at - interval '31 days' where hostel_id = 'a9900000-0000-0000-0000-000000000001';
select test.act('authenticated', 'fb-sd-tenant');
select test.rows($$select count(*) from public.deals where hostel_id = 'a9900000-0000-0000-0000-000000000001'$$, 1);

reset role;
\o
select 'ALL STRIKE DEALS TESTS PASSED';
