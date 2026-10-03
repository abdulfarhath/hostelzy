-- S4 reviews: runs after the other tests (uses their helpers and the S1/S2 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.stays (hostel_id, user_id, name, confirmed, joined_on) values ('e0000000-0000-0000-0000-000000000001', 'fb-reviewer', 'Teja N', true, current_date - 40);

-- a confirmed resident reviews (layout "Mostly" is fine); someone who never stayed can't
select test.act('authenticated', 'fb-reviewer');
insert into public.reviews (hostel_id, author_name, kind, stars, body, cats, layout) values ('e0000000-0000-0000-0000-000000000001', 'Teja N.', 'stay', 4, 'Good food', '{"Food": 5}', 'Mostly');
select test.blocked($$insert into public.reviews (hostel_id, author_name, stars, reply) values ('e0000000-0000-0000-0000-000000000001', 'Teja N.', 5, 'self reply')$$);
select test.act('authenticated', 'fb-stranger');
select test.blocked($$insert into public.reviews (hostel_id, author_name, stars) values ('e0000000-0000-0000-0000-000000000001', 'Fake', 5)$$);

-- the owner replies, but can't change the stars
select test.act('authenticated', 'fb-sai');
update public.reviews set reply = 'Thanks Teja' where author_id = 'fb-reviewer';
select test.fails($$update public.reviews set stars = 5 where author_id = 'fb-reviewer'$$, 'only reply');
reset role;
select test.eq((select stars || ' ' || layout || ' ' || reply || ' ' || (replied_at is not null)::text from public.reviews where author_id = 'fb-reviewer'), '4 Mostly Thanks Teja true');

reset role;
\o
select 'ALL REVIEW TESTS PASSED';
