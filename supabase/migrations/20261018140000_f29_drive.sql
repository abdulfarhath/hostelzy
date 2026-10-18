-- F29 Part 3 (wave 4): tenant IDs in the owner's own Google Drive.
-- Hostelzy never stores a tenant's ID image or number (DECISIONS 2026-10-18).
-- The owner connects their Drive once (scope `drive.file`); the tenant's app
-- uploads the (masked) photo through the Edge Function `id-upload`, which
-- puts it in the owner's folder with the owner's refresh token; the owner
-- and managers see it through `id-view`. This file:
--
--   owner_drive          one row per connected hostel: the refresh token
--                        encrypted with pgcrypto and a server secret
--                        (the Edge Function secret DRIVE_TOKEN_KEY; the
--                        database holds only ciphertext), the Drive folder
--                        id, the "Full copy needed (police file)" switch and
--                        a count of the files the app put there. No RLS
--                        policy at all: only the service role reads it.
--   drive_status(h)      owner / managers: connected, file count, full_copy.
--   set_full_copy(h, v)  owner / managers: the switch.
--   drive_role(h)        the caller's role on the hostel (+ its name), for the
--                        Edge Functions to check who is asking.
--   id_upload_target(t)  the tenant's app (by join token): which hostel and
--                        whether the full copy is needed. Reads the token
--                        through join_hostel_for_token(), a stub here until
--                        F29 Part 2's join_requests lands (wave 2).
--   drive_put / drive_token / drive_forget / drive_file_added
--                        service role only (the Edge Functions).
--
-- F28 Part 4 (28-90): hostels.rent_confirmed_at, added here too (same
-- `add column if not exists` as wave 2/3) so this branch tests alone.
-- Rerun-safe.

-- pgcrypto: Supabase keeps extensions in `extensions`; a plain Postgres
-- (the tests) puts it in public. The wrappers below find either.
do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'extensions') then
    create extension if not exists pgcrypto with schema extensions;
  else
    create extension if not exists pgcrypto;
  end if;
end $$;

-- ------------------------------------------------------------ F28 Part 4
alter table public.hostels add column if not exists rent_confirmed_at timestamptz;

-- ------------------------------------------------------------ owner_drive
create table if not exists public.owner_drive (
  hostel_id uuid primary key references public.hostels (id) on delete cascade,
  refresh_token bytea not null,
  folder_id text not null,
  full_copy boolean not null default false,
  connected_by text,
  connected_at timestamptz not null default now(),
  files int not null default 0 check (files >= 0)
);
alter table public.owner_drive enable row level security;
-- The stub's default privileges grant everything; nobody but the service
-- role may touch this table (it bypasses RLS). No policy is created.
revoke all on public.owner_drive from anon, authenticated;

-- The two sides of the secret: text in, bytea out and back. `key` is the
-- Edge Function secret; the database never sees it at rest.
create or replace function public.drive_enc(v text, key text) returns bytea
language sql security definer set search_path = extensions, public
as $$ select pgp_sym_encrypt(v, key) $$;
revoke all on function public.drive_enc(text, text) from public, anon, authenticated;

create or replace function public.drive_dec(v bytea, key text) returns text
language sql stable security definer set search_path = extensions, public
as $$ select pgp_sym_decrypt(v, key) $$;
revoke all on function public.drive_dec(bytea, text) from public, anon, authenticated;

-- ------------------------------------------------------------ owner / managers
-- H50: "Connected · 12 files" and the Full copy switch.
drop function if exists public.drive_status(uuid);
create function public.drive_status(h uuid) returns table (connected boolean, files int, full_copy boolean)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_staff(h) then raise exception 'not your hostel'; end if;
  return query select true, d.files, d.full_copy from public.owner_drive d where d.hostel_id = h;
  if not found then return query select false, 0, false; end if;
end $$;
grant execute on function public.drive_status(uuid) to authenticated;

create or replace function public.set_full_copy(h uuid, v boolean) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_staff(h) then raise exception 'not your hostel'; end if;
  update public.owner_drive set full_copy = v where hostel_id = h;
  if not found then raise exception 'Connect Google Drive first'; end if;
end $$;
grant execute on function public.set_full_copy(uuid, boolean) to authenticated;

-- Who is asking, for drive-connect / id-view: 'owner', 'manager' or no row.
drop function if exists public.drive_role(uuid);
create function public.drive_role(h uuid) returns table (role text, name text)
language sql stable security definer set search_path = ''
as $$
  select s.role, x.name from public.hostel_staff s join public.hostels x on x.id = s.hostel_id
  where s.hostel_id = h and s.user_id = public.uid()
$$;
grant execute on function public.drive_role(uuid) to authenticated;

-- ------------------------------------------------------------ the tenant's upload
-- Which hostel a join token belongs to, for the caller. A stub until
-- F29 Part 2 (join_requests, wave 2) replaces it with `create or replace`:
-- that version checks the token exists, isn't expired, and is the caller's
-- (status 'sent' with no tenant yet, or tenant_id = public.uid()).
do $$ begin
  if to_regprocedure('public.join_hostel_for_token(text)') is null then
    create function public.join_hostel_for_token(p_token text) returns uuid
    language plpgsql stable security definer set search_path = ''
    as $f$ begin raise exception 'Ask to join isn’t ready yet'; end $f$;
  end if;
end $$;
revoke all on function public.join_hostel_for_token(text) from public, anon;
grant execute on function public.join_hostel_for_token(text) to authenticated;

drop function if exists public.id_upload_target(text);
create function public.id_upload_target(p_token text) returns table (hostel_id uuid, full_copy boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare h uuid;
begin
  if public.uid() is null then raise exception 'sign in first'; end if;
  h := public.join_hostel_for_token(p_token);
  if h is null then raise exception 'This link isn’t valid any more'; end if;
  return query select d.hostel_id, d.full_copy from public.owner_drive d where d.hostel_id = h;
  if not found then raise exception 'The owner hasn’t connected Google Drive'; end if;
end $$;
grant execute on function public.id_upload_target(text) to authenticated;

-- ------------------------------------------------------------ service role only
-- drive-connect stores the owner's refresh token (encrypted) and folder.
create or replace function public.drive_put(h uuid, p_uid text, p_token text, p_folder text, p_key text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.hostel_staff s where s.hostel_id = h and s.user_id = p_uid and s.role = 'owner') then
    raise exception 'only the owner connects Drive';
  end if;
  if coalesce(p_key, '') = '' or coalesce(p_token, '') = '' or coalesce(p_folder, '') = '' then raise exception 'missing value'; end if;
  insert into public.owner_drive (hostel_id, refresh_token, folder_id, connected_by, connected_at, files)
  values (h, public.drive_enc(p_token, p_key), p_folder, p_uid, now(), 0)
  on conflict (hostel_id) do update
    set refresh_token = excluded.refresh_token, folder_id = excluded.folder_id, connected_by = excluded.connected_by, connected_at = now(), files = 0;
end $$;
revoke all on function public.drive_put(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.drive_put(uuid, text, text, text, text) to service_role;

-- id-upload / id-view / drive-connect read the token back (memory only).
drop function if exists public.drive_token(uuid, text);
create function public.drive_token(h uuid, p_key text) returns table (refresh_token text, folder_id text, full_copy boolean)
language sql stable security definer set search_path = ''
as $$
  select public.drive_dec(d.refresh_token, p_key), d.folder_id, d.full_copy from public.owner_drive d where d.hostel_id = h
$$;
revoke all on function public.drive_token(uuid, text) from public, anon, authenticated;
grant execute on function public.drive_token(uuid, text) to service_role;

create or replace function public.drive_forget(h uuid) returns void
language sql security definer set search_path = ''
as $$ delete from public.owner_drive where hostel_id = h $$;
revoke all on function public.drive_forget(uuid) from public, anon, authenticated;
grant execute on function public.drive_forget(uuid) to service_role;

-- +1 after an upload, -1 after "Delete from my Drive".
create or replace function public.drive_file_added(h uuid, delta int) returns void
language sql security definer set search_path = ''
as $$ update public.owner_drive set files = greatest(0, files + delta) where hostel_id = h $$;
revoke all on function public.drive_file_added(uuid, int) from public, anon, authenticated;
grant execute on function public.drive_file_added(uuid, int) to service_role;
