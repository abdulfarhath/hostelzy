-- Waves 2 + 4 wired (integration, 2026-10-18): join_hostel_for_token() behind
-- id_upload_target, join_request_info().drive once owner_drive has a row, and
-- clear_join_id() behind H49 "Delete from my Drive".
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, lat, lng) values
  ('f2940000-0000-0000-0000-000000000001', 'w24-pg', 'W24 Wiring PG', 'Men', 'Kondapur', 'live', 'Suresh', 17.46, 78.36);
insert into public.profiles (id, name, phone) values ('fb-w24-owner', 'Suresh W', '9876524001'), ('fb-w24-t1', 'Ravi W', '9876524011'), ('fb-w24-t2', 'Kiran W', '9876524012');
insert into public.hostel_staff values ('f2940000-0000-0000-0000-000000000001', 'fb-w24-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('f2941000-0000-0000-0000-000000000001', 'f2940000-0000-0000-0000-000000000001', 301, 3, 3, 6500);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('f2942000-0000-0000-0000-000000000001', 'f2940000-0000-0000-0000-000000000001', 'f2941000-0000-0000-0000-000000000001', 'A');

-- the owner makes a link
select test.act('authenticated', 'fb-w24-owner');
select set_config('hz.w24', public.new_join_request('f2942000-0000-0000-0000-000000000001', 6500, 3000, current_date + 3, 'Ravi'), false);

-- ------------------------------------------------------------ 1. the hook id_upload_target uses
select test.act('authenticated', 'fb-w24-t1');
select test.eq(public.join_hostel_for_token(current_setting('hz.w24'))::text, 'f2940000-0000-0000-0000-000000000001');
select test.eq(public.join_hostel_for_token('NOPE')::text, null);
select test.act('anon', null);
select test.blocked($$select public.join_hostel_for_token(current_setting('hz.w24'))$$);

-- ------------------------------------------------------------ 2. drive: false until the owner connected Drive
select test.act('authenticated', 'fb-w24-t1');
select test.eq(public.join_request_info(current_setting('hz.w24')) ->> 'drive', 'false');
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.owner_drive (hostel_id, refresh_token, folder_id) values ('f2940000-0000-0000-0000-000000000001', '\x00'::bytea, 'folder-w24');
select test.act('authenticated', 'fb-w24-t1');
select test.eq(public.join_request_info(current_setting('hz.w24')) ->> 'drive', 'true');
-- the tenant fills the form with a Drive file; the hook keeps answering them, never another tenant
select public.fill_join_request(current_setting('hz.w24'), 'Ravi W', '9876524011', current_date + 3, 'drive', 'file-w24');
select test.eq(public.join_hostel_for_token(current_setting('hz.w24'))::text, 'f2940000-0000-0000-0000-000000000001');
select test.act('authenticated', 'fb-w24-t2');
select test.eq(public.join_hostel_for_token(current_setting('hz.w24'))::text, null);

-- ------------------------------------------------------------ 3. clear_join_id: staff only; the pointer goes
select test.act('authenticated', 'fb-w24-t1');
select test.fails($$select public.clear_join_id((select id from public.join_requests where token = current_setting('hz.w24')))$$, 'owner or managers');
select test.act('authenticated', 'fb-w24-owner');
select test.rows($$select count(*) from public.join_requests where token = current_setting('hz.w24') and id_received = 'drive' and id_file_id = 'file-w24'$$, 1);
select public.clear_join_id((select id from public.join_requests where token = current_setting('hz.w24')));
select test.rows($$select count(*) from public.join_requests where token = current_setting('hz.w24') and id_received = 'none' and id_file_id is null$$, 1);
select test.fails($$select public.clear_join_id('00000000-0000-0000-0000-000000000000')$$, 'no such request');
reset role;
\o
select 'ALL W2+W4 WIRING TESTS PASSED';
