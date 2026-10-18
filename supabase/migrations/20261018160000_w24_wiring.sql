-- Waves 2 + 4 wired together (integration, 2026-10-18). Runs after
-- 20261018110000_f29_join.sql (join_requests) and 20261018140000_f29_drive.sql
-- (owner_drive, the join_hostel_for_token stub). Safe to run again.
--
-- 1. join_hostel_for_token(token): the real body (wave 4 §2.3 of its handover).
--    id_upload_target() calls it to find the hostel whose owner's Drive gets
--    the tenant's ID. Wave 4 created only a stub ("isn't ready yet").
-- 2. join_request_info(token): `drive` is true once the owner connected Drive
--    (an owner_drive row), so S94 shows the camera path instead of WhatsApp
--    (wave 2 left it false until wave 4 existed).
-- 3. clear_join_id(id): H49 "Delete from my Drive" deleted the file in the
--    owner's Drive (Edge Function id-view, action delete); the request forgets
--    the pointer and goes back to "No ID yet". Staff of the hostel only.

create or replace function public.join_hostel_for_token(p_token text) returns uuid
language sql stable security definer set search_path = ''
as $$
  select j.hostel_id from public.join_requests j
  where j.token = upper(trim(p_token)) and j.expires_at > now() and j.status in ('sent', 'filled')
    and (j.tenant_id is null or j.tenant_id = public.uid())
$$;
revoke all on function public.join_hostel_for_token(text) from public, anon;
grant execute on function public.join_hostel_for_token(text) to authenticated;

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
    'drive', exists (select 1 from public.owner_drive d where d.hostel_id = j.hostel_id),
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

create or replace function public.clear_join_id(p_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare j record;
begin
  select * into j from public.join_requests where id = p_id;
  if j.id is null then raise exception 'no such request'; end if;
  if not public.is_staff(j.hostel_id) then raise exception 'only this hostel''s owner or managers'; end if;
  update public.join_requests set id_received = 'none', id_file_id = null where id = p_id;
end $$;
revoke all on function public.clear_join_id(uuid) from public, anon;
grant execute on function public.clear_join_id(uuid) to authenticated;
