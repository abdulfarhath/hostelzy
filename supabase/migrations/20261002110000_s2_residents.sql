-- S2: the owner's resident list lives on the server (public.stays).
--   1. A current stay books its bed; moving out (left_on) frees it.
--   2. Approving an invite sign-up links the owner's own unconfirmed entry
--      with the same phone (instead of adding a second one).
-- Safe to run again.

create or replace function public.stay_marks_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.bed_id is not null and (new.bed_id is distinct from old.bed_id or (new.left_on is not null and old.left_on is null)) then
    update public.beds b set state = 'free'
    where b.id = old.bed_id
      and not exists (select 1 from public.stays s where s.bed_id = old.bed_id and s.id <> new.id and s.left_on is null)
      and not exists (select 1 from public.holds h where h.bed_id = old.bed_id and h.status in ('waiting', 'held', 'booked'));
  end if;
  if new.bed_id is not null and new.left_on is null then
    update public.beds set state = 'booked' where id = new.bed_id;
  end if;
  return new;
end $$;

drop trigger if exists stay_marks_bed on public.stays;
create trigger stay_marks_bed after insert or update of bed_id, left_on on public.stays
for each row execute function public.stay_marks_bed();
revoke execute on function public.stay_marks_bed() from public, anon, authenticated;

create or replace function public.decide_signup(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare g record; s_id uuid;
begin
  select * into g from public.invite_signups where id = p_id and status = 'pending';
  if g is null then raise exception 'already decided'; end if;
  if not (public.is_staff(g.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can decide'; end if;
  update public.invite_signups set status = case when p_approve then 'approved' else 'rejected' end where id = p_id;
  if p_approve then
    -- The owner may already have added them (same phone, not yet confirmed).
    select id into s_id from public.stays
    where hostel_id = g.hostel_id and phone = g.phone and user_id is null and not confirmed and left_on is null
    order by joined_on desc limit 1;
    if s_id is not null then
      update public.stays set user_id = g.user_id, confirmed = true where id = s_id;
    else
      insert into public.stays (hostel_id, user_id, name, phone, confirmed) values (g.hostel_id, g.user_id, g.name, g.phone, true);
    end if;
    insert into public.push_outbox (user_id, title, body, data) values (g.user_id, 'You’re in', 'Your owner approved you. Open Hostelzy to see your stay.', '{"screen":"rHome"}');
  end if;
end $$;

-- The owner's resident list updates live (RLS still decides who hears what).
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here; skipping.';
    return;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'stays') then
    alter publication supabase_realtime add table public.stays;
  end if;
end $$;
