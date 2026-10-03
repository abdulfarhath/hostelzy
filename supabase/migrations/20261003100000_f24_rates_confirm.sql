-- F24 Wave 4d (audit §3, F03 rules): "Confirmed by the owner · date" on rates,
-- and a monthly "Are your rates still right?".
--   rate_cards.confirmed_at   when the owner last stood by this price. Only the
--       server's clock counts: set to now() when a rate card is added or its
--       rent changes, and by confirm_rates(). Whatever the app sends is
--       ignored (the team and the server itself may set it). Rate cards that
--       existed before this ran stay unconfirmed (null): we don't know when
--       their price was last checked, and tenants never see an invented date.
--   confirm_rates(p_hostel)   the owner's "Rates still right" on Today: every
--       rate card of the hostel gets confirmed_at = now(). Owner (or team)
--       only, like rates themselves (Wave 3a, DECISIONS F14).
--   nudge_rates()             daily (pg_cron, 10:15 India time): a push to the
--       hostel's owner when its oldest rate wasn't confirmed for 30 days (or
--       never), at most one every 30 days. data.kind 'rates' (always sent).
-- Tenants read confirmed_at with the rate card: "Confirmed by the owner ·
-- 12 Sep", or "Not confirmed in over a month" after 31 days.
-- Runs after 20261003050000_f24_server_rules.sql. Safe to run again.

alter table public.rate_cards add column if not exists confirmed_at timestamptz;

create or replace function public.guard_rate_confirm() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not (public.is_team() or public.is_server()) or new.confirmed_at is null then new.confirmed_at := now(); end if;
    return new;
  end if;
  if new.rent is distinct from old.rent then
    -- A new price is the owner's price today.
    new.confirmed_at := now();
  elsif current_setting('hz.rates_confirm', true) = 'on' then
    new.confirmed_at := now();
  elsif not (public.is_team() or public.is_server()) then
    new.confirmed_at := old.confirmed_at;
  end if;
  return new;
end $$;

drop trigger if exists guard_rate_confirm on public.rate_cards;
create trigger guard_rate_confirm before insert or update on public.rate_cards
for each row execute function public.guard_rate_confirm();
revoke execute on function public.guard_rate_confirm() from public, anon, authenticated;

create or replace function public.confirm_rates(p_hostel uuid) returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  if not (public.is_owner(p_hostel) or public.is_team()) then raise exception 'only the owner confirms rates'; end if;
  perform set_config('hz.rates_confirm', 'on', true);
  update public.rate_cards set confirmed_at = now() where hostel_id = p_hostel;
  get diagnostics n = row_count;
  perform set_config('hz.rates_confirm', 'off', true);
  return n;
end $$;

revoke execute on function public.confirm_rates(uuid) from public, anon;
grant execute on function public.confirm_rates(uuid) to authenticated;

-- ---------------------------------------------------------------- monthly push

create table if not exists public.rate_nudges (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  sent_at timestamptz not null default now()
);
alter table public.rate_nudges enable row level security;
-- No policies: only the daily job uses it.
revoke all on table public.rate_nudges from public, anon, authenticated;

create or replace function public.nudge_rates() returns int
language plpgsql security definer set search_path = ''
as $$
declare r record; n int := 0;
begin
  for r in
    select h.id, h.name,
      bool_or(c.confirmed_at is null) as never,
      min(c.confirmed_at) as oldest
    from public.hostels h join public.rate_cards c on c.hostel_id = h.id
    where h.status = 'live'
    group by h.id, h.name
  loop
    -- Monthly (a little slack for the job's start time).
    if (r.never or r.oldest < now() - interval '30 days')
       and not exists (select 1 from public.rate_nudges x where x.hostel_id = r.id and x.sent_at > now() - interval '29 days 23 hours') then
      perform public.notify_owner(r.id, 'Are your rates still right?',
        'Confirm the prices at ' || r.name || ' in Today. Tenants see when you last did.',
        jsonb_build_object('screen', 'oToday', 'kind', 'rates'));
      insert into public.rate_nudges (hostel_id, sent_at) values (r.id, now())
      on conflict (hostel_id) do update set sent_at = now();
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

revoke execute on function public.nudge_rates() from public, anon, authenticated;

-- Daily at 10:15 India time (04:45 UTC), where pg_cron is on (it is, since B5).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-rates-nudge', '45 4 * * *', 'select public.nudge_rates()');
  end if;
end $$;
