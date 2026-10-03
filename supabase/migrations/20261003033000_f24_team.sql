-- F24 item 29: the app's team mode reads real rows.
--   team_members            the Hostelzy team, as the app's Team members list
--       shows it. A team account appears (Active) the first time it opens
--       team tools (team_hello). "Send invite" in the app adds a pending row
--       by name and number; it turns Active when that person, signed in with
--       the same number, opens team tools. Who is on the team is still the
--       Firebase `team` claim (GitHub → Actions → Team member); this table
--       never gives access.
--   team_tracker()          one row per hostel for the onboarding tracker:
--       its stage (hostel_leads.stage, then live / trial / paying from the
--       hostel and its plan), the next step, and when the trial ends.
-- Team only. Runs after 20261003032000_f24_notify_switches.sql. Safe to run again.

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  user_id text unique,
  name text not null default '',
  phone text not null default '',
  email text not null default '',
  role text not null default 'Everything' check (role in ('Everything', 'Visits', 'Layouts', 'Payments')),
  joined_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.team_members enable row level security;
drop policy if exists "team only" on public.team_members;
create policy "team only" on public.team_members for all using (public.is_team()) with check (public.is_team());

-- The signed-in team account says hello: its row is made (or a pending
-- invite with its number is matched) and marked Active.
create or replace function public.team_hello() returns void
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); p record; inv uuid;
begin
  if me is null or not public.is_team() then raise exception 'for the Hostelzy team only'; end if;
  select x.name, x.email, right(regexp_replace(coalesce(x.phone, ''), '\D', '', 'g'), 10) as phone into p from public.profiles x where x.id = me;
  if exists (select 1 from public.team_members t where t.user_id = me) then
    update public.team_members set joined_at = coalesce(joined_at, now()),
      name = case when name = '' then coalesce(p.name, '') else name end,
      email = coalesce(nullif(p.email, ''), email),
      phone = case when phone = '' then coalesce(p.phone, '') else phone end
    where user_id = me;
    return;
  end if;
  select t.id into inv from public.team_members t
  where t.user_id is null and t.phone <> '' and t.phone = coalesce(p.phone, '') order by t.created_at limit 1;
  if inv is not null then
    update public.team_members set user_id = me, joined_at = now(), email = coalesce(p.email, '') where id = inv;
  else
    insert into public.team_members (user_id, name, phone, email, joined_at)
    values (me, coalesce(p.name, ''), coalesce(p.phone, ''), coalesce(p.email, ''), now());
  end if;
end $$;

create or replace function public.team_tracker()
returns table (hostel_id uuid, name text, area text, stage int, next_step text, trial_ends date)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'for the Hostelzy team only'; end if;
  return query
  select h.id, h.name, h.area,
    case
      when h.status = 'live' and o.status in ('active', 'overdue', 'paused') then 6
      when h.status = 'live' and o.hostel_id is not null then 5
      when h.status = 'live' then 4
      else case coalesce(l.stage, 'lead') when 'visited' then 1 when 'signed_up' then 2 when 'data_complete' then 3 else 0 end
    end,
    coalesce(l.next_step, ''),
    o.trial_ends
  from public.hostels h
  left join public.hostel_leads l on l.hostel_id = h.id
  left join public.owner_plans o on o.hostel_id = h.id
  order by h.created_at;
end $$;

revoke execute on function public.team_hello(), public.team_tracker() from public, anon;
grant execute on function public.team_hello(), public.team_tracker() to authenticated;
