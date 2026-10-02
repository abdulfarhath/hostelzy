-- S6 Stay Rewards: runs after the other tests (uses their helpers and the S1 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status) values ('f0000000-0000-0000-0000-000000000001', 'nest', 'Nest PG', 'Men', 'Ameerpet', 'live');
insert into public.hostel_staff values ('f0000000-0000-0000-0000-000000000001', 'fb-nest', 'owner');
insert into public.profiles (id, name, phone) values ('fb-asha', 'Asha Kiran', '9876511111'), ('fb-ravi', 'Ravi Teja', '9876522222');

-- the app can't make itself a Member or write the ledger
select test.act('authenticated', 'fb-asha');
select test.fails($$update public.profiles set member = true where id = 'fb-asha'$$, 'not allowed');
select test.blocked($$insert into public.reward_ledger (event_key, kind, user_id, amount) values ('x', 'member', 'fb-asha', 100)$$);
-- Asha gets a code; Ravi uses it before his first stay (not his own, only once)
create temp table rc as select public.my_referral_code() as code;
select test.eq((select (code ~ '^ASHA-[A-Z2-9]{4}$')::text from rc), 'true');
select test.fails(format($$select public.use_referral_code(%L)$$, (select code from rc)), 'your own code');
select test.act('authenticated', 'fb-ravi');
select test.eq(public.use_referral_code(lower((select code from rc))), 'Asha');
select test.fails(format($$select public.use_referral_code(%L)$$, (select code from rc)), 'already used');

-- Asha's first stay through Hostelzy (owner confirms): she's a Member with ₹100 for the next stay
reset role;
insert into public.enquiries (hostel_id, tenant_id, ref, name, phone) values
  ('e0000000-0000-0000-0000-000000000001', 'fb-asha', 'new', 'Asha', '9876511111'),
  ('f0000000-0000-0000-0000-000000000001', 'fb-asha', 'new', 'Asha', '9876511111');
insert into public.stays (hostel_id, user_id, name, phone, via, confirmed) values ('e0000000-0000-0000-0000-000000000001', 'fb-asha', 'Asha Kiran', '9876511111', 'hz', true);
select test.eq((select member::text from public.profiles where id = 'fb-asha'), 'true');
select test.eq(public.reward_balance('fb-asha')::text, '100');
-- a Direct stay earns nothing
insert into public.stays (hostel_id, user_id, name, via, confirmed) values ('e0000000-0000-0000-0000-000000000001', 'fb-ravi', 'Ravi Teja', 'direct', true);
select test.eq(public.reward_balance('fb-ravi')::text, '0');

-- her next stay through Hostelzy: ₹100 off, credited to that owner's next invoice; Member once only
insert into public.stays (hostel_id, user_id, name, phone, via, confirmed) values ('f0000000-0000-0000-0000-000000000001', 'fb-asha', 'Asha Kiran', '9876511111', 'hz', true);
select test.eq(public.reward_balance('fb-asha')::text, '0');
select test.eq((select credit::text from public.owner_plans where hostel_id = 'f0000000-0000-0000-0000-000000000001'), '100');
select test.eq((select count(*)::text from public.reward_ledger where user_id = 'fb-asha' and kind = 'member'), '1');
-- the owner sees their credit, not Asha's balance
select test.act('authenticated', 'fb-nest');
select test.rows('select count(*) from public.reward_ledger', 1);

-- referral: after Ravi's first month at a Hostelzy hostel, ₹100 each, once
reset role;
update public.stays set via = 'hz', joined_on = current_date - 31 where user_id = 'fb-ravi';
select test.eq(public.referral_sweep()::text, '1');
select test.eq(public.referral_sweep()::text, '0');
-- Ravi became a Member (₹100) and got the referral (₹100); Asha got ₹100 for referring
select test.eq(public.reward_balance('fb-ravi')::text, '200');
select test.eq(public.reward_balance('fb-asha')::text, '100');

-- append-only, even for the team; the team reverses instead
select test.act('authenticated', 'fb-team', true);
select test.blocked($$update public.reward_ledger set amount = 1000$$);
select test.blocked($$delete from public.reward_ledger$$);
reset role;
select test.fails($$update public.reward_ledger set amount = 1000$$, 'append-only');
select test.fails($$delete from public.reward_ledger$$, 'append-only');
select test.act('authenticated', 'fb-team', true);
select public.reverse_reward((select id from public.reward_ledger where kind = 'owner_credit' and hostel_id = 'f0000000-0000-0000-0000-000000000001'), 'Asha never moved in');
select test.fails(format($$select public.reverse_reward(%L, 'again')$$, (select id from public.reward_ledger where kind = 'owner_credit' and hostel_id = 'f0000000-0000-0000-0000-000000000001')), 'duplicate');
select test.act('authenticated', 'fb-asha');
select test.fails($$select public.reverse_reward((select id from public.reward_ledger limit 1), 'mine')$$, 'only the Hostelzy team');
reset role;
select test.eq((select credit::text from public.owner_plans where hostel_id = 'f0000000-0000-0000-0000-000000000001'), '0');

reset role;
\o
select 'ALL REWARD TESTS PASSED';
