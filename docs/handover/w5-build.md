# Wave 5 handover · Build 5 · F31 "no explanations, priority order" · 2026-10-18

Branch **`feature/w5-clean`** (from `main` @ 6bf2983). Integrated last by Build 1. No SCREENS/BOARD edits here.

## What changed (read `docs/features/F31-no-explanations-priority.md`, Build section, for every line)
| Area | Change |
|---|---|
| Rule A, app | 130+ helper lines removed or shortened to a value/state across `hostelzy/lib/features/**` (audit table = the list). 153 toasts cut to ≤ 6 words. Delete-account and review-reply placeholders dropped. |
| Rule B, app | S36 Owner Today: `MoneyStrip` (new, key `moneyStrip`) → Needs-you tabs → Fair Play card only while a case is open → This month → Headcount → cards. S23 Home: rent → next meal → food week → 3 actions → review. Manage, Me and Settings reordered (Settings groups: Account · Notifications · Language · About; Delete account last). |
| Retired | Sheet **#41 `waterOffer`**, `maybeOfferReminders()`, `acceptOffer()`, `remOffered`, `WaterOfferSheet`, `TodayCard`, `showToday`. Explore and Home no longer call the offer. |
| SQL | New `supabase/migrations/20261018120000_f31_push_copy.sql`: six functions redefined with shorter push bodies. `docs/sql/run-all-pending.sql` + `full-schema.sql` regenerated with `tools/sql-bundle.sh`. Ships itself from `main`. |
| Web | `app/index.html`, `app/r/index.html`, `app/j/index.html`, `app/console/console.js`: helper paragraphs removed / shortened. `app/delete-account/` untouched. |
| Tests | 46 assertions + ~70 toast assertions updated (marked `// F31`); offer-sheet tests replaced by "no offer sheet on the 3rd app open". |

## For the integrator (Build 1)
1. `docs/SCREENS.md`: remove sheet row **#41 `waterOffer`** (Shared sheets 7 → 6, app sheets 44 → 43, total 157 → 156), and
   update the Today/Home/Manage/Settings descriptions if they list an order. `docs/BOARD.md`: F31 Build status.
2. Shared files touched (merge with care): `lib/ui/shell.dart` (3 lines, the `waterOffer` sheet map/title/kicker),
   `lib/features/owner/owner_today_screen.dart`, `owner_manage_screen.dart` (Build 2 adds the Joining tab and the Tenant IDs row:
   its slot is between House rules and Team), `session/settings_screens.dart`, `session/me_screen.dart`,
   `residents/resident_screens.dart`, `explore/explore_screen.dart`, `reminders/*`.
3. `oStrike` is no longer reachable from Today when there is a strike but no open case (spec side effect; hub decides).
4. The language packs are empty, so nothing to drop there; `docs/i18n/te-review.md` still lists the old lines (Hub/i18n owner).

## Checks
See the bottom of this file for the `tools/check.sh` result on the last commit.
