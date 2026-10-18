-- Did run-all-pending.sql land? Every column must be true. Run by the
-- "Supabase SQL" GitHub action after each apply; paste into the SQL Editor to check by hand.
select to_regproc('public.go_live') is not null as onboarding,
       to_regproc('public.confirm_rates') is not null as rates,
       to_regproc('public.deals_hidden') is not null as strikes,
       (select count(*) from pg_indexes where schemaname = 'public'
          and indexname in ('beds_hostel_id_idx','fair_cases_hostel_id_idx')) = 2 as indexes,
       to_regclass('public.layout_peeks') is null as open_layouts,
       to_regproc('public.hold_seen') is not null as holds_listings,
       to_regproc('public.rsvp_meals') is not null as save_food,
       to_regproc('public.add_hostel') is not null as add_hostels,
       to_regproc('public.fill_join_request') is not null as ask_to_join,
       to_regproc('public.list_draft') is not null as import_queue,
       to_regclass('public.owner_drive') is not null as tenant_ids_drive,
       to_regproc('public.clear_join_id') is not null as w2_w4_wired;
