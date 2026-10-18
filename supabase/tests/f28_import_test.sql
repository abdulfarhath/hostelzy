-- F28 wave 3: import drafts, the web form, the console call lists, the
-- team-only owner phone and the 60-day rent view.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

-- The import (postgres, bypasses RLS) inserts drafts; one old listed hostel.
insert into public.hostels (id, slug, name, gender, area, status, source, place_id, owner_phone_hint, lat, lng, source_seen_at) values
  ('f2830000-0000-0000-0000-000000000001', 'f28i-places', 'F28 Places PG', 'Men', 'Madhapur', 'draft', 'places', 'ChIJf28a', '9876528001', 17.45, 78.39, now()),
  ('f2830000-0000-0000-0000-000000000002', 'f28i-osm', 'F28 OSM Hostel', 'Women', 'Kukatpally', 'draft', 'osm', 'osm:n28', '', 17.49, 78.40, now()),
  ('f2830000-0000-0000-0000-000000000003', 'f28i-team', 'F28 Team Draft', 'Men', 'Ameerpet', 'draft', 'team', null, '', null, null, null);
insert into public.hostels (id, slug, name, gender, area, status, rent_min, rent_max, rent_confirmed_at) values
  ('f2830000-0000-0000-0000-000000000004', 'f28i-stale', 'F28 Stale Listed', 'Men', 'Ameerpet', 'listed', 7000, 9000, now() - interval '55 days'),
  ('f2830000-0000-0000-0000-000000000005', 'f28i-fresh', 'F28 Fresh Listed', 'Men', 'Ameerpet', 'listed', 7000, 9000, now() - interval '10 days'),
  ('f2830000-0000-0000-0000-000000000006', 'f28i-old', 'F28 Old Listed', 'Men', 'Ameerpet', 'listed', 7000, 9000, now() - interval '70 days');
insert into public.hostel_photos (hostel_id, path) values ('f2830000-0000-0000-0000-000000000004', 'f2830000-0000-0000-0000-000000000004/front.jpg');

-- ------------------------------------------------------------ the web form (anon)
select test.act('anon', null);
select set_config('hz.req', public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"98765 28002","area":"Gachibowli","rent_min":6500,"rent_max":8000,"gender":"Women","food":true,"photos":["web/0f0f0f0f-0000-0000-0000-000000000001/a.jpg","../evil.jpg"]}')::text, false);
-- the draft exists, with the rent, the phone hint and only the safe photo path
reset role;
select test.rows($$select count(*) from public.hostels where name = 'Sri Web PG' and status = 'draft' and source = 'web' and rent_min = 6500 and rent_max = 8000 and gender = 'Women' and food and owner_phone_hint = '9876528002'$$, 1);
select test.rows($$select count(*) from public.self_list_requests where name = 'Lakshmi' and photos = array['web/0f0f0f0f-0000-0000-0000-000000000001/a.jpg']$$, 1);
-- the same hostel again points at the same draft (no second row)
select test.act('anon', null);
select public.self_list_request('{"hostel_name":"sri web pg","name":"Lakshmi","phone":"9876528002","area":"gachibowli","rent_min":6500,"rent_max":8000,"gender":"Women"}');
select public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"9876528002","area":"Gachibowli","rent_min":6500,"rent_max":8000,"gender":"Women"}');
reset role;
select test.rows($$select count(*) from public.hostels where lower(name) = 'sri web pg'$$, 1);
select test.rows($$select count(*) from public.self_list_requests where phone = '9876528002'$$, 3);
-- the 4th today is refused; bad input is refused
select test.act('anon', null);
select test.blocked($$select public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"9876528002","area":"Gachibowli","rent_min":6500,"rent_max":8000,"gender":"Women"}')$$);
select test.blocked($$select public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"12345","area":"Gachibowli","rent_min":6500,"rent_max":8000}')$$);
select test.blocked($$select public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"9876528009","area":"Gachibowli","rent_min":6500,"rent_max":800}')$$);
select test.blocked($$select public.self_list_request('{"hostel_name":"Sri Web PG","name":"Lakshmi","phone":"9876528009","area":"Gachibowli","rent_min":6500,"rent_max":8000,"gender":"Boys"}')$$);
-- anon reads nothing: not the requests, not the drafts, not the phone
select test.rows($$select count(*) from public.hostels where source in ('web', 'places', 'osm')$$, 0);
select test.blocked($$select * from public.self_list_requests$$);
select test.blocked($$select public.hostel_owner_phone('f2830000-0000-0000-0000-000000000001')$$);
select test.blocked($$select * from public.call_list('to_call')$$);
-- a signed-in tenant can't use the team's buttons or lists
select test.act('authenticated', 'fb-f28i-t1');
select test.blocked($$select public.list_draft('f2830000-0000-0000-0000-000000000001', 7000, 9000, 'Men', false)$$);
select test.blocked($$select public.draft_not_pg('f2830000-0000-0000-0000-000000000002')$$);
select test.blocked($$select public.rent_confirmed('f2830000-0000-0000-0000-000000000004')$$);
select test.blocked($$select public.call_later('f2830000-0000-0000-0000-000000000001')$$);
select test.rows($$select * from public.call_list('to_call')$$, 0);
select test.rows($$select * from public.claim_adders()$$, 0);
select test.blocked($$select * from public.self_list_requests$$);
select test.blocked($$select public.hostel_owner_phone('f2830000-0000-0000-0000-000000000001')$$);

-- ------------------------------------------------------------ the team's call lists
select test.act('authenticated', 'fb-f28i-team', true);
-- To call: the Places, OSM and web drafts (not the team's own draft), with the phone
select test.rows($$select * from public.call_list('to_call')$$, 3);
select test.eq((select phone from public.call_list('to_call') where name = 'F28 Places PG'), '9876528001');
select test.eq((select phone from public.call_list('to_call') where name = 'F28 OSM Hostel'), '');
select test.eq((select adder || '/' || array_length(photos, 1) from public.call_list('to_call') where name = 'Sri Web PG'), 'Lakshmi/1');
-- Call later: last in the list, with its date
select public.call_later('f2830000-0000-0000-0000-000000000001');
select test.eq((select string_agg(name, ',') from public.call_list('to_call')), 'F28 OSM Hostel,Sri Web PG,F28 Places PG');
select test.rows($$select count(*) from public.call_list('to_call') where name = 'F28 Places PG' and call_after > now()$$, 1);
-- To refresh: the stale (55 days) and old (70 days) listed hostels, not the fresh one
select test.eq((select string_agg(name, ',' order by name) from public.call_list('to_refresh') where name like 'F28%'), 'F28 Old Listed,F28 Stale Listed');
-- the team reads the requests
select test.rows($$select count(*) from public.self_list_requests$$, 3);

-- List: the draft goes UNVERIFIED with the rent, For, Food; rent_confirmed_at now; the phone moves to the lead row
select test.eq(public.list_draft('f2830000-0000-0000-0000-000000000001', 7500, 9500, 'Co-living', true)::text, 'f2830000-0000-0000-0000-000000000001');
reset role;
select test.rows($$select count(*) from public.hostels where id = 'f2830000-0000-0000-0000-000000000001' and status = 'listed' and rent_min = 7500 and rent_max = 9500 and gender = 'Co-living' and food and rent_confirmed_at > now() - interval '1 minute' and owner_phone_hint = '' and call_after is null$$, 1);
select test.rows($$select count(*) from public.hostel_leads where hostel_id = 'f2830000-0000-0000-0000-000000000001' and owner_phone = '9876528001'$$, 1);
select test.eq(public.hostel_owner_phone('f2830000-0000-0000-0000-000000000001'), '9876528001');
-- listed by the web form: its request is done
select test.act('authenticated', 'fb-f28i-team', true);
select public.list_draft((select id from public.hostels where name = 'Sri Web PG'), 6500, 8000, 'Women', true);
select test.rows($$select count(*) from public.self_list_requests where phone = '9876528002' and status = 'done'$$, 3);
-- it is now public, without the phone
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where name = 'Sri Web PG' and status = 'listed' and owner_phone_hint = ''$$, 1);
-- bad rent / gender are refused; a verified hostel can't be listed
select test.act('authenticated', 'fb-f28i-team', true);
select test.blocked($$select public.list_draft('f2830000-0000-0000-0000-000000000002', 7000, 6000, 'Women', false)$$);
select test.blocked($$select public.list_draft('f2830000-0000-0000-0000-000000000002', 7000, 9000, 'Girls', false)$$);
select test.blocked($$select public.list_draft('10000000-0000-0000-0000-000000000001', 7000, 9000, 'Men', false)$$);
-- Not a PG: out of every list, kept with its place id so the import skips it
select public.draft_not_pg('f2830000-0000-0000-0000-000000000002');
select test.rows($$select * from public.call_list('to_call') where id = 'f2830000-0000-0000-0000-000000000002'$$, 0);
select test.blocked($$select public.list_draft('f2830000-0000-0000-0000-000000000002', 7000, 9000, 'Women', false)$$);
reset role;
select test.rows($$select count(*) from public.hostels where id = 'f2830000-0000-0000-0000-000000000002' and status = 'draft' and removed_at is not null and place_id = 'osm:n28'$$, 1);
-- Closed (To refresh): a listed hostel goes off Explore
select test.act('authenticated', 'fb-f28i-team', true);
select public.draft_not_pg('f2830000-0000-0000-0000-000000000006');
select test.rows($$select * from public.call_list('to_refresh') where id = 'f2830000-0000-0000-0000-000000000006'$$, 0);
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where id = 'f2830000-0000-0000-0000-000000000006'$$, 0);
-- a verified hostel is never "closed" here
select test.act('authenticated', 'fb-f28i-team', true);
select test.blocked($$select public.draft_not_pg('10000000-0000-0000-0000-000000000001')$$);
-- Rent confirmed today: out of To refresh
select public.rent_confirmed('f2830000-0000-0000-0000-000000000004');
select test.rows($$select * from public.call_list('to_refresh') where name like 'F28%'$$, 0);
select test.blocked($$select public.rent_confirmed('f2830000-0000-0000-0000-000000000003')$$);

-- ------------------------------------------------------------ the phone hint is never public
reset role;
-- a row listed straight away with a hint (Build 2's add_hostel path): the trigger moves it
insert into public.hostels (id, slug, name, gender, area, status, source, owner_phone_hint, rent_min, rent_max, rent_confirmed_at) values
  ('f2830000-0000-0000-0000-000000000007', 'f28i-added', 'F28 Added PG', 'Men', 'Miyapur', 'listed', 'resident', '98765 28007', 6000, 6000, now());
select test.rows($$select count(*) from public.hostels where id = 'f2830000-0000-0000-0000-000000000007' and owner_phone_hint = ''$$, 1);
select test.rows($$select count(*) from public.hostel_leads where hostel_id = 'f2830000-0000-0000-0000-000000000007' and owner_phone = '9876528007'$$, 1);
select test.eq(public.hostel_owner_phone('f2830000-0000-0000-0000-000000000007'), '9876528007');
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where owner_phone_hint <> ''$$, 0);

-- ------------------------------------------------------------ Claims: added by · phone matches
reset role;
insert into public.profiles (id, name, phone) values ('fb-f28i-adder', 'Ravi', '9000028001');
update public.hostels set added_by = 'fb-f28i-adder' where id = 'f2830000-0000-0000-0000-000000000007';
insert into public.claim_requests (hostel_id, user_id, name, phone) values
  ('f2830000-0000-0000-0000-000000000007', 'fb-f28i-c1', 'Owner', '9876528007'),
  ('f2830000-0000-0000-0000-000000000001', 'fb-f28i-c2', 'Someone', '9000000000');
select test.act('authenticated', 'fb-f28i-team', true);
select test.eq((select source || '/' || adder || '/' || phone_match from public.claim_adders() a join public.claim_requests c on c.id = a.claim_id where c.user_id = 'fb-f28i-c1'), 'resident/Ravi/true');
select test.eq((select source || '/' || adder || '/' || phone_match from public.claim_adders() a join public.claim_requests c on c.id = a.claim_id where c.user_id = 'fb-f28i-c2'), 'places//false');

-- ------------------------------------------------------------ Part 4: rent visible for 60 days
select test.act('anon', null);
select test.rows($$select * from public.listed_rent_visible where id = 'f2830000-0000-0000-0000-000000000005' and rent_visible and rent_min = 7000$$, 1);
select test.rows($$select * from public.listed_rent_visible where id = 'f2830000-0000-0000-0000-000000000004' and rent_visible$$, 1);
reset role;
update public.hostels set rent_confirmed_at = now() - interval '61 days' where id = 'f2830000-0000-0000-0000-000000000005';
select test.act('anon', null);
select test.rows($$select * from public.listed_rent_visible where id = 'f2830000-0000-0000-0000-000000000005' and not rent_visible and rent_min is null$$, 1);
select test.rows($$select * from public.listed_rent_visible where id = '10000000-0000-0000-0000-000000000001' and rent_visible$$, 1);
-- the view follows RLS: a removed (draft) hostel isn't in it
select test.rows($$select * from public.listed_rent_visible where id = 'f2830000-0000-0000-0000-000000000006'$$, 0);

reset role;
select set_config('request.jwt.claims', '', false);
\o
select 'ALL F28 IMPORT TESTS PASSED';
