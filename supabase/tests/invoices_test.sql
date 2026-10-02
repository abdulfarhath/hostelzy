-- S7 owner-plan invoices: runs after the other tests (uses their helpers and the S1 hostel).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select set_config('request.jwt.claims', '', false);
insert into public.invoices (ref, hostel_id, beds, amount, due) values ('HZ-INV-9001', 'e0000000-0000-0000-0000-000000000001', 3, 399, current_date + 5);

-- the owner sees it and sends a UTR; they can't mark it paid
select test.act('authenticated', 'fb-sai');
select test.rows($$select count(*) from public.invoices where ref = 'HZ-INV-9001'$$, 1);
update public.invoices set utr = '998877665544', status = 'checking' where ref = 'HZ-INV-9001';
select test.fails($$update public.invoices set status = 'paid' where ref = 'HZ-INV-9001'$$, 'only the Hostelzy team');
-- someone else's owner can't see it
select test.act('authenticated', 'fb-other');
select test.rows($$select count(*) from public.invoices where ref = 'HZ-INV-9001'$$, 0);

-- the team confirms it; then the owner can't change it any more
select test.act('authenticated', 'fb-team', true);
update public.invoices set status = 'paid' where ref = 'HZ-INV-9001';
select test.act('authenticated', 'fb-sai');
select test.fails($$update public.invoices set status = 'checking', utr = '111111111111' where ref = 'HZ-INV-9001'$$, 'this invoice is paid');
reset role;
select test.eq((select status || ' ' || utr from public.invoices where ref = 'HZ-INV-9001'), 'paid 998877665544');

reset role;
\o
select 'ALL INVOICE TESTS PASSED';
