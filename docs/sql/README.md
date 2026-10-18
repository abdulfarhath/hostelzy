# One-file SQL for the founder

| File | When | How |
|---|---|---|
| `run-all-pending.sql` | The real project. Every migration from FOUNDER-TODO 4d onward (41 so far) | **Applies itself:** the "Supabase SQL" GitHub action runs it on every push to `main` that changes SQL, once the `SUPABASE_DB_URL` secret exists (FOUNDER-TODO step 0). By hand if ever needed: Supabase → SQL Editor → New query → paste the whole file → **Run** → "Success. No rows returned" |
| `full-schema.sql` | Only for a **new, empty** project (staging, 6b). All 46 migrations | Enable `pg_cron` + `pg_net` first (Database → Extensions), then paste → Run, once |

- Both run as **one transaction**: if anything fails, nothing changes. Send the error to the hub.
- `run-all-pending.sql` is **safe to run again**, including after some steps were run one by one. Tested: fresh, twice, half-done, and all SQL tests pass afterwards.
- **Check it worked:** `check.sql`. The action runs it after each apply and fails if any column is false. To check by hand, paste it into the SQL Editor: every column should be `true`.
- **Build:** after adding a migration, run `tools/sql-bundle.sh` (and `--full`) and commit both files; the merge to `main` applies it. Add a column to `check.sql` when a migration adds something worth checking. `FROM` in the script stays at 4d: the file is safe to run again, so it never needs trimming.
