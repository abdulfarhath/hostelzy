#!/usr/bin/env bash
# Everything CI checks, in one command, from any directory:
#   tools/check.sh          analyze + Flutter tests + SQL tests + push/console function tests
#   tools/check.sh --fast   analyze + Flutter tests only
# SQL tests need Postgres 16. If PGHOST/PGPORT aren't set, a throwaway server is
# started in /var/tmp/hzpg (port 54329) and left running for the next call.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/flutter/bin:$PATH"

step() { printf '\n== %s\n' "$1"; }

step "flutter analyze"
(cd "$ROOT/hostelzy" && flutter analyze)

step "flutter test"
(cd "$ROOT/hostelzy" && flutter test)

[ "${1:-}" = "--fast" ] && { echo; echo "OK (fast)"; exit 0; }

step "SQL tests (supabase/tests/run.sh)"
if [ -z "${PGHOST:-}" ]; then
  PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
  [ -n "$PGBIN" ] || { echo "No Postgres found: install postgresql-16 or set PGHOST/PGPORT."; exit 1; }
  export PGHOST=/var/tmp/hzpg PGPORT=54329
  if ! "$PGBIN/pg_isready" -h "$PGHOST" -p "$PGPORT" -q; then
    mkdir -p "$PGHOST"
    run() { if [ "$(id -u)" = 0 ]; then chown postgres "$PGHOST"; su postgres -c "$*"; else sh -c "$*"; fi; }
    [ -d "$PGHOST/data" ] || run "$PGBIN/initdb -D $PGHOST/data -A trust -U postgres >/dev/null"
    run "$PGBIN/pg_ctl -D $PGHOST/data -o '-k $PGHOST -p $PGPORT -c listen_addresses=' -l $PGHOST/log start >/dev/null"
  fi
fi
HZDB="${HZDB:-hz_check}" bash "$ROOT/supabase/tests/run.sh" >/tmp/hz_sql.log 2>&1 || { tail -20 /tmp/hz_sql.log; exit 1; }
grep -c "PASSED" /tmp/hz_sql.log | xargs -I{} echo "{} SQL test files passed"

step "push / console function tests"
(cd "$ROOT" && node --experimental-strip-types --test supabase/functions/tests/*.test.ts 2>&1 | grep -E '^# (pass|fail)')

echo; echo "OK"
