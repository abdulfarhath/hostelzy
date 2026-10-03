-- F24 #18 follow-up: strike 2 hides a hostel's deals from tenants on the server too.
-- Until now only the app hid them (deals_paused covered a late plan, not strikes).
-- Tenants and guests can't read the deals row while deals_hidden(h) is true
-- (strike 2's 30 days, or strike 3); the owner, managers and the team still can.
drop policy if exists "read deals" on public.deals;
create policy "read deals" on public.deals for select
  using ((public.is_live(hostel_id) and not public.deals_paused(hostel_id) and not public.deals_hidden(hostel_id))
    or public.is_staff(hostel_id) or public.is_team());
