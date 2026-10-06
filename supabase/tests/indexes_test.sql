-- Performance indexes exist (migration 20261003120000_perf_indexes.sql).
\set ON_ERROR_STOP 1
set client_min_messages = warning;
\o /dev/null
reset role;
select test.eq((select count(*)::text from pg_indexes where schemaname = 'public' and indexname in ('beds_hostel_id_idx', 'enquiries_dup_of_idx', 'fair_cases_hostel_id_idx', 'fair_reports_case_id_idx', 'fair_reports_hostel_id_idx', 'holds_bed_id_idx', 'holds_hostel_id_idx', 'invite_signups_code_idx', 'invoices_hostel_id_idx', 'layout_history_hostel_id_idx', 'layout_waits_hostel_id_idx', 'manager_invites_hostel_id_idx', 'meter_readings_hostel_id_idx', 'move_requests_hostel_id_idx', 'move_requests_stay_id_idx', 'move_requests_to_bed_id_idx', 'owner_invites_hostel_id_idx', 'payments_hold_id_idx', 'payments_hostel_id_idx', 'payments_stay_id_idx', 'review_reports_hostel_id_idx', 'reviews_hostel_id_idx', 'reward_ledger_hostel_id_idx', 'shape_requests_hostel_id_idx', 'stays_bed_id_idx', 'stays_hostel_id_idx', 'strikes_case_id_idx', 'strikes_hostel_id_idx', 'hostel_staff_user_id_idx', 'stays_user_id_idx', 'holds_tenant_id_idx', 'enquiries_tenant_id_idx', 'payments_payer_id_idx', 'reviews_author_id_idx', 'complaints_author_id_idx', 'push_tokens_user_id_idx', 'push_outbox_user_id_idx', 'reward_ledger_user_id_idx', 'layout_fixes_author_id_idx', 'move_requests_user_id_idx', 'join_answers_tenant_id_idx', 'invite_signups_user_id_idx', 'meal_ratings_user_id_idx', 'push_outbox_unsent_idx', 'holds_status_expires_idx')), '45');
-- F26: layout_peeks (and its index) is gone: layouts are open to everyone.
select test.eq((select to_regclass('public.layout_peeks') is null)::text, 'true');
\o
select 'ALL INDEX TESTS PASSED';
