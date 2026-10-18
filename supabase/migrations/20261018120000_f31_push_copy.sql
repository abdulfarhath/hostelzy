-- F31 (2026-10-18): push bodies are facts, not explanations. Same six functions
-- as before (their latest versions), only the body strings change:
--   send_layout_fix      "Compare it with the current layout and decide."  → "Room N"
--   decide_layout_fix    "Room N is live for tenants now. Thanks for helping." → "Room N is live"
--                        "Thanks for telling them about Room N."           → "Room N"
--   send_shape_drawing   "Check it and publish. Tenants see it straight away." → "Room N · ready to publish"
--   save_meter           "…/unit. It’s on your rent in Hostelzy."          → "…/unit"
--   decide_signup        "Your owner approved you. Open Hostelzy to see your stay." → "Your stay is open"
--   join_with_invite     "Approve them in Manage → Residents"             → "Manage → Residents"
-- Safe to run again.

create or replace function public.send_layout_fix(p_hostel uuid, p_room int, p_layout jsonb, p_note text default '', p_photo text default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s record; me text := public.uid(); n int; fid uuid; who text; base int;
begin
  s := public.fix_author(p_hostel);
  if not public.fix_photo_ok(p_hostel, p_photo) then raise exception 'that photo isn''t yours'; end if;
  perform public.check_layout(p_hostel, p_room, p_layout);
  select count(*) into n from public.layout_fixes where hostel_id = p_hostel and author_id = me and status = 'pending' and not (kind = 'layout' and room = p_room);
  if n >= 3 then raise exception 'you have 3 fixes waiting here'; end if;
  select version into base from public.layouts where hostel_id = p_hostel and room = p_room and stage = 'published';
  update public.layout_fixes set status = 'withdrawn' where hostel_id = p_hostel and room = p_room and author_id = me and status = 'pending' and kind = 'layout';
  insert into public.layout_fixes (hostel_id, room, author_name, author_bed, layout, note, base_version, photo)
  values (p_hostel, p_room, s.name, coalesce(s.bed_label, ''), p_layout, left(coalesce(trim(p_note), ''), 300), coalesce(base, 0), p_photo)
  returning id into fid;
  who := split_part(s.name, ' ', 1) || case when s.my_room is not null then ' (lives in ' || s.my_room || ')' else '' end;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, who || ' suggested a fix for Room ' || p_room, 'Room ' || p_room, jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

create or replace function public.decide_layout_fix(p_id uuid, p_approve boolean, p_reason text default null) returns int
language plpgsql security definer set search_path = ''
as $$
declare f record; v int; oname text;
begin
  select * into f from public.layout_fixes where id = p_id;
  if f is null or f.status <> 'pending' then raise exception 'that fix isn''t waiting any more'; end if;
  if not (public.is_staff(f.hostel_id) or (public.is_team() and f.created_at < now() - interval '7 days')) then
    raise exception 'the owner decides first; the team can after 7 days';
  end if;
  select h.owner_name into oname from public.hostels h where h.id = f.hostel_id;
  if p_approve then
    if f.kind = 'layout' then
      perform public.check_layout(f.hostel_id, f.room, f.layout);
      v := public.put_layout(f.hostel_id, f.room, f.layout);
    end if;
    update public.layout_fixes set status = 'approved', decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' approved your fix',
      case when f.kind = 'layout' then 'Room ' || f.room || ' is live' else 'Room ' || f.room end,
      jsonb_build_object('screen', 'rRoom', 'room', f.room));
  else
    update public.layout_fixes set status = 'rejected', reason = nullif(left(trim(coalesce(p_reason, '')), 300), ''), decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' didn’t approve your fix', coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'You can send a new fix any time.'), jsonb_build_object('screen', 'rRoom', 'room', f.room));
  end if;
  return v;
end $$;

create or replace function public.send_shape_drawing(p_id uuid, p_drawing jsonb) returns void
language plpgsql security definer set search_path = ''
as $$
declare q record; o jsonb := p_drawing -> 'outline'; w double precision; h double precision;
begin
  if not public.is_team() then raise exception 'only the Hostelzy team draws'; end if;
  select * into q from public.shape_requests where id = p_id;
  if q is null or q.status not in ('requested', 'drawing', 'sent') then raise exception 'that request isn''t open any more'; end if;
  w := (p_drawing ->> 'w')::double precision; h := (p_drawing ->> 'h')::double precision;
  if w is null or h is null or w < 6 or w > 60 or h < 6 or h > 60 then raise exception 'room size is 6 to 60 ft'; end if;
  if coalesce(p_drawing ->> 'shape', 'Rectangle') not in ('Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom') then raise exception 'that room shape isn''t known'; end if;
  if o is not null and jsonb_typeof(o) <> 'null' and (jsonb_typeof(o) <> 'array' or jsonb_array_length(o) < 3 or jsonb_array_length(o) > 40
     or exists (select 1 from jsonb_array_elements(o) p where jsonb_typeof(p) <> 'array' or jsonb_array_length(p) <> 2
                or (p ->> 0)::double precision not between 0 and w or (p ->> 1)::double precision not between 0 and h)) then
    raise exception 'the room''s walls don''t fit its size';
  end if;
  -- A full layout (with beds) gets the editor's checks now; a shape alone is
  -- fitted with beds in the owner's app and checked when they publish.
  if jsonb_typeof(p_drawing -> 'beds') = 'object' and exists (select 1 from jsonb_object_keys(p_drawing -> 'beds')) then
    perform public.check_layout(q.hostel_id, q.room, p_drawing);
  end if;
  update public.shape_requests set status = 'sent', drawing = p_drawing, sent_by = public.uid(), sent_at = now() where id = p_id;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, 'Hostelzy drew room ' || q.room, 'Room ' || q.room || ' · ready to publish', jsonb_build_object('screen', 'oLayout', 'room', q.room)
  from public.hostel_staff st where st.hostel_id = q.hostel_id;
end $$;

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
        u || ' units ÷ ' || ppl || ' · ₹' || trim(to_char(p_rate, 'FM999990.##')) || '/unit', '{"screen":"rPay"}'::jsonb
      from public.stays s join public.beds b on b.id = s.bed_id
      where b.room_id = rm.id and s.left_on is null and s.user_id is not null and s.confirmed;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

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
    insert into public.push_outbox (user_id, title, body, data) values (g.user_id, 'You’re in', 'Your stay is open', '{"screen":"rHome"}');
  end if;
end $$;

create or replace function public.join_with_invite(p_code text, p_name text, p_phone text, p_bed text default '') returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hn text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.invites where code = upper(trim(p_code)) and active;
  if i is null then raise exception 'that invite code isn''t valid any more; ask your owner for the new one'; end if;
  if length(trim(p_name)) < 2 or p_phone !~ '^[6-9][0-9]{9}$' then raise exception 'enter your name and 10-digit phone'; end if;
  if exists (select 1 from public.invite_signups where hostel_id = i.hostel_id and user_id = public.uid() and status = 'pending') then
    raise exception 'you already asked; your owner will approve it';
  end if;
  insert into public.invite_signups (code, hostel_id, name, phone, bed) values (i.code, i.hostel_id, trim(p_name), p_phone, trim(coalesce(p_bed, '')));
  select name into hn from public.hostels where id = i.hostel_id;
  perform public.notify_staff(i.hostel_id, trim(p_name) || ' wants to join', 'Manage → Residents', jsonb_build_object('screen', 'oInvite'));
  return hn;
end $$;
