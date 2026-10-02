-- F21 W2: the tenant hears the owner's reply to a hold.
-- After the first hold the app asks for notifications "so the owner's reply
-- reaches you". Until now only staff got a push on a new hold; this sends the
-- tenant one when someone else (the owner or a manager) keeps or declines it.
-- Paid bookings already get "Payment confirmed" from push_on_change.

create or replace function public.push_hold_reply() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare bed text; hn text;
begin
  if new.status is distinct from old.status and new.status in ('held', 'released')
     and old.status = 'waiting' and public.uid() is distinct from new.tenant_id then
    select r.number || '-' || b.letter into bed from public.beds b join public.rooms r on r.id = b.room_id where b.id = new.bed_id;
    select h.name into hn from public.hostels h where h.id = new.hostel_id;
    insert into public.push_outbox (user_id, title, body, data) values (new.tenant_id,
      case when new.status = 'held' then 'Bed ' || coalesce(bed, '') || ' is kept for you' else 'Bed ' || coalesce(bed, '') || ' wasn’t kept' end,
      case when new.status = 'held' then coalesce(hn, 'The owner') || ' confirmed your hold. Go and see it.' else coalesce(hn, 'The owner') || ' couldn’t keep it. Pick another bed in Hostelzy.' end,
      '{"screen":"holds"}');
  end if;
  return new;
end $$;

drop trigger if exists push_hold_reply on public.holds;
create trigger push_hold_reply after update on public.holds for each row execute function public.push_hold_reply();
