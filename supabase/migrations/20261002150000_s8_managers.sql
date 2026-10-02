-- S8: managers and owners with more than one hostel.
-- A typed phone number is never proof (phones aren't verified), so a manager
-- joins with a one-time code the owner sends them on WhatsApp:
--   new_manager_invite(hostel, name, phone) → "MGR-XXXXXXXX" (owner only)
--   join_as_manager(code) → the hostel's name (signed in with Google; the
--   code works once, for 7 days); the owner is told.
-- Owners read their hostel's manager invites (name, phone, joined or not).
-- Safe to run again.

create table if not exists public.manager_invites (
  code text primary key,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  name text not null,
  phone text not null default '',
  created_by text default public.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by text,
  used_at timestamptz
);
alter table public.manager_invites enable row level security;
drop policy if exists "owner reads manager invites" on public.manager_invites;
create policy "owner reads manager invites" on public.manager_invites for select using (public.is_owner(hostel_id) or public.is_team());
-- Writes go through the functions below only.

create or replace function public.new_manager_invite(h uuid, p_name text, p_phone text) returns text
language plpgsql security definer set search_path = ''
as $$
declare c text; abc text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not (public.is_owner(h) or public.is_team()) then raise exception 'only the owner adds managers'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'add the manager''s name'; end if;
  loop
    c := 'MGR-';
    for i in 1..8 loop c := c || substr(abc, 1 + floor(random() * 32)::int, 1); end loop;
    exit when not exists (select 1 from public.manager_invites where code = c);
  end loop;
  insert into public.manager_invites (code, hostel_id, name, phone) values (c, h, trim(p_name), coalesce(p_phone, ''));
  return c;
end $$;

create or replace function public.join_as_manager(p_code text) returns text
language plpgsql security definer set search_path = ''
as $$
declare i record; hname text;
begin
  if not public.is_verified() then raise exception 'sign in with Google first'; end if;
  select * into i from public.manager_invites where code = upper(trim(p_code));
  if i is null or i.used_by is not null or i.expires_at < now() then raise exception 'that manager code isn''t valid any more'; end if;
  update public.manager_invites set used_by = public.uid(), used_at = now() where code = i.code;
  insert into public.hostel_staff (hostel_id, user_id, role) values (i.hostel_id, public.uid(), 'manager') on conflict do nothing;
  select name into hname from public.hostels where id = i.hostel_id;
  insert into public.push_outbox (user_id, title, body, data)
  select s.user_id, i.name || ' joined as manager', 'They can now run beds, residents, enquiries and complaints at ' || hname || '.', '{"screen":"oMore"}'::jsonb
  from public.hostel_staff s where s.hostel_id = i.hostel_id and s.role = 'owner';
  return hname;
end $$;

revoke execute on function public.new_manager_invite(uuid, text, text), public.join_as_manager(text) from public, anon;
grant execute on function public.new_manager_invite(uuid, text, text), public.join_as_manager(text) to authenticated;
