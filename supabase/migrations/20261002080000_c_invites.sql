-- C: server-issued resident invites. The owner's invite link / QR carries a
-- code made here (never in the app). A resident signs in, enters or opens
-- the code, and the owner approves; only then is a stay created.
-- Safe to run again.

create table if not exists public.invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  created_by text default public.uid(),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists invites_one_active on public.invites (hostel_id) where active;

create table if not exists public.invite_signups (
  id uuid primary key default gen_random_uuid(),
  code text not null references public.invites (code) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  user_id text not null default public.uid(),
  name text not null,
  phone text not null,
  bed text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);
create unique index if not exists invite_signups_one_pending on public.invite_signups (hostel_id, user_id) where status = 'pending';

alter table public.invites enable row level security;
alter table public.invite_signups enable row level security;

drop policy if exists "staff read invites" on public.invites;
create policy "staff read invites" on public.invites for select using (public.is_staff(hostel_id) or public.is_team());
drop policy if exists "read signups" on public.invite_signups;
create policy "read signups" on public.invite_signups for select using (user_id = public.uid() or public.is_staff(hostel_id) or public.is_team());
-- Writes go through the functions below only.

-- The hostel's current invite code, made on first use: "ANJ-7Q2".
create or replace function public.hostel_invite(h uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; prefix text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not (public.is_staff(h) or public.is_team()) then raise exception 'only this hostel''s staff can invite'; end if;
  select code into c from public.invites where hostel_id = h and active;
  if c is not null then return c; end if;
  select upper(rpad(left(regexp_replace(name, '[^A-Za-z]', '', 'g'), 3), 3, 'X')) into prefix from public.hostels where id = h;
  loop
    c := prefix || '-' || substr(abc, 1 + floor(random() * 32)::int, 1) || substr(abc, 1 + floor(random() * 32)::int, 1) || substr(abc, 1 + floor(random() * 32)::int, 1);
    exit when not exists (select 1 from public.invites where code = c);
  end loop;
  insert into public.invites (code, hostel_id) values (c, h);
  return c;
end $$;

-- A new code (the old link stops working), e.g. after it was shared too widely.
create or replace function public.new_hostel_invite(h uuid) returns text
language plpgsql security definer set search_path = ''
as $$
begin
  if not (public.is_staff(h) or public.is_team()) then raise exception 'only this hostel''s staff can invite'; end if;
  update public.invites set active = false where hostel_id = h and active;
  return public.hostel_invite(h);
end $$;

-- A signed-in resident asks to join with a code. Returns the hostel's name.
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
  perform public.notify_staff(i.hostel_id, trim(p_name) || ' wants to join', 'Approve them in Manage → Residents', jsonb_build_object('screen', 'oInvite'));
  return hn;
end $$;

-- The owner approves (a stay is created, matched as usual) or rejects.
create or replace function public.decide_signup(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare g record;
begin
  select * into g from public.invite_signups where id = p_id and status = 'pending';
  if g is null then raise exception 'already decided'; end if;
  if not (public.is_staff(g.hostel_id) or public.is_team()) then raise exception 'only this hostel''s staff can decide'; end if;
  update public.invite_signups set status = case when p_approve then 'approved' else 'rejected' end where id = p_id;
  if p_approve then
    insert into public.stays (hostel_id, user_id, name, phone, confirmed) values (g.hostel_id, g.user_id, g.name, g.phone, true);
    insert into public.push_outbox (user_id, title, body, data) values (g.user_id, 'You’re in', 'Your owner approved you. Open Hostelzy to see your stay.', '{"screen":"rHome"}');
  end if;
end $$;

revoke execute on function public.hostel_invite(uuid), public.new_hostel_invite(uuid), public.join_with_invite(text, text, text, text), public.decide_signup(uuid, boolean) from public, anon;
grant execute on function public.hostel_invite(uuid), public.new_hostel_invite(uuid), public.join_with_invite(text, text, text, text), public.decide_signup(uuid, boolean) to authenticated;
