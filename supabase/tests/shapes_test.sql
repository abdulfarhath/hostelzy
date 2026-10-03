-- F24 item 11: room shapes and "Ask Hostelzy to draw it". Runs after the other
-- tests (uses their helpers, the S1 hostel, its owner fb-sai, manager fb-ravi).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

-- old rows stay rectangles
select test.eq((select string_agg(distinct shape, ',') from public.layouts), 'Rectangle');
select test.eq((select count(*)::text from public.layouts where outline is not null), '0');

-- the owner publishes an L-shaped room 101 (3 beds): beds must stand inside the walls
select test.act('authenticated', 'fb-sai');
select test.fails($$select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"shape":"L shape","outline":[[0,0],[10,0],[10,7],[18,7],[18,15],[0,15]],"beds":{"A":[1,1],"B":[5,1],"C":[13,1]},"items":[]}')$$, 'bed C is outside the walls');
select test.fails($$select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"shape":"L shape","outline":[[0,0],[30,0],[0,15]],"beds":{"A":[1,1],"B":[5,1],"C":[1,8]},"items":[]}')$$, 'walls don''t fit');
select test.fails($$select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"shape":"Star","beds":{"A":[1,1],"B":[5,1],"C":[1,8]},"items":[]}')$$, 'shape isn''t known');
create temp table v1 as select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"shape":"L shape","outline":[[0,0],[10,0],[10,7],[18,7],[18,15],[0,15]],"beds":{"A":[1,1],"B":[5,1],"C":[12,8]},"items":[]}') as v;
reset role;
select test.eq((select shape || ' ' || jsonb_array_length(outline) from public.layouts where hostel_id = 'e0000000-0000-0000-0000-000000000001' and room = 101 and stage = 'published'), 'L shape 6');
-- undo brings back the rectangle before it
select test.act('authenticated', 'fb-sai');
select public.undo_layout_publish('e0000000-0000-0000-0000-000000000001', 101);
reset role;
select test.eq((select shape || ' ' || (outline is null)::text from public.layouts where hostel_id = 'e0000000-0000-0000-0000-000000000001' and room = 101 and stage = 'published'), 'Rectangle true');

-- shape requests: only the hostel's staff ask; a note or a photo is needed
select test.act('authenticated', 'fb-rahul');
select test.fails($$select public.request_shape('e0000000-0000-0000-0000-000000000001', 101, 'Custom', 'Slanted wall')$$, 'owner or manager');
select test.act('authenticated', 'fb-sai');
select test.fails($$select public.request_shape('e0000000-0000-0000-0000-000000000001', 101, 'Custom', '  ')$$, 'say what');
select test.fails($$select public.request_shape('e0000000-0000-0000-0000-000000000001', 999, 'Custom', 'x')$$, 'no room 999');
select test.fails($$select public.request_shape('e0000000-0000-0000-0000-000000000001', 101, 'Custom', 'x', 0, 0, array['e0000000-0000-0000-0000-000000000001/fb-rahul/a.jpg'])$$, 'isn''t yours');
create temp table r1 as select public.request_shape('e0000000-0000-0000-0000-000000000001', 101, 'L shape', 'Bed C is against the washroom wall.', 14, 12, array['e0000000-0000-0000-0000-000000000001/fb-sai/1.jpg']) as id;
-- a manager asks again for the same room: it replaces the first
select test.act('authenticated', 'fb-ravi');
create temp table r2 as select public.request_shape('e0000000-0000-0000-0000-000000000001', 101, 'Custom', 'Slanted wall near the balcony.') as id;
select test.eq((select string_agg(status, ',' order by created_at) from public.shape_requests where room = 101), 'cancelled,requested');
select test.eq((select ((due_at - created_at) = interval '48 hours')::text from public.shape_requests where id = (select id from r2)), 'true');
-- staff may upload request photos under their own folder only
select test.rows($$insert into storage.objects (bucket_id, name) values ('fix-photos', 'e0000000-0000-0000-0000-000000000001/fb-ravi/1.jpg')$$, 1);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('fix-photos', 'e0000000-0000-0000-0000-000000000001/fb-sai/2.jpg')$$);
-- others can't see the requests or change them; staff can't update directly
select test.act('authenticated', 'fb-other');
select test.rows('select count(*) from public.shape_requests', 0);
select test.act('authenticated', 'fb-sai');
select test.rows('select count(*) from public.shape_requests', 2);
select test.blocked(format($$update public.shape_requests set status = 'sent' where id = %L$$, (select id from r2)));
select test.fails(format($$select public.send_shape_drawing(%L, '{"w":14,"h":12,"shape":"Custom"}')$$, (select id from r2)), 'only the Hostelzy team');

-- the team: sees all, starts, sends the drawing back; the owner is told
select test.act('authenticated', 'fb-team', true);
select test.rows('select count(*) from public.shape_requests', 2);
select public.start_shape_request((select id from r2));
select test.fails(format($$select public.send_shape_drawing(%L, '{"w":14,"h":12,"shape":"Custom","outline":[[0,0],[20,0],[0,12]]}')$$, (select id from r2)), 'walls don''t fit');
select test.fails(format($$select public.send_shape_drawing(%L, '{"w":18,"h":15,"shape":"L shape","outline":[[0,0],[10,0],[10,7],[18,7],[18,15],[0,15]],"beds":{"A":[1,1],"B":[5,1],"C":[13,1]},"items":[]}')$$, (select id from r2)), 'outside the walls');
select public.send_shape_drawing((select id from r2), '{"w":14,"h":12,"shape":"Custom","outline":[[0,0],[14,0],[14,8],[10,12],[0,12]]}');
reset role;
select test.eq((select status || ' ' || (drawing ->> 'shape') || ' ' || (sent_by = 'fb-team')::text from public.shape_requests where id = (select id from r2)), 'sent Custom true');
select test.eq((select title from public.push_outbox where user_id = 'fb-ravi' order by id desc limit 1), 'Hostelzy drew room 101');
-- the owner publishes the room: the request is done
select test.act('authenticated', 'fb-sai');
select public.publish_layout('e0000000-0000-0000-0000-000000000001', 101, '{"w":14,"h":12,"shape":"Custom","outline":[[0,0],[14,0],[14,8],[10,12],[0,12]],"beds":{"A":[1,1],"B":[5,1],"C":[1,6]},"items":[]}');
select test.eq((select status from public.shape_requests where id = (select id from r2)), 'published');
-- tenants see the shape with the layout
select test.act('authenticated', 'fb-rahul');
select test.eq((select shape from public.layouts where hostel_id = 'e0000000-0000-0000-0000-000000000001' and room = 101 and stage = 'published'), 'Custom');

reset role;
\o
select 'ALL SHAPE TESTS PASSED';
