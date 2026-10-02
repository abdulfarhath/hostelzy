-- F19 v1 additions (designed 2026-10-02): quick fixes on one item (wrong
-- place / missing / broken / not in this room), one optional photo per fix
-- (seen only by the hostel's staff and the team), owners muting a resident's
-- suggestions, and a "Broken" quick fix as a repair the owner starts or
-- closes. Try mode for visitors is app-only (nothing is saved).
-- Safe to run again.

alter table public.layout_fixes add column if not exists kind text not null default 'layout';
alter table public.layout_fixes drop constraint if exists layout_fixes_kind;
alter table public.layout_fixes add constraint layout_fixes_kind check (kind in ('layout', 'quick'));
alter table public.layout_fixes add column if not exists issue text;
alter table public.layout_fixes drop constraint if exists layout_fixes_issue;
alter table public.layout_fixes add constraint layout_fixes_issue check (issue is null or issue in ('wrong_place', 'missing', 'broken', 'not_here'));
alter table public.layout_fixes add column if not exists item text;
alter table public.layout_fixes add column if not exists photo text;
alter table public.layout_fixes add column if not exists repair text;
alter table public.layout_fixes drop constraint if exists layout_fixes_repair;
alter table public.layout_fixes add constraint layout_fixes_repair check (repair is null or repair in ('working', 'not_broken'));

-- One open layout suggestion per room per resident; quick fixes are separate.
drop index if exists public.layout_fixes_one_open;
create unique index if not exists layout_fixes_one_open on public.layout_fixes (hostel_id, room, author_id) where status = 'pending' and kind = 'layout';

-- Residents whose suggestions an owner turned off. They see "Suggestions are
-- off for this hostel"; they're never told who muted them.
create table if not exists public.layout_fix_mutes (
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null,
  name text not null default '',
  muted_by text not null default public.uid(),
  created_at timestamptz not null default now(),
  primary key (hostel_id, user_id)
);
alter table public.layout_fix_mutes enable row level security;
drop policy if exists "read mutes" on public.layout_fix_mutes;
create policy "read mutes" on public.layout_fix_mutes for select
  using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());

-- The photo: private bucket, path `<hostel_id>/<user id>/<uuid>.jpg`.
insert into storage.buckets (id, name, public) values ('fix-photos', 'fix-photos', false) on conflict (id) do nothing;

create or replace function public.fix_photo_ok(p_hostel uuid, p_path text) returns boolean
language sql stable set search_path = ''
as $$ select p_path is null or p_path like p_hostel::text || '/' || public.uid() || '/%' $$;

drop policy if exists "hz residents upload fix photos" on storage.objects;
create policy "hz residents upload fix photos" on storage.objects for insert
  with check (bucket_id = 'fix-photos' and split_part(name, '/', 2) = public.uid() and public.is_resident(public.photo_hostel(name)));
drop policy if exists "hz read fix photos" on storage.objects;
create policy "hz read fix photos" on storage.objects for select
  using (bucket_id = 'fix-photos' and (split_part(name, '/', 2) = public.uid() or public.is_staff(public.photo_hostel(name)) or public.is_team()));

-- The resident sending a fix: a confirmed, current stay here, and not muted.
create or replace function public.fix_author(p_hostel uuid) returns record
language plpgsql stable security definer set search_path = ''
as $$
declare s record;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select st.*, coalesce(rm.label, rm.number::text) || coalesce('-' || b.letter, '') as bed_label, rm.number as my_room into s
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.hostel_id = p_hostel and st.user_id = public.uid() and st.confirmed and st.left_on is null limit 1;
  if s is null then raise exception 'only residents of this hostel can fix its rooms'; end if;
  if exists (select 1 from public.layout_fix_mutes m where m.hostel_id = p_hostel and m.user_id = public.uid()) then
    raise exception 'suggestions are off for this hostel';
  end if;
  return s;
end $$;

drop function if exists public.send_layout_fix(uuid, int, jsonb, text);
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
  select st.user_id, who || ' suggested a fix for Room ' || p_room, 'Compare it with the current layout and decide.', jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

-- A quick fix on one item. "Broken" also goes to the owner as a repair.
create or replace function public.send_quick_fix(p_hostel uuid, p_room int, p_item text, p_issue text, p_note text default '', p_photo text default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare s record; me text := public.uid(); n int; fid uuid; who text; what text;
begin
  s := public.fix_author(p_hostel);
  if not exists (select 1 from public.rooms r where r.hostel_id = p_hostel and r.number = p_room) then raise exception 'there is no room % here', p_room; end if;
  if p_issue is null or p_issue not in ('wrong_place', 'missing', 'broken', 'not_here') then raise exception 'pick what''s wrong'; end if;
  if coalesce(trim(p_item), '') = '' then raise exception 'pick an item'; end if;
  if not public.fix_photo_ok(p_hostel, p_photo) then raise exception 'that photo isn''t yours'; end if;
  select count(*) into n from public.layout_fixes where hostel_id = p_hostel and author_id = me and status = 'pending';
  if n >= 3 then raise exception 'you have 3 fixes waiting here'; end if;
  insert into public.layout_fixes (hostel_id, room, author_name, author_bed, layout, note, kind, issue, item, photo)
  values (p_hostel, p_room, s.name, coalesce(s.bed_label, ''), '{}'::jsonb, left(coalesce(trim(p_note), ''), 300), 'quick', p_issue, left(trim(p_item), 60), p_photo)
  returning id into fid;
  who := split_part(s.name, ' ', 1) || case when s.my_room is not null then ' (lives in ' || s.my_room || ')' else '' end;
  what := case p_issue when 'broken' then 'Broken: ' || trim(p_item) || ', Room ' || p_room
    when 'missing' then 'Missing: ' || trim(p_item) || ' in Room ' || p_room
    when 'not_here' then 'Not in Room ' || p_room || ': ' || trim(p_item)
    else 'Wrong place: ' || trim(p_item) || ' in Room ' || p_room end;
  insert into public.push_outbox (user_id, title, body, data)
  select st.user_id, what, who || case when p_issue = 'broken' then ' reported it. Start work or mark it not broken.' else ' sent a quick fix.' end, jsonb_build_object('screen', 'oToday', 'fix', fid)
  from public.hostel_staff st where st.hostel_id = p_hostel and st.role = 'owner';
  return fid;
end $$;

-- Deciding: a quick fix is a note for the owner, so approving it changes no
-- layout (the owner edits the room themselves).
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
      case when f.kind = 'layout' then 'Room ' || f.room || ' is live for tenants now. Thanks for helping.' else 'Thanks for telling them about Room ' || f.room || '.' end,
      jsonb_build_object('screen', 'rRoom', 'room', f.room));
  else
    update public.layout_fixes set status = 'rejected', reason = nullif(left(trim(coalesce(p_reason, '')), 300), ''), decided_by = public.uid(), decided_at = now() where id = p_id;
    insert into public.push_outbox (user_id, title, body, data)
    values (f.author_id, coalesce(nullif(oname, ''), 'Your owner') || ' didn’t approve your fix', coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'You can send a new fix any time.'), jsonb_build_object('screen', 'rRoom', 'room', f.room));
  end if;
  return v;
end $$;

-- The owner's repair card for a Broken quick fix: Start work, or Not broken.
create or replace function public.set_repair(p_id uuid, p_state text) returns void
language plpgsql security definer set search_path = ''
as $$
declare f record; oname text; thing text;
begin
  select * into f from public.layout_fixes where id = p_id;
  if f is null or f.kind <> 'quick' or f.issue <> 'broken' then raise exception 'that isn''t a repair'; end if;
  if not (public.is_staff(f.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  if f.status <> 'pending' then raise exception 'that repair is already handled'; end if;
  if p_state not in ('working', 'not_broken') then raise exception 'start work or mark it not broken'; end if;
  select h.owner_name into oname from public.hostels h where h.id = f.hostel_id;
  thing := case when f.item ~ '^[A-Z]{2}' then f.item else lower(f.item) end;
  update public.layout_fixes set repair = p_state, status = case when p_state = 'working' then 'approved' else 'rejected' end,
    reason = case when p_state = 'not_broken' then 'Not broken' end, decided_by = public.uid(), decided_at = now() where id = p_id;
  insert into public.push_outbox (user_id, title, body, data)
  values (f.author_id,
    case when p_state = 'working' then coalesce(nullif(oname, ''), 'Your owner') || ' is fixing the ' || thing else coalesce(nullif(oname, ''), 'Your owner') || ' says the ' || thing || ' isn’t broken' end,
    'Room ' || f.room || '.', jsonb_build_object('screen', 'rRoom', 'room', f.room));
end $$;

-- Mute / unmute a resident's suggestions (the hostel's staff only). Muting
-- closes their waiting fixes; nothing tells them who did it.
create or replace function public.mute_fix_author(p_fix uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare f record;
begin
  select * into f from public.layout_fixes where id = p_fix;
  if f is null then raise exception 'that fix is gone'; end if;
  if not (public.is_staff(f.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  insert into public.layout_fix_mutes (hostel_id, user_id, name) values (f.hostel_id, f.author_id, f.author_name)
  on conflict (hostel_id, user_id) do nothing;
  update public.layout_fixes set status = 'rejected', reason = 'Suggestions are off for this hostel', decided_by = public.uid(), decided_at = now()
  where hostel_id = f.hostel_id and author_id = f.author_id and status = 'pending';
end $$;

create or replace function public.unmute_fix_author(p_hostel uuid, p_user text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(p_hostel) or public.is_team()) then raise exception 'only this hostel''s staff can do this'; end if;
  delete from public.layout_fix_mutes where hostel_id = p_hostel and user_id = p_user;
end $$;

revoke execute on function public.fix_author(uuid), public.fix_photo_ok(uuid, text) from public, anon, authenticated;
revoke execute on function public.send_layout_fix(uuid, int, jsonb, text, text), public.send_quick_fix(uuid, int, text, text, text, text),
  public.set_repair(uuid, text), public.mute_fix_author(uuid), public.unmute_fix_author(uuid, text) from public, anon;
grant execute on function public.send_layout_fix(uuid, int, jsonb, text, text), public.send_quick_fix(uuid, int, text, text, text, text),
  public.set_repair(uuid, text), public.mute_fix_author(uuid), public.unmute_fix_author(uuid, text) to authenticated;
