-- F24 item 13: "Your price is fixed". The deal a tenant books with is kept on
-- the server, so the owner and the tenant both see what was promised.
--   holds.deal   set by the server when a booking (advance hold) is placed:
--       {"on": [deal ids], "fee": monthly rent, "advance", "maintenance",
--        "notice"} from the hostel's rate card, terms and deals at that moment.
--       Deals don't apply when the hostel has 2+ strikes, when its plan is
--       overdue or paused, or when they cover the other room type. The app
--       turns it into the perks ("₹7,800 monthly · ₹2,000 advance · …").
--   stays.deal   copied from the tenant's booked hold at that hostel (60 days
--       before joining), so the owner's resident list and bed sheet show it.
-- Nobody can write either column from the app; only the team can correct one.
-- Safe to run again.

alter table public.holds add column if not exists deal jsonb;
alter table public.stays add column if not exists deal jsonb;

-- ---------------------------------------------------------------- the deal at booking time

create or replace function public.deal_for_bed(p_hostel uuid, p_bed uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  rm record;
  fee int;
  t jsonb;
  d record;
  paused boolean;
  on_ids text[] := '{}';
begin
  select r.ac, r.share, r.rent into rm from public.beds b join public.rooms r on r.id = b.room_id where b.id = p_bed and b.hostel_id = p_hostel;
  if not found then return null; end if;
  select c.rent into fee from public.rate_cards c where c.hostel_id = p_hostel and c.ac = rm.ac and c.share = rm.share;
  select coalesce(h.terms, '{}'::jsonb) into t from public.hostels h where h.id = p_hostel;
  select x.deals_on, x.target into d from public.deals x where x.hostel_id = p_hostel;
  paused := (select count(*) from public.strikes s where s.hostel_id = p_hostel) >= 2
    or exists (select 1 from public.owner_plans o where o.hostel_id = p_hostel and o.status in ('overdue', 'paused'));
  if d is not null and not paused and coalesce(array_length(d.deals_on, 1), 0) > 0
     and (coalesce(d.target, '') in ('', 'all') or (d.target = 'ac') = rm.ac) then
    on_ids := d.deals_on;
  end if;
  return jsonb_build_object(
    'on', to_jsonb(on_ids),
    'fee', coalesce(fee, rm.rent),
    'advance', coalesce((t ->> 'advance')::int, 3000),
    'maintenance', coalesce((t ->> 'maintenance')::int, 1000),
    'notice', coalesce((t ->> 'noticeDays')::int, 30),
    'at', now());
end $$;

revoke execute on function public.deal_for_bed(uuid, uuid) from public, anon, authenticated;

-- Bookings lock the deal; free holds don't carry one. The app never sets it.
create or replace function public.hold_deal() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.deal := case when new.opt = 'advance' then public.deal_for_bed(new.hostel_id, new.bed_id) end;
  elsif not (public.is_team() or public.is_server()) then
    new.deal := old.deal;
  end if;
  return new;
end $$;

drop trigger if exists hold_deal on public.holds;
create trigger hold_deal before insert or update on public.holds
for each row execute function public.hold_deal();
revoke execute on function public.hold_deal() from public, anon, authenticated;

-- ---------------------------------------------------------------- the stay keeps it

create or replace function public.stay_deal() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and not (public.is_team() or public.is_server()) then
    new.deal := old.deal;
  elsif tg_op = 'INSERT' and not (public.is_team() or public.is_server()) then
    new.deal := null;
  end if;
  if new.deal is null and (tg_op = 'INSERT' or new.user_id is distinct from old.user_id) then
    select x.deal into new.deal
    from public.holds x left join public.profiles p on p.id = x.tenant_id
    where x.hostel_id = new.hostel_id and x.status = 'booked' and x.deal is not null
      and ((length(new.phone) = 10 and p.phone = new.phone) or (new.user_id is not null and x.tenant_id = new.user_id))
      and x.started_at >= new.joined_on - interval '60 days' and x.started_at < new.joined_on + interval '2 days'
    order by x.started_at desc
    limit 1;
  end if;
  return new;
end $$;

drop trigger if exists stay_deal on public.stays;
create trigger stay_deal before insert or update on public.stays
for each row execute function public.stay_deal();
revoke execute on function public.stay_deal() from public, anon, authenticated;
