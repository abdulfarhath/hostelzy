#!/usr/bin/env bash
# Runs the migrations, the RLS tests and the B5 server-rule tests on a throwaway local Postgres 16.
# Usage: PGHOST=/var/tmp/hzpg PGPORT=54329 supabase/tests/run.sh   (HZDB=name to use another test database)
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${HZDB:-hz_rls_test}"
P="psql -U ${PGUSER:-postgres} -v ON_ERROR_STOP=1 -q"
$P -d postgres -c "drop database if exists $DB" -c "create database $DB"
$P -d $DB -f tests/stub.sql
for f in migrations/*.sql; do $P -d $DB -f "$f"; done
$P -d $DB -f tests/rls_test.sql
$P -d $DB -f tests/b5_test.sql
$P -d $DB -f tests/b7_test.sql
$P -d $DB -f tests/console_test.sql
$P -d $DB -f tests/delete_test.sql
$P -d $DB -f tests/invites_test.sql
$P -d $DB -f tests/holds_test.sql
$P -d $DB -f tests/residents_test.sql
$P -d $DB -f tests/invoices_test.sql
$P -d $DB -f tests/reviews_test.sql
$P -d $DB -f tests/fairplay_test.sql
$P -d $DB -f tests/managers_test.sql
$P -d $DB -f tests/layoutfix_test.sql
$P -d $DB -f tests/rewards_test.sql
$P -d $DB -f tests/reminders_test.sql
$P -d $DB -f tests/fixextras_test.sql
$P -d $DB -f tests/holdpush_test.sql
$P -d $DB -f tests/complaintphoto_test.sql
$P -d $DB -f tests/amenities_test.sql
$P -d $DB -f tests/food_test.sql
$P -d $DB -f tests/owner_phone_test.sql
$P -d $DB -f tests/onboard_test.sql
$P -d $DB -f tests/moves_test.sql
$P -d $DB -f tests/values_test.sql
$P -d $DB -f tests/shapes_test.sql
$P -d $DB -f tests/wave2a_test.sql
$P -d $DB -f tests/confirm_test.sql
$P -d $DB -f tests/lockeddeal_test.sql
$P -d $DB -f tests/joined_test.sql
$P -d $DB -f tests/wave1_test.sql
$P -d $DB -f tests/wave4a_test.sql
$P -d $DB -f tests/wave3a_test.sql
$P -d $DB -f tests/fairhard_test.sql
$P -d $DB -f tests/wave4c_test.sql
$P -d $DB -f tests/wave4b_test.sql
$P -d $DB -f tests/strikedeals_test.sql
$P -d $DB -f tests/rates_confirm_test.sql
$P -d $DB -f tests/indexes_test.sql

# Rerun safety: the founder's one-file bundle (docs/sql/run-all-pending.sql) must succeed twice on the
# same database. Fresh database: the migrations already run in production (before the bundle's FROM),
# then the bundle, then the bundle again.
FROM=$(sed -n 's/^FROM=\([0-9]*\).*/\1/p' ../tools/sql-bundle.sh)
$P -d postgres -c "drop database if exists ${DB}_bundle" -c "create database ${DB}_bundle"
$P -d ${DB}_bundle -f tests/stub.sql
for f in migrations/*.sql; do [ "$(basename "$f" | cut -c1-14)" \< "$FROM" ] && $P -d ${DB}_bundle -f "$f"; done
$P -d ${DB}_bundle -f ../docs/sql/run-all-pending.sql
$P -d ${DB}_bundle -f ../docs/sql/run-all-pending.sql
$P -d postgres -c "drop database ${DB}_bundle"
echo " ALL BUNDLE TESTS PASSED (run-all-pending.sql twice)"
