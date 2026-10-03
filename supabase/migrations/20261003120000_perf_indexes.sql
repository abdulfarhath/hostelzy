-- Performance: indexes for every foreign key and every user-id column the app and the
-- RLS policies filter on (is_staff(), my stays/holds/enquiries/payments…). No behaviour
-- change: only lookups get faster as the tables grow. Safe to run again (if not exists).

-- Foreign keys (joins and per-hostel lists).
create index if not exists beds_hostel_id_idx on public.beds (hostel_id);
create index if not exists enquiries_dup_of_idx on public.enquiries (dup_of);
create index if not exists fair_cases_hostel_id_idx on public.fair_cases (hostel_id);
create index if not exists fair_reports_case_id_idx on public.fair_reports (case_id);
create index if not exists fair_reports_hostel_id_idx on public.fair_reports (hostel_id);
create index if not exists holds_bed_id_idx on public.holds (bed_id);
create index if not exists holds_hostel_id_idx on public.holds (hostel_id);
create index if not exists invite_signups_code_idx on public.invite_signups (code);
create index if not exists invoices_hostel_id_idx on public.invoices (hostel_id);
create index if not exists layout_history_hostel_id_idx on public.layout_history (hostel_id);
create index if not exists layout_peeks_hostel_id_idx on public.layout_peeks (hostel_id);
create index if not exists layout_waits_hostel_id_idx on public.layout_waits (hostel_id);
create index if not exists manager_invites_hostel_id_idx on public.manager_invites (hostel_id);
create index if not exists meter_readings_hostel_id_idx on public.meter_readings (hostel_id);
create index if not exists move_requests_hostel_id_idx on public.move_requests (hostel_id);
create index if not exists move_requests_stay_id_idx on public.move_requests (stay_id);
create index if not exists move_requests_to_bed_id_idx on public.move_requests (to_bed_id);
create index if not exists owner_invites_hostel_id_idx on public.owner_invites (hostel_id);
create index if not exists payments_hold_id_idx on public.payments (hold_id);
create index if not exists payments_hostel_id_idx on public.payments (hostel_id);
create index if not exists payments_stay_id_idx on public.payments (stay_id);
create index if not exists review_reports_hostel_id_idx on public.review_reports (hostel_id);
create index if not exists reviews_hostel_id_idx on public.reviews (hostel_id);
create index if not exists reward_ledger_hostel_id_idx on public.reward_ledger (hostel_id);
create index if not exists shape_requests_hostel_id_idx on public.shape_requests (hostel_id);
create index if not exists stays_bed_id_idx on public.stays (bed_id);
create index if not exists stays_hostel_id_idx on public.stays (hostel_id);
create index if not exists strikes_case_id_idx on public.strikes (case_id);
create index if not exists strikes_hostel_id_idx on public.strikes (hostel_id);

-- The signed-in user's own rows (RLS checks and "my …" lists).
create index if not exists hostel_staff_user_id_idx on public.hostel_staff (user_id);
create index if not exists stays_user_id_idx on public.stays (user_id);
create index if not exists holds_tenant_id_idx on public.holds (tenant_id);
create index if not exists enquiries_tenant_id_idx on public.enquiries (tenant_id);
create index if not exists payments_payer_id_idx on public.payments (payer_id);
create index if not exists reviews_author_id_idx on public.reviews (author_id);
create index if not exists complaints_author_id_idx on public.complaints (author_id);
create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);
create index if not exists push_outbox_user_id_idx on public.push_outbox (user_id);
create index if not exists reward_ledger_user_id_idx on public.reward_ledger (user_id);
create index if not exists layout_fixes_author_id_idx on public.layout_fixes (author_id);
create index if not exists move_requests_user_id_idx on public.move_requests (user_id);
create index if not exists join_answers_tenant_id_idx on public.join_answers (tenant_id);
create index if not exists invite_signups_user_id_idx on public.invite_signups (user_id);
create index if not exists meal_ratings_user_id_idx on public.meal_ratings (user_id);

-- Server jobs: the push sender looks for unsent pushes; hold expiry scans active holds.
create index if not exists push_outbox_unsent_idx on public.push_outbox (created_at) where sent_at is null;
create index if not exists holds_status_expires_idx on public.holds (status, expires_at);
