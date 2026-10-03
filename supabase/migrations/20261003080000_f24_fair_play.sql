-- F24 item 18: Fair Play hardening (DECISIONS F07: 3 strikes — 1 warning,
-- 2 deals hidden for 30 days, 3 removed; a fix within 48 hours closes the
-- case with no strike, and three such fixes in 6 months = one warning).
--   fair_play_accepts       the owner's "I agree" to the Fair Play rules, once
--       per account (accept_fair_play()). Read by the owner and the team.
--   hostels.live_since      the day the hostel went live (set by the server).
--   stays.via = 'before'    "Joined before Hostelzy": only for someone who
--       moved in on or before the go-live day, set by the owner while the
--       hostel isn't live yet (onboarding) and after that by the team only.
--       These residents never count as off-app joins.
--   strike_state(h) / fair_standing()   the hostel's strikes now: strike 2
--       hides deals for 30 days from the day it was given, then they come
--       back; strikes themselves keep counting (DECISIONS sets no expiry for
--       them). Strike 3 removes the hostel: is_live() is false, so tenants
--       can't read it, its rooms, beds or deals, or hold or enquire there;
--       its owner and the team still see it, and its plan stops.
--   give_strike(case)       the team's strike, with the right words.
--   fix_case(case)          as before, and the third fix in 6 months is a
--       warning (a strike, reason 'fixes').
--   holds.declined          the owner or a manager turned a hold down.
--   fair_signals(hostel)    the six collusion signals (F07), team only.
--   fair_reports.status     tenant reports: new → case (report_case()) or
--       closed by the team in the console.
-- Safe to run again.

-- ---------------------------------------------------------------- 1. rules accepted

create table if not exists public.fair_play_accepts (
  user_id text primary key,
  accepted_at timestamptz not null default now()
);
alter table public.fair_play_accepts enable row level security;
drop policy if exists "own or team read accepts" on public.fair_play_accepts;
create policy "own or team read accepts" on public.fair_play_accepts for select using (user_id = public.uid() or public.is_team());
revoke all on table public.fair_play_accepts from public, anon, authenticated;
grant select on table public.fair_play_accepts to authenticated;

create or replace function public.accept_fair_play() returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare at timestamptz;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  insert into public.fair_play_accepts (user_id) values (public.uid()) on conflict (user_id) do nothing;
  select a.accepted_at into at from public.fair_play_accepts a where a.user_id = public.uid();
  return at;
end $$;
revoke execute on function public.accept_fair_play() from public, anon;
grant execute on function public.accept_fair_play() to authenticated;

-- ---------------------------------------------------------------- 2. joined before Hostelzy

alter table public.hostels add column if not exists live_since date;
update public.hostels set live_since = coalesce(visited_on, created_at::date) where status = 'live' and live_since is null;

create or replace function public.hostel_live_since() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.live_since is distinct from old.live_since and not (public.is_team() or public.is_server()) then
    raise exception 'ask the Hostelzy team to change this';
  end if;
  if new.status = 'live' and new.live_since is null then new.live_since := (now() at time zone 'Asia/Kolkata')::date; end if;
  return new;
end $$;
drop trigger if exists hostel_live_since on public.hostels;
create trigger hostel_live_since before insert or update on public.hostels
for each row execute function public.hostel_live_since();
revoke execute on function public.hostel_live_since() from public, anon, authenticated;

-- Runs after match_stay (names sort), so it sees the final "via".
create or replace function public.stay_joined_before() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare ls date; hname text;
begin
  if new.via is distinct from 'before' then return new; end if;
  if tg_op = 'UPDATE' and old.via = 'before' and new.joined_on is not distinct from old.joined_on then return new; end if;
  select h.live_since, h.name into ls, hname from public.hostels h where h.id = new.hostel_id;
  if ls is null then return new; end if;
  if new.joined_on > ls then
    raise exception 'only residents who moved in by % (when % went live) joined before Hostelzy', to_char(ls, 'FMDD Mon YYYY'), hname;
  end if;
  if not (public.is_team() or public.is_server()) then
    raise exception 'after go-live, only the Hostelzy team marks a resident as joined before Hostelzy';
  end if;
  return new;
end $$;
drop trigger if exists stay_joined_before on public.stays;
create trigger stay_joined_before before insert or update on public.stays
for each row execute function public.stay_joined_before();
revoke execute on function public.stay_joined_before() from public, anon, authenticated;

-- ---------------------------------------------------------------- 3–4. strikes now

alter table public.strikes add column if not exists reason text not null default 'case';
alter table public.strikes drop constraint if exists strikes_reason;
alter table public.strikes add constraint strikes_reason check (reason in ('case', 'fixes'));

-- n strikes; strike 2 hides deals for 30 days from the day it was given.
create or replace function public.strike_state(h uuid) returns table (n int, hidden_until timestamptz, removed boolean, last_reason text)
language sql stable security definer set search_path = ''
as $$
  select count(*)::int,
    case when count(*) = 2 then (select s.created_at from public.strikes s where s.hostel_id = h order by s.created_at offset 1 limit 1) + interval '30 days' end,
    count(*) >= 3,
    (select s.reason from public.strikes s where s.hostel_id = h order by s.created_at desc limit 1)
  from public.strikes x where x.hostel_id = h
$$;

create or replace function public.is_removed(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select (select count(*) from public.strikes s where s.hostel_id = h) >= 3 $$;

create or replace function public.deals_hidden(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce((select st.removed or coalesce(st.hidden_until > now(), false) from public.strike_state(h) st), false) $$;

create or replace function public.strike_label(n int) returns text
language sql immutable set search_path = ''
as $$ select case when n <= 1 then 'warning' when n = 2 then 'deals hidden for 30 days' else 'removed from Hostelzy' end $$;

-- Strike 3: tenants can't see the hostel any more. Its owner and the team can.
create or replace function public.is_live(h uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.hostels x where x.id = h and x.status = 'live') and not public.is_removed(h) $$;

drop policy if exists "live hostels" on public.hostels;
create policy "live hostels" on public.hostels for select
  using ((status = 'live' and not public.is_removed(id)) or public.is_staff(id) or public.is_team());

-- Everyone: the strike state of hostels they can see; the owner and the team
-- also for a removed one (so the owner sees why).
create or replace function public.fair_standing() returns table (hostel_id uuid, n int, deals_hidden boolean, hidden_until timestamptz, removed boolean, last_reason text)
language sql stable security definer set search_path = ''
as $$
  select h.hostel_id, st.n, st.removed or coalesce(st.hidden_until > now(), false), st.hidden_until, st.removed, st.last_reason
  from (select distinct s.hostel_id from public.strikes s) h
  cross join lateral public.strike_state(h.hostel_id) st
  where public.is_live(h.hostel_id) or public.is_owner(h.hostel_id) or public.is_team()
$$;
grant execute on function public.fair_standing() to anon, authenticated;

-- A third strike stops the plan (no more invoices).
create or replace function public.strike_effects() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_removed(new.hostel_id) then
    update public.owner_plans set status = 'paused' where hostel_id = new.hostel_id;
  end if;
  return new;
end $$;
drop trigger if exists strike_effects on public.strikes;
create trigger strike_effects after insert on public.strikes
for each row execute function public.strike_effects();
revoke execute on function public.strike_effects() from public, anon, authenticated;

-- The team decides a strike: the case says which one and what it means.
create or replace function public.give_strike(p_case uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare c record; k int; words text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team decides a strike'; end if;
  select * into c from public.fair_cases where id = p_case;
  if c.id is null then raise exception 'that case isn''t there any more'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is already decided'; end if;
  insert into public.strikes (hostel_id, case_id, reason) values (c.hostel_id, p_case, 'case');
  select count(*)::int into k from public.strikes where hostel_id = c.hostel_id;
  words := 'Strike ' || least(k, 3) || ' · ' || public.strike_label(k);
  update public.fair_cases set status = 'decided', decision = words where id = p_case;
  return words;
end $$;
revoke execute on function public.give_strike(uuid) from public, anon;
grant execute on function public.give_strike(uuid) to authenticated;

-- Deals at booking time follow the strikes now (2 strikes: hidden 30 days).
create or replace function public.deal_for_bed(p_hostel uuid, p_bed uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  rm record;
  fee int;
  t jsonb;
  d record;
  paused boolean;
  on_ids text[] := '{}';
begin
  select r.ac, r.share, r.rent into rm from public.beds b join public.rooms r on r.id = b.room_id where b.id = p_bed and b.hostel_id = p_hostel;
  if not found then return null; end if;
  select c.rent into fee from public.rate_cards c where c.hostel_id = p_hostel and c.ac = rm.ac and c.share = rm.share;
  select coalesce(h.terms, '{}'::jsonb) into t from public.hostels h where h.id = p_hostel;
  select x.deals_on, x.target into d from public.deals x where x.hostel_id = p_hostel;
  paused := public.deals_hidden(p_hostel)
    or exists (select 1 from public.owner_plans o where o.hostel_id = p_hostel and o.status in ('overdue', 'paused'));
  if d is not null and not paused and coalesce(array_length(d.deals_on, 1), 0) > 0
     and (coalesce(d.target, '') in ('', 'all') or (d.target = 'ac') = rm.ac) then
    on_ids := d.deals_on;
  end if;
  return jsonb_build_object(
    'on', to_jsonb(on_ids),
    'fee', coalesce(fee, rm.rent),
    'advance', coalesce((t ->> 'advance')::int, 3000),
    'maintenance', coalesce((t ->> 'maintenance')::int, 1000),
    'notice', coalesce((t ->> 'noticeDays')::int, 30),
    'at', now());
end $$;
revoke execute on function public.deal_for_bed(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- 7. three fixes in 6 months

alter table public.fair_cases add column if not exists fixed_at timestamptz;
alter table public.fair_cases add column if not exists fix_counted boolean not null default false;
select set_config('hz.fixing', 'on', false);
update public.fair_cases set fixed_at = created_at where fixed_at is null and decision like 'Fixed by the owner%';
select set_config('hz.fixing', 'off', false);

create or replace function public.fix_case(p_case uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record; three uuid[];
begin
  select * into c from public.fair_cases where id = p_case;
  -- Wave 3a: Fair Play is the owner's, not the managers'.
  if c is null or not public.is_owner(c.hostel_id) then raise exception 'only this hostel''s owner can fix it'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is closed'; end if;
  if c.created_at < now() - interval '48 hours' then raise exception 'the 48 hours are over; reply instead'; end if;
  if c.resident is null then raise exception 'there is no resident to fix; reply instead'; end if;
  update public.stays set via = 'hz', late_days = 0
  where hostel_id = c.hostel_id and left_on is null and (name = c.resident or bed_id in (
    select b.id from public.beds b join public.rooms r on r.id = b.room_id
    where b.hostel_id = c.hostel_id and coalesce(r.label, r.number::text) || '-' || b.letter = c.resident));
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set status = 'closed', decision = 'Fixed by the owner within 48 h · no strike', fixed_at = now() where id = p_case;
  -- Three fixes in 6 months (not yet counted) = one warning.
  select array_agg(x.id) into three from (
    select f.id from public.fair_cases f
    where f.hostel_id = c.hostel_id and f.fixed_at > now() - interval '6 months' and not f.fix_counted
    order by f.fixed_at limit 3) x;
  if coalesce(array_length(three, 1), 0) >= 3 then
    update public.fair_cases set fix_counted = true where id = any(three);
    insert into public.strikes (hostel_id, case_id, reason) values (c.hostel_id, p_case, 'fixes');
  end if;
  perform set_config('hz.fixing', 'off', true);
end $$;
revoke execute on function public.fix_case(uuid) from public, anon;
grant execute on function public.fix_case(uuid) to authenticated;

-- ---------------------------------------------------------------- 5. the six signals

alter table public.holds add column if not exists declined boolean not null default false;

-- The owner or a manager (not the tenant) turned the hold down.
create or replace function public.hold_declined() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'released' and old.status in ('waiting', 'held') and public.uid() is distinct from old.tenant_id
     and public.is_staff(old.hostel_id) then
    new.declined := true;
  elsif not (public.is_team() or public.is_server()) then
    new.declined := old.declined;
  end if;
  return new;
end $$;
drop trigger if exists hold_declined on public.holds;
create trigger hold_declined before update on public.holds
for each row execute function public.hold_declined();
revoke execute on function public.hold_declined() from public, anon, authenticated;

-- One row per hostel and signal (F07): how many, and a short line for the team.
create or replace function public.fair_signals(p_hostel uuid default null)
returns table (hostel_id uuid, signal text, label text, n int, detail text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team sees Fair Play signals'; end if;
  return query
  with hs as (
    select h.id from public.hostels h where p_hostel is null or h.id = p_hostel
  ),
  -- 1. held or enquired on Hostelzy, then added as Direct (same name, another number)
  s1 as (
    select s.hostel_id, count(distinct s.id)::int as n, string_agg(distinct s.name, ', ') as d
    from public.stays s
    where s.via = 'direct' and s.joined_on > current_date - 90
      and (exists (select 1 from public.enquiries e where e.hostel_id = s.hostel_id and lower(trim(e.name)) = lower(trim(s.name))
                     and e.created_at >= s.joined_on - interval '60 days' and e.created_at < s.joined_on + interval '2 days')
        or exists (select 1 from public.holds x join public.profiles p on p.id = x.tenant_id
                     where x.hostel_id = s.hostel_id and p.name <> '' and lower(trim(p.name)) = lower(trim(s.name))
                     and x.started_at >= s.joined_on - interval '60 days' and x.started_at < s.joined_on + interval '2 days'))
    group by s.hostel_id
  ),
  -- 2. a hold ended and the same bed went to a Direct resident within 7 days
  s2 as (
    select x.hostel_id, count(distinct s.id)::int as n,
      string_agg(distinct coalesce(r.label, r.number::text) || '-' || b.letter, ', ') as d
    from public.holds x
    join public.stays s on s.bed_id = x.bed_id and s.hostel_id = x.hostel_id
    join public.beds b on b.id = x.bed_id join public.rooms r on r.id = b.room_id
    where x.status in ('released', 'expired') and x.started_at > now() - interval '90 days' and s.via = 'direct'
      and s.joined_on >= x.started_at::date
      and s.joined_on <= (coalesce(x.decided_at, x.expires_at, x.started_at) + interval '7 days')::date
    group by x.hostel_id
  ),
  -- 3. the tenant said "Yes, I joined" 3+ days ago and was never added
  s3 as (
    select j.hostel_id,
      count(*) filter (where not exists (
        select 1 from public.stays s where s.hostel_id = j.hostel_id
          and (s.user_id = j.tenant_id or (x.ref is not null and s.ref = x.ref) or (coalesce(p.phone, '') <> '' and s.phone = p.phone))))::int as n,
      count(*)::int as yes
    from public.join_answers j join public.holds x on x.id = j.hold_id left join public.profiles p on p.id = j.tenant_id
    where j.answer = 'yes' and j.updated_at < now() - interval '3 days' and j.updated_at > now() - interval '90 days'
    group by j.hostel_id
  ),
  -- 4. a Direct resident paying less than the walk-in price while deals are on
  s4 as (
    select s.hostel_id, count(*)::int as n, string_agg(s.name || ' ₹' || s.rent || ' (walk-in ₹' || c.rent || ')', ', ') as d
    from public.stays s
    join public.beds b on b.id = s.bed_id join public.rooms r on r.id = b.room_id
    join public.rate_cards c on c.hostel_id = s.hostel_id and c.ac = r.ac and c.share = r.share
    join public.deals dl on dl.hostel_id = s.hostel_id and coalesce(array_length(dl.deals_on, 1), 0) > 0
    where s.via = 'direct' and s.left_on is null and s.rent > 0 and s.rent < c.rent
    group by s.hostel_id
  ),
  -- 5. holds declined while Direct residents are added (30 days)
  s5 as (
    select h.id as hostel_id,
      (select count(*)::int from public.holds x where x.hostel_id = h.id and x.declined and coalesce(x.decided_at, x.started_at) > now() - interval '30 days') as declined,
      (select count(*)::int from public.stays s where s.hostel_id = h.id and s.via = 'direct' and s.joined_on > current_date - 30) as added
    from hs h
  ),
  -- 6. tenant reports (90 days)
  s6 as (
    select f.hostel_id, count(*)::int as n, count(*) filter (where f.status = 'new')::int as open,
      string_agg(distinct f.why, ' · ') as d
    from public.fair_reports f where f.created_at > now() - interval '90 days'
    group by f.hostel_id
  )
  select h.id, 'direct_after_app', 'Held or enquired, then added as Direct', coalesce(s1.n, 0), coalesce(s1.d, '')
  from hs h left join s1 on s1.hostel_id = h.id
  union all
  select h.id, 'bed_after_cancel', 'Hold cancelled, same bed taken in 7 days', coalesce(s2.n, 0), coalesce('Beds ' || s2.d, '')
  from hs h left join s2 on s2.hostel_id = h.id
  union all
  select h.id, 'joined_not_added', 'Tenant said “Yes, I joined”, never added', coalesce(s3.n, 0),
    case when s3.yes is null then '' else s3.yes || ' said yes, ' || s3.n || ' not added' end
  from hs h left join s3 on s3.hostel_id = h.id
  union all
  select h.id, 'direct_deal_price', 'Direct resident paying the deal price', coalesce(s4.n, 0), coalesce(s4.d, '')
  from hs h left join s4 on s4.hostel_id = h.id
  union all
  select h.id, 'declines_while_filling', 'Declining holds while occupancy rises',
    case when s5.declined >= 2 and s5.added >= 2 then s5.declined else 0 end,
    s5.declined || ' declined, ' || s5.added || ' added directly in 30 days'
  from hs h join s5 on s5.hostel_id = h.id
  union all
  select h.id, 'tenant_reports', 'Tenant reports', coalesce(s6.n, 0), coalesce(s6.open || ' open · ' || s6.d, '')
  from hs h left join s6 on s6.hostel_id = h.id;
end $$;
revoke execute on function public.fair_signals(uuid) from public, anon;
grant execute on function public.fair_signals(uuid) to authenticated;

-- ---------------------------------------------------------------- 6. tenant reports in the console

alter table public.fair_reports add column if not exists status text not null default 'new';
alter table public.fair_reports add column if not exists case_id uuid references public.fair_cases (id) on delete set null;
alter table public.fair_reports drop constraint if exists fair_reports_status;
alter table public.fair_reports add constraint fair_reports_status check (status in ('new', 'case', 'closed'));

drop policy if exists "report" on public.fair_reports;
create policy "report" on public.fair_reports for insert
  with check (reporter_id = public.uid() and public.is_verified() and status = 'new' and case_id is null);
drop policy if exists "team closes reports" on public.fair_reports;
create policy "team closes reports" on public.fair_reports for update using (public.is_team()) with check (public.is_team());

-- "Open a case": the owner sees the case (never who reported it).
create or replace function public.report_case(p_report uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare f record; cid uuid; cref text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team opens a case'; end if;
  select * into f from public.fair_reports where id = p_report;
  if f.id is null then raise exception 'that report isn''t there any more'; end if;
  if f.status <> 'new' then raise exception 'this report is already handled'; end if;
  insert into public.fair_cases (ref, hostel_id, title, signal, events)
  values (public.next_fp_ref(), f.hostel_id, 'Tenant report',
    'Tenant report: ' || lower(left(f.why, 1)) || substr(f.why, 2),
    jsonb_build_array(jsonb_build_object('on', to_char(f.created_at, 'DD Mon'), 'what', 'A tenant told Hostelzy', 'detail', f.why, 'flag', true)))
  returning id, ref into cid, cref;
  update public.fair_reports set status = 'case', case_id = cid where id = p_report;
  return cref;
end $$;
revoke execute on function public.report_case(uuid) from public, anon;
grant execute on function public.report_case(uuid) to authenticated;
