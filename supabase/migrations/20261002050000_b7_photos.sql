-- B7: hostel photos in Supabase Storage. Owners and managers upload their
-- hostel's photos (compressed on the phone); tenants see them once the hostel
-- is live. Files: bucket `hostel-photos`, path `<hostel_id>/<uuid>.jpg`.
-- Safe to run again.

insert into storage.buckets (id, name, public)
values ('hostel-photos', 'hostel-photos', true)
on conflict (id) do nothing;

-- Which photo is which, in what order, and the cover.
create table if not exists public.hostel_photos (
  id uuid primary key default gen_random_uuid(),
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  path text not null unique,                      -- inside the bucket
  label text not null default '',                 -- "Front", "3 sharing", "Washroom"…
  ord int not null default 0,
  cover boolean not null default false,
  created_by text default public.uid(),           -- null for the team's SQL editor
  created_at timestamptz not null default now(),
  check (path like hostel_id::text || '/%')
);
create unique index if not exists hostel_photos_one_cover on public.hostel_photos (hostel_id) where cover;

alter table public.hostel_photos enable row level security;

drop policy if exists "read photos" on public.hostel_photos;
create policy "read photos" on public.hostel_photos for select
  using (public.is_live(hostel_id) or public.is_staff(hostel_id) or public.is_team());
drop policy if exists "staff manage photos" on public.hostel_photos;
create policy "staff manage photos" on public.hostel_photos for all
  using (public.is_staff(hostel_id) or public.is_team())
  with check (public.is_staff(hostel_id) or public.is_team());

-- The files: only that hostel's staff (or the team) may add, replace or
-- remove them, and only under their hostel's folder. Reading is public (the
-- bucket is public; file names are random), like any listing photo.
create or replace function public.photo_hostel(name text) returns uuid
language sql immutable set search_path = ''
as $$ select case when split_part(name, '/', 1) ~ '^[0-9a-f-]{36}$' then split_part(name, '/', 1)::uuid end $$;

drop policy if exists "hz staff upload photos" on storage.objects;
create policy "hz staff upload photos" on storage.objects for insert
  with check (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));
drop policy if exists "hz staff change photos" on storage.objects;
create policy "hz staff change photos" on storage.objects for update
  using (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()))
  with check (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));
drop policy if exists "hz staff remove photos" on storage.objects;
create policy "hz staff remove photos" on storage.objects for delete
  using (bucket_id = 'hostel-photos' and (public.is_staff(public.photo_hostel(name)) or public.is_team()));
