-- F24 Wave 4a: one open enquiry per bed, one review per stay, 30 days,
-- author edits, owner replies once, report abuse, layout flag.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a4a00000-0000-0000-0000-000000000001', 'w4a-one', 'Wave Four PG', 'Men', 'Ameerpet', 'live', 'Ravi');
insert into public.hostel_staff values ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('a4a10000-0000-0000-0000-000000000001', 'a4a00000-0000-0000-0000-000000000001', 301, 3, 2, 8000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('a4a20000-0000-0000-0000-000000000001', 'a4a00000-0000-0000-0000-000000000001', 'a4a10000-0000-0000-0000-000000000001', 'A'),
  ('a4a20000-0000-0000-0000-000000000002', 'a4a00000-0000-0000-0000-000000000001', 'a4a10000-0000-0000-0000-000000000001', 'B');
insert into public.layouts (hostel_id, room, stage, w, h) values ('a4a00000-0000-0000-0000-000000000001', 301, 'published', 12, 10);
insert into public.stays (hostel_id, bed_id, user_id, name, confirmed, joined_on) values
  ('a4a00000-0000-0000-0000-000000000001', 'a4a20000-0000-0000-0000-000000000001', 'fb-4a-old', 'Old Timer', true, current_date - 45),
  ('a4a00000-0000-0000-0000-000000000001', 'a4a20000-0000-0000-0000-000000000002', 'fb-4a-new', 'New Comer', true, current_date - 5);

-- ================================================================ F05 one open enquiry per bed
select test.act('anon', null);
select test.blocked($$select public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', '301-A')$$);
select test.act('authenticated', 'fb-4a-asha');
select set_config('hz.ref1', public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', '301-A', 'Hostel page', 'Is it free?'), false);
-- asking again about the same bed reuses the code; another bed or "any bed" is a new one
select test.eq(public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', '301-A'), current_setting('hz.ref1'));
select test.eq((public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', '301-B') <> current_setting('hz.ref1'))::text, 'true');
select test.eq((public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', null) <> current_setting('hz.ref1'))::text, 'true');
select test.rows($$select count(*) from public.enquiries where tenant_id = 'fb-4a-asha'$$, 3);
-- a direct second insert for the same bed is refused by the server
select test.fails($$insert into public.enquiries (hostel_id, ref, name, phone, bed) values ('a4a00000-0000-0000-0000-000000000001', 'new', 'Asha', '9000040001', '301-A')$$, 'enquiries_one_open');
-- once the owner answered, asking within 60 days still reuses the code
reset role;
select set_config('request.jwt.claims', '', false);
update public.enquiries set contacted = true where ref = current_setting('hz.ref1');
select test.act('authenticated', 'fb-4a-asha');
select test.eq(public.send_enquiry('a4a00000-0000-0000-0000-000000000001', 'Asha', '9000040001', '301-A'), current_setting('hz.ref1'));
-- old duplicates from before the rule: the migration keeps the newest open one
reset role;
select set_config('request.jwt.claims', '', false);
drop index public.enquiries_one_open;
insert into public.enquiries (hostel_id, tenant_id, ref, name, phone, bed, created_at) values
  ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-dup', 'new', 'Dup', '9000040002', null, now() - interval '3 days'),
  ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-dup', 'new', 'Dup', '9000040002', null, now() - interval '1 day');
\i migrations/20261003060000_f24_enquiries_reviews.sql
\o /dev/null
select test.rows($$select count(*) from public.enquiries where tenant_id = 'fb-4a-dup' and dup_of is null$$, 1);
select test.eq((select created_at > now() - interval '2 days' from public.enquiries where tenant_id = 'fb-4a-dup' and dup_of is null)::text, 'true');

-- ================================================================ F08 reviews
-- 5 days in: the 30-day review isn't open yet
select test.act('authenticated', 'fb-4a-new');
select test.fails($$insert into public.reviews (hostel_id, author_name, kind, stars) values ('a4a00000-0000-0000-0000-000000000001', 'New C.', 'stay', 4)$$, 'reviews open after 30 days');
-- the owner can't review their own hostel
select test.act('authenticated', 'fb-4a-owner');
select test.blocked($$insert into public.reviews (hostel_id, author_name, kind, stars) values ('a4a00000-0000-0000-0000-000000000001', 'Ravi', 'stay', 5)$$);
-- 45 days in: one 30-day review; layout "No" flags room 301
select test.act('authenticated', 'fb-4a-old');
insert into public.reviews (id, hostel_id, author_name, kind, stars, body, layout) values
  ('a4a30000-0000-0000-0000-000000000001', 'a4a00000-0000-0000-0000-000000000001', 'Old T.', 'stay', 3, 'Beds are not where the map says', 'No');
select test.fails($$insert into public.reviews (hostel_id, author_name, kind, stars) values ('a4a00000-0000-0000-0000-000000000001', 'Old T.', 'stay', 5)$$, 'already reviewed');
select test.eq((select room::text || ' ' || (stay_id is not null)::text from public.reviews where id = 'a4a30000-0000-0000-0000-000000000001'), '301 true');
reset role;
select test.eq((select disputes::text from public.layouts where hostel_id = 'a4a00000-0000-0000-0000-000000000001' and room = 301 and stage = 'published'), '1');
-- the author edits their review (marked edited); changing the layout answer takes the flag back
select test.act('authenticated', 'fb-4a-old');
select test.rows($$update public.reviews set stars = 4, body = 'Fixed the fan, beds still wrong' where id = 'a4a30000-0000-0000-0000-000000000001'$$, 1);
select test.fails($$update public.reviews set reply = 'me' where id = 'a4a30000-0000-0000-0000-000000000001'$$, 'only your stars and words');
select test.fails($$update public.reviews set hidden = true where id = 'a4a30000-0000-0000-0000-000000000001'$$, 'only your stars and words');
select test.rows($$update public.reviews set layout = 'Yes' where id = 'a4a30000-0000-0000-0000-000000000001'$$, 1);
reset role;
select test.eq((select disputes::text from public.layouts where hostel_id = 'a4a00000-0000-0000-0000-000000000001' and room = 301 and stage = 'published'), '0');
select test.act('authenticated', 'fb-4a-old');
update public.reviews set layout = 'No' where id = 'a4a30000-0000-0000-0000-000000000001';
reset role;
select test.eq((select stars || ' ' || (edited_at is not null)::text from public.reviews where id = 'a4a30000-0000-0000-0000-000000000001'), '4 true');
select test.eq((select disputes::text from public.layouts where hostel_id = 'a4a00000-0000-0000-0000-000000000001' and room = 301 and stage = 'published'), '1');
-- someone else can't edit it
select test.act('authenticated', 'fb-4a-new');
select test.rows($$update public.reviews set stars = 1 where id = 'a4a30000-0000-0000-0000-000000000001'$$, 0);

-- the owner replies once
select test.act('authenticated', 'fb-4a-owner');
select test.rows($$update public.reviews set reply = 'We will redraw room 301' where id = 'a4a30000-0000-0000-0000-000000000001'$$, 1);
select test.fails($$update public.reviews set reply = 'Second try' where id = 'a4a30000-0000-0000-0000-000000000001'$$, 'already replied');

-- report abuse: once per person, never your own; the team sees it and hides the review
select test.fails($$select public.report_review('a4a30000-0000-0000-0000-000000000001', '')$$, 'say what is wrong');
select public.report_review('a4a30000-0000-0000-0000-000000000001', 'Abusive words');
select public.report_review('a4a30000-0000-0000-0000-000000000001', 'Abusive words');
select test.act('authenticated', 'fb-4a-old');
select test.fails($$select public.report_review('a4a30000-0000-0000-0000-000000000001', 'x')$$, 'edit your own review');
select test.rows('select count(*) from public.review_reports', 0);   -- reports are private
select test.fails($$select public.decide_review_report('a4a30000-0000-0000-0000-000000000001', true)$$, 'only the Hostelzy team');
select test.act('authenticated', 'fb-4a-team', true);
select test.rows($$select count(*) from public.review_reports where review_id = 'a4a30000-0000-0000-0000-000000000001' and status = 'open'$$, 1);
select public.decide_review_report('a4a30000-0000-0000-0000-000000000001', true);
select test.rows($$select count(*) from public.review_reports where status = 'hidden'$$, 1);
-- hidden: gone from the hostel page (and from the owner), still seen by its author; the layout flag goes
select test.act('authenticated', 'fb-4a-tenant');
select test.rows($$select count(*) from public.reviews where id = 'a4a30000-0000-0000-0000-000000000001'$$, 0);
select test.act('authenticated', 'fb-4a-owner');
select test.rows($$select count(*) from public.reviews where id = 'a4a30000-0000-0000-0000-000000000001'$$, 0);
select test.act('authenticated', 'fb-4a-old');
select test.rows($$select count(*) from public.reviews where id = 'a4a30000-0000-0000-0000-000000000001'$$, 1);
select test.fails($$update public.reviews set stars = 5 where id = 'a4a30000-0000-0000-0000-000000000001'$$, 'hidden by Hostelzy');
reset role;
select test.eq((select disputes::text from public.layouts where hostel_id = 'a4a00000-0000-0000-0000-000000000001' and room = 301 and stage = 'published'), '0');

-- the exit review is a separate one for the same stay, any time
select test.act('authenticated', 'fb-4a-new');
select test.rows($$insert into public.reviews (hostel_id, author_name, kind, stars, advance) values ('a4a00000-0000-0000-0000-000000000001', 'New C.', 'exit', 4, 'all')$$, 1);
select test.fails($$insert into public.reviews (hostel_id, author_name, kind, stars, advance) values ('a4a00000-0000-0000-0000-000000000001', 'New C.', 'exit', 4, 'all')$$, 'already reviewed');

-- duplicate reviews from before the rule: the migration hides the older one
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.stays (hostel_id, user_id, name, confirmed, joined_on) values ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-twice', 'Twice', true, current_date - 90);
drop index public.reviews_one_per_stay;
insert into public.reviews (hostel_id, author_id, author_name, kind, stars, created_at) values
  ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-twice', 'Twice', 'stay', 2, now() - interval '20 days'),
  ('a4a00000-0000-0000-0000-000000000001', 'fb-4a-twice', 'Twice', 'stay', 4, now() - interval '2 days');
\i migrations/20261003060000_f24_enquiries_reviews.sql
\o /dev/null
select test.eq((select string_agg(stars || ':' || hidden, ',' order by stars) from public.reviews where author_id = 'fb-4a-twice'), '2:true,4:false');

reset role;
\o
select 'ALL WAVE 4A TESTS PASSED';
