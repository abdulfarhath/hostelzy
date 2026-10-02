#!/usr/bin/env bash
# Runs the migrations, the RLS tests and the B5 server-rule tests on a throwaway local Postgres 16.
# Usage: PGHOST=/var/tmp/hzpg PGPORT=54329 supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
P="psql -U ${PGUSER:-postgres} -v ON_ERROR_STOP=1 -q"
$P -d postgres -c 'drop database if exists hz_rls_test' -c 'create database hz_rls_test'
$P -d hz_rls_test -f tests/stub.sql
for f in migrations/*.sql; do $P -d hz_rls_test -f "$f"; done
$P -d hz_rls_test -f tests/rls_test.sql
$P -d hz_rls_test -f tests/b5_test.sql
$P -d hz_rls_test -f tests/b7_test.sql
$P -d hz_rls_test -f tests/console_test.sql
$P -d hz_rls_test -f tests/delete_test.sql
$P -d hz_rls_test -f tests/invites_test.sql
$P -d hz_rls_test -f tests/holds_test.sql
$P -d hz_rls_test -f tests/residents_test.sql
$P -d hz_rls_test -f tests/invoices_test.sql
$P -d hz_rls_test -f tests/reviews_test.sql
$P -d hz_rls_test -f tests/fairplay_test.sql
$P -d hz_rls_test -f tests/managers_test.sql
$P -d hz_rls_test -f tests/layoutfix_test.sql
