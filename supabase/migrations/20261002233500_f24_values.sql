-- F24 item 6: real values instead of made-up ones on the hostel page and in
-- the ranking.
--   enquiries.contacted_at, holds.decided_at   set by the server when the
--       owner first marks an enquiry contacted / answers a hold.
--   hostel_signals() → per live hostel, counts only (anyone may read):
--       reply_minutes / reply_n   median minutes to reply over the last 60
--           days (enquiries contacted, holds answered); shown once n ≥ 3.
--       complaints_30d, residents the hostel's complaints in 30 days and its
--           current residents (the ranking's complaints factor).
--       photos, rooms, layouts      listing completeness.
-- Safe to run again.

alter table public.enquiries add column if not exists contacted_at timestamptz;
alter table public.holds add column if not exists decided_at timestamptz;

create or replace function public.stamp_reply() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'enquiries' then
    if new.contacted and not coalesce(old.contacted, false) and new.contacted_at is null then new.contacted_at := now(); end if;
  elsif new.status is distinct from old.status and old.status = 'waiting' and new.decided_at is null then
    new.decided_at := now();
  end if;
  return new;
end $$;

drop trigger if exists stamp_reply on public.enquiries;
create trigger stamp_reply before update of contacted on public.enquiries for each row execute function public.stamp_reply();
drop trigger if exists stamp_reply on public.holds;
create trigger stamp_reply before update of status on public.holds for each row execute function public.stamp_reply();
revoke execute on function public.stamp_reply() from public, anon, authenticated;

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
    (select count(*)::int from public.complaints c where c.hostel_id = h.id and c.created_at > now() - interval '30 days'),
    (select count(*)::int from public.stays s where s.hostel_id = h.id and s.left_on is null),
    (select count(*)::int from public.hostel_photos p where p.hostel_id = h.id),
    (select count(*)::int from public.rooms r where r.hostel_id = h.id),
    (select count(*)::int from public.layouts l where l.hostel_id = h.id and l.stage = 'published')
  from public.hostels h left join speed sp on sp.hostel_id = h.id
  where h.status = 'live'
$$;

grant execute on function public.hostel_signals() to anon, authenticated;
