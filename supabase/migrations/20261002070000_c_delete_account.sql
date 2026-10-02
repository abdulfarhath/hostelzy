-- C: delete my account. The app confirms with Google first, calls this, then
-- deletes the Firebase user. Removes the person, keeps what others need
-- (an owner's payment and stay records, reviews) without their identity.
-- Safe to run again.

-- Payments: the deletion may detach the payer (nothing else changes).
create or replace function public.guard_payment() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
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
    if new.status not in ('pending', 'waiting', 'cancelled') then raise exception 'only the owner confirms a payment'; end if;
    if new.confirmed_by is distinct from old.confirmed_by or new.confirmed_at is distinct from old.confirmed_at then raise exception 'not allowed'; end if;
  end if;
  return new;
end $$;

-- Reviews: the deletion may change only who wrote it ("Former resident").
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if public.is_team() then return new; end if;
  if current_setting('hz.deleting', true) = 'on' and new.author_id = 'deleted' and new.author_name = 'Former resident'
     and (to_jsonb(new) - 'author_id' - 'author_name') = (to_jsonb(old) - 'author_id' - 'author_name') then
    return new;
  end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  new.replied_at := now();
  return new;
end $$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = ''
as $$
declare u text := public.uid();
begin
  if u is null then raise exception 'sign in first'; end if;
  if exists (select 1 from public.hostel_staff s join public.hostels h on h.id = s.hostel_id
             where s.user_id = u and s.role = 'owner' and h.status <> 'draft') then
    raise exception 'Owners: ask Hostelzy to close or hand over your hostel first.';
  end if;
  perform set_config('hz.deleting', 'on', true);

  -- open holds end now (their beds are freed by the hold triggers)
  update public.holds set status = 'released' where tenant_id = u and status in ('waiting', 'held');
  update public.holds set tenant_id = 'deleted' where tenant_id = u;
  update public.enquiries set tenant_id = 'deleted', name = 'Deleted user', phone = '', msg = '' where tenant_id = u;
  update public.reviews set author_id = 'deleted', author_name = 'Former resident' where author_id = u;
  update public.complaints set author_id = 'deleted' where author_id = u;
  update public.payments set payer_id = 'deleted' where payer_id = u;
  update public.fair_reports set reporter_id = 'deleted' where reporter_id = u;
  update public.stays set user_id = null where user_id = u;
  delete from public.move_requests where user_id = u;
  delete from public.push_tokens where user_id = u;
  delete from public.hostel_staff where user_id = u;
  delete from public.profiles where id = u;
end $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
