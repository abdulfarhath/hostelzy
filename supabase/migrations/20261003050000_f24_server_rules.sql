-- F24 Wave 3a: server rules (items 17, 19, 20, 21).
--   17. Owner-only areas (DECISIONS F14): the plan and its invoices, Hostelzy
--       credits, deals, rates (the rate card and a room's rent / AC) and Fair
--       Play cases and strikes belong to the owner. Managers keep beds,
--       residents, enquiries, complaints, menus and layouts.
--         rate_cards, deals      only the owner (or the team) writes.
--         rooms                  a manager can't change a room's rent or AC.
--         owner_plans, invoices, fair_cases, strikes, owner credits in
--         reward_ledger          only the owner (and the team) reads.
--         fair_cases             only the owner replies or fixes (also inside
--                                fix_case, by a trigger).
--   19. An AC room needs an AC unit in its layout (DECISIONS 2026-10-02):
--       also when a room becomes AC (Manage → Rates, Rooms and floors), not
--       only when its layout is published. A room whose published layout has
--       no AC unit can't be made AC; a room with no layout yet can.
--   20. Ranking (DECISIONS F10, F08):
--         hostel_flags() → per live hostel: beds, featured (80+ beds plan:
--             more than 80 beds, the ₹1,499 tier, while the plan isn't 15+
--             days late), deals_paused.
--         hostel_signals().complaints_30d counts only residents' complaints:
--             not the owner's, a manager's or the team's own "Not working"
--             marks (4zz1), nor anything the hostel's staff raised.
--   21. Deals pause while the owner's plan is 15+ days late (DECISIONS F10):
--         deals_paused(h) — an unpaid invoice 15+ days past its due day.
--         Tenants can't read the deals row then (walk-in prices only); the
--         owner and managers still can. hostel_flags() says so to everyone.
--       Pushes (push_outbox; data.kind so the Settings switches apply):
--         new invoice → the owner ("plan", always sent);
--         money_pushes() daily 9 am IST (pg_cron): plan 5 days late → the
--             owner; 15 days late → "deals paused" → the owner; rent due today
--             (the hostel's terms: the joining date, or the 1st) → each
--             resident on the app ("rent", their Rent switch).
-- Runs after 20261003042000_f24_did_you_join.sql (and 20261003020000_f24_wave1.sql, case photos). Safe to run again.

-- ================================================================ 17. owner-only areas

drop policy if exists "staff write rates" on public.rate_cards;
drop policy if exists "owner writes rates" on public.rate_cards;
create policy "owner writes rates" on public.rate_cards for all
  using (public.is_owner(hostel_id) or public.is_team()) with check (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "staff write deals" on public.deals;
drop policy if exists "owner writes deals" on public.deals;
create policy "owner writes deals" on public.deals for all
  using (public.is_owner(hostel_id) or public.is_team()) with check (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read plan" on public.owner_plans;
create policy "read plan" on public.owner_plans for select using (public.is_owner(hostel_id) or public.is_team());
drop policy if exists "read invoices" on public.invoices;
create policy "read invoices" on public.invoices for select using (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read cases" on public.fair_cases;
create policy "read cases" on public.fair_cases for select using (public.is_owner(hostel_id) or public.is_team());
drop policy if exists "owner replies to case" on public.fair_cases;
create policy "owner replies to case" on public.fair_cases for update using (public.is_owner(hostel_id)) with check (public.is_owner(hostel_id));
drop policy if exists "read strikes" on public.strikes;
create policy "read strikes" on public.strikes for select using (public.is_owner(hostel_id) or public.is_team());

drop policy if exists "read own rewards" on public.reward_ledger;
create policy "read own rewards" on public.reward_ledger for select
  using (user_id = public.uid() or public.is_team()
    or (hostel_id is not null and (public.is_owner(hostel_id) or (kind <> 'owner_credit' and public.is_staff(hostel_id)))));

-- Fair Play case photos (20261003020000_f24_wave1.sql): the owner's too.
drop policy if exists "hz upload case photos" on storage.objects;
create policy "hz upload case photos" on storage.objects for insert
  with check (bucket_id = 'case-photos' and split_part(name, '/', 2) = public.uid()
    and (public.is_owner(public.complaint_photo_hostel(name)) or public.is_team()));
drop policy if exists "hz read case photos" on storage.objects;
create policy "hz read case photos" on storage.objects for select
  using (bucket_id = 'case-photos' and (split_part(name, '/', 2) = public.uid() or public.is_team()
    or (public.is_owner(public.complaint_photo_hostel(name))
        and exists (select 1 from public.fair_cases c where c.hostel_id = public.complaint_photo_hostel(name) and (c.tenant_photo = name or c.owner_photo = name)))));

-- fix_case() and case_photo() are security definer; this keeps a manager out of them too.
create or replace function public.owner_only_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() or public.is_owner(old.hostel_id) then return new; end if;
  raise exception 'only the owner handles Fair Play';
end $$;
drop trigger if exists owner_only_case on public.fair_cases;
create trigger owner_only_case before update on public.fair_cases
for each row execute function public.owner_only_case();

-- ================================================================ 17 + 19. rooms: rent, AC

create or replace function public.guard_room_rates() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and (new.rent is distinct from old.rent or new.ac is distinct from old.ac)
     and not (public.is_server() or public.is_team() or public.is_owner(new.hostel_id)) then
    raise exception 'only the owner changes rates and AC rooms';
  end if;
  if new.ac and (tg_op = 'INSERT' or not old.ac)
     and exists (select 1 from public.layouts l where l.hostel_id = new.hostel_id and l.room = new.number and l.stage = 'published')
     and not exists (select 1 from public.layouts l, jsonb_array_elements(l.items) i
                     where l.hostel_id = new.hostel_id and l.room = new.number and l.stage = 'published' and i ->> 'kind' = 'ac') then
    raise exception 'room %: an AC room needs an AC unit. Add it in the room''s layout and publish, then make it AC', coalesce(new.label, new.number::text);
  end if;
  return new;
end $$;
drop trigger if exists guard_room_rates on public.rooms;
create trigger guard_room_rates before insert or update of ac, rent on public.rooms
for each row execute function public.guard_room_rates();

-- ================================================================ 21. deals pause

-- An unpaid invoice 15+ days past its due day (India time).
create or replace function public.deals_paused(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.invoices i where i.hostel_id = h and i.status <> 'paid'
    and (now() at time zone 'Asia/Kolkata')::date - i.due >= 15)
$$;

drop policy if exists "read deals" on public.deals;
create policy "read deals" on public.deals for select
  using ((public.is_live(hostel_id) and not public.deals_paused(hostel_id)) or public.is_staff(hostel_id) or public.is_team());

-- ================================================================ 20. ranking

create or replace function public.hostel_flags() returns table (hostel_id uuid, beds int, featured boolean, deals_paused boolean)
language sql stable security definer set search_path = ''
as $$
  select x.id, x.beds,
    x.beds > 80 and coalesce(o.status, 'trial') in ('trial', 'active') and not x.paused,
    x.paused
  from (
    select h.id, (select count(*)::int from public.beds b where b.hostel_id = h.id) as beds, public.deals_paused(h.id) as paused
    from public.hostels h where h.status = 'live'
  ) x left join public.owner_plans o on o.hostel_id = x.id
$$;

-- Same as 20261002233500_f24_values.sql, but complaints_30d counts only
-- complaints from the hostel's residents (not the owner's own marks).
create or replace function public.hostel_signals() returns table (hostel_id uuid, reply_minutes int, reply_n int, complaints_30d int, residents int, photos int, rooms int, layouts int)
language sql stable security definer set search_path = ''
as $$
  with replies as (
    select e.hostel_id, extract(epoch from e.contacted_at - e.created_at) / 60 as m from public.enquiries e
    where e.contacted_at is not null and e.created_at > now() - interval '60 days'
    union all
    select x.hostel_id, extract(epoch from x.decided_at - x.started_at) / 60 from public.holds x
    where x.decided_at is not null and x.started_at > now() - interval '60 days' and x.status <> 'expired'
  ), speed as (
    select r.hostel_id, round(percentile_cont(0.5) within group (order by r.m))::int as minutes, count(*)::int as n from replies r group by r.hostel_id
  )
  select h.id,
    coalesce(sp.minutes, 0),
    coalesce(sp.n, 0),
    (select count(*)::int from public.complaints c where c.hostel_id = h.id and c.created_at > now() - interval '30 days'
       and not exists (select 1 from public.hostel_staff st where st.hostel_id = h.id and st.user_id = c.author_id)
       and (c.item is null or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = c.author_id))),
    (select count(*)::int from public.stays s where s.hostel_id = h.id and s.left_on is null),
    (select count(*)::int from public.hostel_photos p where p.hostel_id = h.id),
    (select count(*)::int from public.rooms r where r.hostel_id = h.id),
    (select count(*)::int from public.layouts l where l.hostel_id = h.id and l.stage = 'published')
  from public.hostels h left join speed sp on sp.hostel_id = h.id
  where h.status = 'live'
$$;

-- ================================================================ 21. pushes

alter table public.invoices add column if not exists pushed int[] not null default '{}';
alter table public.stays add column if not exists rent_reminded_on date;

create or replace function public.notify_owner(h uuid, t text, b text, d jsonb) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, t, b, d from public.hostel_staff s where s.hostel_id = h and s.role = 'owner'
$$;

create or replace function public.invoice_push() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.notify_owner(new.hostel_id, 'New Hostelzy invoice: ₹' || new.amount,
    new.ref || ' · due ' || to_char(new.due, 'FMDD Mon') || '. Pay by UPI from Manage › Your plan.',
    jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', new.ref));
  return new;
end $$;
drop trigger if exists invoice_push on public.invoices;
create trigger invoice_push after insert on public.invoices
for each row execute function public.invoice_push();

-- Daily, 9 am India time. Safe to run twice a day: each push goes once.
create or replace function public.money_pushes() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  i record;
  late int;
  n int := 0;
begin
  for i in select * from public.invoices where status in ('due', 'missing') and today - due >= 5 loop
    late := today - i.due;
    if late >= 15 and not (15 = any(i.pushed)) then
      perform public.notify_owner(i.hostel_id, 'Deals paused: plan ' || late || ' days late',
        'Tenants see walk-in prices only. Pay ₹' || i.amount || ' (' || i.ref || ') to switch your deals back on.',
        jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', i.ref));
      update public.invoices set pushed = pushed || array[5, 15] where id = i.id;
      n := n + 1;
    elsif late < 15 and not (5 = any(i.pushed)) then
      perform public.notify_owner(i.hostel_id, 'Your Hostelzy plan is ' || late || ' days late',
        'Pay ₹' || i.amount || ' by ' || to_char(i.due + 15, 'FMDD Mon') || ' to keep your deals showing.',
        jsonb_build_object('screen', 'oPlan', 'kind', 'plan', 'ref', i.ref));
      update public.invoices set pushed = pushed || 5 where id = i.id;
      n := n + 1;
    end if;
  end loop;

  -- Rent due today: the joining date's day each month (the month's last day
  -- when it's shorter), or the 1st, by the hostel's terms. Not on the joining
  -- day itself, and not when this month's rent is already sent or paid.
  with due as (
    update public.stays s set rent_reminded_on = today
    from public.hostels h
    where h.id = s.hostel_id and s.user_id is not null and s.confirmed and s.left_on is null
      and s.joined_on < today and s.rent_reminded_on is distinct from today
      and extract(day from today)::int = case when coalesce((h.terms ->> 'dueOnJoining')::boolean, true)
        then least(extract(day from s.joined_on)::int, extract(day from (date_trunc('month', today) + interval '1 month - 1 day'))::int)
        else 1 end
      and not exists (select 1 from public.payments p where p.hostel_id = s.hostel_id and p.payer_id = s.user_id
        and p.kind = 'rent' and p.status in ('waiting', 'paid') and p.created_at > now() - interval '20 days')
    returning s.user_id, s.rent, h.name
  )
  insert into public.push_outbox (user_id, title, body, data)
  select d.user_id, 'Rent due today',
    case when d.rent > 0 then '₹' || d.rent || ' to ' || d.name || '. Pay by UPI from Pay rent.' else 'Your rent at ' || d.name || ' is due today. Pay by UPI from Pay rent.' end,
    jsonb_build_object('screen', 'rPay', 'kind', 'rent')
  from due d;
  get diagnostics late = row_count;
  return n + late;
end $$;

revoke execute on function public.owner_only_case(), public.guard_room_rates(), public.notify_owner(uuid, text, text, jsonb),
  public.invoice_push(), public.money_pushes() from public, anon, authenticated;
grant execute on function public.deals_paused(uuid), public.hostel_flags(), public.hostel_signals() to anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-money-pushes', '25 3 * * *', 'select public.money_pushes()');
  end if;
end $$;
