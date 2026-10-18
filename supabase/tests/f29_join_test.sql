-- F29 Part 2: Ask to join. Token (7 days, single use, one bed), the tenant's
-- form, approve = a stay like "Add a resident", first approved wins, ask again, expiry.
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.hostels (id, slug, name, gender, area, status, owner_name, lat, lng) values
  ('f2900000-0000-0000-0000-000000000001', 'f29-pg', 'F29 Comforts PG', 'Men', 'Kondapur', 'live', 'Suresh', 17.46, 78.36);
insert into public.profiles (id, name, phone) values ('fb-f29-owner', 'Suresh Kumar', '9876529001'), ('fb-f29-t1', 'Ravi', '9876529011'), ('fb-f29-t2', 'Kiran', '9876529012');
insert into public.hostel_staff values ('f2900000-0000-0000-0000-000000000001', 'fb-f29-owner', 'owner');
insert into public.rooms (id, hostel_id, number, floor, share, rent) values
  ('f2910000-0000-0000-0000-000000000001', 'f2900000-0000-0000-0000-000000000001', 203, 2, 3, 6500);
insert into public.beds (id, hostel_id, room_id, letter) values
  ('f2920000-0000-0000-0000-000000000001', 'f2900000-0000-0000-0000-000000000001', 'f2910000-0000-0000-0000-000000000001', 'A'),
  ('f2920000-0000-0000-0000-000000000002', 'f2900000-0000-0000-0000-000000000001', 'f2910000-0000-0000-0000-000000000001', 'B');

-- ------------------------------------------------------------ H48: only staff, only a free bed
select test.act('authenticated', 'fb-f29-t1');
select test.blocked($$select public.new_join_request('f2920000-0000-0000-0000-000000000001', 6500, 3000, current_date + 3, 'Ravi')$$);
select test.act('authenticated', 'fb-f29-owner');
select test.fails($$select public.new_join_request('f2920000-0000-0000-0000-000000000001', 500, 3000, current_date, '')$$, 'monthly fee');
select set_config('hz.j1', public.new_join_request('f2920000-0000-0000-0000-000000000001', 6500, 3000, current_date + 3, 'Ravi'), false);
select test.eq(length(current_setting('hz.j1'))::text, '12');
-- sending again makes a new token; the old one still works until used
select set_config('hz.j1b', public.new_join_request('f2920000-0000-0000-0000-000000000001', 6500, 3000, current_date + 3, ''), false);
select test.rows($$select count(*) from public.join_requests where bed_id = 'f2920000-0000-0000-0000-000000000001' and status = 'sent'$$, 2);

-- ------------------------------------------------------------ S94: the tenant opens the link
select test.act('anon', null);
select test.blocked($$select public.join_request_info(current_setting('hz.j1'))$$);
select test.act('authenticated', 'fb-f29-t1');
select test.eq((public.join_request_info(current_setting('hz.j1')) ->> 'hostel') || ' · ' || (public.join_request_info(current_setting('hz.j1')) ->> 'bed') || ' · ' || (public.join_request_info(current_setting('hz.j1')) ->> 'fee'), 'F29 Comforts PG · 203-A · 6500');
select test.eq((public.join_request_info(current_setting('hz.j1')) ->> 'owner') || ' ' || (public.join_request_info(current_setting('hz.j1')) ->> 'status') || ' ' || (public.join_request_info(current_setting('hz.j1')) ->> 'drive') || ' ' || (public.join_request_info(current_setting('hz.j1')) ->> 'taken'), 'Suresh sent false false');
-- the owner's WhatsApp number, to send the ID to the person who invited them
select test.eq((public.join_request_info(current_setting('hz.j1')) ->> 'owner_phone'), '9876529001');
select test.eq(public.join_request_info('NOPE')::text, null);
-- not visible as a row before filling (no tenant yet)
select test.rows($$select count(*) from public.join_requests$$, 0);
-- the form
select test.fails($$select public.fill_join_request(current_setting('hz.j1'), 'R', '9876529011', current_date + 3, 'whatsapp')$$, 'your name');
select test.fails($$select public.fill_join_request(current_setting('hz.j1'), 'Ravi Teja', '12', current_date + 3, 'whatsapp')$$, '10-digit');
select test.eq((public.fill_join_request(current_setting('hz.j1'), 'Ravi Teja', '9876529011', current_date + 3, 'whatsapp') ->> 'hostel'), 'F29 Comforts PG');
select test.fails($$select public.fill_join_request(current_setting('hz.j1'), 'Ravi Teja', '9876529011', current_date + 3, 'whatsapp')$$, 'valid any more');
select test.rows($$select count(*) from public.join_requests where status = 'filled' and tenant_id = 'fb-f29-t1' and id_received = 'whatsapp' and id_file_id is null$$, 1);
select test.eq((public.join_request_info(current_setting('hz.j1')) ->> 'mine'), 'true');
-- the owner got a push
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f29-owner' and title = 'Ravi wants to join · bed 203-A'$$, 1);
select set_config('hz.jid', (select id::text from public.join_requests where token = current_setting('hz.j1')), false);
-- another tenant can't read it
select test.act('authenticated', 'fb-f29-t2');
select test.rows($$select count(*) from public.join_requests$$, 0);

-- ------------------------------------------------------------ H49: ask again, then approve
select test.act('authenticated', 'fb-f29-t1');
select test.blocked($$select public.ask_id_again(current_setting('hz.jid')::uuid)$$);
select test.blocked($$select public.decide_join(current_setting('hz.jid')::uuid, true, '')$$);
select test.act('authenticated', 'fb-f29-owner');
select test.eq(public.ask_id_again(current_setting('hz.jid')::uuid), '9876529011');
select test.rows($$select count(*) from public.join_requests where id = current_setting('hz.jid')::uuid and id_received = 'none' and id_asked_at is not null$$, 1);
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f29-t1' and title = 'Please re-send your ID'$$, 1);
-- a second tenant fills the other link for the same bed, before anyone is approved
select test.act('authenticated', 'fb-f29-t2');
select test.eq((public.fill_join_request(current_setting('hz.j1b'), 'Kiran Kumar', '9876529012', current_date + 5, 'none') ->> 'hostel'), 'F29 Comforts PG');
-- approve the first: a stay, matched like Add a resident, the bed booked
select test.act('authenticated', 'fb-f29-owner');
select public.decide_join(current_setting('hz.jid')::uuid, true, '');
select test.fails($$select public.decide_join(current_setting('hz.jid')::uuid, true, '')$$, 'already decided');
select test.rows($$select count(*) from public.stays where hostel_id = 'f2900000-0000-0000-0000-000000000001' and bed_id = 'f2920000-0000-0000-0000-000000000001' and user_id = 'fb-f29-t1' and name = 'Ravi Teja' and rent = 6500 and advance = 3000 and confirmed and joined_on = current_date + 3$$, 1);
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq((select state from public.beds where id = 'f2920000-0000-0000-0000-000000000001'), 'booked');
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f29-t1' and title = 'You’re in. Welcome to F29 Comforts PG'$$, 1);
-- first approved wins: the second request can't be approved; the tenant sees "taken"
select test.act('authenticated', 'fb-f29-owner');
select set_config('hz.jid2', (select id::text from public.join_requests where token = current_setting('hz.j1b')), false);
select test.fails($$select public.decide_join(current_setting('hz.jid2')::uuid, true, '')$$, 'is taken');
select test.act('authenticated', 'fb-f29-t2');
select test.eq((public.join_request_info(current_setting('hz.j1b')) ->> 'taken'), 'true');
-- a third link on that bed can't be made, nor filled
select test.act('authenticated', 'fb-f29-owner');
select test.fails($$select public.new_join_request('f2920000-0000-0000-0000-000000000001', 6500, 3000, current_date, '')$$, 'is taken');
select set_config('hz.j2', public.new_join_request('f2920000-0000-0000-0000-000000000002', 6500, 3000, current_date, ''), false);
reset role;
select set_config('request.jwt.claims', '', false);
update public.join_requests set bed_id = 'f2920000-0000-0000-0000-000000000001' where token = current_setting('hz.j2');
select test.act('authenticated', 'fb-f29-t2');
select test.fails($$select public.fill_join_request(current_setting('hz.j2'), 'Kiran Kumar', '9876529012', current_date, 'none')$$, 'just taken');
-- decline the second with a note: a push with the note
select test.act('authenticated', 'fb-f29-owner');
select public.decide_join(current_setting('hz.jid2')::uuid, false, 'Bed went to someone else, sorry');
reset role;
select set_config('request.jwt.claims', '', false);
select test.rows($$select count(*) from public.push_outbox where user_id = 'fb-f29-t2' and body = 'Bed went to someone else, sorry'$$, 1);
select test.rows($$select count(*) from public.stays where user_id = 'fb-f29-t2'$$, 0);

-- ------------------------------------------------------------ expiry (7 days, hourly job)
update public.join_requests set expires_at = now() - interval '1 minute' where token = current_setting('hz.j2');
select test.act('authenticated', 'fb-f29-t2');
select test.eq((public.join_request_info(current_setting('hz.j2')) ->> 'status'), 'expired');
select test.eq((public.join_request_info(current_setting('hz.j2')) ->> 'owner_phone'), '');
select test.fails($$select public.fill_join_request(current_setting('hz.j2'), 'Kiran Kumar', '9876529012', current_date, 'none')$$, 'valid any more');
select test.blocked($$select public.expire_join_tokens()$$);
reset role;
select set_config('request.jwt.claims', '', false);
select test.eq(public.expire_join_tokens()::text, '1');
select test.rows($$select count(*) from public.join_requests where status = 'expired'$$, 1);
\o
\echo ' F29 JOIN TESTS PASSED'
