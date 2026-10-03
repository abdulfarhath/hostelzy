-- F24 item 8: "Hold for a walk-in" on the server.
--   hold_walk_in(bed) → when it ends
--       The hostel's staff (or the team) keep a free (or free-soon) bed for
--       someone who walked in. The bed shows as held to every tenant, so
--       nobody can hold it on Hostelzy meanwhile. Like a free hold it ends
--       after 1 hour (DECISIONS F04) and the bed goes back to what it was.
--   release_walk_in(bed)  the same people end it early.
--   expire_walk_ins()     the server ends them; every minute with pg_cron,
--       and also whenever anyone holds a walk-in bed.
-- Runs after 20261003030000_f24_item_working.sql. Safe to run again.

alter table public.beds add column if not exists walk_in_until timestamptz;
alter table public.beds add column if not exists walk_in_before text;

create or replace function public.expire_walk_ins() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.beds set state = coalesce(walk_in_before, 'free'), walk_in_until = null, walk_in_before = null
  where walk_in_until is not null and walk_in_until <= now() and state = 'held';
  get diagnostics n = row_count;
  -- A bed that changed some other way keeps its state; just forget the walk-in.
  update public.beds set walk_in_until = null, walk_in_before = null
  where walk_in_until is not null and (walk_in_until <= now() or state <> 'held');
  return n;
end $$;

create or replace function public.hold_walk_in(p_bed uuid) returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare b record; until timestamptz := now() + interval '1 hour';
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  select x.id, x.hostel_id, x.state into b from public.beds x where x.id = p_bed;
  if b.id is null then raise exception 'that bed isn''t on Hostelzy'; end if;
  if not (public.is_staff(b.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or manager can hold a bed for a walk-in'; end if;
  perform public.expire_walk_ins();
  update public.beds set state = 'held', walk_in_before = state, walk_in_until = until
  where id = p_bed and state in ('free', 'soon')
    and not exists (select 1 from public.holds h where h.bed_id = p_bed and h.status in ('waiting', 'held'));
  if not found then raise exception 'that bed isn''t free any more'; end if;
  return until;
end $$;

create or replace function public.release_walk_in(p_bed uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare b record;
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  select x.id, x.hostel_id, x.walk_in_until into b from public.beds x where x.id = p_bed;
  if b.id is null then raise exception 'that bed isn''t on Hostelzy'; end if;
  if not (public.is_staff(b.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or manager can release it'; end if;
  update public.beds set state = coalesce(walk_in_before, 'free'), walk_in_until = null, walk_in_before = null
  where id = p_bed and walk_in_until is not null and state = 'held';
end $$;

revoke execute on function public.expire_walk_ins() from public, anon, authenticated;
revoke execute on function public.hold_walk_in(uuid), public.release_walk_in(uuid) from public, anon;
grant execute on function public.hold_walk_in(uuid), public.release_walk_in(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-expire-walk-ins', '* * * * *', 'select public.expire_walk_ins()');
  end if;
end $$;
