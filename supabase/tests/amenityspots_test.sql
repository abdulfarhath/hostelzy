-- F25 spots of shared things on the floor map: runs after the other tests (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name) values
  ('a2500000-0000-0000-0000-000000000001', 'f25-live', 'F25 Live PG', 'Men', 'Madhapur', 'live', 'Ravi'),
  ('a2500000-0000-0000-0000-000000000002', 'f25-other', 'F25 Other PG', 'Men', 'Kondapur', 'live', 'Lata');
insert into public.hostel_staff values
  ('a2500000-0000-0000-0000-000000000001', 'fb-sp-owner', 'owner'),
  ('a2500000-0000-0000-0000-000000000001', 'fb-sp-mgr', 'manager'),
  ('a2500000-0000-0000-0000-000000000002', 'fb-sp-other', 'owner');
insert into public.rooms (hostel_id, number, floor, share, rent, bath) values
  ('a2500000-0000-0000-0000-000000000001', 101, 1, 2, 9000, 'Attached'),
  ('a2500000-0000-0000-0000-000000000001', 201, 2, 2, 9000, 'Attached');
insert into public.stays (hostel_id, user_id, name, confirmed, left_on) values
  ('a2500000-0000-0000-0000-000000000001', 'fb-sp-res', 'Priya Sharma', true, null);
insert into public.amenities (id, hostel_id, floor, kind) values
  ('a2510000-0000-0000-0000-000000000001', 'a2500000-0000-0000-0000-000000000001', 2, 'fridge'),
  ('a2510000-0000-0000-0000-000000000002', 'a2500000-0000-0000-0000-000000000001', 2, 'washer');
insert into public.amenities (id, hostel_id, floor, kind, place, rooms) values
  ('a2510000-0000-0000-0000-000000000003', 'a2500000-0000-0000-0000-000000000001', 2, 'geyser', 'washroom', '{201}');

-- new things start without a spot (never guessed)
select test.eq((select count(*)::text from public.amenities where hostel_id = 'a2500000-0000-0000-0000-000000000001' and pos_x is null and pos_y is null), '3');

-- the owner places one; the manager another; the team can too
select test.act('authenticated', 'fb-sp-owner');
select public.place_amenity('a2510000-0000-0000-0000-000000000001', 10, 80);
select test.act('authenticated', 'fb-sp-mgr');
select public.place_amenity('a2510000-0000-0000-0000-000000000002', 70, 40);
select test.act('authenticated', 'fb-sp-hq', true);
select public.place_amenity('a2510000-0000-0000-0000-000000000002', 75, 30);
reset role;
select test.eq((select string_agg(kind || ' ' || pos_x || ',' || pos_y, '; ' order by kind) from public.amenities where pos_x is not null), 'fridge 10,80; washer 75,30');
select test.eq((select string_agg(what, ', ' order by id) from public.amenity_log where hostel_id = 'a2500000-0000-0000-0000-000000000001'),
  'Fridge on floor 2, placed on the map, Washing machine on floor 2, placed on the map, Washing machine on floor 2, placed on the map');

-- the checks, in plain words
select test.act('authenticated', 'fb-sp-owner');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 101, 50)$$, 'inside the floor');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', -1, 50)$$, 'inside the floor');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 50, null)$$, 'pick a spot');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000003', 50, 50)$$, 'only shared things on the floor');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-0000000000ff', 50, 50)$$, 'isn''t there any more');
-- residents, other owners, tenants and guests can't move things
select test.act('authenticated', 'fb-sp-res');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 50, 50)$$, 'only the owner or a manager');
select test.act('authenticated', 'fb-sp-other');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 50, 50)$$, 'only the owner or a manager');
select test.act('authenticated', 'fb-sp-tenant');
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 50, 50)$$, 'only the owner or a manager');
select test.act('anon', null);
select test.fails($$select public.place_amenity('a2510000-0000-0000-0000-000000000001', 50, 50)$$, 'permission denied');
-- no direct writes of a spot either
select test.act('authenticated', 'fb-sp-owner');
select test.blocked($$update public.amenities set pos_x = 1, pos_y = 1 where id = 'a2510000-0000-0000-0000-000000000001'$$);
-- the table's own check backs it up
reset role;
select test.fails($$update public.amenities set pos_x = 5 where id = 'a2510000-0000-0000-0000-000000000002'$$, 'amenities_pos');
select test.fails($$update public.amenities set pos_x = 5, pos_y = 5 where id = 'a2510000-0000-0000-0000-000000000003'$$, 'amenities_pos');

-- taking it off the map
select test.act('authenticated', 'fb-sp-owner');
select public.place_amenity('a2510000-0000-0000-0000-000000000001', null, null);
reset role;
select test.eq((select coalesce(pos_x::text, 'none') from public.amenities where id = 'a2510000-0000-0000-0000-000000000001'), 'none');

-- an ordinary change keeps the spot; moving to another floor clears it
select test.act('authenticated', 'fb-sp-owner');
select public.save_amenity('a2500000-0000-0000-0000-000000000001', 'a2510000-0000-0000-0000-000000000002', 2, 'washer', '', 1, false, 'floor', '{}');
reset role;
select test.eq((select pos_x || ',' || pos_y || ' ' || working from public.amenities where id = 'a2510000-0000-0000-0000-000000000002'), '75,30 false');
select test.act('authenticated', 'fb-sp-owner');
select public.save_amenity('a2500000-0000-0000-0000-000000000001', 'a2510000-0000-0000-0000-000000000002', 1, 'washer', '', 1, false, 'floor', '{}');
reset role;
select test.eq((select coalesce(pos_x::text, 'none') from public.amenities where id = 'a2510000-0000-0000-0000-000000000002'), 'none');

-- everyone who can read the hostel reads the spot
select test.act('authenticated', 'fb-sp-owner');
select public.place_amenity('a2510000-0000-0000-0000-000000000001', 20, 60);
select test.act('anon', null);
select test.eq((select pos_x || ',' || pos_y from public.amenities where id = 'a2510000-0000-0000-0000-000000000001'), '20,60');
\o
select 'ALL AMENITY SPOT TESTS PASSED';
