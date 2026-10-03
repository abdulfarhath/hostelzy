-- F24 item 5: notice, move to another bed, move out and the refund.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, terms) values
  ('a2600000-0000-0000-0000-000000000001', 'mv-one', 'Move PG', 'Men', 'Madhapur', 'live', 'Ravi', '{"advance": 3000, "maintenance": 1000}'),
  ('a2600000-0000-0000-0000-000000000002', 'mv-two', 'Other PG', 'Men', 'Madhapur', 'live', 'Lata', '{}');
insert into public.hostel_staff values ('a2600000-0000-0000-0000-000000000001', 'fb-mv-owner', 'owner'), ('a2600000-0000-0000-0000-000000000002', 'fb-mv-other', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('a2610000-0000-0000-0000-000000000001', 'a2600000-0000-0000-0000-000000000001', 101, 1, 2, 8000),
  ('a2610000-0000-0000-0000-000000000002', 'a2600000-0000-0000-0000-000000000001', 201, 2, 2, 9500),
  ('a2610000-0000-0000-0000-000000000003', 'a2600000-0000-0000-0000-000000000002', 101, 1, 2, 7000);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('a2620000-0000-0000-0000-000000000001', 'a2600000-0000-0000-0000-000000000001', 'a2610000-0000-0000-0000-000000000001', 'A'),
  ('a2620000-0000-0000-0000-000000000002', 'a2600000-0000-0000-0000-000000000001', 'a2610000-0000-0000-0000-000000000001', 'B'),
  ('a2620000-0000-0000-0000-000000000003', 'a2600000-0000-0000-0000-000000000001', 'a2610000-0000-0000-0000-000000000002', 'A'),
  ('a2620000-0000-0000-0000-000000000004', 'a2600000-0000-0000-0000-000000000002', 'a2610000-0000-0000-0000-000000000003', 'A');
insert into public.stays (id, hostel_id, bed_id, user_id, name, rent, advance, confirmed) values
  ('a2630000-0000-0000-0000-000000000001', 'a2600000-0000-0000-0000-000000000001', 'a2620000-0000-0000-0000-000000000001', 'fb-mv-res', 'Priya', 8000, 3000, true),
  ('a2630000-0000-0000-0000-000000000002', 'a2600000-0000-0000-0000-000000000001', 'a2620000-0000-0000-0000-000000000002', 'fb-mv-res2', 'Kiran', 8000, 3000, true);
create temp table mv (k text primary key, v uuid);
grant all on mv to anon, authenticated;

-- notice: residents only, not in the past; the owner is told
select test.act('authenticated', 'fb-mv-stranger');
select test.fails($$select public.give_notice(current_date + 30)$$, 'only residents give notice');
select test.act('authenticated', 'fb-mv-res');
select test.fails($$select public.give_notice(current_date - 1)$$, 'pick a last day from today on');
insert into mv select 'n1', public.give_notice(current_date + 20, 'Moving home');
insert into mv select 'n2', public.give_notice(current_date + 30, '');
select test.eq((select string_agg(status, ',' order by created_at, id) from public.move_requests where user_id = 'fb-mv-res'), 'withdrawn,open');
reset role;
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-mv-owner' and title = 'Priya gave notice'$$, 2);
-- another owner can't answer it; the owner accepts → the bed is free from that day
select test.act('authenticated', 'fb-mv-other');
select test.fails($$select public.answer_move((select v from mv where k = 'n2'), true)$$, 'only this hostel''s owner or managers');
select test.act('authenticated', 'fb-mv-owner');
select public.answer_move((select v from mv where k = 'n2'), true);
select test.fails($$select public.answer_move((select v from mv where k = 'n2'), true)$$, 'isn''t open any more');
select test.eq((select state || ' ' || (free_from = current_date + 30)::text from public.beds where id = 'a2620000-0000-0000-0000-000000000001'), 'soon true');
select test.eq((select (leaving_on = current_date + 30)::text from public.stays where id = 'a2630000-0000-0000-0000-000000000001'), 'true');
reset role;
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-mv-res' and title = 'Notice accepted'$$, 1);

-- move to another bed: free, same hostel; accepted → new bed and its rent
select test.act('authenticated', 'fb-mv-res2');
select test.fails($$select public.ask_move('a2620000-0000-0000-0000-000000000004')$$, 'pick a bed in your hostel');
select test.fails($$select public.ask_move('a2620000-0000-0000-0000-000000000001')$$, 'isn''t free');
select test.fails($$select public.ask_move('a2620000-0000-0000-0000-000000000002')$$, 'that''s your bed now');
insert into mv select 'm1', public.ask_move('a2620000-0000-0000-0000-000000000003');
select test.eq((select to_bed from public.move_requests where id = (select v from mv where k = 'm1')), '201-A');
select test.act('authenticated', 'fb-mv-owner');
select public.answer_move((select v from mv where k = 'm1'), true);
select test.eq((select bed_id::text || ' ' || rent from public.stays where id = 'a2630000-0000-0000-0000-000000000002'), 'a2620000-0000-0000-0000-000000000003 9500');
select test.eq((select string_agg(state, ',' order by id) from public.beds where room_id in ('a2610000-0000-0000-0000-000000000001', 'a2610000-0000-0000-0000-000000000002')), 'soon,free,booked');
-- withdraw: only the resident's own, only while open
select test.act('authenticated', 'fb-mv-res2');
insert into mv select 'm2', public.ask_move('a2620000-0000-0000-0000-000000000002');
select test.act('authenticated', 'fb-mv-res');
select test.fails($$select public.withdraw_move((select v from mv where k = 'm2'))$$, 'isn''t open any more');
select test.act('authenticated', 'fb-mv-res2');
select public.withdraw_move((select v from mv where k = 'm2'));
-- a "no": the resident is told
select test.act('authenticated', 'fb-mv-res2');
insert into mv select 'm3', public.ask_move('a2620000-0000-0000-0000-000000000002');
select test.act('authenticated', 'fb-mv-owner');
select public.answer_move((select v from mv where k = 'm3'), false);
select test.eq((select status from public.move_requests where id = (select v from mv where k = 'm3')), 'declined');

-- moved out: the bed is free, the refund (3000 - 1000) is due
select public.moved_out('a2630000-0000-0000-0000-000000000001');
select test.eq((select (left_on = (now() at time zone 'Asia/Kolkata')::date)::text || ' ' || refund_amount || ' ' || refund_status from public.stays where id = 'a2630000-0000-0000-0000-000000000001'), 'true 2000 due');
select test.eq((select state || ' ' || coalesce(free_from::text, '-') from public.beds where id = 'a2620000-0000-0000-0000-000000000001'), 'free -');
select test.fails($$select public.moved_out('a2630000-0000-0000-0000-000000000001')$$, 'already moved out');
-- the former resident still sees their stay, and can't confirm before it's sent
select test.act('authenticated', 'fb-mv-res');
select test.rows($$select count(*) from public.stays where id = 'a2630000-0000-0000-0000-000000000001'$$, 1);
select test.fails($$select public.confirm_refund('a2630000-0000-0000-0000-000000000001', true)$$, 'hasn''t marked it refunded yet');
select test.fails($$select public.send_refund('a2630000-0000-0000-0000-000000000001', '123456789012')$$, 'only this hostel''s owner or managers');
-- refund sent with a 12-digit UPI ref
select test.act('authenticated', 'fb-mv-owner');
select test.fails($$select public.send_refund('a2630000-0000-0000-0000-000000000001', '1234')$$, '12 digits');
select public.send_refund('a2630000-0000-0000-0000-000000000001', '4021 8834 1297');
select test.eq((select refund_status || ' ' || refund_utr from public.stays where id = 'a2630000-0000-0000-0000-000000000001'), 'sent 402188341297');
-- not received → the owner is told; then sent again and received
select test.act('authenticated', 'fb-mv-res2');
select test.fails($$select public.confirm_refund('a2630000-0000-0000-0000-000000000001', true)$$, 'that isn''t your stay');
select test.act('authenticated', 'fb-mv-res');
select public.confirm_refund('a2630000-0000-0000-0000-000000000001', false);
reset role;
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-mv-owner' and title = 'Priya hasn''t got the refund'$$, 1);
select test.act('authenticated', 'fb-mv-owner');
select public.send_refund('a2630000-0000-0000-0000-000000000001', '402188341298');
select test.act('authenticated', 'fb-mv-res');
select public.confirm_refund('a2630000-0000-0000-0000-000000000001', true);
select test.eq((select refund_status from public.stays where id = 'a2630000-0000-0000-0000-000000000001'), 'received');
-- mark leaving (no notice in the app)
select test.act('authenticated', 'fb-mv-owner');
select public.mark_leaving('a2630000-0000-0000-0000-000000000002', current_date + 10);
select test.eq((select state from public.beds where id = 'a2620000-0000-0000-0000-000000000003'), 'soon');
select test.act('anon', null);
select test.blocked($$select public.give_notice(current_date + 5)$$);

\o
select 'ALL MOVE TESTS PASSED';
