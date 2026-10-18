-- F28 Part 2: add_hostel (dedupe, one in progress, partner code), rewards
-- ₹200 / ₹20 with the ₹2,000 monthly cap, payouts, my_added_hostel, photos.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, lat, lng) values
  ('f2800000-0000-0000-0000-000000000001', 'f28-live', 'Sri Venkateswara PG', 'Men', 'Madhapur', 'live', 17.4486, 78.3908),
  ('f2800000-0000-0000-0000-000000000002', 'f28-listed', 'F28 Listed PG', 'Men', 'Madhapur', 'listed', 17.4600, 78.4000);
insert into public.profiles (id, name, phone) values ('fb-f28-owner', 'Ravi', '9876528001'), ('fb-f28-adder', 'Asha', '9876528002'), ('fb-f28-partner', 'Partner P', '9876528003');
insert into public.hostel_staff values ('f2800000-0000-0000-0000-000000000001', 'fb-f28-owner', 'owner');
insert into public.hostel_leads (hostel_id, owner_phone) values ('f2800000-0000-0000-0000-000000000002', '9876528011');

create function pg_temp.p(extra jsonb default '{}') returns jsonb language sql as $$
  select '{"name":"Lakshmi Nivas PG","gender":"Women","lat":17.4420,"lng":78.3800,"area":"Madhapur","rent":7500,"share":3,"food":true,"owner_name":"Lakshmi Devi","owner_phone":"9876528020"}'::jsonb || extra
$$;

-- ------------------------------------------------------------ guests and bad input
select test.act('anon', null);
select test.blocked($$select public.add_hostel(pg_temp.p())$$);
select test.act('authenticated', 'fb-f28-adder');
select test.fails($$select public.add_hostel(pg_temp.p('{"name":"X"}'))$$, 'hostel name');
select test.fails($$select public.add_hostel(pg_temp.p('{"lat":12.9}'))$$, 'pin');
select test.fails($$select public.add_hostel(pg_temp.p('{"owner_phone":"12345"}'))$$, '10 digits');
select test.fails($$select public.add_hostel(pg_temp.p('{"rent":500}'))$$, 'rent');
select test.fails($$select public.add_hostel(pg_temp.p('{"partner_code":"HZ-PART-99","rent_min":7000,"rent_max":9000}'))$$, 'partner code');

-- ------------------------------------------------------------ dedupe
-- same owner phone as the live hostel's owner (profile)
select test.eq((public.add_hostel(pg_temp.p('{"owner_phone":"9876528001"}')) ->> 'duplicate'), 'true');
select test.eq((public.add_hostel(pg_temp.p('{"owner_phone":"9876528001"}')) ->> 'name'), 'Sri Venkateswara PG');
-- same owner phone as a listed hostel's lead (team-only table)
select test.eq((public.add_hostel(pg_temp.p('{"owner_phone":"9876528011"}')) ->> 'name'), 'F28 Listed PG');
-- same name within 150 m (punctuation and case don't matter)
select test.eq((public.add_hostel(pg_temp.p('{"name":"sri venkateswara p.g.","lat":17.4490,"lng":78.3910}')) ->> 'duplicate'), 'true');
-- same name 2 km away is a different hostel
select test.eq((public.add_hostel(pg_temp.p('{"name":"Sri Venkateswara PG","lat":17.4700,"lng":78.4100}')) ->> 'duplicate'), 'false');
select test.rows($$select count(*) from public.hostels where added_by = 'fb-f28-adder'$$, 1);
reset role;
-- a resident has one hostel in progress at a time
select test.act('authenticated', 'fb-f28-adder');
select test.fails($$select public.add_hostel(pg_temp.p())$$, 'in progress');
reset role;
select set_config('hz.f28a', (select id::text from public.hostels where added_by = 'fb-f28-adder'), false);
-- what was stored: listed, resident source, rent confirmed, masked hint, team-only phone
select test.eq((select status || ' ' || source || ' ' || rent_min || '-' || rent_max || ' ' || owner_phone_hint || ' ' || (rent_confirmed_at is not null) from public.hostels where id = current_setting('hz.f28a')::uuid), 'listed resident 7500-7500  true');
select test.eq((select owner_phone from public.hostel_leads where hostel_id = current_setting('hz.f28a')::uuid), '9876528020');
select test.eq((select array_to_string(tags, ',') from public.hostels where id = current_setting('hz.f28a')::uuid), '3 sharing,Food included');
-- the public sees the listed hostel but never the owner's full number
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where id = current_setting('hz.f28a')::uuid and owner_phone_hint = ''$$, 1);
select test.blocked($$select owner_phone from public.hostel_leads where hostel_id = current_setting('hz.f28a')::uuid$$);

-- ------------------------------------------------------------ the adder's photos (up to 3), nobody else's
select test.act('authenticated', 'fb-f28-adder');
insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.f28a')::uuid, current_setting('hz.f28a') || '/a.jpg');
insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.f28a')::uuid, current_setting('hz.f28a') || '/b.jpg');
insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.f28a')::uuid, current_setting('hz.f28a') || '/c.jpg');
select test.blocked($$insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.f28a')::uuid, current_setting('hz.f28a') || '/d.jpg')$$);
select test.act('authenticated', 'fb-f28-stranger');
select test.blocked($$insert into public.hostel_photos (hostel_id, path) values (current_setting('hz.f28a')::uuid, current_setting('hz.f28a') || '/e.jpg')$$);

-- ------------------------------------------------------------ S93 steps: asked, agreed, verified, paid
select test.act('authenticated', 'fb-f28-adder');
select test.eq((public.my_added_hostel() ->> 'name'), 'Sri Venkateswara PG');
select test.eq((public.my_added_hostel() ->> 'owner_phone'), '9876528020');
select test.eq((public.my_added_hostel() ->> 'photos'), '3');
select test.eq((public.my_added_hostel() ->> 'owner_asked_at'), null);
select public.asked_owner(current_setting('hz.f28a')::uuid);
select test.eq(((public.my_added_hostel() ->> 'owner_asked_at') is not null)::text, 'true');
select test.act('authenticated', 'fb-f28-stranger');
select test.fails($$select public.asked_owner(current_setting('hz.f28a')::uuid)$$, 'not your hostel');
select test.eq(public.my_added_hostel()::text, null);
-- the owner claims it (owner agreed)
select test.act('authenticated', 'fb-f28-newowner');
insert into public.claim_requests (hostel_id, name, phone) values (current_setting('hz.f28a')::uuid, 'Lakshmi Devi', '9876528020');
select test.act('authenticated', 'fb-f28-adder');
select test.eq(((public.my_added_hostel() ->> 'owner_agreed_at') is not null)::text, 'true');
select test.eq((public.my_added_hostel() ->> 'reward'), null);
-- UPI id for the payout
select test.fails($$select public.set_adder_upi('not a upi')$$, 'UPI');
select public.set_adder_upi('asha@upi');
select test.eq((public.my_added_hostel() ->> 'upi'), 'asha@upi');
-- the team verifies it: ₹200 to the adder, once, and a push
select test.act('authenticated', 'fb-f28-team', true);
update public.hostels set status = 'live' where id = current_setting('hz.f28a')::uuid;
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.reward_ledger where kind = 'hostel_added' and user_id = 'fb-f28-adder' and amount = 200 and hostel_id = current_setting('hz.f28a')::uuid$$, 1);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f28-adder' and title like '% is verified'$$, 1);
select test.act('authenticated', 'fb-f28-team', true);
update public.hostels set status = 'paused' where id = current_setting('hz.f28a')::uuid;
update public.hostels set status = 'live' where id = current_setting('hz.f28a')::uuid;
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.reward_ledger where kind = 'hostel_added' and user_id = 'fb-f28-adder'$$, 1);
select test.eq((select pay_month::text from public.reward_ledger where kind = 'hostel_added' and user_id = 'fb-f28-adder'), date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date::text);
select test.act('authenticated', 'fb-f28-adder');
select test.eq((public.my_added_hostel() ->> 'status') || ' ' || (public.my_added_hostel() ->> 'reward') || ' ' || ((public.my_added_hostel() ->> 'paid_at') is null), 'live 200 true');
-- the adder reads their own ledger row; a stranger doesn't
select test.rows($$select count(*) from public.reward_ledger where kind = 'hostel_added'$$, 1);
select test.act('authenticated', 'fb-f28-stranger');
select test.rows($$select count(*) from public.reward_ledger where kind = 'hostel_added'$$, 0);
-- after it went live the adder can add another
select test.act('authenticated', 'fb-f28-adder');
select test.eq((public.add_hostel(pg_temp.p('{"name":"Second PG","lat":17.4300,"lng":78.3700,"owner_phone":"9876528030"}')) ->> 'duplicate'), 'false');
select test.eq((public.my_added_hostel() ->> 'name'), 'Second PG');

-- ------------------------------------------------------------ partners: code, range, ₹20 after the team check
select test.act('authenticated', 'fb-f28-adder');
select test.blocked($$select public.new_partner('Partner P', '9876528003', 'pp@upi')$$);
select test.act('authenticated', 'fb-f28-team', true);
select test.eq(public.new_partner('Partner P', '9876528003', 'pp@upi'), 'HZ-PART-1');
select test.eq(public.new_partner('Partner Q', '9876528004'), 'HZ-PART-2');
select test.act('authenticated', 'fb-f28-partner');
select test.fails($$select public.add_hostel(pg_temp.p('{"partner_code":"HZ-PART-1","owner_phone":"9876528040","lat":17.4100,"lng":78.3600}'))$$, 'rent');
select test.eq((public.add_hostel(pg_temp.p('{"name":"Partner PG One","partner_code":"hz-part-1","rent_min":7000,"rent_max":9000,"owner_phone":"9876528040","lat":17.4100,"lng":78.3600}')) ->> 'duplicate'), 'false');
-- a partner can have many in progress
select test.eq((public.add_hostel(pg_temp.p('{"name":"Partner PG Two","partner_code":"HZ-PART-1","rent_min":6000,"rent_max":8000,"owner_phone":"9876528041","lat":17.4150,"lng":78.3650}')) ->> 'duplicate'), 'false');
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.hostels where added_by = 'fb-f28-partner' and source = 'partner' and partner_code = 'HZ-PART-1' and rent_min = 7000 and rent_max = 9000$$, 1);
select set_config('hz.f28p', (select id::text from public.hostels where name = 'Partner PG One'), false);
-- no ₹20 until the team ticks "checked"
select test.act('authenticated', 'fb-f28-partner');
select test.blocked($$select public.check_partner_hostel(current_setting('hz.f28p')::uuid)$$);
select test.act('authenticated', 'fb-f28-team', true);
select test.fails($$select public.check_partner_hostel(current_setting('hz.f28a')::uuid)$$, 'not a partner listing');
select public.check_partner_hostel(current_setting('hz.f28p')::uuid);
select public.check_partner_hostel(current_setting('hz.f28p')::uuid);
select test.rows($$select count(*) from public.reward_ledger where kind = 'hostel_listed' and user_id = 'fb-f28-partner' and amount = 20$$, 1);
select test.eq((select listed || ' ' || checked || ' ' || due || ' ' || paid from public.partners_due() where code = 'HZ-PART-1'), '2 1 20 0');
-- console › Payments: both payouts due, with the UPI id to pay
select test.rows($$select count(*) from public.payouts_due()$$, 2);
select test.eq((select upi from public.payouts_due() where kind = 'hostel_added'), 'asha@upi');
select test.eq((select upi || ' ' || who from public.payouts_due() where kind = 'hostel_listed'), 'pp@upi Partner P');
select public.mark_payout_paid((select ledger_id from public.payouts_due() where kind = 'hostel_listed'), 'UTR123');
select test.rows($$select count(*) from public.payouts_due()$$, 1);
select test.eq((select due || ' ' || paid from public.partners_due() where code = 'HZ-PART-1'), '0 20');
select test.act('authenticated', 'fb-f28-partner');
select test.blocked($$select public.mark_payout_paid((select id from public.reward_ledger where kind = 'hostel_added' limit 1), 'x')$$);
select test.blocked($$select * from public.partners_due()$$);
select test.blocked($$select * from public.payouts_due()$$);

-- ------------------------------------------------------------ the ₹2,000 monthly cap: queued to next month
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.reward_ledger (event_key, kind, user_id, amount, reason, pay_month, created_by)
values ('cap-fill', 'hostel_listed', 'fb-f28-x', 1780, 'test fill', date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date, 'server');
-- used so far this month: 200 + 20 + 1780 = 2000 → the next ₹200 goes to next month
insert into public.hostels (id, slug, name, gender, area, status, lat, lng, source, added_by) values
  ('f2800000-0000-0000-0000-000000000003', 'f28-cap', 'Cap PG', 'Men', 'Madhapur', 'listed', 17.40, 78.40, 'resident', 'fb-f28-cap');
select test.act('authenticated', 'fb-f28-team', true);
update public.hostels set status = 'live' where id = 'f2800000-0000-0000-0000-000000000003';
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select pay_month::text from public.reward_ledger where event_key = 'added:f2800000-0000-0000-0000-000000000003'),
  (date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date + interval '1 month')::date::text);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f28-cap' and body like '%UPI in %'$$, 1);
select test.act('authenticated', 'fb-f28-cap');
select test.eq((public.my_added_hostel() ->> 'pay_month'), (date_trunc('month', (now() at time zone 'Asia/Kolkata'))::date + interval '1 month')::date::text);

-- rerun safety of the ledger: the kind check still allows the old kinds
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.reward_ledger (event_key, kind, user_id, amount, reason) values ('f28-member', 'member', 'fb-f28-y', 100, 'ok');
\o
\echo ' F28 ADD HOSTELS TESTS PASSED'
