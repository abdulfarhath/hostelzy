-- B5: server-side rules. What the app used to decide on the phone now happens
-- in the database, so a modified app can't skip it:
--   1. HZ codes (holds, enquiries) and FP case numbers are issued here.
--   2. Hold rules: the bed must be free, at most 2 open holds per tenant, and a
--      free hold ends after 1 hour (2 for Hostelzy Members).
--   3. Hold expiry: public.expire_holds(), every minute (pg_cron).
--   4. Resident matching: a stay whose phone asked about, held or booked a bed
--      at that hostel on Hostelzy in the 60 days before joining is "via
--      Hostelzy" with its HZ code, whatever the owner picked.
--   5. Fair Play signals: such a resident added more than 3 days after moving
--      in, and a booked HZ hold with nobody added after 3 days, open a case.
--   6. Monthly invoices: public.issue_invoices() on the 1st; public.invoice_sweep()
--      daily for late days and pausing after 15 days.
--   7. Push: rows in public.push_outbox; the send-push Edge Function sends them.
-- Runs after 20261002020000_f13_firebase_ids.sql.

-- ================================================================ 0. server context

-- True for the database's own jobs (pg_cron, SQL editor): no request JWT at
-- all. Every app request through the API carries claims, so the app is never
-- "server", whichever token it sends.
create or replace function public.is_server() returns boolean
language sql stable set search_path = ''
as $$ select nullif(current_setting('request.jwt.claims', true), '') is null $$;

-- Invoice jobs (late days) run as the server, not as the team.
create or replace function public.guard_invoice() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if (to_jsonb(new) - 'utr' - 'status') <> (to_jsonb(old) - 'utr' - 'status') or new.status not in ('due', 'checking') then
    raise exception 'only the Hostelzy team confirms an invoice';
  end if;
  return new;
end $$;

-- ================================================================ 1. codes

create sequence if not exists public.hz_code_seq start 5001;
create sequence if not exists public.fp_case_seq start 200;
create sequence if not exists public.invoice_seq start 1100;

create or replace function public.next_hz_code() returns text
language sql volatile security definer set search_path = ''
as $$ select 'HZ-' || nextval('public.hz_code_seq') $$;

create or replace function public.next_fp_ref() returns text
language sql volatile security definer set search_path = ''
as $$ select 'FP-' || lpad(nextval('public.fp_case_seq')::text, 4, '0') $$;

-- The app never chooses its own code.
create or replace function public.set_hz_code() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.ref := public.next_hz_code();
  return new;
end $$;

drop trigger if exists set_hz_code on public.holds;
create trigger set_hz_code before insert on public.holds
for each row execute function public.set_hz_code();
drop trigger if exists set_hz_code on public.enquiries;
create trigger set_hz_code before insert on public.enquiries
for each row execute function public.set_hz_code();

-- ================================================================ 2. hold rules

create or replace function public.hold_rules() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  b record;
  open_holds int;
  member boolean;
begin
  select x.hostel_id, x.state into b from public.beds x where x.id = new.bed_id;
  if b is null or b.hostel_id <> new.hostel_id then
    raise exception 'that bed is not in this hostel';
  end if;
  if b.state <> 'free' then
    raise exception 'that bed is not free any more';
  end if;
  select count(*) into open_holds from public.holds h
  where h.tenant_id = new.tenant_id and h.status in ('waiting', 'held');
  if open_holds >= 2 then
    raise exception 'you can hold 2 beds at a time; release one first';
  end if;
  new.status := 'waiting';
  new.started_at := now();
  if new.opt = 'free' then
    select coalesce(p.member, false) into member from public.profiles p where p.id = new.tenant_id;
    new.expires_at := now() + case when coalesce(member, false) then interval '2 hours' else interval '1 hour' end;
  else
    new.expires_at := null;   -- paid and advance holds wait for the owner to confirm the payment
  end if;
  return new;
end $$;

drop trigger if exists hold_rules on public.holds;
create trigger hold_rules before insert on public.holds
for each row execute function public.hold_rules();

-- The bed shows as held while a hold is open.
create or replace function public.hold_marks_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.beds set state = 'held' where id = new.bed_id and state = 'free';
  return new;
end $$;

drop trigger if exists hold_marks_bed on public.holds;
create trigger hold_marks_bed after insert on public.holds
for each row execute function public.hold_marks_bed();

-- A released or expired hold frees its bed again (unless another hold is open
-- on it, or the owner has since booked it).
create or replace function public.hold_frees_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status in ('released', 'expired') and old.status in ('waiting', 'held') then
    update public.beds b set state = 'free'
    where b.id = new.bed_id and b.state = 'held'
      and not exists (select 1 from public.holds h where h.bed_id = new.bed_id and h.id <> new.id and h.status in ('waiting', 'held'));
  end if;
  return new;
end $$;

drop trigger if exists hold_frees_bed on public.holds;
create trigger hold_frees_bed after update of status on public.holds
for each row execute function public.hold_frees_bed();

-- ================================================================ 3. hold expiry

create or replace function public.expire_holds() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.holds set status = 'expired'
  where status in ('waiting', 'held') and expires_at is not null and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

-- ================================================================ 4. resident matching

-- The HZ code of this phone's enquiry or hold at hostel h in the 60 days
-- before joining (and the day after), newest first; null when none.
create or replace function public.hz_match(h uuid, p_phone text, joined date)
returns table (ref text, what text, at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select * from (
    select e.ref, 'asked about your hostel'::text, e.created_at
    from public.enquiries e
    where e.hostel_id = h and e.phone = p_phone
      and e.created_at >= joined - interval '60 days' and e.created_at < joined + interval '2 days'
    union all
    select x.ref, case when x.opt = 'free' then 'held a bed' else 'booked a bed' end, x.started_at
    from public.holds x join public.profiles p on p.id = x.tenant_id
    where x.hostel_id = h and p.phone = p_phone and x.status <> 'released'
      and x.started_at >= joined - interval '60 days' and x.started_at < joined + interval '2 days'
  ) m
  where length(p_phone) = 10
  order by 3 desc
  limit 1
$$;

create or replace function public.match_stay() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  m record;
  late int;
begin
  select * into m from public.hz_match(new.hostel_id, new.phone, new.joined_on);
  if m.ref is null then
    if new.via = 'hz' then new.via := 'direct'; end if;
    new.ref := null;
    new.late_days := 0;
    return new;
  end if;
  new.via := 'hz';
  new.ref := m.ref;
  late := current_date - new.joined_on;
  new.late_days := case when late > 3 then late else 0 end;
  if new.late_days > 0 then
    insert into public.fair_cases (ref, hostel_id, title, signal, resident, events)
    values (public.next_fp_ref(), new.hostel_id,
      new.name || ' added ' || new.late_days || ' days after moving in',
      'Hostelzy resident (' || m.ref || ') added after the 3-day limit',
      new.name,
      jsonb_build_array(
        jsonb_build_object('on', to_char(m.at, 'DD Mon'), 'what', 'On Hostelzy', 'detail', 'Tenant ' || m.what),
        jsonb_build_object('on', to_char(new.joined_on, 'DD Mon'), 'what', 'Moved in', 'detail', ''),
        jsonb_build_object('on', to_char(current_date, 'DD Mon'), 'what', 'Added by the owner', 'detail', new.late_days || ' days later', 'flag', true)));
  end if;
  return new;
end $$;

drop trigger if exists match_stay on public.stays;
create trigger match_stay before insert on public.stays
for each row execute function public.match_stay();

-- ================================================================ 5. Fair Play scan

-- A booked HZ hold with no resident added (by that code or the tenant's phone)
-- more than 3 days later. One case per hold. Returns the number of new cases.
create or replace function public.fair_play_scan() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  insert into public.fair_cases (ref, hostel_id, title, signal, events)
  select public.next_fp_ref(), x.hostel_id,
    'Booked on Hostelzy, not added',
    'Hostelzy booking (' || x.ref || ') not added as a resident after 3 days',
    jsonb_build_array(jsonb_build_object('on', to_char(x.started_at, 'DD Mon'), 'what', 'Booked on Hostelzy', 'detail', x.ref))
  from public.holds x
  left join public.profiles p on p.id = x.tenant_id
  where x.status = 'booked' and x.started_at < now() - interval '3 days'
    and not exists (select 1 from public.stays s where s.hostel_id = x.hostel_id and (s.ref = x.ref or (p.phone is not null and s.phone = p.phone)))
    and not exists (select 1 from public.fair_cases c where c.hostel_id = x.hostel_id and c.signal like '%(' || x.ref || ')%');
  get diagnostics n = row_count;
  return n;
end $$;

-- ================================================================ 6. invoices

-- Flat plans by size (DECISIONS 2026-10-02, data.dart planTiers).
create or replace function public.plan_price(beds int) returns int
language sql immutable set search_path = ''
as $$ select case when beds <= 30 then 499 when beds <= 80 then 999 else 1499 end $$;

-- One invoice per hostel per month once its trial has ended, priced by its
-- bed count, minus credit. Safe to run twice. Returns the number issued.
create or replace function public.issue_invoices(p_month date default current_date) returns int
language plpgsql security definer set search_path = ''
as $$
declare
  m date := date_trunc('month', p_month)::date;
  r record;
  beds int;
  amt int;
  n int := 0;
begin
  for r in
    select o.* from public.owner_plans o join public.hostels h on h.id = o.hostel_id
    where h.status = 'live' and o.status <> 'paused' and coalesce(o.trial_ends, m) <= m + 4
      and not exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and date_trunc('month', i.due) = m)
  loop
    select count(*) into beds from public.beds b where b.hostel_id = r.hostel_id;
    amt := greatest(public.plan_price(beds) - r.credit, 0);
    insert into public.invoices (ref, hostel_id, beds, amount, due)
    values ('HZ-INV-' || nextval('public.invoice_seq'), r.hostel_id, beds, amt, m + 4);
    update public.owner_plans set credit = greatest(credit - public.plan_price(beds), 0),
      status = case when status = 'trial' then 'active' else status end
    where hostel_id = r.hostel_id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Daily: days late on unpaid invoices; plans 15+ days late are overdue
-- (deals paused), and active again once nothing is late.
create or replace function public.invoice_sweep() returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.invoices set late = greatest(current_date - due, 0)
  where status in ('due', 'missing');
  update public.owner_plans o set status = 'overdue'
  where o.status = 'active' and exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and i.status in ('due', 'missing') and i.late >= 15);
  update public.owner_plans o set status = 'active'
  where o.status = 'overdue' and not exists (select 1 from public.invoices i where i.hostel_id = o.hostel_id and i.status in ('due', 'missing') and i.late >= 15);
end $$;

-- ================================================================ 7. push outbox

create table if not exists public.push_outbox (
  id bigserial primary key,
  user_id text not null,
  title text not null,
  body text not null default '',
  data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error text
);
alter table public.push_outbox enable row level security;
-- No policies: only the send-push function (service role) reads it.

create or replace function public.notify_staff(h uuid, t text, b text, d jsonb) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, t, b, d from public.hostel_staff s where s.hostel_id = h
$$;

create or replace function public.push_on_change() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bed text;
begin
  if tg_table_name = 'holds' and tg_op = 'INSERT' then
    select r.number || '-' || b.letter into bed from public.beds b join public.rooms r on r.id = b.room_id where b.id = new.bed_id;
    perform public.notify_staff(new.hostel_id, 'New hold on bed ' || coalesce(bed, ''), new.ref || ' · open Today to see it', jsonb_build_object('screen', 'oToday', 'ref', new.ref));
  elsif tg_table_name = 'enquiries' and tg_op = 'INSERT' then
    perform public.notify_staff(new.hostel_id, 'New enquiry from ' || new.name, new.ref || coalesce(' · bed ' || new.bed, ''), jsonb_build_object('screen', 'oToday', 'ref', new.ref));
  elsif tg_table_name = 'complaints' and tg_op = 'INSERT' then
    perform public.notify_staff(new.hostel_id, 'New complaint: ' || new.cat, left(new.body, 120), jsonb_build_object('screen', 'oMore'));
  elsif tg_table_name = 'payments' and tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'waiting' then
      perform public.notify_staff(new.hostel_id, 'Check a payment of ₹' || new.amount, 'UTR ' || coalesce(new.utr, '') || ' · confirm it in Rent', jsonb_build_object('screen', 'oRent'));
    elsif new.status in ('paid', 'missing') then
      insert into public.push_outbox (user_id, title, body, data) values (new.payer_id,
        case when new.status = 'paid' then 'Payment confirmed' else 'Payment not found' end,
        case when new.status = 'paid' then 'Your owner confirmed ₹' || new.amount || '.' else 'Your owner couldn''t find UTR ' || coalesce(new.utr, '') || '. Check it and send again.' end,
        jsonb_build_object('screen', case when new.kind = 'rent' then 'rPay' else 'holds' end));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists push_on_change on public.holds;
create trigger push_on_change after insert on public.holds for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.enquiries;
create trigger push_on_change after insert on public.enquiries for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.complaints;
create trigger push_on_change after insert on public.complaints for each row execute function public.push_on_change();
drop trigger if exists push_on_change on public.payments;
create trigger push_on_change after update on public.payments for each row execute function public.push_on_change();

-- ================================================================ who may call what

-- Jobs and helpers run only from the server (pg_cron, the service role),
-- never from the app.
revoke execute on function public.expire_holds(), public.fair_play_scan(), public.issue_invoices(date),
  public.invoice_sweep(), public.next_hz_code(), public.next_fp_ref(), public.notify_staff(uuid, text, text, jsonb),
  public.hz_match(uuid, text, date)
  from public, anon, authenticated;
revoke all on sequence public.hz_code_seq, public.fp_case_seq, public.invoice_seq from public, anon, authenticated;
revoke all on table public.push_outbox from public, anon, authenticated;
revoke all on sequence public.push_outbox_id_seq from public, anon, authenticated;

-- ================================================================ schedules

-- Only where pg_cron is switched on (Supabase: Database → Extensions → pg_cron).
-- Without it, docs/FOUNDER-TODO.md has the one-time SQL.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-expire-holds', '* * * * *', 'select public.expire_holds()');
    perform cron.schedule('hz-fair-play-scan', '30 3 * * *', 'select public.fair_play_scan()');
    perform cron.schedule('hz-invoice-sweep', '0 4 * * *', 'select public.invoice_sweep()');
    perform cron.schedule('hz-issue-invoices', '0 5 1 * *', 'select public.issue_invoices()');
  end if;
  -- Push: call the send-push Edge Function every minute with the secret the
  -- founder keeps in Vault as 'push_secret' (never in this file).
  if exists (select 1 from pg_extension where extname = 'pg_cron') and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule('hz-send-push', '* * * * *', $job$
      select net.http_post(
        url := 'https://oafiaczotlilomlvhphp.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object('content-type', 'application/json',
          'x-hz-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_secret')),
        body := '{}'::jsonb)
      where exists (select 1 from public.push_outbox where sent_at is null)
    $job$);
  end if;
end $$;
