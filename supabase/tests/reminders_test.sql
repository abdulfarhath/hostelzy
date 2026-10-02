-- F20 reminders backup: runs after the other tests (uses their helpers).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);

-- a user backs up their own reminders and reads them back
select test.act('authenticated', 'fb-rem-1');
select test.rows($$insert into public.profiles (name) values ('Rahul')$$, 1);
select test.rows($$update public.profiles set reminders = '{"water": {"on": true, "every": 30}, "mine": []}' where id = 'fb-rem-1'$$, 1);
select test.eq((select reminders->'water'->>'every' from public.profiles where id = 'fb-rem-1'), '30');
-- only an object, and small
select test.fails($$update public.profiles set reminders = '[1, 2]' where id = 'fb-rem-1'$$, 'reminders_small');
select test.fails($$update public.profiles set reminders = jsonb_build_object('x', repeat('a', 20000)) where id = 'fb-rem-1'$$, 'reminders_small');

-- someone else can neither read nor change them
select test.act('authenticated', 'fb-rem-2');
select test.rows($$select count(*) from public.profiles where id = 'fb-rem-1'$$, 0);
select test.rows($$update public.profiles set reminders = '{}' where id = 'fb-rem-1'$$, 0);
reset role;
select test.eq((select reminders->'water'->>'on' from public.profiles where id = 'fb-rem-1'), 'true');

reset role;
\o
select 'ALL REMINDER TESTS PASSED';
