-- B5 server rules: runs after rls_test.sql (uses its test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;

-- Back to the database itself (like pg_cron): no role, no request JWT.
create function test.server() returns void language sql as $$
  select set_config('request.jwt.claims', '', false);
  select set_config('role', 'postgres', false);
$$;
select test.server();

-- Fails unless q raises an error whose message contains msg.
create function test.fails(q text, msg text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    if position(msg in sqlerrm) = 0 then raise exception 'wrong error for %: %', q, sqlerrm; end if;
    return;
  end;
  raise exception 'NOT BLOCKED: %', q;
end $$;
grant execute on function test.fails to anon, authenticated;

create function test.eq(got text, want text) returns void language plpgsql as $$
begin
  if got is distinct from want then raise exception 'expected % got %', want, got; end if;
end $$;
grant execute on function test.eq to anon, authenticated;

-- ------------------------------------------------------------ seed: a live hostel with 3 beds
insert into public.hostels (id, slug, name, gender, area, status) values
  ('b5000000-0000-0000-0000-000000000001', 'sai-b5', 'Sai B5 PG', 'Men', 'Kondapur', 'live');
insert into public.hostel_staff values ('b5000000-0000-0000-0000-000000000001', 'fb-owner-b5', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('b5100000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 101, 1, 3, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('b5200000-0000-0000-0000-00000000000a', 'b5000000-0000-0000-0000-000000000001', 'b5100000-0000-0000-0000-000000000001', 'A'),
  ('b5200000-0000-0000-0000-00000000000b', 'b5000000-0000-0000-0000-000000000001', 'b5100000-0000-0000-0000-000000000001', 'B'),
  ('b5200000-0000-0000-0000-00000000000c', 'b5000000-0000-0000-0000-000000000001', 'b5100000-0000-0000-0000-000000000001', 'C');
insert into public.profiles (id, phone, name, member) values ('fb-b5-tenant', '9111111111', 'Kiran', false), ('fb-b5-member', '9222222222', 'Meena', true);

-- ------------------------------------------------------------ 1. HZ codes come from the server
select test.act('authenticated', 'fb-b5-tenant');
insert into public.enquiries (hostel_id, ref, name, phone) values ('b5000000-0000-0000-0000-000000000001', 'HZ-1', 'Kiran', '9111111111');
select test.server();
select test.eq((select ref ~ '^HZ-[0-9]{4,}$' and ref <> 'HZ-1' from public.enquiries where phone = '9111111111')::text, 'true');   -- not the app's 'HZ-1'

-- ------------------------------------------------------------ 2. hold rules
select test.act('authenticated', 'fb-b5-tenant');
insert into public.holds (hostel_id, bed_id, opt, ref) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000a', 'free', 'HZ-FAKE');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000a', 'free')$$, 'not free');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('10000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000b', 'free')$$, 'not in this hostel');
insert into public.holds (hostel_id, bed_id, opt) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000b', 'advance');
select test.fails($$insert into public.holds (hostel_id, bed_id, opt) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000c', 'free')$$, 'hold 2 beds');
select test.server();
select test.eq((select ref ~ '^HZ-[0-9]{4,}$' and ref <> 'HZ-FAKE' from public.holds where bed_id = 'b5200000-0000-0000-0000-00000000000a')::text, 'true');
select test.eq((select state from public.beds where id = 'b5200000-0000-0000-0000-00000000000a'), 'held');
select test.eq((select round(extract(epoch from expires_at - started_at) / 60)::text from public.holds where bed_id = 'b5200000-0000-0000-0000-00000000000a'), '60');
select test.eq((select coalesce(expires_at::text, 'none') from public.holds where bed_id = 'b5200000-0000-0000-0000-00000000000b'), 'none');
-- a Hostelzy Member's free hold lasts 2 hours
select test.act('authenticated', 'fb-b5-member');
insert into public.holds (hostel_id, bed_id, opt) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000c', 'free');
select test.server();
select test.eq((select round(extract(epoch from expires_at - started_at) / 60)::text from public.holds where bed_id = 'b5200000-0000-0000-0000-00000000000c'), '120');
-- the tenant releases: the bed is free again
select test.act('authenticated', 'fb-b5-member');
update public.holds set status = 'released' where bed_id = 'b5200000-0000-0000-0000-00000000000c';
select test.server();
select test.eq((select state from public.beds where id = 'b5200000-0000-0000-0000-00000000000c'), 'free');

-- ------------------------------------------------------------ 3. expiry (the app can't run it)
select test.act('authenticated', 'fb-b5-tenant');
select test.fails('select public.expire_holds()', 'permission denied');
select test.server();
update public.holds set expires_at = now() - interval '1 minute' where bed_id = 'b5200000-0000-0000-0000-00000000000a';
select test.eq(public.expire_holds()::text, '1');
select test.eq((select status from public.holds where bed_id = 'b5200000-0000-0000-0000-00000000000a'), 'expired');
select test.eq((select state from public.beds where id = 'b5200000-0000-0000-0000-00000000000a'), 'free');
select test.eq(public.expire_holds()::text, '0');   -- the advance hold has no timer

-- ------------------------------------------------------------ 4. resident matching (60 days)
update public.enquiries set created_at = now() - interval '10 days' where phone = '9111111111';
select test.act('authenticated', 'fb-owner-b5');
-- the owner says "direct", but this phone enquired 10 days before joining
insert into public.stays (hostel_id, name, phone, via, joined_on) values ('b5000000-0000-0000-0000-000000000001', 'Kiran', '9111111111', 'direct', current_date - 2);
-- no Hostelzy history: the owner can't claim "hz" either
insert into public.stays (hostel_id, name, phone, via, joined_on) values ('b5000000-0000-0000-0000-000000000001', 'Walk-in', '9333333333', 'hz', current_date);
select test.server();
select test.eq((select via || ' ' || ref || ' ' || late_days from public.stays where phone = '9111111111'), 'hz ' || (select ref from public.enquiries where phone = '9111111111') || ' 0');
select test.eq((select via || ' ' || coalesce(ref, '-') from public.stays where phone = '9333333333'), 'direct -');
-- an enquiry or hold older than 60 days doesn't count
update public.enquiries set created_at = now() - interval '61 days' where phone = '9111111111';
update public.holds set started_at = now() - interval '61 days' where tenant_id = 'fb-b5-tenant';
insert into public.stays (hostel_id, name, phone, joined_on) values ('b5000000-0000-0000-0000-000000000001', 'Kiran again', '9111111111', current_date);
select test.eq((select via from public.stays where name = 'Kiran again'), 'direct');
update public.enquiries set created_at = now() - interval '10 days' where phone = '9111111111';

-- ------------------------------------------------------------ 5. Fair Play signals
-- added 6 days after moving in: late, and a case opens
insert into public.stays (hostel_id, name, phone, joined_on) values ('b5000000-0000-0000-0000-000000000001', 'Kiran late', '9111111111', current_date - 6);
select test.eq((select late_days::text from public.stays where name = 'Kiran late'), '6');
select test.eq((select signal from public.fair_cases where hostel_id = 'b5000000-0000-0000-0000-000000000001'), 'Hostelzy resident (' || (select ref from public.enquiries where phone = '9111111111') || ') added after the 3-day limit');
select test.eq((select ref ~ '^FP-[0-9]{4}$' from public.fair_cases where hostel_id = 'b5000000-0000-0000-0000-000000000001')::text, 'true');
-- a booked HZ hold with nobody added after 3 days opens one case, once
insert into public.profiles (id, phone, name) values ('fb-b5-booker', '9444444444', 'Ravi');
insert into public.holds (hostel_id, bed_id, tenant_id, opt) values ('b5000000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-00000000000c', 'fb-b5-booker', 'advance');
update public.holds set status = 'booked', started_at = now() - interval '4 days' where tenant_id = 'fb-b5-booker';
select test.eq(public.fair_play_scan()::text, '1');
select test.eq(public.fair_play_scan()::text, '0');
-- once the owner adds him, no new case
insert into public.stays (hostel_id, name, phone, joined_on) values ('b5000000-0000-0000-0000-000000000001', 'Ravi', '9444444444', current_date);
select test.eq(public.fair_play_scan()::text, '0');

-- ------------------------------------------------------------ 6. invoices
insert into public.owner_plans (hostel_id, trial_ends, credit) values ('b5000000-0000-0000-0000-000000000001', '2026-10-31', 100);
select test.eq(public.issue_invoices('2026-10-01')::text, '0');   -- still in trial
select test.eq(public.issue_invoices('2026-11-01')::text, '1');
select test.eq(public.issue_invoices('2026-11-15')::text, '0');   -- once a month
select test.eq((select beds || ' ' || amount || ' ' || due from public.invoices where hostel_id = 'b5000000-0000-0000-0000-000000000001'), '3 399 2026-11-05');
select test.eq((select status || ' ' || credit from public.owner_plans where hostel_id = 'b5000000-0000-0000-0000-000000000001'), 'active 0');
update public.invoices set due = current_date - 16 where hostel_id = 'b5000000-0000-0000-0000-000000000001';
select public.invoice_sweep();
select test.eq((select status from public.owner_plans where hostel_id = 'b5000000-0000-0000-0000-000000000001'), 'overdue');
-- an owner's request is never "server", so it still can't mark it paid
select test.act('authenticated', 'fb-owner-b5');
select test.fails($$update public.invoices set status = 'paid'$$, 'only the Hostelzy team');
select test.server();
update public.invoices set status = 'paid' where hostel_id = 'b5000000-0000-0000-0000-000000000001';
select public.invoice_sweep();
select test.eq((select status from public.owner_plans where hostel_id = 'b5000000-0000-0000-0000-000000000001'), 'active');
select test.eq(public.plan_price(30) || ' ' || public.plan_price(31) || ' ' || public.plan_price(81), '499 999 1499');

-- ------------------------------------------------------------ 7. push outbox
-- the owner heard about the enquiry and each hold
select test.eq((select count(*)::text from public.push_outbox where user_id = 'fb-owner-b5' and title like 'New hold on bed 101-%'), '4');
select test.eq((select count(*)::text from public.push_outbox where user_id = 'fb-owner-b5' and title = 'New enquiry from Kiran'), '1');
-- UTR sent → owner; confirmed → payer
insert into public.payments (id, hostel_id, payer_id, kind, amount) values ('b5300000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'fb-b5-tenant', 'rent', 8000);
select test.act('authenticated', 'fb-b5-tenant');
update public.payments set status = 'waiting', utr = '123456789012' where id = 'b5300000-0000-0000-0000-000000000001';
select test.act('authenticated', 'fb-owner-b5');
update public.payments set status = 'paid' where id = 'b5300000-0000-0000-0000-000000000001';
select test.server();
select test.eq((select body from public.push_outbox where user_id = 'fb-owner-b5' and title = 'Check a payment of ₹8000'), 'UTR 123456789012 · confirm it in Rent');
select test.eq((select title from public.push_outbox where user_id = 'fb-b5-tenant'), 'Payment confirmed');
-- nobody in the app can read the outbox
select test.act('authenticated', 'fb-owner-b5');
select test.fails('select count(*) from public.push_outbox', 'permission denied');
select test.act('authenticated', 'fb-team', true);
select test.fails('select count(*) from public.push_outbox', 'permission denied');

select test.server();
\o
select 'ALL B5 TESTS PASSED';
