-- F24 items 2 and 3: a real hostel onboarded end to end from the team's Add
-- hostel wizard, its owner's account linked, and rooms saved on the server.
--   save_hostel(id, jsonb) → id      the team: creates (null id) or updates a
--       draft: basics, rate card, the owner's number (hostel_leads) and rooms.
--   save_rooms(hostel, jsonb)        staff or the team: the hostel's rooms as
--       a list [{number, label, floor, share, ac, rent, bath}]. Adds and
--       changes rooms and beds; a room or bed with someone in it (a resident,
--       a hold or a booking) is never removed.
--   new_owner_invite(hostel, name, phone) → "OWN-XXXXXXXX"   the team; sent to
--       the owner on WhatsApp, works once, for 7 days.
--   join_as_owner(code) → hostel name   signed in with Google: becomes the
--       hostel's owner (a hostel has one owner account).
--   go_live(hostel)                  the team: rooms, a price for every room
--       type, the owner's account and 8 photos are there → live, "Visited by
--       Hostelzy" today, and the 30-day trial starts (owner_plans).
-- Safe to run again.

alter table public.hostels add column if not exists visited_on date;

create table if not exists public.owner_invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  name text not null default '',
  phone text not null default '',
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by text,
  used_at timestamptz
);
alter table public.owner_invites enable row level security;
drop policy if exists "team reads owner invites" on public.owner_invites;
create policy "team reads owner invites" on public.owner_invites for select using (public.is_team());
-- Writes go through the functions below only.

-- A bed someone is in: booked or held on the board, a live hold, or a resident.
create or replace function public.bed_busy(b uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.beds x where x.id = b and x.state <> 'free')
    or exists (select 1 from public.holds h where h.bed_id = b and h.status in ('waiting', 'held', 'booked'))
    or exists (select 1 from public.stays s where s.bed_id = b and s.left_on is null)
$$;

create or replace function public.save_rooms(p_hostel uuid, p_rooms jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare r jsonb; rid uuid; v_share int; v_number int; busy text; keep int[] := '{}';
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner, managers or the team change its rooms'; end if;
  if jsonb_typeof(coalesce(p_rooms, 'null')) <> 'array' then raise exception 'send the rooms as a list'; end if;
  for r in select * from jsonb_array_elements(p_rooms) loop
    v_number := (r ->> 'number')::int;
    v_share := (r ->> 'share')::int;
    if v_number is null then raise exception 'every room needs a number'; end if;
    if v_share is null or v_share not between 1 and 8 then raise exception 'room % : 1 to 8 beds', v_number; end if;
    if v_number = any(keep) then raise exception 'room % is in the list twice', v_number; end if;
    keep := keep || v_number;
    insert into public.rooms (hostel_id, number, label, floor, share, ac, rent, bath)
    values (p_hostel, v_number, nullif(trim(coalesce(r ->> 'label', '')), ''), coalesce((r ->> 'floor')::int, v_number / 100), v_share,
      coalesce((r ->> 'ac')::boolean, false), greatest(coalesce((r ->> 'rent')::int, 0), 0), coalesce(r ->> 'bath', 'Shared'))
    on conflict (hostel_id, number) do update set label = excluded.label, floor = excluded.floor, share = excluded.share,
      ac = excluded.ac, rent = excluded.rent, bath = excluded.bath
    returning id into rid;
    -- Beds A, B, C… up to the share; extra letters go only when nobody is in them.
    select string_agg(b.letter, ', ' order by b.letter) into busy from public.beds b
    where b.room_id = rid and ascii(b.letter) - 64 > v_share and public.bed_busy(b.id);
    if busy is not null then raise exception 'room %: bed % has someone in it', coalesce(nullif(r ->> 'label', ''), v_number::text), busy; end if;
    delete from public.beds b where b.room_id = rid and ascii(b.letter) - 64 > v_share;
    insert into public.beds (hostel_id, room_id, letter)
    select p_hostel, rid, chr(64 + k) from generate_series(1, v_share) k
    where not exists (select 1 from public.beds b where b.room_id = rid and b.letter = chr(64 + k));
  end loop;
  -- Rooms left out are removed, unless someone is in one of their beds.
  select string_agg(coalesce(x.label, x.number::text), ', ' order by x.number) into busy from public.rooms x
  where x.hostel_id = p_hostel and not (x.number = any(keep))
    and exists (select 1 from public.beds b where b.room_id = x.id and public.bed_busy(b.id));
  if busy is not null then raise exception 'room % has someone in it', busy; end if;
  delete from public.rooms x where x.hostel_id = p_hostel and not (x.number = any(keep));
end $$;

create or replace function public.save_hostel(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare hid uuid := p_id; v_name text := trim(coalesce(p ->> 'name', '')); v_slug text; st text; rc jsonb;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team adds hostels'; end if;
  if v_name = '' then raise exception 'add the hostel name'; end if;
  if hid is null then
    v_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
    if v_slug = '' then v_slug := 'hostel'; end if;
    while exists (select 1 from public.hostels where slug = v_slug) loop
      v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
    end loop;
    insert into public.hostels (slug, name, gender, area, status) values (v_slug, v_name, coalesce(p ->> 'gender', 'Men'), coalesce(p ->> 'area', ''), 'draft')
    returning id into hid;
  end if;
  select status into st from public.hostels where id = hid;
  if st is null then raise exception 'that hostel isn''t on Hostelzy'; end if;
  update public.hostels set
    name = v_name,
    gender = coalesce(p ->> 'gender', gender),
    area = coalesce(p ->> 'area', area),
    owner_name = coalesce(trim(p ->> 'owner_name'), owner_name),
    food = coalesce((p ->> 'food')::boolean, food),
    ac = coalesce((p ->> 'ac')::boolean, ac),
    only_ac = coalesce((p ->> 'only_ac')::boolean, only_ac),
    tags = coalesce(array(select jsonb_array_elements_text(p -> 'tags')), tags),
    terms = coalesce(p -> 'terms', terms),
    lat = coalesce((p ->> 'lat')::double precision, lat),
    lng = coalesce((p ->> 'lng')::double precision, lng)
  where id = hid;
  insert into public.hostel_leads (hostel_id, owner_phone, stage)
  values (hid, regexp_replace(coalesce(p ->> 'owner_phone', ''), '\D', '', 'g'), 'signed_up')
  on conflict (hostel_id) do update set owner_phone = case when excluded.owner_phone <> '' then excluded.owner_phone else public.hostel_leads.owner_phone end,
    stage = case when public.hostel_leads.stage in ('lead', 'visited') then 'signed_up' else public.hostel_leads.stage end, updated_at = now();
  if p ? 'rates' then
    delete from public.rate_cards where hostel_id = hid;
    for rc in select * from jsonb_array_elements(p -> 'rates') loop
      insert into public.rate_cards (hostel_id, ac, share, rent) values (hid, (rc ->> 'ac')::boolean, (rc ->> 'share')::int, (rc ->> 'rent')::int);
    end loop;
  end if;
  if p ? 'rooms' then perform public.save_rooms(hid, p -> 'rooms'); end if;
  return hid;
end $$;

create or replace function public.new_owner_invite(h uuid, p_name text, p_phone text) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not public.is_team() then raise exception 'only the Hostelzy team links owners'; end if;
  if not exists (select 1 from public.hostels where id = h) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  loop
    c := 'OWN-';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.owner_invites where code = c);
  end loop;
  insert into public.owner_invites (code, hostel_id, name, phone) values (c, h, trim(coalesce(p_name, '')), regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'));
  return c;
end $$;

create or replace function public.join_as_owner(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hname text; me text := public.uid();
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.owner_invites where code = upper(trim(p_code));
  if i is null or i.used_by is not null or i.expires_at < now() then raise exception 'that owner code isn''t valid any more'; end if;
  if exists (select 1 from public.hostel_staff s where s.hostel_id = i.hostel_id and s.role = 'owner' and s.user_id <> me) then
    raise exception 'this hostel already has an owner account';
  end if;
  update public.owner_invites set used_by = me, used_at = now() where code = i.code;
  insert into public.hostel_staff (hostel_id, user_id, role) values (i.hostel_id, me, 'owner')
  on conflict (hostel_id, user_id) do update set role = 'owner';
  update public.profiles set role = 'owner' where id = me;
  select name into hname from public.hostels where id = i.hostel_id;
  return hname;
end $$;

create or replace function public.go_live(h uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare missing text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team puts hostels live'; end if;
  if not exists (select 1 from public.hostels where id = h) then raise exception 'that hostel isn''t on Hostelzy'; end if;
  if not exists (select 1 from public.beds where hostel_id = h) then raise exception 'add at least one room with beds'; end if;
  select string_agg(distinct r.share || ' sharing' || case when r.ac then ' AC' else '' end, ', ') into missing
  from public.rooms r where r.hostel_id = h
    and not exists (select 1 from public.rate_cards c where c.hostel_id = h and c.ac = r.ac and c.share = r.share and c.rent > 0);
  if missing is not null then raise exception 'add a price for %', missing; end if;
  if not exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.role = 'owner') then raise exception 'link the owner''s account first'; end if;
  if (select count(*) from public.hostel_photos p where p.hostel_id = h) < 8 then raise exception 'add 8 photos first'; end if;
  update public.hostels set status = 'live', visited_on = coalesce(visited_on, (now() at time zone 'Asia/Kolkata')::date) where id = h;
  insert into public.owner_plans (hostel_id, trial_ends, status) values (h, (now() at time zone 'Asia/Kolkata')::date + 30, 'trial')
  on conflict (hostel_id) do nothing;
  update public.hostel_leads set stage = 'data_complete', next_step = '', updated_at = now() where hostel_id = h;
end $$;

revoke execute on function public.bed_busy(uuid) from public, anon, authenticated;
revoke execute on function public.save_rooms(uuid, jsonb), public.save_hostel(uuid, jsonb), public.new_owner_invite(uuid, text, text),
  public.join_as_owner(text), public.go_live(uuid) from public, anon;
grant execute on function public.save_rooms(uuid, jsonb), public.save_hostel(uuid, jsonb), public.new_owner_invite(uuid, text, text),
  public.join_as_owner(text), public.go_live(uuid) to authenticated;
