-- F29 Part 2 (wave 2): "Ask to join". The owner picks a free bed and a date
-- and sends a WhatsApp link; the tenant fills name, phone, date and sends
-- their ID to the owner; the owner approves and the stay is made the same way
-- as "Add a resident" (a public.stays row: hz_match, bed booked).
--   join_requests          token (single use, 7 days, one bed), the owner's fee / advance / date / name hint,
--                          the tenant's name / phone / date, id_received drive | whatsapp | none, id_file_id
--   new_join_request(bed, fee, advance, moves_in, name) → token      (staff)
--   join_request_info(token) → jsonb                                 (signed-in tenant opens the link)
--   fill_join_request(token, name, phone, date, id_received, id_file_id) → jsonb   (tenant)
--   decide_join(id, approve, note)                                   (staff; approve = a stay)
--   ask_id_again(id) → tenant phone                                  (staff; a push + the WhatsApp text)
--   expire_join_tokens()   pg_cron, hourly
-- Hostelzy never stores the ID image or number: Drive gets the file (wave 4),
-- the WhatsApp path stores only the tick. The Drive option shows only when
-- owner_drive (wave 4) has a row: join_request_info returns drive = false
-- until then (Build 4 wiring point).
-- Safe to run again.

create table if not exists public.join_requests (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  bed_id uuid not null references public.beds (id) on delete cascade,
  fee int not null check (fee between 1000 and 100000),
  advance int not null default 0 check (advance between 0 and 100000),
  moves_in date not null,
  name_hint text not null default '',
  status text not null default 'sent' check (status in ('sent', 'filled', 'approved', 'declined', 'expired')),
  tenant_id text,
  tenant_name text,
  tenant_phone text,
  tenant_date date,
  id_received text not null default 'none' check (id_received in ('drive', 'whatsapp', 'none')),
  id_file_id text,
  id_asked_at timestamptz,
  note text not null default '',
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  filled_at timestamptz,
  decided_at timestamptz
);
create index if not exists join_requests_hostel_id_idx on public.join_requests (hostel_id);
create index if not exists join_requests_tenant_id_idx on public.join_requests (tenant_id) where tenant_id is not null;
alter table public.join_requests enable row level security;
drop policy if exists "read join requests" on public.join_requests;
create policy "read join requests" on public.join_requests for select
  using (public.is_staff(hostel_id) or public.is_team() or (tenant_id is not null and tenant_id = public.uid()));
-- Writes go through the functions below only.
grant select on public.join_requests to authenticated;

-- Not in the Realtime publication: the owner's Today reloads the Joining tab
-- when it opens and after each decision (Build 4 may add it with the Drive work).

-- "203" or "204A-B": the bed's label as the app shows it.
create or replace function public.bed_label(p_bed uuid) returns text
language sql stable security definer set search_path = ''
as $$ select coalesce(r.label, r.number::text) || '-' || b.letter from public.beds b join public.rooms r on r.id = b.room_id where b.id = p_bed $$;
revoke execute on function public.bed_label(uuid) from public, anon, authenticated;

-- A bed with nobody living in it (holds don't count: the bed isn't held for a joiner).
create or replace function public.bed_free_to_join(p_bed uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select not exists (select 1 from public.stays s where s.bed_id = p_bed and s.left_on is null) $$;
revoke execute on function public.bed_free_to_join(uuid) from public, anon, authenticated;

-- H48 "Ask to join": the owner (or a manager) makes a 7-day, single-use link for one bed.
create or replace function public.new_join_request(p_bed uuid, p_fee int, p_advance int, p_moves_in date, p_name text default '') returns text
language plpgsql security definer set search_path = ''
as $$
declare h uuid; t text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select hostel_id into h from public.beds where id = p_bed;
  if h is null then raise exception 'pick a bed'; end if;
  if not (public.is_staff(h) or public.is_team()) then raise exception 'only this hostel''s staff can ask someone to join'; end if;
  if not public.bed_free_to_join(p_bed) then raise exception 'bed % is taken', public.bed_label(p_bed); end if;
  if p_fee is null or p_fee not between 1000 and 100000 then raise exception 'add the monthly fee'; end if;
  if p_advance is null or p_advance not between 0 and 100000 then raise exception 'add the advance'; end if;
  if p_moves_in is null then raise exception 'pick the move-in date'; end if;
  loop
    t := '';
    for i in 1..12 loop t := t || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.join_requests where token = t);
  end loop;
  insert into public.join_requests (token, hostel_id, bed_id, fee, advance, moves_in, name_hint)
  values (t, h, p_bed, p_fee, p_advance, p_moves_in, left(regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g'), 80));
  return t;
end $$;
revoke execute on function public.new_join_request(uuid, int, int, date, text) from public, anon;
grant execute on function public.new_join_request(uuid, int, int, date, text) to authenticated;

-- S94 opens: what the link is for. The owner's WhatsApp number comes back
-- while the request is open, so the tenant can send their ID to the owner
-- who invited them (never to anyone else). drive = false until owner_drive
-- (wave 4) exists: Build 4 replaces it with `exists (select 1 from
-- public.owner_drive d where d.hostel_id = j.hostel_id)`.
create or replace function public.join_request_info(p_token text) returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'id', j.id, 'hostel_id', j.hostel_id, 'hostel', h.name,
    'owner', coalesce(nullif(h.owner_name, ''), (select split_part(pr.name, ' ', 1) from public.hostel_staff st join public.profiles pr on pr.id = st.user_id
                                                   where st.hostel_id = h.id and st.role = 'owner' order by pr.created_at limit 1), 'your owner'),
    'bed', public.bed_label(j.bed_id), 'fee', j.fee, 'advance', j.advance, 'moves_in', j.moves_in, 'name_hint', j.name_hint,
    'status', case when j.status = 'sent' and j.expires_at <= now() then 'expired' else j.status end,
    'taken', not public.bed_free_to_join(j.bed_id),
    'mine', j.tenant_id is not null and j.tenant_id = public.uid(),
    'id_received', j.id_received,
    'drive', false,
    'owner_phone', case when j.status in ('sent', 'filled') and j.expires_at > now() or j.tenant_id = public.uid() then coalesce(
      nullif((select coalesce(nullif(pr.whatsapp, ''), regexp_replace(coalesce(pr.phone, ''), '\D', '', 'g')) from public.hostel_staff st join public.profiles pr on pr.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by pr.created_at limit 1), ''),
      nullif((select regexp_replace(coalesce(l.owner_whatsapp, l.owner_phone), '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      '') else '' end)
  from public.join_requests j join public.hostels h on h.id = j.hostel_id
  where j.token = upper(trim(p_token)) and public.is_verified()
$$;
revoke execute on function public.join_request_info(text) from public, anon;
grant execute on function public.join_request_info(text) to authenticated;

-- S94 "Send to owner": the tenant's own details. The bed must still be free
-- (first approved wins; a second form says so). Returns {hostel, owner}.
create or replace function public.fill_join_request(p_token text, p_name text, p_phone text, p_date date, p_id_received text default 'none', p_id_file_id text default null) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare j record; nm text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g'); ph text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'); hn text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into j from public.join_requests where token = upper(trim(p_token));
  if j.id is null or j.status <> 'sent' or j.expires_at <= now() then raise exception 'this link isn''t valid any more; ask your owner for a new one'; end if;
  if length(nm) < 2 then raise exception 'enter your name'; end if;
  if ph !~ '^[6-9][0-9]{9}$' then raise exception 'enter your 10-digit phone'; end if;
  if p_date is null then raise exception 'pick your move-in date'; end if;
  if coalesce(p_id_received, 'none') not in ('drive', 'whatsapp', 'none') then raise exception 'bad id_received'; end if;
  if not public.bed_free_to_join(j.bed_id) then raise exception 'this bed was just taken; ask your owner'; end if;
  update public.join_requests set tenant_id = public.uid(), tenant_name = nm, tenant_phone = ph, tenant_date = p_date,
    id_received = coalesce(p_id_received, 'none'), id_file_id = case when coalesce(p_id_received, 'none') = 'drive' then p_id_file_id end,
    status = 'filled', filled_at = now()
  where id = j.id;
  select name into hn from public.hostels where id = j.hostel_id;
  perform public.notify_staff(j.hostel_id, split_part(nm, ' ', 1) || ' wants to join · bed ' || public.bed_label(j.bed_id),
    'Moves in ' || to_char(p_date, 'FMDD Mon') || ' · open Today → Joining to approve', jsonb_build_object('screen', 'oToday', 'kind', 'join', 'join', j.id));
  return jsonb_build_object('hostel', hn, 'owner', public.join_request_info(j.token) ->> 'owner');
end $$;
revoke execute on function public.fill_join_request(text, text, text, date, text, text) from public, anon;
grant execute on function public.fill_join_request(text, text, text, date, text, text) to authenticated;

-- H49: Approve (→ the same stays row the owner's "Add a resident" makes:
-- hz_match, Fair Play late check, bed booked) or Decline.
create or replace function public.decide_join(p_id uuid, p_approve boolean, p_note text default '') returns void
language plpgsql security definer set search_path = ''
as $$
declare j record; hn text;
begin
  select * into j from public.join_requests where id = p_id;
  if j.id is null then raise exception 'no such request'; end if;
  if not (public.is_staff(j.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can decide'; end if;
  if j.status <> 'filled' then raise exception 'already decided'; end if;
  select name into hn from public.hostels where id = j.hostel_id;
  if p_approve then
    if not public.bed_free_to_join(j.bed_id) then raise exception 'bed % is taken', public.bed_label(j.bed_id); end if;
    insert into public.stays (hostel_id, bed_id, user_id, name, phone, rent, advance, joined_on, confirmed)
    values (j.hostel_id, j.bed_id, j.tenant_id, j.tenant_name, j.tenant_phone, j.fee, j.advance, j.tenant_date, true);
    update public.join_requests set status = 'approved', decided_at = now(), note = trim(coalesce(p_note, '')) where id = j.id;
    insert into public.push_outbox (user_id, title, body, data)
    values (j.tenant_id, 'You’re in. Welcome to ' || hn, 'Bed ' || public.bed_label(j.bed_id) || ' · open Hostelzy to see your stay.', jsonb_build_object('screen', 'rHome', 'kind', 'join'));
  else
    update public.join_requests set status = 'declined', decided_at = now(), note = trim(coalesce(p_note, '')) where id = j.id;
    insert into public.push_outbox (user_id, title, body, data)
    values (j.tenant_id, hn || ' didn’t approve your request', case when length(trim(coalesce(p_note, ''))) > 0 then trim(p_note) else 'Ask your owner what to do next.' end, jsonb_build_object('screen', 'joinForm', 'kind', 'join', 'token', j.token));
  end if;
end $$;
revoke execute on function public.decide_join(uuid, boolean, text) from public, anon;
grant execute on function public.decide_join(uuid, boolean, text) to authenticated;

-- H49 "Ask again": a push to the tenant; returns their phone for the owner's WhatsApp text.
create or replace function public.ask_id_again(p_id uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare j record; hn text;
begin
  select * into j from public.join_requests where id = p_id;
  if j.id is null then raise exception 'no such request'; end if;
  if not (public.is_staff(j.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can ask'; end if;
  if j.status <> 'filled' then raise exception 'already decided'; end if;
  select name into hn from public.hostels where id = j.hostel_id;
  update public.join_requests set id_received = 'none', id_file_id = null, id_asked_at = now() where id = j.id;
  insert into public.push_outbox (user_id, title, body, data)
  values (j.tenant_id, 'Please re-send your ID', hn || ' needs a clear photo of your ID for bed ' || public.bed_label(j.bed_id) || '.', jsonb_build_object('screen', 'joinForm', 'kind', 'join', 'token', j.token));
  return j.tenant_phone;
end $$;
revoke execute on function public.ask_id_again(uuid) from public, anon;
grant execute on function public.ask_id_again(uuid) to authenticated;

-- Hourly (pg_cron): links older than 7 days stop working.
create or replace function public.expire_join_tokens() returns int
language plpgsql security definer set search_path = ''
as $$
declare n int;
begin
  update public.join_requests set status = 'expired' where status = 'sent' and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.expire_join_tokens() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hz-expire-join-tokens', '15 * * * *', 'select public.expire_join_tokens()');
  end if;
end $$;
