-- B7 photos: runs after rls_test.sql and b5_test.sql (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;

-- 10000000-…01 is live (Anjani, owner fb-owner-anjani); b7…01 is a draft PG.
insert into public.hostels (id, slug, name, gender, area, status) values
  ('b7000000-0000-0000-0000-000000000001', 'draft-b7', 'Draft B7', 'Women', 'KPHB', 'draft');
insert into public.hostel_photos (hostel_id, path, label, cover) values
  ('b7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001/draft.jpg', 'Front', true);

-- the owner uploads to their own hostel's folder, not someone else's
select test.act('authenticated', 'fb-owner-anjani');
select test.rows($$insert into storage.objects (bucket_id, name) values ('hostel-photos', '10000000-0000-0000-0000-000000000001/a.jpg')$$, 1);
select test.rows($$insert into public.hostel_photos (hostel_id, path, label, cover) values ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001/a.jpg', 'Front', true)$$, 1);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('hostel-photos', 'b7000000-0000-0000-0000-000000000001/x.jpg')$$);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('hostel-photos', 'not-a-hostel/x.jpg')$$);
select test.blocked($$insert into public.hostel_photos (hostel_id, path) values ('b7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001/y.jpg')$$);
-- a photo row must point inside its own hostel's folder
select test.blocked($$insert into public.hostel_photos (hostel_id, path) values ('10000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001/z.jpg')$$);
-- one cover per hostel
select test.fails($$insert into public.hostel_photos (hostel_id, path, cover) values ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001/b.jpg', true)$$, 'hostel_photos_one_cover');
select test.rows($$update public.hostel_photos set ord = 2 where path like '10000000-0000-0000-0000-000000000001/%'$$, 1);

-- a tenant sees live hostels' photos only, and can't upload or delete
select test.act('authenticated', 'fb-b7-tenant');
select test.rows('select count(*) from public.hostel_photos', 1);
select test.blocked($$insert into storage.objects (bucket_id, name) values ('hostel-photos', '10000000-0000-0000-0000-000000000001/t.jpg')$$);
select test.blocked($$delete from public.hostel_photos$$);
select test.act('anon', null);
select test.rows('select count(*) from public.hostel_photos', 1);

-- the team manages any hostel's photos
select test.act('authenticated', 'fb-team', true);
select test.rows('select count(*) from public.hostel_photos', 2);
select test.rows($$insert into storage.objects (bucket_id, name) values ('hostel-photos', 'b7000000-0000-0000-0000-000000000001/team.jpg')$$, 1);

reset role;
\o
select 'ALL B7 TESTS PASSED';
