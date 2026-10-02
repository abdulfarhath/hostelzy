-- C invites: runs after rls_test.sql and b5_test.sql (uses their test.* helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

insert into public.hostels (id, slug, name, gender, area, status) values ('d0000000-0000-0000-0000-000000000001', 'vasavi', 'Vasavi Boys Hostel', 'Men', 'Ameerpet', 'live');
insert into public.hostel_staff values ('d0000000-0000-0000-0000-000000000001', 'fb-vasavi', 'owner');

-- the owner gets one stable code; a tenant can't make one
select test.act('authenticated', 'fb-vasavi');
create temp table c1 as select public.hostel_invite('d0000000-0000-0000-0000-000000000001') as code;
select test.eq((select code ~ '^VAS-[A-Z2-9]{3}$' from c1)::text, 'true');
select test.eq(public.hostel_invite('d0000000-0000-0000-0000-000000000001'), (select code from c1));
select test.act('authenticated', 'fb-joiner');
select test.fails($$select public.hostel_invite('d0000000-0000-0000-0000-000000000001')$$, 'only this hostel');
select test.rows('select count(*) from public.invites', 0);

-- a resident joins with it; a wrong code, a bad phone or a second ask is refused
select test.fails($$select public.join_with_invite('VAS-000', 'Kiran', '9876543210')$$, 'isn''t valid');
select test.fails(format($$select public.join_with_invite(%L, 'K', '12345')$$, (select code from c1)), 'enter your name');
select test.eq(public.join_with_invite(lower((select code from c1)), 'Kiran Rao', '9876543210', '101-A'), 'Vasavi Boys Hostel');
select test.fails(format($$select public.join_with_invite(%L, 'Kiran Rao', '9876543210')$$, (select code from c1)), 'already asked');
select test.rows('select count(*) from public.invite_signups', 1);
select test.blocked($$insert into public.invite_signups (code, hostel_id, name, phone) values ('x', 'd0000000-0000-0000-0000-000000000001', 'x', 'x')$$);
-- anonymous sign-ins can't join
select test.act('authenticated', 'fb-anon', false, 'anonymous');
select test.fails(format($$select public.join_with_invite(%L, 'Anon', '9876543211')$$, (select code from c1)), 'sign in with Google');

-- the owner sees it and approves: a stay is created and the resident told
select test.act('authenticated', 'fb-vasavi');
select test.rows('select count(*) from public.invite_signups', 1);
select public.decide_signup((select id from public.invite_signups where user_id = 'fb-joiner'), true);
select test.fails($$select public.decide_signup((select id from public.invite_signups where user_id = 'fb-joiner'), true)$$, 'already decided');
select test.server();
select test.eq((select user_id || ' ' || name || ' ' || confirmed from public.stays where hostel_id = 'd0000000-0000-0000-0000-000000000001'), 'fb-joiner Kiran Rao true');
select test.eq((select title from public.push_outbox where user_id = 'fb-joiner'), 'You’re in');
select test.eq((select count(*)::text from public.push_outbox where user_id = 'fb-vasavi' and title = 'Kiran Rao wants to join'), '1');

-- a new code retires the old one
select test.act('authenticated', 'fb-vasavi');
select test.eq((public.new_hostel_invite('d0000000-0000-0000-0000-000000000001') <> (select code from c1))::text, 'true');
select test.act('authenticated', 'fb-joiner2');
select test.fails(format($$select public.join_with_invite(%L, 'Ravi', '9876543212')$$, (select code from c1)), 'isn''t valid');

reset role;
\o
select 'ALL INVITE TESTS PASSED';
