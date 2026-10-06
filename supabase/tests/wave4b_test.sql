-- F24 Wave 4b: one editor at a time, "Tell me when it's ready"; F26: layouts
-- open to everyone (the women's PG hold-first rule is gone).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a7000000-0000-0000-0000-000000000001', 'w4b-women', 'Lotus Women PG', 'Women', 'KPHB', 'live', 'Lalitha'),
  ('a7000000-0000-0000-0000-000000000002', 'w4b-men', 'Lotus Men PG', 'Men', 'KPHB', 'live', 'Raju');
insert into public.profiles (id, name) values ('fb-w4-owner', 'Lalitha Devi'), ('fb-w4-mgr', ''), ('fb-w4-team', 'Asha');
insert into public.hostel_staff values
  ('a7000000-0000-0000-0000-000000000001', 'fb-w4-owner', 'owner'),
  ('a7000000-0000-0000-0000-000000000001', 'fb-w4-mgr', 'manager');
-- rooms 101–108 (single) with layouts, 109 without; one room in the men's PG
insert into public.rooms (id, hostel_id, number, floor, share, rent)
select ('a7100000-0000-0000-0000-00000000010' || (n - 100))::uuid, 'a7000000-0000-0000-0000-000000000001', n, 1, 1, 9000 from generate_series(101, 109) n;
insert into public.rooms (id, hostel_id, number, floor, share, rent) values ('a7100000-0000-0000-0000-000000000201', 'a7000000-0000-0000-0000-000000000002', 201, 2, 1, 8000);
insert into public.beds (id, hostel_id, room_id, letter, state)
select ('a7200000-0000-0000-0000-00000000010' || (n - 100))::uuid, 'a7000000-0000-0000-0000-000000000001', ('a7100000-0000-0000-0000-00000000010' || (n - 100))::uuid, 'A', 'free' from generate_series(101, 109) n;
insert into public.layouts (hostel_id, room, stage, w, h, beds)
select 'a7000000-0000-0000-0000-000000000001', n, 'published', 10, 12, '{"A":[1,1]}' from generate_series(101, 108) n;
insert into public.layouts (hostel_id, room, stage, w, h, beds) values ('a7000000-0000-0000-0000-000000000002', 201, 'published', 10, 12, '{"A":[1,1]}');

-- ================================================================ 1. layouts open to everyone (F26)
-- F26 (founder 2026-10-05) replaced the women's-PG hold-first rule: every
-- published layout of a live hostel is open to all, with no daily room limit.
select test.act('authenticated', 'fb-w4-tenant');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001'$$, 8);
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000002'$$, 1);
-- room by room: any number of rooms, no hold
select test.eq((select string_agg(room::text, ',') from public.room_layout('a7000000-0000-0000-0000-000000000001', 101)), '101');
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 109)), '0');
select public.room_layout('a7000000-0000-0000-0000-000000000001', n) from generate_series(102, 106) n;
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 107)), '1');
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 108)), '1');
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000002', 201)), '1');
-- guests (not Google) and anon see them too
select test.act('authenticated', 'fb-w4-guest', false, 'anonymous');
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 101)), '1');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001'$$, 8);
select test.act('anon', null);
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 101)), '1');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000002'$$, 1);
-- drafts stay private; a hostel that isn't live shows nothing to tenants
reset role;
insert into public.layouts (hostel_id, room, stage, w, h, beds) values ('a7000000-0000-0000-0000-000000000001', 109, 'draft', 10, 12, '{"A":[1,1]}');
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values ('a7000000-0000-0000-0000-000000000003', 'w4b-draft', 'Lotus Draft PG', 'Men', 'KPHB', 'draft', 'Raju');
insert into public.layouts (hostel_id, room, stage, w, h, beds) values ('a7000000-0000-0000-0000-000000000003', 301, 'published', 10, 12, '{"A":[1,1]}');
select test.act('authenticated', 'fb-w4-tenant');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001' and room = 109$$, 0);
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000001', 109)), '0');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000003'$$, 0);
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000003', 301)), '0');
-- staff and the team see their own hostel's, live or not
select test.act('authenticated', 'fb-w4-team', true);
select test.eq((select count(*)::text from public.room_layout('a7000000-0000-0000-0000-000000000003', 301)), '1');
reset role;
delete from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001' and room = 109;
-- the old hold-first pieces are gone
select test.eq((to_regclass('public.layout_peeks') is null and to_regproc('public.sees_floor') is null and to_regproc('public.is_womens') is null)::text, 'true');
-- a resident still sees it all
insert into public.stays (hostel_id, user_id, name) values ('a7000000-0000-0000-0000-000000000001', 'fb-w4-res', 'Divya');
select test.act('authenticated', 'fb-w4-res');
select test.rows($$select count(*) from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001'$$, 8);

-- ================================================================ 2. one editor at a time
select test.act('authenticated', 'fb-w4-tenant');
select test.fails($$select public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)$$, 'only this hostel''s staff');
select test.blocked($$insert into public.layout_locks values ('a7000000-0000-0000-0000-000000000001', 101, 'fb-w4-tenant', 'x', now() + interval '1 hour')$$);
-- the owner opens the editor: hers, 10 minutes, her first name
select test.act('authenticated', 'fb-w4-owner');
select test.eq((select name || ' ' || mine::text || ' ' || (until between now() + interval '9 minutes' and now() + interval '11 minutes')::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)), 'Lalitha true true');
-- the manager (no name on the profile) sees who is editing and can't publish
select test.act('authenticated', 'fb-w4-mgr');
select test.eq((select name || ' ' || mine::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)), 'Lalitha false');
select test.rows($$select count(*) from public.layout_locks where room = 101$$, 1);
select test.fails($$select public.publish_layout('a7000000-0000-0000-0000-000000000001', 101, '{"w":11,"h":12,"beds":{"A":[2,2]},"items":[]}')$$, 'Lalitha is editing this room');
-- other rooms are free; the manager's own lock reads "A manager" to others
select test.eq((select name || ' ' || mine::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 102)), 'A manager true');
-- the owner publishes while she holds it (and refreshes it)
select test.act('authenticated', 'fb-w4-owner');
select test.eq((select mine::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)), 'true');
select test.eq(public.publish_layout('a7000000-0000-0000-0000-000000000001', 101, '{"w":11,"h":12,"beds":{"A":[2,2]},"items":[]}')::text, '2');
select test.fails($$select public.publish_layout('a7000000-0000-0000-0000-000000000001', 102, '{"w":11,"h":12,"beds":{"A":[2,2]},"items":[]}')$$, 'A manager is editing this room');
-- she leaves the editor: the manager can take it and publish
select public.unlock_layout('a7000000-0000-0000-0000-000000000001', 101);
select test.act('authenticated', 'fb-w4-mgr');
select test.eq((select name || ' ' || mine::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)), 'A manager true');
select test.eq(public.publish_layout('a7000000-0000-0000-0000-000000000001', 101, '{"w":12,"h":12,"beds":{"A":[2,2]},"items":[]}')::text, '3');
-- a lock runs out after 10 minutes without a refresh
reset role;
update public.layout_locks set until = now() - interval '1 second' where room = 101;
select test.act('authenticated', 'fb-w4-team', true);
select test.eq((select name || ' ' || mine::text from public.lock_layout('a7000000-0000-0000-0000-000000000001', 101)), 'Asha true');
select test.eq(public.undo_layout_publish('a7000000-0000-0000-0000-000000000001', 101)::text, '2');

-- ================================================================ 3. "Tell me when it's ready"
select test.act('authenticated', 'fb-w4-waiter', false, 'anonymous');
select test.fails($$select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 109)$$, 'sign in with Google');
select test.act('authenticated', 'fb-w4-waiter');
select test.fails($$select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 101)$$, 'layout is ready');
select test.fails($$select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 999)$$, 'no room 999');
select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 109);
select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 109);
select test.rows($$select count(*) from public.layout_waits$$, 1);
select test.blocked($$insert into public.layout_waits (hostel_id, room) values ('a7000000-0000-0000-0000-000000000001', 108)$$);
select test.act('authenticated', 'fb-w4-tenant');
select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 109);
select test.rows($$select count(*) from public.layout_waits$$, 1);
-- the owner publishes room 109: both get one push (kind hold), the waits close
select test.act('authenticated', 'fb-w4-owner');
select public.publish_layout('a7000000-0000-0000-0000-000000000001', 109, '{"w":10,"h":12,"beds":{"A":[1,1]},"items":[]}');
reset role;
select test.eq((select string_agg(user_id || ':' || kind || ':' || (data ->> 'room'), ',' order by user_id) from public.push_outbox where title = 'Room 109’s layout is ready'), 'fb-w4-tenant:hold:109,fb-w4-waiter:hold:109');
select test.eq((select count(*)::text from public.layout_waits where told_at is null), '0');
-- a new version later doesn't push again
select test.act('authenticated', 'fb-w4-owner');
select public.publish_layout('a7000000-0000-0000-0000-000000000001', 109, '{"w":11,"h":12,"beds":{"A":[1,1]},"items":[]}');
reset role;
select test.eq((select count(*)::text from public.push_outbox where title = 'Room 109’s layout is ready'), '2');
-- a tenant who switched off "Holds and bookings" isn't pushed
update public.profiles set notify = '{"hold": false}' where id = 'fb-w4-owner';
insert into public.profiles (id, name, notify) values ('fb-w4-quiet', 'Q', '{"hold": false}');
delete from public.layouts where hostel_id = 'a7000000-0000-0000-0000-000000000001' and room = 109;
select test.act('authenticated', 'fb-w4-quiet');
select public.wait_for_layout('a7000000-0000-0000-0000-000000000001', 109);
select test.act('authenticated', 'fb-w4-owner');
select public.publish_layout('a7000000-0000-0000-0000-000000000001', 109, '{"w":10,"h":12,"beds":{"A":[1,1]},"items":[]}');
reset role;
select test.eq((select error from public.push_outbox where user_id = 'fb-w4-quiet'), 'switched off');

reset role;
\o
select 'ALL WAVE 4B TESTS PASSED';
