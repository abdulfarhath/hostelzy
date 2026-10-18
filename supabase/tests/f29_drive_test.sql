-- F29 Part 3 (wave 4): owner_drive is service-role only; drive_status and
-- set_full_copy for the hostel's staff; id_upload_target by join token;
-- the token round-trips through pgcrypto with the server secret.
-- F28 Part 4: hostels.rent_confirmed_at exists.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
-- The Edge Functions act as the service role; let it use the test helpers.
grant usage on schema test to service_role;
grant execute on all functions in schema test to service_role;
insert into public.hostels (id, slug, name, gender, area, status, owner_name, lat, lng) values
  ('f2950000-0000-0000-0000-000000000001', 'f29d-drive', 'F29 Drive PG', 'Men', 'Miyapur', 'live', 'Ravi', 17.4, 78.4),
  ('f2950000-0000-0000-0000-000000000002', 'f29d-other', 'F29 Other PG', 'Men', 'Miyapur', 'live', 'Suresh', 17.4, 78.4);
insert into public.profiles (id, name, phone) values ('fb-f29d-owner', 'Ravi', '9876529001'), ('fb-f29d-mgr', 'Manager', '9876529002'), ('fb-f29d-other', 'Suresh', '9876529003');
insert into public.hostel_staff values
  ('f2950000-0000-0000-0000-000000000001', 'fb-f29d-owner', 'owner'),
  ('f2950000-0000-0000-0000-000000000001', 'fb-f29d-mgr', 'manager'),
  ('f2950000-0000-0000-0000-000000000002', 'fb-f29d-other', 'owner');

-- F28 Part 4: the freshness column is there (added by wave 2/3 and here).
select test.rows($$select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'hostels' and column_name = 'rent_confirmed_at'$$, 1);

-- ------------------------------------------------------------ not connected yet
select test.act('authenticated', 'fb-f29d-owner');
select test.eq((select connected || ' ' || files || ' ' || full_copy from public.drive_status('f2950000-0000-0000-0000-000000000001')), 'false 0 false');
select test.fails($$select public.set_full_copy('f2950000-0000-0000-0000-000000000001', true)$$, 'Connect Google Drive first');
select test.eq((select role || ' · ' || name from public.drive_role('f2950000-0000-0000-0000-000000000001')), 'owner · F29 Drive PG');
select test.rows($$select * from public.drive_role('f2950000-0000-0000-0000-000000000002')$$, 0);

-- Someone else: nothing. The table and the service-role functions are closed to users.
select test.act('authenticated', 'fb-f29d-tenant');
select test.fails($$select * from public.drive_status('f2950000-0000-0000-0000-000000000001')$$, 'not your hostel');
select test.blocked($$select * from public.owner_drive$$);
select test.blocked($$insert into public.owner_drive (hostel_id, refresh_token, folder_id) values ('f2950000-0000-0000-0000-000000000001', 'x', 'f')$$);
select test.fails($$select public.drive_put('f2950000-0000-0000-0000-000000000001', 'fb-f29d-owner', 'rt', 'folder', 'key')$$, 'permission denied');
select test.fails($$select * from public.drive_token('f2950000-0000-0000-0000-000000000001', 'key')$$, 'permission denied');
select test.fails($$select public.drive_forget('f2950000-0000-0000-0000-000000000001')$$, 'permission denied');
select test.fails($$select public.drive_file_added('f2950000-0000-0000-0000-000000000001', 1)$$, 'permission denied');
select test.fails($$select public.drive_dec('\x00'::bytea, 'key')$$, 'permission denied');

-- ------------------------------------------------------------ drive-connect (service role)
select test.act('service_role', null);
select test.fails($$select public.drive_put('f2950000-0000-0000-0000-000000000001', 'fb-f29d-mgr', 'rt-1', 'folder-1', 'secret-1')$$, 'only the owner connects Drive');
select test.fails($$select public.drive_put('f2950000-0000-0000-0000-000000000001', 'fb-f29d-owner', 'rt-1', 'folder-1', '')$$, 'missing value');
select public.drive_put('f2950000-0000-0000-0000-000000000001', 'fb-f29d-owner', 'rt-1', 'folder-1', 'secret-1');
-- Ciphertext at rest: the token itself is not in the row.
select test.rows($$select count(*) from public.owner_drive where hostel_id = 'f2950000-0000-0000-0000-000000000001' and position('rt-1'::bytea in refresh_token) = 0 and connected_by = 'fb-f29d-owner'$$, 1);
select test.eq((select refresh_token || ' ' || folder_id || ' ' || full_copy from public.drive_token('f2950000-0000-0000-0000-000000000001', 'secret-1')), 'rt-1 folder-1 false');
select test.fails($$select * from public.drive_token('f2950000-0000-0000-0000-000000000001', 'wrong')$$, 'Wrong key');
select test.rows($$select * from public.drive_token('f2950000-0000-0000-0000-000000000002', 'secret-1')$$, 0);
select public.drive_file_added('f2950000-0000-0000-0000-000000000001', 1);
select public.drive_file_added('f2950000-0000-0000-0000-000000000001', 1);
select public.drive_file_added('f2950000-0000-0000-0000-000000000001', -1);
-- Reconnecting replaces the token and folder and starts the count again.
select public.drive_put('f2950000-0000-0000-0000-000000000001', 'fb-f29d-owner', 'rt-2', 'folder-2', 'secret-1');
select test.eq((select refresh_token || ' ' || folder_id from public.drive_token('f2950000-0000-0000-0000-000000000001', 'secret-1')), 'rt-2 folder-2');
select public.drive_file_added('f2950000-0000-0000-0000-000000000001', 1);

-- ------------------------------------------------------------ connected: status and the switch
select test.act('authenticated', 'fb-f29d-owner');
select test.eq((select connected || ' ' || files || ' ' || full_copy from public.drive_status('f2950000-0000-0000-0000-000000000001')), 'true 1 false');
select public.set_full_copy('f2950000-0000-0000-0000-000000000001', true);
select test.act('authenticated', 'fb-f29d-mgr');
select test.eq((select connected || ' ' || files || ' ' || full_copy from public.drive_status('f2950000-0000-0000-0000-000000000001')), 'true 1 true');
select public.set_full_copy('f2950000-0000-0000-0000-000000000001', false);
select test.act('authenticated', 'fb-f29d-other');
select test.fails($$select public.set_full_copy('f2950000-0000-0000-0000-000000000001', true)$$, 'not your hostel');
select test.eq((select connected::text from public.drive_status('f2950000-0000-0000-0000-000000000002')), 'false');

-- ------------------------------------------------------------ id-upload: the tenant's target by join token
select test.act('authenticated', 'fb-f29d-tenant');
-- Until wave 2's join_requests replaces the stub: an honest error.  (integration: the real hook from 20261018160000_w24_wiring.sql answers "valid any more" for an unknown token)
select test.fails($$select * from public.id_upload_target('tok-1')$$, 'valid any more');
-- Wave 2's version maps a token to its hostel; here a stand-in does.
reset role;
create or replace function public.join_hostel_for_token(p_token text) returns uuid
language sql stable security definer set search_path = ''
as $$ select case p_token when 'tok-1' then 'f2950000-0000-0000-0000-000000000001'::uuid when 'tok-2' then 'f2950000-0000-0000-0000-000000000002'::uuid end $$;
select test.act('authenticated', 'fb-f29d-tenant');
select test.eq((select hostel_id || ' ' || full_copy from public.id_upload_target('tok-1')), 'f2950000-0000-0000-0000-000000000001 false');
select test.fails($$select * from public.id_upload_target('tok-2')$$, 'The owner hasn’t connected Google Drive');
select test.fails($$select * from public.id_upload_target('nope')$$, 'This link isn’t valid any more');
select test.act('anon', null);
select test.fails($$select * from public.id_upload_target('tok-1')$$, 'sign in first');

-- ------------------------------------------------------------ disconnect
select test.act('service_role', null);
select public.drive_forget('f2950000-0000-0000-0000-000000000001');
select test.act('authenticated', 'fb-f29d-owner');
select test.eq((select connected || ' ' || files from public.drive_status('f2950000-0000-0000-0000-000000000001')), 'false 0');

reset role;
\o
select 'ALL F29 DRIVE TESTS PASSED';
