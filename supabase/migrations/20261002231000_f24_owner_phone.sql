-- F24 item 1: the owner's number from the server. DECISIONS (F07): a tenant
-- sees it only after they hold a bed, enquire through Hostelzy, or stay there.
--   owner_contacts(hostels[]) → (hostel_id, phone)
--       The owner's own phone (profiles.phone of the hostel's owner), else
--       the number the team noted at onboarding (hostel_leads.owner_phone).
--       Only for hostels where the caller is staff or the team, or has a hold
--       or an enquiry there in the last 60 days, or a stay (now or ended in
--       the last 60 days). Other hostels are left out.
-- Residents' phones stay where they were: staff read them in stays. Safe to run again.

create or replace function public.owner_contacts(p_hostels uuid[]) returns table (hostel_id uuid, phone text)
language sql stable security definer set search_path = ''
as $$
  select h.id,
    coalesce(
      nullif((select regexp_replace(coalesce(p.phone, ''), '\D', '', 'g') from public.hostel_staff st join public.profiles p on p.id = st.user_id
              where st.hostel_id = h.id and st.role = 'owner' order by p.created_at limit 1), ''),
      nullif((select regexp_replace(l.owner_phone, '\D', '', 'g') from public.hostel_leads l where l.hostel_id = h.id), ''),
      '')
  from public.hostels h
  where h.id = any(p_hostels)
    and public.uid() is not null
    and (public.is_staff(h.id) or public.is_team()
      or exists (select 1 from public.holds x where x.hostel_id = h.id and x.tenant_id = public.uid() and x.started_at > now() - interval '60 days')
      or exists (select 1 from public.enquiries e where e.hostel_id = h.id and e.tenant_id = public.uid() and e.created_at > now() - interval '60 days')
      or exists (select 1 from public.stays s where s.hostel_id = h.id and s.user_id = public.uid() and (s.left_on is null or s.left_on > current_date - 60)))
$$;

revoke execute on function public.owner_contacts(uuid[]) from public, anon;
grant execute on function public.owner_contacts(uuid[]) to authenticated;
