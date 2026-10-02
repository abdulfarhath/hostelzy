-- F24 item 5: notice, moving to another bed and moving out on the server,
-- and the advance refund tracked to the end.
--   give_notice(last_day, reason) → id       a resident; the owner is told.
--   ask_move(to_bed) → id                    a resident; a free bed in the same hostel.
--   withdraw_move(id)                        the resident, while it's open.
--   answer_move(id, accept)                  staff: notice accepted → the bed shows
--       "free from <last day>"; a move accepted → the stay moves to the new bed
--       (its rent from the new room); the resident is told either way.
--   mark_leaving(stay, day)                  staff: the same as an accepted notice.
--   moved_out(stay, day)                     staff: the stay ends, the bed is free and
--       the refund (advance minus what the hostel keeps) is due in 7 days.
--   send_refund(stay, utr)                   staff: marked refunded with the UPI ref.
--   confirm_refund(stay, got)                the former resident: "Yes, I got it" or
--       "Not received" (the owner is told).
-- Safe to run again.

alter table public.stays add column if not exists leaving_on date;
alter table public.stays add column if not exists refund_amount int;
alter table public.stays add column if not exists refund_status text;
alter table public.stays add column if not exists refund_utr text;
alter table public.stays add column if not exists refund_sent_at timestamptz;
alter table public.stays drop constraint if exists stays_refund_status;
alter table public.stays add constraint stays_refund_status check (refund_status is null or refund_status in ('due', 'sent', 'received', 'not_received'));

alter table public.move_requests add column if not exists stay_id uuid references public.stays (id) on delete cascade;
alter table public.move_requests add column if not exists reason text not null default '';
alter table public.move_requests add column if not exists to_bed_id uuid references public.beds (id) on delete set null;
alter table public.move_requests add column if not exists decided_at timestamptz;

-- The caller's current confirmed stay.
create or replace function public.my_current_stay() returns public.stays
language sql stable security definer set search_path = ''
as $$ select * from public.stays s where s.user_id = public.uid() and s.confirmed and s.left_on is null order by s.joined_on desc limit 1 $$;

create or replace function public.tell_owners(h uuid, p_title text, p_body text) returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, p_title, p_body, '{"screen":"oToday"}'::jsonb from public.hostel_staff st where st.hostel_id = h and st.role = 'owner'
$$;

create or replace function public.tell_resident(s public.stays, p_title text, p_body text, p_screen text default 'rStay') returns void
language sql security definer set search_path = ''
as $$
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, p_title, p_body, jsonb_build_object('screen', p_screen) where s.user_id is not null
$$;

create or replace function public.give_notice(p_last_day date, p_reason text default '') returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.my_current_stay(); rid uuid;
begin
  if s.id is null then raise exception 'only residents give notice'; end if;
  if p_last_day is null or p_last_day < (now() at time zone 'Asia/Kolkata')::date then raise exception 'pick a last day from today on'; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and kind = 'vacate' and status = 'open';
  insert into public.move_requests (hostel_id, user_id, stay_id, kind, last_day, reason)
  values (s.hostel_id, public.uid(), s.id, 'vacate', p_last_day, left(trim(coalesce(p_reason, '')), 200)) returning id into rid;
  perform public.tell_owners(s.hostel_id, s.name || ' gave notice', 'Last day ' || to_char(p_last_day, 'FMDD Mon') || '. Accept it in Hostelzy.');
  return rid;
end $$;

create or replace function public.ask_move(p_to_bed uuid) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.my_current_stay(); b record; rid uuid;
begin
  if s.id is null then raise exception 'only residents ask to move'; end if;
  select x.id, x.hostel_id, coalesce(r.label, r.number::text) || '-' || x.letter as label into b
  from public.beds x join public.rooms r on r.id = x.room_id where x.id = p_to_bed;
  if b.id is null or b.hostel_id <> s.hostel_id then raise exception 'pick a bed in your hostel'; end if;
  if b.id = s.bed_id then raise exception 'that''s your bed now'; end if;
  if public.bed_busy(b.id) then raise exception 'bed % isn''t free', b.label; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and kind = 'swap' and status = 'open';
  insert into public.move_requests (hostel_id, user_id, stay_id, kind, to_bed, to_bed_id)
  values (s.hostel_id, public.uid(), s.id, 'swap', b.label, b.id) returning id into rid;
  perform public.tell_owners(s.hostel_id, s.name || ' asks to move to bed ' || b.label, 'Accept or say no in Hostelzy.');
  return rid;
end $$;

create or replace function public.withdraw_move(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.move_requests set status = 'withdrawn' where id = p_id and user_id = public.uid() and status = 'open';
  if not found then raise exception 'that request isn''t open any more'; end if;
end $$;

-- Notice accepted / marked: the bed shows "free from" the last day.
create or replace function public.set_leaving(s public.stays, p_day date) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.stays set leaving_on = p_day where id = s.id;
  if s.bed_id is not null then update public.beds set state = 'soon', free_from = p_day where id = s.bed_id; end if;
end $$;

create or replace function public.answer_move(p_id uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare m public.move_requests; s public.stays; nb record;
begin
  select * into m from public.move_requests where id = p_id;
  if m.id is null then raise exception 'that request isn''t there any more'; end if;
  if not (public.is_staff(m.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers answer it'; end if;
  if m.status <> 'open' then raise exception 'that request isn''t open any more'; end if;
  select * into s from public.stays where id = m.stay_id;
  if not p_accept then
    update public.move_requests set status = 'declined', decided_at = now() where id = p_id;
    perform public.tell_resident(s, case when m.kind = 'vacate' then 'Your notice needs a word' else 'Your move to bed ' || m.to_bed || ' wasn''t accepted' end,
      'Talk to your owner on WhatsApp.');
    return;
  end if;
  if m.kind = 'vacate' then
    perform public.set_leaving(s, m.last_day);
    perform public.tell_resident(s, 'Notice accepted', 'Your last day is ' || to_char(m.last_day, 'FMDD Mon') || '. Your refund shows in Hostelzy after you move out.');
  else
    if m.to_bed_id is null or public.bed_busy(m.to_bed_id) then raise exception 'bed % isn''t free any more', m.to_bed; end if;
    select r.rent into nb from public.beds b join public.rooms r on r.id = b.room_id where b.id = m.to_bed_id;
    update public.stays set bed_id = m.to_bed_id, rent = coalesce(nb.rent, rent) where id = s.id;
    perform public.tell_resident(s, 'You can move to bed ' || m.to_bed, 'New rent ' || coalesce(nb.rent, s.rent) || ' from next month.');
  end if;
  update public.move_requests set status = 'accepted', decided_at = now() where id = p_id;
end $$;

create or replace function public.staff_stay(p_stay uuid) returns public.stays
language plpgsql security definer set search_path = ''
as $$
declare s public.stays;
begin
  select * into s from public.stays where id = p_stay;
  if s.id is null then raise exception 'that resident isn''t there any more'; end if;
  if not (public.is_staff(s.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers do this'; end if;
  return s;
end $$;

create or replace function public.mark_leaving(p_stay uuid, p_day date) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay);
begin
  if s.left_on is not null then raise exception 'they''ve already moved out'; end if;
  if p_day is null then raise exception 'pick the last day'; end if;
  perform public.set_leaving(s, p_day);
  update public.move_requests set status = 'accepted', decided_at = now() where stay_id = s.id and kind = 'vacate' and status = 'open';
end $$;

create or replace function public.moved_out(p_stay uuid, p_day date default null) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay); kept int; amt int; d date := coalesce(p_day, (now() at time zone 'Asia/Kolkata')::date);
begin
  if s.left_on is not null then raise exception 'they''ve already moved out'; end if;
  select coalesce((h.terms ->> 'maintenance')::int, 0) into kept from public.hostels h where h.id = s.hostel_id;
  amt := greatest(coalesce(s.advance, 0) - coalesce(kept, 0), 0);
  update public.stays set left_on = d, leaving_on = coalesce(leaving_on, d), refund_amount = amt,
    refund_status = case when amt > 0 then 'due' else null end where id = s.id;
  if s.bed_id is not null then update public.beds set free_from = null where id = s.bed_id; end if;
  update public.move_requests set status = 'withdrawn' where stay_id = s.id and status = 'open';
  if amt > 0 then
    perform public.tell_resident(s, 'Your refund: ' || amt, 'Due by ' || to_char(d + 7, 'FMDD Mon') || '. Hostelzy asks you when it arrives.', 'rRefund');
  end if;
end $$;

create or replace function public.send_refund(p_stay uuid, p_utr text) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays := public.staff_stay(p_stay); u text := regexp_replace(coalesce(p_utr, ''), '\D', '', 'g');
begin
  if s.refund_status is null or s.refund_status not in ('due', 'not_received', 'sent') then raise exception 'there''s no refund due'; end if;
  if u !~ '^[0-9]{12}$' then raise exception 'the UPI reference is 12 digits'; end if;
  update public.stays set refund_status = 'sent', refund_utr = u, refund_sent_at = now() where id = s.id;
  perform public.tell_resident(s, 'Refund of ' || s.refund_amount || ' sent', 'UPI ref ' || u || '. Tell Hostelzy when you get it.', 'rRefund');
end $$;

create or replace function public.confirm_refund(p_stay uuid, p_got boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare s public.stays;
begin
  select * into s from public.stays where id = p_stay and user_id = public.uid();
  if s.id is null then raise exception 'that isn''t your stay'; end if;
  if s.refund_status <> 'sent' then raise exception 'your owner hasn''t marked it refunded yet'; end if;
  update public.stays set refund_status = case when p_got then 'received' else 'not_received' end where id = s.id;
  if not p_got then
    perform public.tell_owners(s.hostel_id, s.name || ' hasn''t got the refund', 'UPI ref ' || coalesce(s.refund_utr, '') || '. Check your bank and talk to them.');
  end if;
end $$;

revoke execute on function public.my_current_stay(), public.tell_owners(uuid, text, text), public.tell_resident(public.stays, text, text, text),
  public.set_leaving(public.stays, date), public.staff_stay(uuid) from public, anon, authenticated;
revoke execute on function public.give_notice(date, text), public.ask_move(uuid), public.withdraw_move(uuid), public.answer_move(uuid, boolean),
  public.mark_leaving(uuid, date), public.moved_out(uuid, date), public.send_refund(uuid, text), public.confirm_refund(uuid, boolean) from public, anon;
grant execute on function public.give_notice(date, text), public.ask_move(uuid), public.withdraw_move(uuid), public.answer_move(uuid, boolean),
  public.mark_leaving(uuid, date), public.moved_out(uuid, date), public.send_refund(uuid, text), public.confirm_refund(uuid, boolean) to authenticated;
