# One-file SQL for the founder

| File | When | How |
|---|---|---|
| `run-all-pending.sql` | **Now**, on the real project. Covers FOUNDER-TODO 4d → 4zi (37 migrations) | Supabase → SQL Editor → New query → paste the whole file → **Run** → "Success. No rows returned" |
| `full-schema.sql` | Only for a **new, empty** project (staging, 6b). All 45 migrations | Enable `pg_cron` + `pg_net` first (Database → Extensions), then paste → Run, once |

- Both run as **one transaction**: if anything fails, nothing changes. Send the error to the hub.
- `run-all-pending.sql` is **safe to run again**, including after some steps were run one by one. Tested: fresh, twice, half-done, and all SQL tests pass afterwards.
- **Check it worked** (paste and run; every column should be `true`):
  ```sql
  select to_regproc('public.go_live') is not null as onboarding,
         to_regproc('public.confirm_rates') is not null as rates,
         to_regproc('public.deals_hidden') is not null as strikes,
         (select count(*) from pg_indexes where schemaname = 'public'
            and indexname in ('beds_hostel_id_idx','fair_cases_hostel_id_idx')) = 2 as indexes;
  ```
- **Build:** after adding a migration, run `tools/sql-bundle.sh` (and `--full`) and commit both files. After the founder has run the pending file, move `FROM` in the script to the next new migration.
