-- F24 item 9: "Still N free beds?" and "Do your room layouts still match?"
-- saved on the server, with a push to staff who haven't confirmed.
--   beds.confirmed_at      the owner's "Yes, all free" (the app writes it for
--       every bed of the hostel; tenants read the newest one as "confirmed by
--       the owner X days ago"). Only the server's clock counts: whatever the
--       app sends, the time stored is now().
--   confirm_layouts(p_hostel)     the owner's "All still correct": every published
--       layout of the hostel gets confirmed_at = now() (staff or team).
--   nudge_confirmations()  daily (pg_cron): a push to the hostel's owner and
--       managers when the free beds weren't confirmed for 3 days (at most one
--       every 3 days), and when a layout wasn't confirmed for 90 days (at most
--       one every 30 days).
-- Safe to run again.

-- ---------------------------------------------------------------- beds

create or replace function public.guard_bed_confirm() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or public.is_server() then return new; end if;
  if new.confirmed_at is distinct from old.confirmed_at then
    -- A confirmation is "now", never a date the phone picks; it can't be cleared.
    new.confirmed_at := case when new.confirmed_at is null then old.confirmed_at else now() end;
  end if;
  return new;
end $$;

drop trigger if exists guard_bed_confirm on public.beds;
create trigger guard_bed_confirm before update of confirmed_at on public.beds
for each row execute function public.guard_bed_confirm();
revoke execute on function public.guard_bed_confirm() from public, anon, authenticated;

-- ---------------------------------------------------------------- layouts

create or replace function public.confirm_layouts(p_hostel uuid) returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or managers confirm its layouts'; end if;
  update public.layouts set confirmed_at = now() where hostel_id = p_hostel and stage = 'published';
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.confirm_layouts(uuid) from public, anon;
grant execute on function public.confirm_layouts(uuid) to authenticated;

-- ---------------------------------------------------------------- reminders

create table if not exists public.hostel_nudges (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  kind text not null check (kind in ('beds', 'layouts')),
  sent_at timestamptz not null default now(),
  primary key (hostel_id, kind)
);
alter table public.hostel_nudges enable row level security;
-- No policies: only the daily job uses it.
revoke all on table public.hostel_nudges from public, anon, authenticated;

create or replace function public.nudge_confirmations() returns int
language plpgsql security definer set search_path = ''
as $$
declare r record; n int := 0;
begin
  for r in
    select h.id, h.name,
      (select count(*)::int from public.beds b where b.hostel_id = h.id and b.state = 'free') as free,
      (select max(b.confirmed_at) from public.beds b where b.hostel_id = h.id) as beds_at,
      (select min(coalesce(l.confirmed_at, l.updated_at)) from public.layouts l where l.hostel_id = h.id and l.stage = 'published') as layouts_at
    from public.hostels h
    where h.status = 'live' and exists (select 1 from public.beds b where b.hostel_id = h.id)
  loop
    -- Every 3 days (a little slack for the job's start time).
    if (r.beds_at is null or r.beds_at < now() - interval '3 days')
       and not exists (select 1 from public.hostel_nudges x where x.hostel_id = r.id and x.kind = 'beds' and x.sent_at > now() - interval '71 hours') then
      perform public.notify_staff(r.id,
        'Still ' || r.free || ' free ' || case when r.free = 1 then 'bed' else 'beds' end || '?',
        'Confirm the free beds at ' || r.name || ' in Today. Fresh beds rank higher.',
        '{"screen":"oToday"}');
      insert into public.hostel_nudges (hostel_id, kind, sent_at) values (r.id, 'beds', now())
      on conflict (hostel_id, kind) do update set sent_at = now();
      n := n + 1;
    end if;
    if r.layouts_at is not null and r.layouts_at < now() - interval '90 days'
       and not exists (select 1 from public.hostel_nudges x where x.hostel_id = r.id and x.kind = 'layouts' and x.sent_at > now() - interval '30 days') then
      perform public.notify_staff(r.id, 'Do your room layouts still match?',
        'It''s been 3 months. Check that beds, fans, AC and windows at ' || r.name || ' are where the layouts show them.',
        '{"screen":"oToday"}');
      insert into public.hostel_nudges (hostel_id, kind, sent_at) values (r.id, 'layouts', now())
      on conflict (hostel_id, kind) do update set sent_at = now();
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

revoke execute on function public.nudge_confirmations() from public, anon, authenticated;

-- Daily at 10:00 India time (04:30 UTC), where pg_cron is on (it is, since B5).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-confirm-nudge', '30 4 * * *', 'select public.nudge_confirmations()');
  end if;
end $$;
