-- F24 item 18: Fair Play hardening (rules accepted, joined before Hostelzy,
-- strikes now, strike 3 hides the hostel, 3 fixes = 1 warning, the six
-- signals, tenant reports for the team).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('fa000000-0000-0000-0000-000000000001', 'fh-live', 'Fair Live PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('fa000000-0000-0000-0000-000000000002', 'fh-draft', 'Fair Draft PG', 'Men', 'Madhapur', 'draft', 'Ravi'),
  ('fa000000-0000-0000-0000-000000000003', 'fh-fix', 'Fair Fix PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('fa000000-0000-0000-0000-000000000004', 'fh-sig', 'Fair Signal PG', 'Men', 'Madhapur', 'live', 'Ravi');
insert into public.hostel_staff values
  ('fa000000-0000-0000-0000-000000000001', 'fb-fh-owner', 'owner'),
  ('fa000000-0000-0000-0000-000000000002', 'fb-fh-owner', 'owner'),
  ('fa000000-0000-0000-0000-000000000003', 'fb-fh-owner', 'owner'),
  ('fa000000-0000-0000-0000-000000000004', 'fb-fh-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('fa010000-0000-0000-0000-000000000001', 'fa000000-0000-0000-0000-000000000001', 101, 1, 2, 8000),
  ('fa010000-0000-0000-0000-000000000004', 'fa000000-0000-0000-0000-000000000004', 101, 1, 4, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('fa020000-0000-0000-0000-000000000001', 'fa000000-0000-0000-0000-000000000001', 'fa010000-0000-0000-0000-000000000001', 'A'),
  ('fa020000-0000-0000-0000-000000000041', 'fa000000-0000-0000-0000-000000000004', 'fa010000-0000-0000-0000-000000000004', 'A'),
  ('fa020000-0000-0000-0000-000000000042', 'fa000000-0000-0000-0000-000000000004', 'fa010000-0000-0000-0000-000000000004', 'B'),
  ('fa020000-0000-0000-0000-000000000043', 'fa000000-0000-0000-0000-000000000004', 'fa010000-0000-0000-0000-000000000004', 'C'),
  ('fa020000-0000-0000-0000-000000000044', 'fa000000-0000-0000-0000-000000000004', 'fa010000-0000-0000-0000-000000000004', 'D');
insert into public.rate_cards values
  ('fa000000-0000-0000-0000-000000000001', false, 2, 8000),
  ('fa000000-0000-0000-0000-000000000004', false, 4, 8000);
insert into public.deals (hostel_id, deals_on) values
  ('fa000000-0000-0000-0000-000000000001', '{adv1500}'),
  ('fa000000-0000-0000-0000-000000000004', '{adv1500}');
insert into public.owner_plans (hostel_id, status) values ('fa000000-0000-0000-0000-000000000001', 'trial');
-- go-live day is set by the server
select test.eq((select (live_since = (now() at time zone 'Asia/Kolkata')::date)::text from public.hostels where id = 'fa000000-0000-0000-0000-000000000001'), 'true');
select test.eq((select live_since::text from public.hostels where id = 'fa000000-0000-0000-0000-000000000002'), null);

-- ---------------------------------------------------------------- 1. rules accepted, once, on the server
select test.act('anon', null);
select test.fails($$select public.accept_fair_play()$$, 'permission denied');
select test.act('authenticated', 'fb-fh-owner');
select public.accept_fair_play();
select public.accept_fair_play();
select test.rows($$select count(*) from public.fair_play_accepts$$, 1);
select test.blocked($$insert into public.fair_play_accepts (user_id) values ('fb-someone')$$);
select test.act('authenticated', 'fb-fh-other');
select test.rows($$select count(*) from public.fair_play_accepts$$, 0);
select test.act('authenticated', 'fb-fh-team', true);
select test.rows($$select count(*) from public.fair_play_accepts where user_id = 'fb-fh-owner'$$, 1);

-- ---------------------------------------------------------------- 2. joined before Hostelzy
select test.act('authenticated', 'fb-fh-owner');
-- onboarding (not live yet): the owner may
insert into public.stays (hostel_id, name, phone, via) values ('fa000000-0000-0000-0000-000000000002', 'Old Timer', '9000000001', 'before');
-- after go-live: only the team
select test.fails($$insert into public.stays (hostel_id, name, phone, via) values ('fa000000-0000-0000-0000-000000000001', 'Late Old', '9000000002', 'before')$$, 'only the Hostelzy team');
insert into public.stays (hostel_id, name, phone, via) values ('fa000000-0000-0000-0000-000000000001', 'Walk In', '9000000003', 'direct');
select test.fails($$update public.stays set via = 'before' where name = 'Walk In' and hostel_id::text like 'fa000000-%'$$, 'only the Hostelzy team');
select test.fails($$update public.hostels set live_since = '2020-01-01' where id = 'fa000000-0000-0000-0000-000000000001'$$, 'ask the Hostelzy team');
select test.act('authenticated', 'fb-fh-team', true);
insert into public.stays (hostel_id, name, phone, via, joined_on) values ('fa000000-0000-0000-0000-000000000001', 'Long Stay', '9000000004', 'before', current_date - 200);
select test.fails($$insert into public.stays (hostel_id, name, phone, via, joined_on) values ('fa000000-0000-0000-0000-000000000001', 'Too New', '9000000005', 'before', current_date + 5)$$, 'only residents who moved in by');
-- the draft goes live: its day is set, and its before-resident stays before
update public.hostels set status = 'live' where id = 'fa000000-0000-0000-0000-000000000002';
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select (live_since is not null)::text from public.hostels where id = 'fa000000-0000-0000-0000-000000000002'), 'true');
select test.eq((select via from public.stays where name = 'Old Timer' and hostel_id::text like 'fa000000-%'), 'before');
select test.eq((select via from public.stays where name = 'Long Stay' and hostel_id::text like 'fa000000-%'), 'before');
-- the owner may still edit a before-resident's other details
select test.act('authenticated', 'fb-fh-owner');
update public.stays set rent = 7500 where name = 'Old Timer' and hostel_id::text like 'fa000000-%';

-- ---------------------------------------------------------------- 3–4. strikes now
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.fair_cases (ref, hostel_id, title, signal) values
  ('FP-8001', 'fa000000-0000-0000-0000-000000000001', 'One', 'Signal'),
  ('FP-8002', 'fa000000-0000-0000-0000-000000000001', 'Two', 'Signal'),
  ('FP-8003', 'fa000000-0000-0000-0000-000000000001', 'Three', 'Signal');
select test.act('authenticated', 'fb-fh-owner');
select test.fails($$select public.give_strike((select id from public.fair_cases where ref = 'FP-8001'))$$, 'only the Hostelzy team');
select test.act('authenticated', 'fb-fh-team', true);
select test.eq(public.give_strike((select id from public.fair_cases where ref = 'FP-8001')), 'Strike 1 · warning');
select test.fails($$select public.give_strike((select id from public.fair_cases where ref = 'FP-8001'))$$, 'already decided');
select test.eq(public.give_strike((select id from public.fair_cases where ref = 'FP-8002')), 'Strike 2 · deals hidden for 30 days');
select test.eq((select status || ' · ' || decision from public.fair_cases where ref = 'FP-8002'), 'decided · Strike 2 · deals hidden for 30 days');
-- strike 2: deals hidden, for everyone and at booking time
select test.act('anon', null);
select test.eq((select n || ' ' || deals_hidden || ' ' || removed from public.fair_standing() where hostel_id = 'fa000000-0000-0000-0000-000000000001'), '2 true false');
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq(public.deal_for_bed('fa000000-0000-0000-0000-000000000001', 'fa020000-0000-0000-0000-000000000001') ->> 'on', '[]');
-- 30 days later the deals come back; the strikes still count
update public.strikes set created_at = created_at - interval '31 days' where hostel_id = 'fa000000-0000-0000-0000-000000000001';
select test.act('anon', null);
select test.eq((select n || ' ' || deals_hidden from public.fair_standing() where hostel_id = 'fa000000-0000-0000-0000-000000000001'), '2 false');
select test.eq((select n::text from public.strike_counts() where hostel_id = 'fa000000-0000-0000-0000-000000000001'), '2');
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq(public.deal_for_bed('fa000000-0000-0000-0000-000000000001', 'fa020000-0000-0000-0000-000000000001') ->> 'on', '["adv1500"]');
-- strike 3: removed on the server
select test.act('authenticated', 'fb-fh-team', true);
select test.eq(public.give_strike((select id from public.fair_cases where ref = 'FP-8003')), 'Strike 3 · removed from Hostelzy');
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where id = 'fa000000-0000-0000-0000-000000000001'$$, 0);
select test.rows($$select count(*) from public.rooms where hostel_id = 'fa000000-0000-0000-0000-000000000001'$$, 0);
select test.rows($$select count(*) from public.fair_standing() where hostel_id = 'fa000000-0000-0000-0000-000000000001'$$, 0);
select test.act('authenticated', 'fb-fh-tenant');
select test.rows($$select count(*) from public.hostels where id = 'fa000000-0000-0000-0000-000000000001'$$, 0);
select test.blocked($$insert into public.enquiries (hostel_id, ref, name, phone) values ('fa000000-0000-0000-0000-000000000001', 'new', 'T', '9000000009')$$);
-- the owner still sees the hostel and why
select test.act('authenticated', 'fb-fh-owner');
select test.rows($$select count(*) from public.hostels where id = 'fa000000-0000-0000-0000-000000000001'$$, 1);
select test.eq((select n || ' ' || removed from public.fair_standing() where hostel_id = 'fa000000-0000-0000-0000-000000000001'), '3 true');
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select status from public.owner_plans where hostel_id = 'fa000000-0000-0000-0000-000000000001'), 'paused');

-- ---------------------------------------------------------------- 7. three fixes in 6 months = one warning
insert into public.stays (hostel_id, name, phone, via) values
  ('fa000000-0000-0000-0000-000000000003', 'Fix One', '9100000001', 'direct'),
  ('fa000000-0000-0000-0000-000000000003', 'Fix Two', '9100000002', 'direct'),
  ('fa000000-0000-0000-0000-000000000003', 'Fix Three', '9100000003', 'direct');
insert into public.fair_cases (ref, hostel_id, title, signal, resident) values
  ('FP-8101', 'fa000000-0000-0000-0000-000000000003', 'A', 'Signal', 'Fix One'),
  ('FP-8102', 'fa000000-0000-0000-0000-000000000003', 'B', 'Signal', 'Fix Two'),
  ('FP-8103', 'fa000000-0000-0000-0000-000000000003', 'C', 'Signal', 'Fix Three');
select test.act('authenticated', 'fb-fh-owner');
select public.fix_case((select id from public.fair_cases where ref = 'FP-8101'));
select public.fix_case((select id from public.fair_cases where ref = 'FP-8102'));
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.strikes where hostel_id = 'fa000000-0000-0000-0000-000000000003'$$, 0);
select test.act('authenticated', 'fb-fh-owner');
select public.fix_case((select id from public.fair_cases where ref = 'FP-8103'));
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select count(*) || ' ' || min(reason) from public.strikes where hostel_id = 'fa000000-0000-0000-0000-000000000003'), '1 fixes');
select test.eq((select count(*)::text from public.fair_cases where hostel_id = 'fa000000-0000-0000-0000-000000000003' and fix_counted), '3');
select test.eq((select via from public.stays where name = 'Fix Three' and hostel_id::text like 'fa000000-%'), 'hz');

-- ---------------------------------------------------------------- 5. the six signals
insert into public.profiles (id, phone, name) values ('fb-fh-t1', '9200000001', 'Yes Sayer'), ('fb-fh-t2', '9200000002', 'Hold Person');
-- 1: Ravi enquired from one number, added as Direct with another
insert into public.enquiries (hostel_id, tenant_id, ref, name, phone, created_at) values
  ('fa000000-0000-0000-0000-000000000004', 'fb-fh-t3', 'HZ-ENQ1', 'Ravi Kumar', '9200000003', now() - interval '5 days');
insert into public.stays (hostel_id, bed_id, name, phone, via, rent) values
  ('fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000041', 'ravi kumar', '9299999999', 'direct', 8000);
-- 2 + 5: holds on bed B and C declined by the owner; bed B goes to a Direct resident
set session_replication_role = replica;
insert into public.holds (id, hostel_id, bed_id, tenant_id, opt, status, started_at) values
  ('fa040000-0000-0000-0000-000000000001', 'fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000042', 'fb-fh-t2', 'free', 'waiting', now() - interval '2 days'),
  ('fa040000-0000-0000-0000-000000000002', 'fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000043', 'fb-fh-t2', 'free', 'waiting', now() - interval '2 days'),
  ('fa040000-0000-0000-0000-000000000003', 'fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000044', 'fb-fh-t1', 'free', 'expired', now() - interval '10 days'),
  ('fa040000-0000-0000-0000-000000000004', 'fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000044', 'fb-fh-t2', 'free', 'waiting', now() - interval '1 day');
set session_replication_role = origin;
-- the tenant releasing their own hold isn't a decline
select test.act('authenticated', 'fb-fh-t2');
update public.holds set status = 'released' where id = 'fa040000-0000-0000-0000-000000000004';
update public.holds set declined = true where id = 'fa040000-0000-0000-0000-000000000004';
select test.act('authenticated', 'fb-fh-owner');
update public.holds set status = 'released' where id in ('fa040000-0000-0000-0000-000000000001', 'fa040000-0000-0000-0000-000000000002');
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select string_agg(declined::text, ',' order by id) from public.holds where hostel_id = 'fa000000-0000-0000-0000-000000000004'), 'true,true,false,false');
-- 4: on the deal price (₹7,000 against a ₹8,000 walk-in)
insert into public.stays (hostel_id, bed_id, name, phone, via, rent) values
  ('fa000000-0000-0000-0000-000000000004', 'fa020000-0000-0000-0000-000000000042', 'Cheap Direct', '9288888888', 'direct', 7000);
-- 3: said yes four days ago, never added
insert into public.join_answers (hold_id, hostel_id, tenant_id, answer, updated_at) values
  ('fa040000-0000-0000-0000-000000000003', 'fa000000-0000-0000-0000-000000000004', 'fb-fh-t1', 'yes', now() - interval '4 days');
-- 6: a tenant report
insert into public.fair_reports (hostel_id, reporter_id, why) values ('fa000000-0000-0000-0000-000000000004', 'fb-fh-t2', 'Asked to pay without the app');

select test.act('authenticated', 'fb-fh-owner');
select test.fails($$select * from public.fair_signals('fa000000-0000-0000-0000-000000000004')$$, 'only the Hostelzy team');
select test.act('authenticated', 'fb-fh-team', true);
select test.eq((select string_agg(signal || '=' || n, ' ' order by signal) from public.fair_signals('fa000000-0000-0000-0000-000000000004')),
  'bed_after_cancel=1 declines_while_filling=2 direct_after_app=1 direct_deal_price=1 joined_not_added=1 tenant_reports=1');
select test.eq((select count(*)::text from public.fair_signals()), ((select count(*) from public.hostels) * 6)::text);
-- "before" residents never count
select test.eq((select n::text from public.fair_signals('fa000000-0000-0000-0000-000000000002') where signal = 'declines_while_filling'), '0');

-- ---------------------------------------------------------------- 6. tenant reports in the console
select test.act('authenticated', 'fb-fh-t1');
select test.blocked($$insert into public.fair_reports (hostel_id, reporter_id, why, status) values ('fa000000-0000-0000-0000-000000000004', 'fb-fh-t1', 'x', 'case')$$);
insert into public.fair_reports (hostel_id, reporter_id, why, note) values ('fa000000-0000-0000-0000-000000000004', 'fb-fh-t1', 'Lower price to skip the app', 'He said 500 less');
select test.act('authenticated', 'fb-fh-owner');
select test.rows($$select count(*) from public.fair_reports$$, 0);
select test.fails($$select public.report_case((select id from public.fair_reports limit 1))$$, 'only the Hostelzy team');
select test.act('authenticated', 'fb-fh-team', true);
select public.report_case((select id from public.fair_reports where why = 'Lower price to skip the app'));
select test.fails($$select public.report_case((select id from public.fair_reports where why = 'Lower price to skip the app'))$$, 'already handled');
update public.fair_reports set status = 'closed' where why = 'Asked to pay without the app';
select test.eq((select string_agg(status, ',' order by why) from public.fair_reports where hostel_id = 'fa000000-0000-0000-0000-000000000004'), 'closed,case');
-- the owner sees the case, never the tenant's note or name
select test.act('authenticated', 'fb-fh-owner');
select test.rows($$select count(*) from public.fair_cases where signal = 'Tenant report: lower price to skip the app' and events::text not like '%500%'$$, 1);

-- ---------------------------------------------------------------- 9. the team attaches the tenant's photo
select test.act('authenticated', 'fb-fh-team', true);
update public.fair_cases set tenant_photo = 'fa000000-0000-0000-0000-000000000004/fb-fh-team/1.jpg' where signal = 'Tenant report: lower price to skip the app';
select test.act('authenticated', 'fb-fh-owner');
select test.fails($$update public.fair_cases set tenant_photo = null where signal = 'Tenant report: lower price to skip the app'$$, 'only reply');

reset role;
\o
select 'ALL FAIR PLAY HARDENING TESTS PASSED';
