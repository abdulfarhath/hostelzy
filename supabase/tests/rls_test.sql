-- RLS tests: run after stub.sql and the migrations (see run.sh). Each check
-- acts as a real role (anon / authenticated) with a fake JWT.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null

create schema test;
grant usage on schema test to anon, authenticated;

-- Runs q; fails unless it errors or touches no rows.
create function test.blocked(q text) returns void language plpgsql as $$
declare n int;
begin
  begin
    execute q;
    get diagnostics n = row_count;
  -- RLS (42501), a guard trigger (P0001) or a check (23514); anything else is a bug.
  exception when insufficient_privilege or raise_exception or check_violation then return;
  end;
  if n > 0 then raise exception 'NOT BLOCKED: %', q; end if;
end $$;

-- Runs q; fails unless it touches exactly n rows (or returns n for a count).
create function test.rows(q text, n int) returns void language plpgsql as $$
declare got int;
begin
  if q ilike 'select count%' then execute q into got; else execute q; get diagnostics got = row_count; end if;
  if got <> n then raise exception 'expected % got %: %', n, got, q; end if;
end $$;
grant execute on all functions in schema test to anon, authenticated;

-- Acts as a Firebase user of the `hostelzy` project (or anon when uid is null).
create function test.act(who text, uid text, team boolean default false, provider text default 'google.com', iss text default 'https://securetoken.google.com/hostelzy') returns void language sql as $$
  select set_config('request.jwt.claims',
    case when uid is null then '{}' else jsonb_build_object('sub', uid, 'role', who, 'iss', iss, 'aud', 'hostelzy', 'firebase', jsonb_build_object('sign_in_provider', provider), 'team', team)::text end, false);
  select set_config('role', who, false);
$$;
grant execute on function test.act to anon, authenticated;

-- ------------------------------------------------------------ seed (as postgres)
insert into public.hostels (id, slug, name, gender, area, status) values
  ('10000000-0000-0000-0000-000000000001', 'anjani', 'Anjani Residency', 'Men', 'Madhapur', 'live'),
  ('10000000-0000-0000-0000-000000000002', 'draft-pg', 'Draft PG', 'Women', 'Kondapur', 'draft');
insert into public.hostel_staff values
  ('10000000-0000-0000-0000-000000000001', 'fb-owner-anjani', 'owner'),
  ('10000000-0000-0000-0000-000000000002', 'fb-owner-draft', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 204, 2, 4, 7600),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 101, 1, 2, 9000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'D'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'A');
insert into public.stays (hostel_id, bed_id, user_id, name, confirmed) values
  ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'fb-resident', 'Rahul Varma', true);
insert into public.layouts (hostel_id, room, stage, w, h) values
  ('10000000-0000-0000-0000-000000000001', 204, 'draft', 12, 10),
  ('10000000-0000-0000-0000-000000000001', 204, 'published', 12, 10);
insert into public.invoices (ref, hostel_id, beds, amount, due) values ('HZ-INV-1', '10000000-0000-0000-0000-000000000001', 40, 999, '2026-11-01');
insert into public.fair_cases (ref, hostel_id, title, signal) values ('FP-1', '10000000-0000-0000-0000-000000000001', 'Case', 'Signal');

-- ------------------------------------------------------------ anon (the key in the app)
select test.act('anon', null);
select test.rows('select count(*) from public.hostels', 1);          -- live only
select test.rows('select count(*) from public.rooms', 1);
select test.rows('select count(*) from public.beds', 1);
select test.rows('select count(*) from public.layouts', 0);           -- sign in first
select test.rows('select count(*) from public.profiles', 0);
select test.rows('select count(*) from public.stays', 0);
select test.rows('select count(*) from public.invoices', 0);
select test.rows('select count(*) from public.app_settings', 2);
select test.blocked($$insert into public.hostels (slug, name, gender, area, status) values ('x', 'x', 'Men', 'x', 'live')$$);
select test.blocked($$update public.beds set state = 'booked'$$);
select test.blocked($$insert into public.enquiries (hostel_id, ref, name, phone) values ('10000000-0000-0000-0000-000000000001', 'HZ1', 'x', 'x')$$);

-- ------------------------------------------------------------ tenant
select test.act('authenticated', 'fb-tenant');
select test.blocked($$insert into public.profiles (id, name) values ('fb-owner-anjani', 'x')$$);   -- not someone else's
select test.blocked($$insert into public.profiles (name, phone_verified) values ('Asha', true)$$);  -- no self-verified phone
select test.rows($$insert into public.profiles (name, phone) values ('Asha', '9000000001')$$, 1);
select test.act('authenticated', 'fb-owner-anjani');
select test.rows($$insert into public.profiles (name) values ('Srinivas')$$, 1);
select test.act('authenticated', 'fb-tenant');
select test.rows('select count(*) from public.profiles', 1);          -- only own
select test.rows($$update public.profiles set phone = '9000000009'$$, 1);   -- typed, stays not verified
select test.blocked($$update public.profiles set phone_verified = true$$);
select test.rows('select count(*) from public.hostels', 1);
select test.rows('select count(*) from public.layouts', 1);           -- published only
select test.blocked($$update public.profiles set member = true$$);   -- earned, not self-set
select test.rows($$update public.profiles set name = 'Asha', role = 'tenant'$$, 1);
select test.rows($$insert into public.enquiries (hostel_id, ref, name, phone) values ('10000000-0000-0000-0000-000000000001', 'HZ1', 'Asha', '9000000001')$$, 1);
select test.blocked($$insert into public.enquiries (hostel_id, ref, name, phone) values ('10000000-0000-0000-0000-000000000002', 'HZ2', 'Asha', '9000000001')$$);  -- draft hostel
select test.rows($$insert into public.holds (id, hostel_id, bed_id, opt) values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'free')$$, 1);
select test.blocked($$update public.holds set status = 'booked'$$);
select test.rows($$insert into public.payments (id, hostel_id, kind, amount, utr, status) values ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'advance', 3000, '402188341297', 'waiting')$$, 1);
select test.blocked($$insert into public.payments (hostel_id, kind, amount, status) values ('10000000-0000-0000-0000-000000000001', 'advance', 3000, 'paid')$$);
select test.blocked($$update public.payments set status = 'paid'$$);  -- never self-confirm
select test.blocked($$update public.payments set amount = 1$$);
select test.blocked($$insert into public.reviews (hostel_id, author_name, stars) values ('10000000-0000-0000-0000-000000000001', 'Asha', 5)$$);  -- no stay
select test.blocked($$insert into public.complaints (hostel_id, cat, body) values ('10000000-0000-0000-0000-000000000001', 'Water', 'x')$$);
select test.rows($$insert into public.fair_reports (hostel_id, why) values ('10000000-0000-0000-0000-000000000001', 'Asked for cash')$$, 1);
select test.rows('select count(*) from public.fair_cases', 0);
select test.blocked($$insert into public.hostel_staff values ('10000000-0000-0000-0000-000000000001', 'fb-tenant', 'owner')$$);
select test.blocked($$select public.approve_layout('10000000-0000-0000-0000-000000000001', 204)$$);

-- anonymous Firebase sign-in: no layouts, no holds
select test.act('authenticated', 'fb-tenant', false, 'anonymous');
select test.rows('select count(*) from public.layouts', 0);
select test.blocked($$insert into public.holds (hostel_id, bed_id, opt) values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'free')$$);

-- ------------------------------------------------------------ resident
select test.act('authenticated', 'fb-resident');
select test.rows('select count(*) from public.stays', 1);
select test.rows('select count(*) from public.payments', 0);         -- not theirs
select test.rows($$insert into public.reviews (id, hostel_id, author_name, stars, layout) values ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Rahul V.', 4, 'No')$$, 1);
select test.blocked($$update public.reviews set stars = 5$$);
select test.rows($$insert into public.complaints (hostel_id, cat, body) values ('10000000-0000-0000-0000-000000000001', 'Water', 'No hot water')$$, 1);
select test.blocked($$update public.complaints set status = 'Fixed'$$);

-- ------------------------------------------------------------ owner of Anjani
select test.act('authenticated', 'fb-owner-anjani');
select test.rows('select count(*) from public.hostels', 1);
select test.rows('select count(*) from public.enquiries', 1);
select test.rows('select count(*) from public.holds', 1);
select test.rows('select count(*) from public.payments', 1);
select test.rows('select count(*) from public.fair_reports', 0);     -- reporter stays private
select test.rows($$update public.payments set status = 'paid' where id = '50000000-0000-0000-0000-000000000001'$$, 1);
do $$ begin assert (select confirmed_by from public.payments) = 'fb-owner-anjani', 'confirmed_by set'; end $$;
select test.blocked($$update public.payments set status = 'waiting'$$);   -- already paid
select test.rows($$update public.reviews set reply = 'Fixed the fan'$$, 1);
select test.blocked($$update public.reviews set stars = 5$$);
select test.rows($$update public.complaints set status = 'Fixed'$$, 1);
select test.rows($$update public.hostels set upi_id = 'srinivas@okaxis', rules = '[{"k":"Gate","v":"11 pm"}]'$$, 1);
select test.blocked($$update public.hostels set status = 'paused'$$);
select test.blocked($$update public.hostels set name = 'x' where slug = 'draft-pg'$$);  -- not theirs
select test.rows('select count(*) from public.invoices', 1);
select test.rows($$update public.invoices set utr = '402188341297', status = 'checking'$$, 1);
select test.blocked($$update public.invoices set status = 'paid'$$);
select test.blocked($$update public.invoices set amount = 0$$);
select test.rows('select count(*) from public.fair_cases', 1);
select test.rows($$update public.fair_cases set owner_reply = 'He paid cash himself'$$, 1);
select test.blocked($$update public.fair_cases set status = 'closed'$$);
select test.rows('select count(*) from public.layouts', 2);
select test.blocked($$update public.layouts set w = 1$$);
select public.approve_layout('10000000-0000-0000-0000-000000000001', 204);
select test.rows($$insert into public.hostel_staff values ('10000000-0000-0000-0000-000000000001', 'fb-tenant', 'manager')$$, 1);
select test.blocked($$insert into public.hostel_staff values ('10000000-0000-0000-0000-000000000002', 'fb-owner-anjani', 'owner')$$);
select test.blocked($$insert into public.strikes (hostel_id) values ('10000000-0000-0000-0000-000000000001')$$);

-- the new manager now sees the hostel's enquiries, but not the owner's plan edits
select test.act('authenticated', 'fb-tenant');
select test.rows('select count(*) from public.payments', 1);
select test.blocked($$update public.invoices set status = 'checking'$$);  -- owners only

-- ------------------------------------------------------------ owner of the draft hostel
select test.act('authenticated', 'fb-owner-draft');
select test.rows('select count(*) from public.hostels', 2);          -- live + own draft
select test.rows('select count(*) from public.enquiries', 0);
select test.blocked($$update public.hostels set status = 'live'$$);  -- the team puts it live

-- ------------------------------------------------------------ push tokens
select test.act('authenticated', 'fb-tenant');
select test.rows($$insert into public.push_tokens (token) values ('tok-tenant')$$, 1);
select test.act('authenticated', 'fb-owner-anjani');
select test.rows('select count(*) from public.push_tokens', 0);     -- not even the owner
select test.blocked($$update public.push_tokens set user_id = auth.uid()$$);
select test.blocked($$insert into public.push_tokens (token, user_id) values ('x', 'fb-tenant')$$);
select test.act('anon', null);
select test.rows('select count(*) from public.push_tokens', 0);

-- ------------------------------------------------------------ Hostelzy team
select test.act('authenticated', 'fb-team', true);
select test.rows('select count(*) from public.hostels', 2);
select test.rows('select count(*) from public.fair_reports', 1);
select test.rows($$update public.invoices set status = 'paid'$$, 1);
select test.rows($$update public.fair_cases set status = 'closed', decision = 'Owner warned'$$, 1);
select test.rows($$update public.hostels set status = 'live' where slug = 'draft-pg'$$, 1);
select test.rows($$update public.app_settings set value = '2' where key = 'min_supported_build'$$, 1);

-- a token from another Firebase project counts as nobody, even with team: true
select test.act('authenticated', 'fb-team', true, 'google.com', 'https://securetoken.google.com/someone-else');
select test.rows('select count(*) from public.profiles', 0);
select test.rows('select count(*) from public.hostels', 2);           -- both live by now; reads like anon
select test.blocked($$update public.app_settings set value = '9'$$);
select test.blocked($$insert into public.enquiries (hostel_id, ref, name, phone) values ('10000000-0000-0000-0000-000000000001', 'HZ9', 'x', 'x')$$);

reset role;

-- ------------------------------------------------------------ B6 Realtime publication
do $$ begin
  if (select string_agg(tablename, ',' order by tablename) from pg_publication_tables where pubname = 'supabase_realtime') is distinct from 'complaints,enquiries,holds,payments' then
    raise exception 'Realtime publication is missing tables';
  end if;
end $$;

\o
select 'ALL RLS TESTS PASSED';
