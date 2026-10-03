-- F24 Wave 4d: rates confirmed by the owner (server time only) and the monthly push.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a4d00000-0000-0000-0000-000000000001', 'rc-one', 'Rates PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.hostel_staff values ('a4d00000-0000-0000-0000-000000000001', 'fb-rc-owner', 'owner'), ('a4d00000-0000-0000-0000-000000000001', 'fb-rc-mgr', 'manager');

-- a new rate card is confirmed now, whatever date it's sent with
select test.act('authenticated', 'fb-rc-owner');
insert into public.rate_cards (hostel_id, ac, share, rent, confirmed_at) values
  ('a4d00000-0000-0000-0000-000000000001', false, 2, 8000, '2020-01-01'),
  ('a4d00000-0000-0000-0000-000000000001', true, 2, 9500, null);
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at > now() - interval '1 minute'), '2');

-- 40 days on (backdated as the server)
select test.server();
update public.rate_cards set confirmed_at = now() - interval '40 days' where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at < now() - interval '39 days'), '2');

-- the phone can't pick the date, nor clear it; saving the same price keeps the old date
select test.act('authenticated', 'fb-rc-owner');
update public.rate_cards set confirmed_at = now() where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
update public.rate_cards set confirmed_at = null where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
insert into public.rate_cards (hostel_id, ac, share, rent) values ('a4d00000-0000-0000-0000-000000000001', false, 2, 8000)
  on conflict (hostel_id, ac, share) do update set rent = excluded.rent;
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at < now() - interval '39 days'), '2');

-- the monthly push: to the owner only, data.kind 'rates', not again the next day
select test.server();
select public.nudge_rates();
select test.rows($$select count(*) from public.push_outbox where title = 'Are your rates still right?' and user_id = 'fb-rc-owner' and data ->> 'kind' = 'rates' and data ->> 'screen' = 'oToday'$$, 1);
select test.rows($$select count(*) from public.push_outbox where title = 'Are your rates still right?' and user_id = 'fb-rc-mgr'$$, 0);
select public.nudge_rates();
select test.rows($$select count(*) from public.push_outbox where title = 'Are your rates still right?' and user_id = 'fb-rc-owner'$$, 1);

-- a new price is confirmed now (only that card)
select test.act('authenticated', 'fb-rc-owner');
update public.rate_cards set rent = 8200 where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and not ac;
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at > now() - interval '1 minute'), '1');

-- "Rates still right": owner only (managers and strangers can't), and the job is the server's
select test.act('authenticated', 'fb-rc-mgr');
select test.fails($$select public.confirm_rates('a4d00000-0000-0000-0000-000000000001')$$, 'only the owner confirms rates');
select test.act('authenticated', 'fb-rc-stranger');
select test.fails($$select public.confirm_rates('a4d00000-0000-0000-0000-000000000001')$$, 'only the owner confirms rates');
select test.fails($$select public.nudge_rates()$$, 'permission denied');
select test.act('authenticated', 'fb-rc-owner');
select test.eq(public.confirm_rates('a4d00000-0000-0000-0000-000000000001')::text, '2');
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at > now() - interval '1 minute'), '2');
-- after a confirm, a plain update can't move the date again
update public.rate_cards set confirmed_at = '2020-01-01' where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
select test.eq((select count(*)::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001' and confirmed_at > now() - interval '1 minute'), '2');

-- tenants (even signed out) read it
select test.act('anon', null);
select test.eq((select (min(confirmed_at) > now() - interval '1 minute')::text from public.rate_cards where hostel_id = 'a4d00000-0000-0000-0000-000000000001'), 'true');

-- fresh rates: no push, even a month after the last one
select test.server();
update public.rate_nudges set sent_at = now() - interval '31 days' where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
select public.nudge_rates();
select test.rows($$select count(*) from public.push_outbox where title = 'Are your rates still right?' and user_id = 'fb-rc-owner'$$, 1);
-- a month stale again: one more
update public.rate_cards set confirmed_at = now() - interval '31 days' where hostel_id = 'a4d00000-0000-0000-0000-000000000001';
select public.nudge_rates();
select test.rows($$select count(*) from public.push_outbox where title = 'Are your rates still right?' and user_id = 'fb-rc-owner'$$, 2);

reset role;
\o
select 'ALL RATES CONFIRM TESTS PASSED';
