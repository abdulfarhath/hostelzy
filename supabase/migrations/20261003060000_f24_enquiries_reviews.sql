-- F24 Wave 4a (audit §3): enquiries and reviews on the server.
--   F05  one open enquiry per tenant + hostel + bed (asking again reuses the code)
--   F08  one review per stay (30-day and exit), the 30-day review opens after
--        30 days of a confirmed stay, the author can edit it, the owner replies
--        once, anyone can report a review for abuse and the team can hide it
--   F13 S4  "Is the room layout right? No" flags that room's layout
-- Safe to run again. Existing duplicate rows are kept, never deleted: older
-- duplicate enquiries are marked `dup_of`, older duplicate reviews are hidden.

-- ================================================================ F05 enquiries

alter table public.enquiries add column if not exists dup_of uuid references public.enquiries (id) on delete set null;

-- Duplicates from before: the newest open one stays open, older ones point at it.
with ranked as (
  select id, first_value(id) over w as keep, row_number() over w as n
  from public.enquiries
  where not contacted and dup_of is null and tenant_id <> 'deleted'
  window w as (partition by hostel_id, tenant_id, coalesce(bed, '') order by created_at desc, id)
)
update public.enquiries e set dup_of = r.keep from ranked r where e.id = r.id and r.n > 1;

create unique index if not exists enquiries_one_open on public.enquiries (hostel_id, tenant_id, coalesce(bed, ''))
  where not contacted and dup_of is null and tenant_id <> 'deleted';

-- The app's way in: returns the tenant's open enquiry for this hostel + bed
-- (or one the owner answered in the last 60 days), else records a new one.
create or replace function public.send_enquiry(p_hostel uuid, p_name text, p_phone text, p_bed text default null, p_source text default '', p_msg text default '')
returns text
language plpgsql security definer set search_path = ''
as $$
declare me text := public.uid(); r text;
begin
  if me is null or not public.is_verified() then raise exception 'sign in first'; end if;
  if not public.is_live(p_hostel) then raise exception 'this hostel isn''t on Hostelzy yet'; end if;
  select e.ref into r from public.enquiries e
  where e.hostel_id = p_hostel and e.tenant_id = me and coalesce(e.bed, '') = coalesce(p_bed, '') and e.dup_of is null
    and (not e.contacted or e.created_at > now() - interval '60 days')
  order by (not e.contacted) desc, e.created_at desc limit 1;
  if r is not null then return r; end if;
  insert into public.enquiries (hostel_id, tenant_id, ref, name, phone, bed, source, msg)
  values (p_hostel, me, 'new', coalesce(nullif(btrim(p_name), ''), 'Hostelzy user'), coalesce(p_phone, ''), p_bed, coalesce(p_source, ''), coalesce(p_msg, ''))
  returning ref into r;
  return r;
end $$;

revoke execute on function public.send_enquiry(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.send_enquiry(uuid, text, text, text, text, text) to authenticated;

-- ================================================================ F08 reviews

alter table public.reviews add column if not exists stay_id uuid references public.stays (id) on delete set null;
alter table public.reviews add column if not exists room int;                -- the author's room when posted (S4 layout flag)
alter table public.reviews add column if not exists edited_at timestamptz;
alter table public.reviews add column if not exists hidden boolean not null default false;
alter table public.reviews add column if not exists hidden_why text;

-- Who may change what on a review:
--   the server (SQL editor, jobs) and the team: anything (the team hides reviews)
--   account deletion: only who wrote it ("Former resident")
--   the author: their stars, words and answers (marked edited)
--   the hostel's staff: one reply, once
create or replace function public.guard_review() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare mine constant text[] := array['stars', 'body', 'cats', 'layout', 'advance', 'again', 'edited_at'];
begin
  if public.is_server() or public.is_team() then return new; end if;
  if current_setting('hz.deleting', true) = 'on' and new.author_id = 'deleted' and new.author_name = 'Former resident'
     and (to_jsonb(new) - 'author_id' - 'author_name') = (to_jsonb(old) - 'author_id' - 'author_name') then
    return new;
  end if;
  if old.author_id = public.uid() then
    if old.hidden then raise exception 'this review was hidden by Hostelzy'; end if;
    if (to_jsonb(new) - mine) <> (to_jsonb(old) - mine) then raise exception 'you can change only your stars and words'; end if;
    new.edited_at := now();
    return new;
  end if;
  if (to_jsonb(new) - 'reply' - 'replied_at') <> (to_jsonb(old) - 'reply' - 'replied_at') then
    raise exception 'owners can only reply to a review';
  end if;
  if old.reply is not null then raise exception 'you already replied to this review'; end if;
  if coalesce(btrim(new.reply), '') = '' then raise exception 'write a reply first'; end if;
  new.replied_at := now();
  return new;
end $$;

-- Backfill: each review's stay and room (the author's confirmed stay there).
update public.reviews r set stay_id = s.id, room = s.number
from (
  select distinct on (st.hostel_id, st.user_id) st.id, st.hostel_id, st.user_id, rm.number
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.confirmed and st.user_id is not null
  order by st.hostel_id, st.user_id, (st.left_on is null) desc, st.joined_on desc
) s
where r.stay_id is null and s.hostel_id = r.hostel_id and s.user_id = r.author_id;

-- Older duplicates for the same stay are hidden (kept for the record).
with ranked as (
  select id, row_number() over (partition by stay_id, kind order by created_at desc, id) as n
  from public.reviews where stay_id is not null
)
update public.reviews r set stay_id = null, hidden = true, hidden_why = 'Duplicate review for the same stay'
from ranked x where r.id = x.id and x.n > 1;

create unique index if not exists reviews_one_per_stay on public.reviews (stay_id, kind) where stay_id is not null;

-- A new review: a confirmed stay at this hostel, 30 days in for the 30-day
-- review, one of each kind per stay, never by the hostel's own staff.
create or replace function public.review_rules() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare s record;
begin
  if public.is_server() or public.is_team() then return new; end if;
  if public.is_staff(new.hostel_id) then raise exception 'owners can''t review their own hostel'; end if;
  select st.id, st.joined_on, rm.number into s
  from public.stays st left join public.beds b on b.id = st.bed_id left join public.rooms rm on rm.id = b.room_id
  where st.hostel_id = new.hostel_id and st.user_id = public.uid() and st.confirmed
  order by (st.left_on is null) desc, st.joined_on desc limit 1;
  if s.id is null then raise exception 'only residents with a confirmed stay can review'; end if;
  if new.kind = 'stay' and s.joined_on > current_date - 30 then
    raise exception 'reviews open after 30 days of your stay, on %', to_char(s.joined_on + 30, 'FMDD Mon');
  end if;
  if exists (select 1 from public.reviews x where x.stay_id = s.id and x.kind = new.kind) then
    raise exception 'you already reviewed this stay';
  end if;
  new.stay_id := s.id;
  new.room := s.number;
  new.hidden := false;
  new.hidden_why := null;
  new.edited_at := null;
  return new;
end $$;

drop trigger if exists review_rules on public.reviews;
create trigger review_rules before insert on public.reviews
for each row execute function public.review_rules();

-- Hidden reviews leave the hostel's page; the author and the team still see them.
drop policy if exists "read reviews" on public.reviews;
create policy "read reviews" on public.reviews for select
  using ((not hidden and (public.is_live(hostel_id) or public.is_staff(hostel_id))) or author_id = public.uid() or public.is_team());
drop policy if exists "author edits review" on public.reviews;
create policy "author edits review" on public.reviews for update using (author_id = public.uid()) with check (author_id = public.uid());

-- ---------------------------------------------------------------- report abuse

create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews (id) on delete cascade,
  hostel_id uuid not null references public.hostels (id) on delete cascade,
  reporter_id text not null default public.uid(),
  why text not null,
  status text not null default 'open' check (status in ('open', 'hidden', 'kept')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (review_id, reporter_id)
);
alter table public.review_reports enable row level security;
drop policy if exists "read review reports" on public.review_reports;
create policy "read review reports" on public.review_reports for select using (reporter_id = public.uid() or public.is_team());

-- Anyone signed in who can see a review can report it (once); the team decides.
create or replace function public.report_review(p_review uuid, p_why text) returns void
language plpgsql security definer set search_path = ''
as $$
declare r public.reviews;
begin
  if public.uid() is null or not public.is_verified() then raise exception 'sign in first'; end if;
  if coalesce(btrim(p_why), '') = '' then raise exception 'say what is wrong'; end if;
  select * into r from public.reviews where id = p_review;
  if r.id is null or r.hidden or not (public.is_live(r.hostel_id) or public.is_staff(r.hostel_id)) then raise exception 'review not found'; end if;
  if r.author_id = public.uid() then raise exception 'you can edit your own review instead'; end if;
  insert into public.review_reports (review_id, hostel_id, reporter_id, why)
  values (r.id, r.hostel_id, public.uid(), left(btrim(p_why), 200))
  on conflict (review_id, reporter_id) do nothing;
end $$;

-- The team hides a reported review (or keeps it); every open report on it closes.
create or replace function public.decide_review_report(p_review uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_team() then raise exception 'only the Hostelzy team decides reports'; end if;
  update public.reviews set hidden = p_hide, hidden_why = case when p_hide then 'Reported for abuse' end where id = p_review;
  update public.review_reports set status = case when p_hide then 'hidden' else 'kept' end, decided_at = now()
  where review_id = p_review and status = 'open';
end $$;

revoke execute on function public.report_review(uuid, text), public.decide_review_report(uuid, boolean) from public, anon;
grant execute on function public.report_review(uuid, text), public.decide_review_report(uuid, boolean) to authenticated;
revoke execute on function public.review_rules() from public, anon, authenticated;

-- ================================================================ F13 S4 layout flag

-- "Is the room layout right? No" on a 30-day review adds a dispute to the
-- author's room; changing the answer (or the team hiding the review) takes it
-- back. Publishing the room again resets the count (publish/approve_layout).
create or replace function public.review_layout_flag() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  was boolean := tg_op = 'UPDATE' and old.layout = 'No' and not old.hidden and old.room is not null;
  now_no boolean := new.layout = 'No' and not new.hidden and new.room is not null;
begin
  if was = now_no then return null; end if;
  update public.layouts set disputes = greatest(0, disputes + case when now_no then 1 else -1 end)
  where hostel_id = new.hostel_id and room = new.room and stage = 'published';
  return null;
end $$;

revoke execute on function public.review_layout_flag() from public, anon, authenticated;

drop trigger if exists review_layout_flag on public.reviews;
create trigger review_layout_flag after insert or update of layout, hidden on public.reviews
for each row execute function public.review_layout_flag();

-- Flags for reviews posted before this ran (since the room was last published).
update public.layouts l set disputes = greatest(l.disputes, (
  select count(*)::int from public.reviews r
  where r.hostel_id = l.hostel_id and r.room = l.room and r.layout = 'No' and not r.hidden
    and r.created_at > coalesce(l.confirmed_at, '-infinity'::timestamptz)))
where l.stage = 'published';
