-- F24 items 2 and 3: the team onboards a hostel; owners change rooms.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
create temp table ob (k text primary key, v text);
grant all on ob to anon, authenticated;
insert into public.profiles (id, name, role) values ('fb-ob-owner', 'Lakshmi', 'tenant');

-- only the team creates hostels
select test.act('authenticated', 'fb-ob-owner');
select test.fails($$select public.save_hostel(null, '{"name": "Nope PG"}')$$, 'only the Hostelzy team adds hostels');

-- the team saves a draft: basics, rates, owner's number, rooms
select test.act('authenticated', 'fb-ob-hq', true);
select test.fails($$select public.save_hostel(null, '{"name": "  "}')$$, 'add the hostel name');
insert into ob select 'h', public.save_hostel(null, '{"name": "Sri Sai Annex", "gender": "Women", "area": "Kondapur", "owner_name": "Lakshmi", "food": true, "tags": ["3 meals a day", "Wi-Fi"],
  "terms": {"advance": 4000, "maintenance": 1000, "noticeDays": 30, "dueOnJoining": true, "electricityExtra": true}, "owner_phone": "98765 11111",
  "rates": [{"ac": false, "share": 3, "rent": 7000}, {"ac": true, "share": 2, "rent": 9500}],
  "rooms": [{"number": 101, "floor": 1, "share": 3, "ac": false, "rent": 7000}, {"number": 102, "label": "102A", "floor": 1, "share": 2, "ac": true, "rent": 9500}]}');
select test.eq((select slug || ' ' || status || ' ' || owner_name || ' ' || food::text from public.hostels where id = (select v from ob where k = 'h')::uuid), 'sri-sai-annex draft Lakshmi true');
select test.eq((select owner_phone || ' ' || stage from public.hostel_leads where hostel_id = (select v from ob where k = 'h')::uuid), '9876511111 signed_up');
select test.rows($$select count(*) from public.beds where hostel_id = (select v from ob where k = 'h')::uuid$$, 5);
select test.rows($$select count(*) from public.rate_cards where hostel_id = (select v from ob where k = 'h')::uuid$$, 2);
-- the same name gets its own slug
insert into ob select 'h2', public.save_hostel(null, '{"name": "Sri Sai Annex", "rooms": [{"number": 1, "share": 2, "ac": true, "rent": 9000}]}');
select test.rows($$select count(*) from public.hostels where name = 'Sri Sai Annex'$$, 2);
-- saving again changes it (a bed less in 101, room 103 added)
select public.save_hostel((select v from ob where k = 'h')::uuid, '{"name": "Sri Sai Annex", "rooms": [{"number": 101, "floor": 1, "share": 2, "rent": 7000}, {"number": 102, "label": "102A", "floor": 1, "share": 2, "ac": true, "rent": 9500}, {"number": 103, "floor": 1, "share": 3, "rent": 7000}]}');
select test.eq((select string_agg(coalesce(r.label, r.number::text) || ':' || (select string_agg(b.letter, '' order by b.letter) from public.beds b where b.room_id = r.id), ' ' order by r.number)
  from public.rooms r where r.hostel_id = (select v from ob where k = 'h')::uuid), '101:AB 102A:AB 103:ABC');
-- an owner of another hostel can't change these rooms
select test.act('authenticated', 'fb-ob-stranger');
select test.fails($$select public.save_rooms((select v from ob where k = 'h')::uuid, '[]')$$, 'only this hostel''s owner, managers or the team');

-- not live yet: no owner account, no photos
select test.act('authenticated', 'fb-ob-hq', true);
select test.fails($$select public.go_live((select v from ob where k = 'h')::uuid)$$, 'add a price for 2 sharing');
select public.save_hostel((select v from ob where k = 'h')::uuid, '{"name": "Sri Sai Annex", "rates": [{"ac": false, "share": 2, "rent": 7500}, {"ac": false, "share": 3, "rent": 7000}, {"ac": true, "share": 2, "rent": 9500}]}');
select test.fails($$select public.go_live((select v from ob where k = 'h')::uuid)$$, 'link the owner''s account first');
insert into ob select 'code', public.new_owner_invite((select v from ob where k = 'h')::uuid, 'Lakshmi', '98765 11111');
select test.eq((select left(v, 4) || length(v) from ob where k = 'code'), 'OWN-12');
-- only the team makes owner codes
select test.act('authenticated', 'fb-ob-owner');
select test.fails($$select public.new_owner_invite((select v from ob where k = 'h')::uuid, 'X', '')$$, 'only the Hostelzy team links owners');
select test.rows($$select count(*) from public.owner_invites$$, 0);
-- the owner joins with the code, once
select test.eq(public.join_as_owner(lower((select v from ob where k = 'code'))), 'Sri Sai Annex');
select test.eq((select role from public.hostel_staff where user_id = 'fb-ob-owner'), 'owner');
select test.eq((select role from public.profiles where id = 'fb-ob-owner'), 'owner');
select test.act('authenticated', 'fb-ob-other');
select test.fails($$select public.join_as_owner((select v from ob where k = 'code'))$$, 'isn''t valid any more');
-- one owner account per hostel
select test.act('authenticated', 'fb-ob-hq', true);
insert into ob select 'code2', public.new_owner_invite((select v from ob where k = 'h')::uuid, 'Someone', '');
select test.act('authenticated', 'fb-ob-other');
select test.fails($$select public.join_as_owner((select v from ob where k = 'code2'))$$, 'already has an owner account');

-- the owner changes rooms; a room with a resident stays
select test.act('authenticated', 'fb-ob-owner');
reset role;
insert into public.stays (hostel_id, user_id, name, confirmed, bed_id)
select (select v from ob where k = 'h')::uuid, 'fb-ob-res', 'Priya', true, b.id from public.beds b join public.rooms r on r.id = b.room_id
where r.hostel_id = (select v from ob where k = 'h')::uuid and r.number = 103 and b.letter = 'C';
select test.act('authenticated', 'fb-ob-owner');
select test.fails($$select public.save_rooms((select v from ob where k = 'h')::uuid, '[{"number": 101, "share": 2, "rent": 7000}, {"number": 102, "label": "102A", "share": 2, "ac": true, "rent": 9500}]')$$, 'room 103 has someone in it');
select test.fails($$select public.save_rooms((select v from ob where k = 'h')::uuid, '[{"number": 101, "share": 2, "rent": 7000}, {"number": 102, "label": "102A", "share": 2, "ac": true, "rent": 9500}, {"number": 103, "share": 2, "rent": 7000}]')$$, 'room 103: bed C has someone in it');
select test.fails($$select public.save_rooms((select v from ob where k = 'h')::uuid, '[{"number": 101, "share": 9}]')$$, '1 to 8 beds');
select public.save_rooms((select v from ob where k = 'h')::uuid, '[{"number": 101, "floor": 1, "share": 2, "rent": 7000}, {"number": 102, "label": "102A", "floor": 1, "share": 2, "ac": true, "rent": 9500}, {"number": 103, "floor": 1, "share": 4, "rent": 6500}, {"number": 201, "floor": 2, "share": 3, "rent": 7000}]');
select test.rows($$select count(*) from public.beds where hostel_id = (select v from ob where k = 'h')::uuid$$, 11);

-- go live: needs a price for every room type and 8 photos
select test.act('authenticated', 'fb-ob-hq', true);
select test.fails($$select public.go_live((select v from ob where k = 'h')::uuid)$$, 'add a price for 4 sharing');
select public.save_hostel((select v from ob where k = 'h')::uuid, '{"name": "Sri Sai Annex", "rates": [{"ac": false, "share": 2, "rent": 7500}, {"ac": false, "share": 3, "rent": 7000}, {"ac": false, "share": 4, "rent": 6500}, {"ac": true, "share": 2, "rent": 9500}]}');
select test.fails($$select public.go_live((select v from ob where k = 'h')::uuid)$$, 'add 8 photos first');
reset role;
insert into public.hostel_photos (hostel_id, path, label) select (select v from ob where k = 'h')::uuid, (select v from ob where k = 'h') || '/p' || k || '.jpg', 'Front' from generate_series(1, 8) k;
select test.act('authenticated', 'fb-ob-hq', true);
select public.save_hostel((select v from ob where k = 'h')::uuid, '{"name": "Sri Sai Annex", "rates": [{"ac": false, "share": 3, "rent": 7000}]}');
select test.fails($$select public.go_live((select v from ob where k = 'h')::uuid)$$, 'add a price for');
select public.save_hostel((select v from ob where k = 'h')::uuid, '{"name": "Sri Sai Annex", "rates": [{"ac": false, "share": 2, "rent": 7500}, {"ac": false, "share": 3, "rent": 7000}, {"ac": false, "share": 4, "rent": 6500}, {"ac": true, "share": 2, "rent": 9500}]}');
select public.go_live((select v from ob where k = 'h')::uuid);
select test.eq((select status || ' ' || (visited_on is not null)::text from public.hostels where id = (select v from ob where k = 'h')::uuid), 'live true');
select test.eq((select status || ' ' || (trial_ends - (now() at time zone 'Asia/Kolkata')::date)::text from public.owner_plans where hostel_id = (select v from ob where k = 'h')::uuid), 'trial 30');
select test.eq((select stage from public.hostel_leads where hostel_id = (select v from ob where k = 'h')::uuid), 'data_complete');
-- going live again doesn't restart the trial
reset role;
update public.owner_plans set trial_ends = trial_ends - 5 where hostel_id = (select v from ob where k = 'h')::uuid;
select test.act('authenticated', 'fb-ob-hq', true);
select public.go_live((select v from ob where k = 'h')::uuid);
select test.eq((select (trial_ends - (now() at time zone 'Asia/Kolkata')::date)::text from public.owner_plans where hostel_id = (select v from ob where k = 'h')::uuid), '25');
-- anyone sees it now
select test.act('anon', null);
select test.rows($$select count(*) from public.hostels where name = 'Sri Sai Annex'$$, 1);
select test.blocked($$select public.go_live((select v from ob where k = 'h')::uuid)$$);

\o
select 'ALL ONBOARDING TESTS PASSED';
