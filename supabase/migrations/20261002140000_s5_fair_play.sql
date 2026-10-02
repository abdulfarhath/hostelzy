-- S5: Fair Play from the app.
--   1. The owner's reply to a case the team sent back ("waiting") returns it
--      to the team ("new"). Owners still change nothing else.
--   2. fix_case(): within 48 hours the owner marks the resident Via Hostelzy;
--      the case closes with no strike.
--   3. strike_counts(): how many strikes each live hostel has, for everyone
--      (2 hide deals, 3 hide the listing, and ranking uses them).
-- Safe to run again.

create or replace function public.guard_case() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() or current_setting('hz.fixing', true) = 'on' then return new; end if;
  if old.status = 'waiting' and new.status = 'new' and new.owner_reply is not null then
    if (to_jsonb(new) - 'owner_reply' - 'status') <> (to_jsonb(old) - 'owner_reply' - 'status') then
      raise exception 'owners can only reply; the Hostelzy team decides';
    end if;
    return new;
  end if;
  if (to_jsonb(new) - 'owner_reply') <> (to_jsonb(old) - 'owner_reply') then
    raise exception 'owners can only reply; the Hostelzy team decides';
  end if;
  return new;
end $$;

create or replace function public.fix_case(p_case uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record;
begin
  select * into c from public.fair_cases where id = p_case;
  if c is null or not public.is_staff(c.hostel_id) then raise exception 'only this hostel''s staff can fix it'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is closed'; end if;
  if c.created_at < now() - interval '48 hours' then raise exception 'the 48 hours are over; reply instead'; end if;
  if c.resident is null then raise exception 'there is no resident to fix; reply instead'; end if;
  update public.stays set via = 'hz', late_days = 0
  where hostel_id = c.hostel_id and left_on is null and (name = c.resident or bed_id in (
    select b.id from public.beds b join public.rooms r on r.id = b.room_id
    where b.hostel_id = c.hostel_id and coalesce(r.label, r.number::text) || '-' || b.letter = c.resident));
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set status = 'closed', decision = 'Fixed by the owner within 48 h · no strike' where id = p_case;
  perform set_config('hz.fixing', 'off', true);
end $$;

create or replace function public.strike_counts() returns table (hostel_id uuid, n int)
language sql stable security definer set search_path = ''
as $$
  select s.hostel_id, count(*)::int from public.strikes s
  where public.is_live(s.hostel_id) or public.is_staff(s.hostel_id) or public.is_team()
  group by s.hostel_id
$$;

revoke execute on function public.fix_case(uuid) from public, anon;
grant execute on function public.fix_case(uuid) to authenticated;
grant execute on function public.strike_counts() to anon, authenticated;

-- Cases update live for the owner and the team (RLS decides who hears what).
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'fair_cases') then
    alter publication supabase_realtime add table public.fair_cases;
  end if;
end $$;
