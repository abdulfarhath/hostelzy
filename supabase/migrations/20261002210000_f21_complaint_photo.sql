-- F21 W3: a complaint can carry one photo ("Add a photo" on Help).
-- Private bucket `complaint-photos`, path `<hostel_id>/<user id>/<name>.jpg`.
-- The resident uploads into their own folder at a hostel they live in; the
-- resident, that hostel's staff and the Hostelzy team can read it.

alter table public.complaints add column if not exists photo text;

create or replace function public.complaint_photo_hostel(p text) returns uuid
language sql immutable set search_path = ''
as $$ select case when split_part(p, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(p, '/', 1)::uuid end $$;

-- The photo on a complaint must be the author's own, at that hostel.
create or replace function public.complaint_photo_ok() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.photo is not null and (public.complaint_photo_hostel(new.photo) is distinct from new.hostel_id
     or split_part(new.photo, '/', 2) <> new.author_id or new.photo !~ '^[^/]+/[^/]+/[^/]+\.jpg$') then
    raise exception 'complaint photo must be your own, at this hostel';
  end if;
  if tg_op = 'UPDATE' and new.photo is distinct from old.photo then
    raise exception 'the photo can''t be changed';
  end if;
  return new;
end $$;
drop trigger if exists complaint_photo_ok on public.complaints;
create trigger complaint_photo_ok before insert or update on public.complaints for each row execute function public.complaint_photo_ok();

insert into storage.buckets (id, name, public) values ('complaint-photos', 'complaint-photos', false) on conflict (id) do nothing;

drop policy if exists "hz residents upload complaint photos" on storage.objects;
create policy "hz residents upload complaint photos" on storage.objects for insert
  with check (bucket_id = 'complaint-photos' and split_part(name, '/', 2) = public.uid() and public.is_resident(public.complaint_photo_hostel(name)));
drop policy if exists "hz read complaint photos" on storage.objects;
create policy "hz read complaint photos" on storage.objects for select
  using (bucket_id = 'complaint-photos' and (split_part(name, '/', 2) = public.uid() or public.is_staff(public.complaint_photo_hostel(name)) or public.is_team()));
