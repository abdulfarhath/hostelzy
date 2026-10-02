-- F19 layout fixes: runs after the other tests (uses their helpers and the S1/S2 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
update public.hostels set owner_name = 'Srinivas' where id = 'e0000000-0000-0000-0000-000000000001';
-- Room 101 (2 beds... A, B, C exist: make it 3 sharing) and a second room for the limit
update public.rooms set share = 3 where id = 'e1000000-0000-0000-0000-000000000001';
insert into public.rooms (id, hostel_id, number, floor, share, rent, ac) values
  ('e1000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 102, 1, 1, 9000, true),
  ('e1000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 103, 1, 1, 9000, false),
  ('e1000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000001', 104, 1, 1, 9000, false);
insert into public.beds (hostel_id, room_id, letter) values
  ('e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002', 'A'),
  ('e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000003', 'A'),
  ('e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000004', 'A');
insert into public.layouts (hostel_id, room, stage, version, w, h, beds, items) values
  ('e0000000-0000-0000-0000-000000000001', 101, 'published', 1, 18, 15, '{"A":[1,1],"B":[5,1],"C":[9,1]}', '[{"id":"fan1","kind":"fan","x":8,"y":7,"w":1,"h":1}]');
insert into public.stays (hostel_id, user_id, name, confirmed, bed_id) values
  ('e0000000-0000-0000-0000-000000000001', 'fb-rahul', 'Rahul Varma', true, null);

-- someone who doesn't live here can't send a fix
select test.act('authenticated', 'fb-stranger');
select test.fails($$select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[]}')$$, 'only residents');
-- a resident: the editor's checks hold on the server too
select test.act('authenticated', 'fb-rahul');
select test.fails($$select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1]},"items":[]}')$$, 'place 3 beds');
select test.fails($$select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 102, '{"w":12,"h":10,"beds":{"A":[1,1]},"items":[]}')$$, 'needs an AC unit');
select test.fails($$select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[{"id":"g","kind":"gate"}]}')$$, 'no gates');
create temp table fx as select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[{"id":"fan1","kind":"fan","x":2,"y":7,"w":1,"h":1}]}', 'Fan is near the window') as id;
-- a new one for the same room replaces it
create temp table fx2 as select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[{"id":"fan1","kind":"fan","x":3,"y":7,"w":1,"h":1}]}', 'Fan is near the window') as id;
select test.eq((select string_agg(status, ',' order by created_at) from public.layout_fixes where author_id = 'fb-rahul'), 'withdrawn,pending');
-- at most 3 waiting: 101, 103, 104 then 102 is refused
select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 103, '{"w":10,"h":10,"beds":{"A":[1,1]},"items":[]}');
select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 104, '{"w":10,"h":10,"beds":{"A":[1,1]},"items":[]}');
select test.fails($$select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 102, '{"w":12,"h":10,"beds":{"A":[1,1]},"items":[{"id":"ac1","kind":"ac"}]}')$$, '3 fixes waiting');
select public.withdraw_layout_fix((select id from public.layout_fixes where author_id = 'fb-rahul' and room = 104 and status = 'pending'));
-- the owner was told, with the resident's first name
reset role;
select test.eq((select title from public.push_outbox where user_id = 'fb-sai' and title like 'Rahul%' order by id desc limit 1), 'Rahul suggested a fix for Room 104');

-- the team can't decide before 7 days; another hostel's owner never
select test.act('authenticated', 'fb-team', true);
select test.fails(format($$select public.decide_layout_fix(%L, true)$$, (select id from fx2)), 'owner decides first');
select test.act('authenticated', 'fb-other');
select test.fails(format($$select public.decide_layout_fix(%L, true)$$, (select id from fx2)), 'owner decides first');
-- the owner approves: v2 is live, v1 kept; the resident is told; tenants see one check
select test.act('authenticated', 'fb-sai');
select test.eq(public.decide_layout_fix((select id from fx2), true)::text, '2');
select test.act('anon', null);
select test.eq((select n || ' ' || (last_at is not null)::text from public.layout_checks() where room = 101), '1 true');
select test.rows('select count(*) from public.layout_fixes', 0);   -- names stay private
reset role;
select test.eq((select version || ' ' || (items -> 0 ->> 'x') from public.layouts where room = 101 and stage = 'published' and hostel_id = 'e0000000-0000-0000-0000-000000000001'), '2 3');
select test.eq((select count(*)::text from public.layout_history where room = 101), '1');
select test.eq((select title from public.push_outbox where user_id = 'fb-rahul' order by id desc limit 1), 'Srinivas approved your fix');
-- reject with a reason; the owner can undo the publish
select test.act('authenticated', 'fb-sai');
select public.decide_layout_fix((select id from public.layout_fixes where room = 103 and status = 'pending'), false, 'It was moved back');
select test.eq(public.undo_layout_publish('e0000000-0000-0000-0000-000000000001', 101)::text, '1');
-- owners publish their own edits straight away (checks still apply)
select test.fails($$select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1]},"items":[]}')$$, 'place 3 beds');
select test.eq(public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[]}')::text, '2');
select test.act('authenticated', 'fb-rahul');
select test.fails($$select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[]}')$$, 'only this hostel');
reset role;
select test.eq((select string_agg(room || ':' || status || coalesce(':' || reason, ''), ',' order by room, created_at) from public.layout_fixes where author_id = 'fb-rahul' and status <> 'withdrawn'), '101:rejected:Undone by the owner,103:rejected:It was moved back');
select test.eq((select title from public.push_outbox where user_id = 'fb-rahul' order by id desc limit 1), 'Srinivas didn’t approve your fix');

reset role;
\o
select 'ALL LAYOUT FIX TESTS PASSED';
