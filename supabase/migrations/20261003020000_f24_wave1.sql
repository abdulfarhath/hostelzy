-- F24 Wave 1: electricity by meter, Trusted tenant on the server (level,
-- first pick of new free beds, "Trusted tenant" on hold requests) and photos
-- on Fair Play cases.
--   meter_readings                 one "Now" reading per room per month. Staff
--       save them with save_meter(hostel, month, ₹ per unit, rows); units since
--       last month are split between the residents in the room. Residents read
--       their own room's rows; staff their hostel's.
--   tenant_level(user) / my_level()  none | member | trusted, from the server:
--       Member (profiles.member) + 6 months in confirmed stays + no rent paid
--       more than 3 days after its due day.
--   holds.trusted                  set when the hold is placed; owners see it.
--   beds.freed_at                  when a bed turned free again (a resident left,
--       a booking ended). For 1 hour only Trusted tenants can hold it.
--   fair_cases.tenant_photo / owner_photo, bucket `case-photos`, case_photo():
--       the tenant's proof (attached by the team) and the owner's photo with
--       their reply. Private: the hostel's staff and the team.
-- The ₹ per unit is the owner's own number, not a Hostelzy amount.
-- Safe to run again.

-- ================================================================ electricity by meter

create table if not exists public.meter_readings (
  room_id uuid not null references public.rooms (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  reading int not null check (reading >= 0),
  rate numeric(6, 2) not null check (rate > 0 and rate <= 100),
  units int,                 -- since last month's reading (null: first reading)
  people int,                -- residents in the room when saved
  each_amt int,              -- ₹ each, rounded up
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  primary key (room_id, month)
);
alter table public.meter_readings enable row level security;
drop policy if exists "read meter readings" on public.meter_readings;
create policy "read meter readings" on public.meter_readings for select using (
  public.is_staff(hostel_id) or public.is_team()
  or exists (select 1 from public.stays s join public.beds b on b.id = s.bed_id
             where s.user_id = public.uid() and s.confirmed and s.left_on is null and b.room_id = meter_readings.room_id)
);
-- Writes go through save_meter only.

-- rows: [{"room": 204, "reading": 1940}, …] (room = the room's number).
create or replace function public.save_meter(p_hostel uuid, p_month date, p_rate numeric, p_rows jsonb) returns int
language plpgsql security definer set search_path = ''
as $$
declare
  m date := date_trunc('month', p_month)::date;
  e jsonb; rm record; prev int; u int; ppl int; amt int; n int := 0; old_each int; hname text;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner or managers add meter readings'; end if;
  if p_rate is null or p_rate <= 0 or p_rate > 100 then raise exception 'type the ₹ per unit'; end if;
  select name into hname from public.hostels where id = p_hostel;
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if (e ->> 'reading') is null then continue; end if;
    select id, coalesce(label, number::text) as label into rm from public.rooms where hostel_id = p_hostel and number = (e ->> 'room')::int;
    if rm.id is null then raise exception 'room % isn''t in this hostel', e ->> 'room'; end if;
    select reading into prev from public.meter_readings where room_id = rm.id and month < m order by month desc limit 1;
    if prev is not null and (e ->> 'reading')::int < prev then
      raise exception 'room %: the reading is lower than last month''s (%)', rm.label, prev;
    end if;
    u := case when prev is null then null else (e ->> 'reading')::int - prev end;
    select count(*) into ppl from public.stays s join public.beds b on b.id = s.bed_id where b.room_id = rm.id and s.left_on is null;
    amt := case when u is null or ppl = 0 then null else ceil(u * p_rate / ppl)::int end;
    select each_amt into old_each from public.meter_readings where room_id = rm.id and month = m;
    insert into public.meter_readings (room_id, hostel_id, month, reading, rate, units, people, each_amt)
    values (rm.id, p_hostel, m, (e ->> 'reading')::int, p_rate, u, ppl, amt)
    on conflict (room_id, month) do update set reading = excluded.reading, rate = excluded.rate, units = excluded.units,
      people = excluded.people, each_amt = excluded.each_amt, created_by = public.uid(), created_at = now();
    -- The room's residents hear about a new or changed amount.
    if amt is not null and amt is distinct from old_each then
      insert into public.push_outbox (user_id, title, body, data)
      select s.user_id, 'Electricity for ' || to_char(m, 'FMMonth') || ': ₹' || amt,
        u || ' units ÷ ' || ppl || ' · ₹' || trim(to_char(p_rate, 'FM999990.##')) || '/unit. It’s on your rent in Hostelzy.', '{"screen":"rPay"}'::jsonb
      from public.stays s join public.beds b on b.id = s.bed_id
      where b.room_id = rm.id and s.left_on is null and s.user_id is not null and s.confirmed;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke execute on function public.save_meter(uuid, date, numeric, jsonb) from public, anon;
grant execute on function public.save_meter(uuid, date, numeric, jsonb) to authenticated;

-- ================================================================ Trusted tenant on the server

-- Rent paid on time: a confirmed rent payment counts as late when it was made
-- more than 3 days after that month's due day (the joining day, or the 1st).
create or replace function public.tenant_level(u text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare mem boolean; days int; late int; lv text;
begin
  select coalesce(p.member, false) into mem from public.profiles p where p.id = u;
  select coalesce(sum(greatest(0, coalesce(s.left_on, (now() at time zone 'Asia/Kolkata')::date) - s.joined_on)), 0) into days
  from public.stays s where s.user_id = u and s.confirmed;
  select count(distinct date_trunc('month', p.created_at)) into late
  from public.payments p join public.stays s on s.id = p.stay_id join public.hostels h on h.id = p.hostel_id
  where p.payer_id = u and p.kind = 'rent' and p.status = 'paid'
    and (p.created_at at time zone 'Asia/Kolkata')::date > make_date(
      extract(year from p.created_at at time zone 'Asia/Kolkata')::int,
      extract(month from p.created_at at time zone 'Asia/Kolkata')::int,
      case when coalesce((h.terms ->> 'dueOnJoining')::boolean, true) then least(extract(day from s.joined_on)::int, 28) else 1 end) + 3;
  lv := case when not coalesce(mem, false) then 'none' when days / 30 >= 6 and late = 0 then 'trusted' else 'member' end;
  return jsonb_build_object('level', lv, 'months', days / 30, 'late', late);
end $$;

create or replace function public.my_level() returns jsonb
language sql stable security definer set search_path = ''
as $$ select public.tenant_level(public.uid()) $$;

revoke execute on function public.tenant_level(text) from public, anon, authenticated;
revoke execute on function public.my_level() from public, anon;
grant execute on function public.my_level() to authenticated;

alter table public.holds add column if not exists trusted boolean not null default false;
alter table public.beds add column if not exists freed_at timestamptz;

-- A bed turns free again (someone moved out, a booking ended): note when.
-- A hold that ends (held → free) doesn't count: that bed was already out there.
create or replace function public.bed_freed() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.state = 'free' and old.state in ('soon', 'booked') then new.freed_at := now(); end if;
  return new;
end $$;
drop trigger if exists bed_freed on public.beds;
create trigger bed_freed before update of state on public.beds for each row execute function public.bed_freed();

-- A new hold: the owner sees "Trusted tenant"; for its first hour a bed that
-- just turned free is for Trusted tenants only.
create or replace function public.hold_level() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare fa timestamptz;
begin
  new.trusted := public.tenant_level(new.tenant_id) ->> 'level' = 'trusted';
  select freed_at into fa from public.beds where id = new.bed_id;
  if not new.trusted and fa is not null and fa > now() - interval '1 hour' then
    raise exception 'Trusted tenants get the first hour on this bed. It opens to you at %',
      lower(to_char((fa + interval '1 hour') at time zone 'Asia/Kolkata', 'FMHH12:MI am'));
  end if;
  return new;
end $$;
drop trigger if exists hold_level on public.holds;
create trigger hold_level before insert on public.holds for each row execute function public.hold_level();

-- ================================================================ Fair Play case photos

alter table public.fair_cases add column if not exists tenant_photo text;
alter table public.fair_cases add column if not exists owner_photo text;

insert into storage.buckets (id, name, public) values ('case-photos', 'case-photos', false) on conflict (id) do nothing;

-- Path `<hostel_id>/<user id>/<name>.jpg` (the same shape as complaint photos).
drop policy if exists "hz upload case photos" on storage.objects;
create policy "hz upload case photos" on storage.objects for insert
  with check (bucket_id = 'case-photos' and split_part(name, '/', 2) = public.uid()
    and (public.is_staff(public.complaint_photo_hostel(name)) or public.is_team()));
drop policy if exists "hz read case photos" on storage.objects;
create policy "hz read case photos" on storage.objects for select
  using (bucket_id = 'case-photos' and (split_part(name, '/', 2) = public.uid() or public.is_team()
    or (public.is_staff(public.complaint_photo_hostel(name))
        and exists (select 1 from public.fair_cases c where c.hostel_id = public.complaint_photo_hostel(name) and (c.tenant_photo = name or c.owner_photo = name)))));

-- The owner adds a photo to their reply, while the case is open.
create or replace function public.case_photo(p_case uuid, p_path text) returns void
language plpgsql security definer set search_path = ''
as $$
declare c record;
begin
  select * into c from public.fair_cases where id = p_case;
  if c.id is null then raise exception 'that case isn''t there any more'; end if;
  if not (public.is_staff(c.hostel_id) or public.is_team()) then raise exception 'only this hostel''s owner or managers reply'; end if;
  if c.status in ('decided', 'closed') then raise exception 'this case is already closed'; end if;
  if public.complaint_photo_hostel(p_path) is distinct from c.hostel_id or split_part(p_path, '/', 2) <> public.uid() or p_path !~ '^[^/]+/[^/]+/[^/]+\.jpg$' then
    raise exception 'the photo must be your own, for this hostel';
  end if;
  perform set_config('hz.fixing', 'on', true);
  update public.fair_cases set owner_photo = p_path where id = p_case;
  perform set_config('hz.fixing', 'off', true);
end $$;

revoke execute on function public.case_photo(uuid, text) from public, anon;
grant execute on function public.case_photo(uuid, text) to authenticated;
