#!/usr/bin/env bash
# Builds one paste-and-run SQL file for the founder from supabase/migrations/.
#   tools/sql-bundle.sh                → docs/sql/run-all-pending.sql (from FROM below to the newest migration)
#   tools/sql-bundle.sh --full         → docs/sql/full-schema.sql     (every migration, for a NEW Supabase project)
# After the founder runs run-all-pending.sql, move FROM to the first migration added after that.
# Rerun-safety is tested by supabase/tests: run the bundle twice on one database.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT/supabase"
FROM=20261002080000   # first migration the founder hasn't run (FOUNDER-TODO 4d)
if [ "${1:-}" = "--full" ]; then FROM=0; OUT="$ROOT/docs/sql/full-schema.sql"; WHAT="every migration, for a NEW Supabase project (staging)"
else OUT="$ROOT/docs/sql/run-all-pending.sql"; WHAT="every pending step (FOUNDER-TODO 4d onward)"; fi
files=$(ls migrations/*.sql | awk -F/ -v f="$FROM" '$2 >= f')
{
  echo "-- Hostelzy: $WHAT, in ONE file. Generated $(date -u +%F) by tools/sql-bundle.sh."
  echo "-- How: Supabase → SQL Editor → New query → paste this whole file → Run → \"Success. No rows returned\"."
  if [ "$FROM" = 0 ]; then echo "-- One transaction: if anything fails, nothing changes. Run it ONCE on an empty project. First enable pg_cron and pg_net (Database → Extensions)."
  else echo "-- One transaction: if anything fails, nothing changes. Safe to run again. Send any error to the hub."; fi
  echo "begin;"
  for f in $files; do
    echo; echo "-- ================================================================"; echo "-- $(basename "$f")"; echo "-- ================================================================"
    # a later step changes owner_contacts' columns; drop first so a second run works
    [ "$(basename "$f")" = 20261002231000_f24_owner_phone.sql ] && echo "drop function if exists public.owner_contacts(uuid[]);"
    cat "$f"; echo
  done
  echo "commit;"
} > "$OUT"
echo "wrote $OUT ($(echo "$files" | wc -l) migrations)"
