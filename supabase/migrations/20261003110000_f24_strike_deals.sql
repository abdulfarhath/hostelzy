-- F24 #18 follow-up: strike 2 hides a hostel's deals from tenants on the server too.
-- Until now only the app hid them (deals_paused covered a late plan, not strikes).
-- Tenants and guests can't read the deals row while deals_hidden(h) is true
-- (strike 2's 30 days, or strike 3); the owner, managers and the team still can.
drop policy if exists "read deals" on public.deals;
create policy "read deals" on public.deals for select
  using ((public.is_live(hostel_id) and not public.deals_paused(hostel_id) and not public.deals_hidden(hostel_id))
    or public.is_staff(hostel_id) or public.is_team());

-- F24 #15: "Layouts checked by N residents" on the hostel page: how many
-- different residents had a layout fix approved in the last 6 months, per hostel
-- (layout_checks() counts per room, and one resident can check several rooms).
create or replace function public.hostel_layout_checks() returns table (hostel_id uuid, n int)
language sql stable security definer set search_path = ''
as $$
  select f.hostel_id, count(distinct f.author_id)::int
  from public.layout_fixes f
  where f.status = 'approved' and f.decided_at > now() - interval '6 months'
    and (public.is_live(f.hostel_id) or public.is_staff(f.hostel_id) or public.is_team())
  group by f.hostel_id
$$;
grant execute on function public.hostel_layout_checks() to anon, authenticated;
