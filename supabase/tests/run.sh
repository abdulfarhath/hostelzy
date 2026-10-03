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
$P -d $DB -f tests/wave1_test.sql
