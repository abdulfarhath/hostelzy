-- S1: holds and bookings are made on the server by the app. One fix to the
-- payment guard: the payer may cancel or resend an open payment, but never
-- touch one that is already paid or cancelled. Safe to run again.

create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  -- C: account deletion may detach the payer (nothing else changes).
  if current_setting('hz.deleting', true) = 'on' and new.payer_id = 'deleted'
     and (to_jsonb(new) - 'payer_id') = (to_jsonb(old) - 'payer_id') then
    return new;
  end if;
  if new.hostel_id <> old.hostel_id or new.payer_id <> old.payer_id or new.kind <> old.kind or new.amount <> old.amount then
    raise exception 'payment details cannot change';
  end if;
  if public.is_staff(old.hostel_id) and old.payer_id <> public.uid() then
    if new.utr is distinct from old.utr or new.note <> old.note then raise exception 'only the payer edits the UTR'; end if;
    if old.status <> 'waiting' or new.status not in ('paid', 'missing') then raise exception 'owner confirms waiting payments only'; end if;
    new.confirmed_by := public.uid();
    new.confirmed_at := now();
  else
    if old.status in ('paid', 'cancelled') then raise exception 'this payment is closed'; end if;
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

-- A booked hold (advance confirmed) books its bed.
create or replace function public.hold_books_bed() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'booked' and old.status <> 'booked' then
    update public.beds set state = 'booked' where id = new.bed_id;
  end if;
  return new;
end $$;

drop trigger if exists hold_books_bed on public.holds;
create trigger hold_books_bed after update of status on public.holds
for each row execute function public.hold_books_bed();
revoke execute on function public.hold_books_bed() from public, anon, authenticated;
