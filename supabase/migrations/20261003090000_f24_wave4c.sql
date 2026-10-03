-- F24 Wave 4c: the rest of Wave A items 1, 2 and 4.
--   Item 1, owner's WhatsApp: an owner may chat on a different number than
--     they take calls on.
--       profiles.whatsapp            the owner's own (Settings › WhatsApp), '' = same as phone.
--       hostel_leads.owner_whatsapp  the one the team notes in the Add hostel wizard.
--       owner_contacts(hostels[]) → (hostel_id, phone, whatsapp)   same people
--         as before; whatsapp is the owner's own, else the team's note, else ''.
--   Item 2, onboard a real hostel:
--       save_hostel also saves "rules" (house rules: gate time, visitors…) and
--         "amenities" (the wizard's list) when sent. The pin (lat, lng) is the
--         one the team dropped at the gate.
--       go_live also needs that pin: "drop the map pin at the gate".
--       hostels.amenities            the wizard's amenities (Wi-Fi, Power backup…).
--   Item 4, meal times: menus.breakfast_time / lunch_time / dinner_time,
--     'HH:MM-HH:MM' (24 h) or '' (not set: the app keeps its usual times).
--       save_meal_times(hostel, {"b": "07:30-09:30", "l": …, "n": …})   staff or
--         the team; the same times go on every day of the week.
-- Safe to run again.

-- ------------------------------------------------------------ item 1

alter table public.profiles add column if not exists whatsapp text not null default '';
alter table public.profiles drop constraint if exists profiles_whatsapp;
alter table public.profiles add constraint profiles_whatsapp check (whatsapp ~ '^([0-9]{10})?$');
alter table public.hostel_leads add column if not exists owner_whatsapp text not null default '';

drop function if exists public.owner_contacts(uuid[]);
create function public.owner_contacts(p_hostels uuid[]) returns table (hostel_id uuid, phone text, whatsapp text)
language sql stable security definer set search_path = ''
as $$
  select h.id,
    coalesce(
      nullif((select regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_phone, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      ''),
    coalesce(
      nullif((select p.whatsapp from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_whatsapp, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      '')
  from public.hostels h
  where h.id = any(p_hostels)
    and public.uid() is not null
    and (public.is_staff(h.id) or public.is_team()
      or exists (select 1 from public.holds x where x.hostel_id = h.id and x.tenant_id = public.uid() and x.started_at > now() - interval '60 days')
      or exists (select 1 from public.enquiries e where e.hostel_id = h.id and e.tenant_id = public.uid() and e.created_at > now() - interval '60 days')
      or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = public.uid() and (s.left_on is null or s.left_on > current_date - 60)))
$$;
revoke execute on function public.owner_contacts(uuid[]) from public, anon;
grant execute on function public.owner_contacts(uuid[]) to authenticated;

-- ------------------------------------------------------------ item 2

alter table public.hostels add column if not exists amenities text[] not null default '{}';

create or replace function public.save_hostel(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare hid uuid := p_id; v_name text := trim(coalesce(p ->> 'name', '')); v_slug text; st text; rc jsonb; v_wa text;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team adds hostels'; end if;
  if v_name = '' then raise exception 'add the hostel name'; end if;
  if p ? 'lat' and ((p ->> 'lat')::double precision not between 17.0 and 18.0 or (p ->> 'lng')::double precision not between 78.0 and 79.0) then
    raise exception 'the map pin isn''t in Hyderabad';
  end if;
  v_wa := regexp_replace(coalesce(p ->> 'owner_whatsapp', ''), '\D', '', 'g');
  if v_wa <> '' and length(v_wa) <> 10 then raise exception 'the owner''s WhatsApp needs 10 digits'; end if;
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
    lng = coalesce((p ->> 'lng')::double precision, lng),
    rules = case when jsonb_typeof(p -> 'rules') = 'array' then
      (select coalesce(jsonb_agg(jsonb_build_object('k', trim(r ->> 'k'), 'v', trim(coalesce(r ->> 'v', '')))), '[]') from jsonb_array_elements(p -> 'rules') r where trim(coalesce(r ->> 'k', '')) <> '')
      else rules end,
    amenities = case when jsonb_typeof(p -> 'amenities') = 'array' then
      array(select distinct trim(a) from jsonb_array_elements_text(p -> 'amenities') a where trim(a) <> '')
      else amenities end
  where id = hid;
  insert into public.hostel_leads (hostel_id, owner_phone, owner_whatsapp, stage)
  values (hid, regexp_replace(coalesce(p ->> 'owner_phone', ''), '\D', '', 'g'), v_wa, 'signed_up')
  on conflict (hostel_id) do update set owner_phone = case when excluded.owner_phone <> '' then excluded.owner_phone else public.hostel_leads.owner_phone end,
    owner_whatsapp = case when p ? 'owner_whatsapp' then excluded.owner_whatsapp else public.hostel_leads.owner_whatsapp end,
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

-- go_live as before, plus the pin dropped at the gate.
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
  if exists (select 1 from public.hostels x where x.id = h and (x.lat is null or x.lng is null)) then raise exception 'drop the map pin at the gate'; end if;
  update public.hostels set status = 'live', visited_on = coalesce(visited_on, (now() at time zone 'Asia/Kolkata')::date) where id = h;
  insert into public.owner_plans (hostel_id, trial_ends, status) values (h, (now() at time zone 'Asia/Kolkata')::date + 30, 'trial')
  on conflict (hostel_id) do nothing;
  update public.hostel_leads set stage = 'data_complete', next_step = '', updated_at = now() where hostel_id = h;
end $$;

revoke execute on function public.save_hostel(uuid, jsonb), public.go_live(uuid) from public, anon;
grant execute on function public.save_hostel(uuid, jsonb), public.go_live(uuid) to authenticated;

-- ------------------------------------------------------------ item 4

alter table public.menus add column if not exists breakfast_time text not null default '';
alter table public.menus add column if not exists lunch_time text not null default '';
alter table public.menus add column if not exists dinner_time text not null default '';
alter table public.menus drop constraint if exists menus_times;
alter table public.menus add constraint menus_times check (
  breakfast_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$'
  and lunch_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$'
  and dinner_time ~ '^(([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9])?$');

create or replace function public.save_meal_times(p_hostel uuid, p jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare b text := coalesce(p ->> 'b', ''); l text := coalesce(p ->> 'l', ''); n text := coalesce(p ->> 'n', ''); t text;
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s owner, managers or the team set its meal times'; end if;
  foreach t in array array[b, l, n] loop
    if t <> '' and (t !~ '^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$' or split_part(t, '-', 2) <= split_part(t, '-', 1)) then
      raise exception 'a meal ends after it starts';
    end if;
  end loop;
  insert into public.menus (hostel_id, day, breakfast_time, lunch_time, dinner_time)
  select p_hostel, d, b, l, n from generate_series(0, 6) d
  on conflict (hostel_id, day) do update set breakfast_time = excluded.breakfast_time, lunch_time = excluded.lunch_time, dinner_time = excluded.dinner_time;
end $$;
revoke execute on function public.save_meal_times(uuid, jsonb) from public, anon;
grant execute on function public.save_meal_times(uuid, jsonb) to authenticated;
