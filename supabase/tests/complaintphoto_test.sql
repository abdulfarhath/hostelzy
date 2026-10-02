-- F21 W3: a complaint photo, uploaded by a resident, seen by staff (runs after holds_test.sql).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.stays (hostel_id, user_id, name, phone, joined_on) values ('e0000000-0000-0000-0000-000000000001', 'fb-cphoto', 'Kavya', '9222200001', current_date);

-- the resident uploads into their own folder, then raises the complaint with it
select test.act('authenticated', 'fb-cphoto');
select test.rows($$insert into storage.objects (bucket_id, name) values ('complaint-photos', 'e0000000-0000-0000-0000-000000000001/fb-cphoto/a.jpg')$$, 1);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('complaint-photos', 'e0000000-0000-0000-0000-000000000001/fb-other/b.jpg')$$);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('complaint-photos', 'b5000000-0000-0000-0000-000000000001/fb-cphoto/c.jpg')$$);
select test.rows($$insert into public.complaints (hostel_id, cat, body, photo) values ('e0000000-0000-0000-0000-000000000001', 'Water', 'Leak under the sink', 'e0000000-0000-0000-0000-000000000001/fb-cphoto/a.jpg')$$, 1);
-- someone else's photo can't be attached
select test.fails($$insert into public.complaints (hostel_id, cat, body, photo) values ('e0000000-0000-0000-0000-000000000001', 'Water', 'x', 'e0000000-0000-0000-0000-000000000001/fb-other/b.jpg')$$, 'your own');

-- staff read it; a stranger doesn't
select test.act('authenticated', 'fb-sai');
select test.rows($$select count(*) from storage.objects where bucket_id = 'complaint-photos'$$, 1);
select test.eq((select photo from public.complaints where body = 'Leak under the sink'), 'e0000000-0000-0000-0000-000000000001/fb-cphoto/a.jpg');
select test.fails($$update public.complaints set photo = null where body = 'Leak under the sink'$$, 'can''t be changed');
select test.rows($$update public.complaints set status = 'Fixed' where body = 'Leak under the sink'$$, 1);
select test.act('authenticated', 'fb-stranger');
select test.rows($$select count(*) from storage.objects where bucket_id = 'complaint-photos'$$, 0);

reset role;
\o
select 'ALL COMPLAINT PHOTO TESTS PASSED';
