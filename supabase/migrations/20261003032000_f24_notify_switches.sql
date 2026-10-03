-- F24 item 22: the Settings switches are kept on the profile and the server
-- honours them, plus "New free beds" alerts.
--   profiles.notify          {"hold": true, "rent": true, "beds": false}; the
--       user's own (Settings → Notifications).
--   profiles.searched_areas  the last areas the tenant picked in Where? (≤ 5).
--   push_outbox.kind         hold | rent | beds, or null for everything else
--       (always sent). Set by every queued push: from data.kind, or worked
--       out from where the push opens. A push of a kind the user switched off
--       is closed at once ("switched off"), never sent. Nobody gets a push
--       about something they did themselves.
--   New free beds: when a bed in a live hostel turns free, tenants with the
--       switch on who searched that area get one push, at most one a day each
--       (profiles.beds_alert_at). Never the hostel's own staff or residents.
-- send-push checks the switch again before sending (a switch turned off
-- after a push was queued). Runs after 20261003031000_f24_walk_in.sql. Safe to run again.

alter table public.profiles add column if not exists notify jsonb not null default '{"hold": true, "rent": true, "beds": false}';
alter table public.profiles add column if not exists searched_areas text[] not null default '{}';
alter table public.profiles add column if not exists beds_alert_at timestamptz;
alter table public.profiles drop constraint if exists profiles_notify;
alter table public.profiles add constraint profiles_notify check (jsonb_typeof(notify) = 'object');
alter table public.profiles drop constraint if exists profiles_searched_areas;
alter table public.profiles add constraint profiles_searched_areas check (cardinality(searched_areas) <= 5);

alter table public.push_outbox add column if not exists kind text;

-- The user's switch for [p_kind]; on unless they turned it off ("beds" is off unless turned on).
create or replace function public.wants_push(p_user text, p_kind text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select case when p_kind is null then true
    else coalesce((select (p.notify ->> p_kind)::boolean from public.profiles p where p.id = p_user), p_kind <> 'beds') end
$$;

create or replace function public.push_filter() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Never about your own action (the owner's own walk-in, their own repair…).
  if public.uid() is not null and new.user_id = public.uid() then return null; end if;
  -- A complaint raised by marking a thing not working (4zz1) isn't pushed again.
  if current_setting('hz.item_complaint', true) = 'on' and new.title like 'New complaint:%' then return null; end if;
  new.kind := coalesce(new.kind, new.data ->> 'kind', case
    when new.data ->> 'screen' in ('holds', 'hold') then 'hold'
    when new.title like 'New hold on bed%' then 'hold'
    when new.data ->> 'screen' = 'rPay' then 'rent'
  end);
  if new.kind not in ('hold', 'rent', 'beds') then new.kind := null; end if;
  if not public.wants_push(new.user_id, new.kind) then
    new.sent_at := now();
    new.error := 'switched off';
  end if;
  return new;
end $$;

drop trigger if exists push_filter on public.push_outbox;
create trigger push_filter before insert on public.push_outbox
for each row execute function public.push_filter();

-- "New free beds": a bed turned free in a live hostel.
create or replace function public.free_bed_alert() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare h record; label text;
begin
  if new.state <> 'free' or (tg_op = 'UPDATE' and old.state = 'free') then return new; end if;
  select x.id, x.name, x.area into h from public.hostels x where x.id = new.hostel_id and x.status = 'live';
  if h.id is null then return new; end if;
  select coalesce(r.label, r.number::text) || '-' || new.letter into label from public.rooms r where r.id = new.room_id;
  with picked as (
    update public.profiles p set beds_alert_at = now()
    where coalesce((p.notify ->> 'beds')::boolean, false)
      and h.area = any (p.searched_areas)
      and (p.beds_alert_at is null or p.beds_alert_at <= now() - interval '1 day')
      and not exists (select 1 from public.hostel_staff s where s.hostel_id = h.id and s.user_id = p.id)
      and not exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = p.id and s.left_on is null)
    returning p.id
  )
  insert into public.push_outbox (user_id, title, body, data, kind)
  select picked.id, 'A bed is free in ' || h.area,
    h.name || ': bed ' || coalesce(label, new.letter) || ' is free now. Hold it free for 1 hour on Hostelzy.',
    jsonb_build_object('screen', 'detail', 'hostel', h.id, 'kind', 'beds'), 'beds'
  from picked;
  return new;
end $$;

drop trigger if exists free_bed_alert on public.beds;
create trigger free_bed_alert after insert or update of state on public.beds
for each row execute function public.free_bed_alert();

revoke execute on function public.push_filter(), public.free_bed_alert(), public.wants_push(text, text) from public, anon, authenticated;
