-- F19 extras: quick fixes, photos, repairs, muting. Runs after layoutfix_test.sql.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.stays (hostel_id, user_id, name, confirmed, bed_id) values
  ('e0000000-0000-0000-0000-000000000001', 'fb-meena', 'Meena Rao', true, null);

-- a quick fix: only a resident, a real room and issue, and their own photo folder
select test.act('authenticated', 'fb-stranger');
select test.fails($$select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'AC unit', 'broken')$$, 'only residents');
select test.act('authenticated', 'fb-meena');
select test.fails($$select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 999, 'AC unit', 'broken')$$, 'no room 999');
select test.fails($$select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'AC unit', 'smelly')$$, 'pick what');
select test.fails($$select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'AC unit', 'broken', '', 'e0000000-0000-0000-0000-000000000001/fb-rahul/x.jpg')$$, 'isn''t yours');
create temp table qf as select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'AC unit', 'broken', 'AC doesn''t cool', 'e0000000-0000-0000-0000-000000000001/fb-meena/a.jpg') as id;
-- the photo: uploaded to their own folder only; the owner can read it, others can't
select test.rows($$insert into storage.objects (bucket_id, name) values ('fix-photos', 'e0000000-0000-0000-0000-000000000001/fb-meena/a.jpg')$$, 1);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('fix-photos', 'e0000000-0000-0000-0000-000000000001/fb-rahul/b.jpg')$$);
select test.act('authenticated', 'fb-sai');
select test.rows($$select count(*) from storage.objects where bucket_id = 'fix-photos'$$, 1);
select test.act('authenticated', 'fb-stranger');
select test.rows($$select count(*) from storage.objects where bucket_id = 'fix-photos'$$, 0);
-- a quick fix and a layout fix for the same room can both wait
select test.act('authenticated', 'fb-meena');
select public.send_layout_fix('e0000000-0000-0000-0000-000000000001', 101, '{"w":18,"h":15,"beds":{"A":[1,1],"B":[5,1],"C":[9,1]},"items":[]}', '', null);
reset role;
select test.eq((select title from public.push_outbox where user_id = 'fb-sai' and title like 'Broken%' order by id desc limit 1), 'Broken: AC unit, Room 101');

-- the repair: only staff; Start work closes it as approved and tells the resident
select test.act('authenticated', 'fb-meena');
select test.fails(format($$select public.set_repair(%L, 'working')$$, (select id from qf)), 'only this hostel');
select test.act('authenticated', 'fb-sai');
select public.set_repair((select id from qf), 'working');
select test.fails(format($$select public.set_repair(%L, 'not_broken')$$, (select id from qf)), 'already handled');
reset role;
select test.eq((select status || ' ' || repair from public.layout_fixes where id = (select id from qf)), 'approved working');
select test.eq((select title from public.push_outbox where user_id = 'fb-meena' order by id desc limit 1), 'Srinivas is fixing the AC unit');

-- a quick fix approved changes no layout
select test.act('authenticated', 'fb-meena');
create temp table qf2 as select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'Fan', 'wrong_place') as id;
select test.act('authenticated', 'fb-sai');
select public.decide_layout_fix((select id from qf2), true);

-- muting: only staff; waiting fixes close; the resident can't send any more and can see they're muted
select test.act('authenticated', 'fb-meena');
select test.fails(format($$select public.mute_fix_author(%L)$$, (select id from qf2)), 'only this hostel');
select test.act('authenticated', 'fb-sai');
select public.mute_fix_author((select id from public.layout_fixes where author_id = 'fb-meena' and kind = 'layout' and status = 'pending'));
select test.rows($$select count(*) from public.layout_fix_mutes where user_id = 'fb-meena'$$, 1);
select test.act('authenticated', 'fb-meena');
select test.rows($$select count(*) from public.layout_fixes where author_id = 'fb-meena' and status = 'pending'$$, 0);
select test.rows($$select count(*) from public.layout_fix_mutes$$, 1);
select test.fails($$select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'Fan', 'missing')$$, 'suggestions are off');
select test.act('authenticated', 'fb-rahul');
select test.rows($$select count(*) from public.layout_fix_mutes$$, 0);
-- unmuting lets them send again
select test.act('authenticated', 'fb-sai');
select public.unmute_fix_author('e0000000-0000-0000-0000-000000000001', 'fb-meena');
select test.act('authenticated', 'fb-meena');
select public.send_quick_fix('e0000000-0000-0000-0000-000000000001', 101, 'Fan', 'missing');

reset role;
\o
select 'ALL FIX EXTRA TESTS PASSED';
