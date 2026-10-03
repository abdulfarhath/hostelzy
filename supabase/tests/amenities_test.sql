-- F23 floor amenities: runs after the other tests (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2300000-0000-0000-0000-000000000001', 'f23-live', 'F23 Live PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('a2300000-0000-0000-0000-000000000002', 'f23-draft', 'F23 Draft PG', 'Women', 'Kondapur', 'draft', 'Lata');
insert into public.hostel_staff values
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-owner', 'owner'),
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-mgr', 'manager'),
  ('a2300000-0000-0000-0000-000000000002', 'fb-am-draft', 'owner');
insert into public.rooms (hostel_id, number, floor, share, rent, bath) values
  ('a2300000-0000-0000-0000-000000000001', 101, 1, 2, 9000, 'Attached'),
  ('a2300000-0000-0000-0000-000000000001', 201, 2, 2, 9000, 'Attached'),
  ('a2300000-0000-0000-0000-000000000001', 202, 2, 2, 9000, 'Attached'),
  ('a2300000-0000-0000-0000-000000000001', 203, 2, 3, 8000, 'Shared'),
  ('a2300000-0000-0000-0000-000000000002', 201, 2, 2, 9000, 'Attached');
insert into public.stays (hostel_id, user_id, name, confirmed, left_on) values
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-res', 'Priya Sharma', true, null),
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-busy', 'Kiran Rao', true, null),
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-muted', 'Arun Das', true, null),
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-new', 'Not Confirmed', false, null),
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-left', 'Moved Out', true, current_date - 3);
insert into public.layout_fix_mutes (hostel_id, user_id, name, muted_by) values
  ('a2300000-0000-0000-0000-000000000001', 'fb-am-muted', 'Arun Das', 'fb-am-owner');
insert into public.amenities (id, hostel_id, floor, kind, qty) values ('a2310000-0000-0000-0000-000000000001', 'a2300000-0000-0000-0000-000000000002', 2, 'fridge', 1);

-- no direct writes, for anyone
select test.act('authenticated', 'fb-am-owner');
select test.blocked($$insert into public.amenities (hostel_id, floor, kind) values ('a2300000-0000-0000-0000-000000000001', 2, 'fridge')$$);
select test.blocked($$insert into public.amenity_log (hostel_id, amenity_id, action, by_id, by_role) values ('a2300000-0000-0000-0000-000000000001', gen_random_uuid(), 'add', 'x', 'staff')$$);

-- staff: add, change, remove
create temp table am (k text primary key, id uuid);
grant all on am to authenticated;
insert into am select 'fridge', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}');
insert into am select 'geyser', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'geyser', '', 1, true, 'washroom', '{202, 201, 201}');
select test.act('authenticated', 'fb-am-mgr');
insert into am select 'washer', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'washer', '', 1, true, 'floor', '{}');
select public.save_amenity('a2300000-0000-0000-0000-000000000001', (select id from am where k = 'washer'), 2, 'washer', '', 2, true, 'floor', '{}');
select test.eq((select qty::text || ' ' || by_role from public.amenities where id = (select id from am where k = 'washer')), '2 staff');
select test.eq((select rooms::text from public.amenities where id = (select id from am where k = 'geyser')), '{201,202}');
-- a thing on the floor drops stray rooms
insert into am select 'tv', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 1, 'tv', '', 1, true, 'floor', '{101}');
select test.eq((select rooms::text from public.amenities where id = (select id from am where k = 'tv')), '{}');
select public.remove_amenity((select id from am where k = 'tv'));
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000001'$$, 3);
select test.eq((select string_agg(action || ':' || what, ', ' order by id) from public.amenity_log where hostel_id = 'a2300000-0000-0000-0000-000000000001'),
  'add:Fridge on floor 2, add:Geyser in 2 room washrooms on floor 2, add:Washing machine on floor 2, change:Washing machine on floor 2, add:TV on floor 1, remove:TV on floor 1');
-- staff changes don't notify anyone
reset role;
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-am-owner'$$, 0);

-- the team can save too, as staff
select test.act('authenticated', 'fb-am-hq', true);
insert into am select 'lift', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 1, 'lift', '', 1, true, 'floor', '{}');

-- the checks, in plain words
select test.act('authenticated', 'fb-am-owner');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'cctv', '', 1, true, 'floor', '{}')$$, 'no CCTV, gates or exits');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'gate', '', 1, true, 'floor', '{}')$$, 'no CCTV, gates or exits');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'sofa', '', 1, true, 'floor', '{}')$$, 'pick a thing from the list');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'other', '   ', 1, true, 'floor', '{}')$$, 'type a name');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'other', repeat('x', 41), 1, true, 'floor', '{}')$$, '40 letters');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 0, true, 'floor', '{}')$$, '1 to 20');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 21, true, 'floor', '{}')$$, '1 to 20');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'roof', '{}')$$, 'pick where it is');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'geyser', '', 1, true, 'washroom', '{}')$$, 'at least one room');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'geyser', '', 1, true, 'washroom', '{201, 999}')$$, 'room 999 isn''t on floor 2');
-- a room item on a room that is on another floor
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'geyser', '', 1, true, 'washroom', '{101}')$$, 'room 101 isn''t on floor 2');
-- "Other" with a name is fine, and trimmed
insert into am select 'other', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'other', '  Water dispenser ', 1, true, 'room', '{203}');
select test.eq((select name || ' / ' || place || ' ' || rooms::text from public.amenities where id = (select id from am where k = 'other')), 'Water dispenser / room {203}');
-- an id from another hostel isn't this hostel's
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', 'a2310000-0000-0000-0000-000000000001', 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'isn''t there any more');
-- nor can they remove it
select test.fails($$select public.remove_amenity('a2310000-0000-0000-0000-000000000001')$$, 'only this hostel''s owner and residents');

-- a resident adds a thing and marks one not working; the owners (not the manager) are told, in plain words
select test.act('authenticated', 'fb-am-res');
insert into am select 'ro', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'ro', '', 1, true, 'floor', '{}');
select public.save_amenity('a2300000-0000-0000-0000-000000000001', (select id from am where k = 'fridge'), 2, 'fridge', '', 1, false, 'floor', '{}');
select test.eq((select by_role from public.amenities where id = (select id from am where k = 'fridge')), 'resident');
reset role;
select test.eq((select string_agg(title, ' | ' order by id) from public.push_outbox where user_id = 'fb-am-owner'),
  'A resident added an RO water purifier on floor 2 | A resident marked the Fridge on floor 2 not working');
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-am-mgr'$$, 0);
select test.eq((select by_name || ' ' || by_role from public.amenity_log where amenity_id = (select id from am where k = 'ro')), 'Priya Sharma resident');
-- staff fixing it clears the "by a resident" tag
select test.act('authenticated', 'fb-am-owner');
select public.save_amenity('a2300000-0000-0000-0000-000000000001', (select id from am where k = 'fridge'), 2, 'fridge', '', 1, true, 'floor', '{}');
select test.eq((select by_role from public.amenities where id = (select id from am where k = 'fridge')), 'staff');
-- a resident removing a thing tells the owner too
select test.act('authenticated', 'fb-am-res');
select public.remove_amenity((select id from am where k = 'ro'));
reset role;
select test.eq((select title from public.push_outbox where user_id = 'fb-am-owner' order by id desc limit 1), 'A resident removed the RO water purifier on floor 2');

-- the resident limit: 20 changes a day per hostel
select test.act('authenticated', 'fb-am-busy');
insert into am select 'cooler', public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'cooler', '', 1, true, 'floor', '{}');
select public.save_amenity('a2300000-0000-0000-0000-000000000001', (select id from am where k = 'cooler'), 2, 'cooler', '', 1 + (g % 3), g % 2 = 0, 'floor', '{}') from generate_series(1, 19) g;
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'iron', '', 1, true, 'floor', '{}')$$, '20 changes here today');
select test.fails(format($$select public.remove_amenity(%L)$$, (select id from am where k = 'cooler')), '20 changes here today');
-- yesterday's changes don't count; staff have no limit
reset role;
update public.amenity_log set at = at - interval '1 day' where by_id = 'fb-am-busy' and id in (select id from public.amenity_log where by_id = 'fb-am-busy' order by id limit 5);
select test.act('authenticated', 'fb-am-busy');
select public.remove_amenity((select id from am where k = 'cooler'));
select test.act('authenticated', 'fb-am-owner');
select public.save_amenity('a2300000-0000-0000-0000-000000000001', (select id from am where k = 'washer'), 2, 'washer', '', 1 + (g % 3), true, 'floor', '{}') from generate_series(1, 25) g;

-- a muted resident, someone who hasn't moved in or has left, and a stranger are refused
select test.act('authenticated', 'fb-am-muted');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'your changes are off for this hostel');
select test.fails(format($$select public.remove_amenity(%L)$$, (select id from am where k = 'fridge')), 'your changes are off for this hostel');
select test.act('authenticated', 'fb-am-new');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'only this hostel''s owner and residents');
select test.act('authenticated', 'fb-am-left');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'only this hostel''s owner and residents');
select test.act('authenticated', 'fb-am-stranger');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'only this hostel''s owner and residents');
select test.fails(format($$select public.remove_amenity(%L)$$, (select id from am where k = 'fridge')), 'only this hostel''s owner and residents');
select test.act('authenticated', 'fb-am-anon', false, 'anonymous');
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'sign in with Google');
-- the owner of another hostel can't change this one's
select test.act('authenticated', 'fb-am-draft');
select test.fails(format($$select public.remove_amenity(%L)$$, (select id from am where k = 'fridge')), 'only this hostel''s owner and residents');
-- signed out: the functions aren't there for anon at all
select test.act('anon', null);
select test.fails($$select public.save_amenity('a2300000-0000-0000-0000-000000000001', null, 2, 'fridge', '', 1, true, 'floor', '{}')$$, 'permission denied');

-- reading: anyone sees a live hostel's things (no names on the rows); a draft hostel's only its staff
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000001'$$, 5);
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000002'$$, 0);
select test.act('authenticated', 'fb-am-tenant');
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000001'$$, 5);
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000002'$$, 0);
select test.act('authenticated', 'fb-am-draft');
select test.rows($$select count(*) from public.amenities where hostel_id = 'a2300000-0000-0000-0000-000000000002'$$, 1);
reset role;
select test.eq((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns where table_schema = 'public' and table_name = 'amenities'),
  'id,hostel_id,floor,kind,name,qty,working,place,rooms,by_role,created_at,updated_at');

-- the change log: the hostel's staff and the team only; never tenants or residents
select test.act('authenticated', 'fb-am-tenant');
select test.rows($$select count(*) from public.amenity_log$$, 0);
select test.act('authenticated', 'fb-am-res');
select test.rows($$select count(*) from public.amenity_log$$, 0);
select test.act('anon', null);
select test.rows($$select count(*) from public.amenity_log$$, 0);
select test.act('authenticated', 'fb-am-draft');
select test.rows($$select count(*) from public.amenity_log$$, 0);
select test.act('authenticated', 'fb-am-mgr');
select test.rows($$select count(*) from public.amenity_log where by_role = 'resident'$$, 24);
select test.act('authenticated', 'fb-am-hq', true);
select test.rows($$select count(*) from public.amenity_log where by_id = 'fb-am-hq'$$, 1);

-- live updates
reset role;
select test.rows($$select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'amenities'$$, 1);

\o
select 'ALL AMENITY TESTS PASSED';
