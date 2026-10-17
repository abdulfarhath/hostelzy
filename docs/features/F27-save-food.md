# F27 · Save food: "Are you eating?" headcount (founder idea, 2026-10-06)

**Stage:** Ideas → Designing → **Design approved** (founder, 2026-10-06, proposal canvas v11) → **Built · prototype first** (2026-10-17, on top of F26; not on `main`).

## Problem
Hostels cook for everyone, every meal. Many residents skip meals (office, travel, weekends home). The food is wasted
and the owner pays for it. If residents say in advance whether they'll eat, the kitchen cooks the right amount.

## How it works
| Who | What |
|---|---|
| Resident | Before each meal, taps **Eating** or **Skip**. Default is Eating, so nobody goes hungry by mistake. Can plan ahead for the week (e.g. skip Sat–Sun, going home) |
| Owner | Sees the headcount per meal: "Dinner tonight: 34 of 40 eating". Cooks for 34 |
| Hostelzy | Counts plates saved: resident, hostel, and across Hostelzy. Shows it as a green number (green = savings) |

Rules:
- **Cut-off**: the owner sets how long before a meal the count closes (default 3 h). After cut-off, a skip still counts for the next meal only.
- Reminder push to residents 1 h before cut-off: "Dinner at 8. Eating? Tap Skip if not." Only to residents who haven't answered that day.
- Push to the owner at cut-off: "Dinner headcount: 34 of 40". The owner sees counts; names only in a "Who's skipping" list for the kitchen (residents, not tenants).
- Plates saved = skips. 1 skip = 1 plate. Weekly and lifetime totals.
- Honest: the hostel page says "This hostel cooks to count: N plates saved" only once there is real data.

## Screens (design these only)
| # | Screen | What's on it |
|---|---|---|
| F27-1 | **Resident Home · Next meal card** (replaces the "today's food" row) | "Dinner · 8:00 pm · Chapati, dal" · two big buttons **Eating ✓** / **Skip** · under it: "Closes at 5:00 pm · 31 eating so far" · a green chip "You saved 3 plates this week" |
| F27-2 | **Week plan** (opens from the card: "Plan the week ›") | 7 days × Breakfast / Lunch / Dinner grid; tap a cell to toggle ✓ / skip; "Skip all weekend" shortcut; cut-off note |
| F27-3 | **Owner Today · Headcount card** (new group item on Today) | "Dinner tonight · 34 of 40 eating" with a bar; "Closes 5:00 pm"; tap → F27-4 |
| F27-4 | **Owner · Meals** (from Manage) | Today's 3 meals with counts and the "Who's skipping" list; 7-day table of counts; setting: cut-off hours; "Plates saved this month: 412" in green |
| F27-5 | **Resident push** (notification) | "Dinner at 8 · Eating? [Eating] [Skip]" with action buttons |
| F27-6 | **Plates saved** (Me → Rewards area, one card) | "You saved 23 plates · Anjani Residency saved 412 · Hostelzy saved 9,870". Green |
| F27-7 | **Hostel page line** (tenant) | Under food: "Cooks to count · 412 plates saved" green chip (only when real) |

Creative hook: the number is the feature. Plates saved shows on the resident's Home, the owner's Today, the hostel page and
(later) the owner's poster. Optional: a monthly "Most plates saved" line for the hostel (no individual leaderboards: nobody
is shamed for eating).

## Not now
- Money: no rent reduction per skipped meal (changes money rules; founder decision later).
- Guests and extra plates (a resident bringing a friend): later.

## Build
**Built · prototype first, waiting for F26 and the founder** (branch `feature/f27-save-food`, on top of `f26/integration` with
the 12 F26 reverts; must not merge before F26).

| Board | In the app |
|---|---|
| F27-1 | Resident Home (S23): `NextMealCard` above the week table: next meal, menu line, **Eating ✓** / **Skip**, "Closes at …", count so far, green "You saved N plates this week", "Plan the week ›" |
| F27-2 | **S90 `rMeals`** Week plan (`WeekPlanScreen`): today first, 7 days × 3 meals, tap to toggle, closed meals locked, **Skip all weekend**, cut-off note, green weekly saving |
| F27-3 | Owner Today (S36): `HeadcountCard` under the Fair Play pin: "Dinner tonight · 34 of 40 eating", bar, "Closes …", "6 skipping · cook for 34" → S91 |
| F27-4 | **S91 `oMeals`** Owner Meals (`OwnerMealsScreen`): green plates saved this month, today's 3 meals, "Who's skipping" (names + bed), next 7 days, cut-off 2 h / 3 h / 4 h |
| F27-5 | Meal ask push (data `kind: food`) with **Eating** / **Skip** buttons (`reminders.dart`, `push.dart`, `supabase/functions/_shared/fcm.ts`) |
| F27-6 | Stay Rewards (S22): `PlatesSavedCard` (you · this hostel · Hostelzy), green, no ranking of people |
| F27-7 | Hostel page (S13): `CooksToCountChip` "Cooks to count · N plates saved", only with real numbers |

- **Server:** `supabase/migrations/20261006120000_f27_save_food.sql` (rerun-safe): `meal_rsvp` (RLS: a resident reads and changes their own
  answers while the meal is open, the hostel's staff and the team read; no delete), `hostels.meal_cutoff_hours` (2–4, default 3), RPCs `rsvp_meals` (confirmed residents of
  this hostel only; a closed meal is refused), `set_meal_cutoff` (owner / managers), `food_board`, `hostel_plates`, and
  `food_pushes()` on pg_cron every 5 min (ask before the cut-off, owner headcount at the cut-off). Bundles regenerated.
  FOUNDER-TODO **4zf27**. Until it runs the app hides the next-meal card, the headcount card, Manage › Meals and the chip.
- **Screens:** +S90, +S91 (SCREENS app 157, overall 179); variants of S23, S36, S13, S22, S80, S39; push not counted.
- **Prototype:** jump buttons "Save food · Home" (`start=rHome&role=resident`) and "Save food · Owner meals" (`start=oMeals&role=owner`).
- **Tests:** `hostelzy/test/f27_save_food_test.dart` (8 flows: card, week plan, owner headcount + Meals, server + before the SQL,
  push buttons, plates saved + chip, Settings switch, dark + 2× text at 360 px). SQL `supabase/tests/f27_save_food_test.sql`
  (who can answer: residents only, anon refused with "permission denied"; who reads what; cut-off; push timing).
  `fcm.test.ts` for the food kind.

### Approved extras (founder 2026-10-17)
First listed as "Not in the spec"; the founder approved all 6 through the hub on 2026-10-17. They stay in the build.
| # | What | Why it is there |
|---|---|---|
| 1 | Settings › **Meals** notification switch (residents, owners) | the meal pushes needed their own `food` kind so people can turn them off |
| 2 | Manage › **Meals** row | the spec says S91 opens "from Manage"; the row is how |
| 3 | Owner headcount push at the cut-off ("Dinner headcount: 34 of 40") | listed in the spec's Rules, but not drawn as a board |
| 4 | Quiet hours: no meal asks 10 pm–7 am; breakfast asks go at 9 pm the evening before | an ask at 3:30 am for breakfast would wake people |
| 5 | Plates saved counted only after a meal's count closes | a skip can still change before the cut-off |
| 6 | Notification buttons open the app (saving needs the session) | Eating / Skip can't save from a closed app |
| — | Also: demo / test clock fixed at 2:30 pm on the sample day (real India time in the Play build); meal asks are data-only pushes, so older builds don't show them | |

## Design
**Design approved** (founder, 2026-10-06). On the main canvas: S23 and S36 updated, new S90 Week plan and S91 Owner Meals (provisional ids), Plates saved = variant of S22, chip = variant of S13, push = not counted.

Drawn on the F26 proposal canvas (https://claude.ai/artifact/QXYxc9NdqqtJCarAy2XS7g), version 11 (2026-10-06), row **F27 · Save food**.
8 boards: 7 light + 1 dark, each 390×844 with current tokens. Green only on the plates-saved numbers.

| Board | Shows |
|---|---|
| [F27-1] Resident Home · Next meal card | "Dinner · 8:00 pm · Chapati, dal", big **Eating ✓** / **Skip**, "Closes at 5:00 pm · 31 eating so far", green "You saved 3 plates this week", "Plan the week ›"; the week table stays below |
| [F27-1] [dark] | Same, dark |
| [F27-2] Week plan | Today first, 7 days × Breakfast / Lunch / Dinner; ✓ cells filled, Skip cells dashed; **Skip all weekend**; cut-off note; green "This week you're saving 8 plates" |
| [F27-3] Owner Today · Headcount card | "Dinner tonight · 34 of 40 eating", bar, "Closes 5:00 pm", "6 skipping · cook for 34" (tap → F27-4); sits under the Fair Play pin, above the groups |
| [F27-4] Owner · Meals | Green "Plates saved this month 412"; today's 3 meals with counts; "Who's skipping dinner · 6" (names + bed); next 7 days count table; cut-off 2 h / **3 h** / 4 h |
| [F27-5] Resident push | "Dinner at 8 · Eating?" with **Eating** / **Skip** actions; sent 1 h before cut-off to residents who haven't answered |
| [F27-6] Plates saved | Green card: "You saved 23 plates" · Anjani Residency 412 · Hostelzy 9,870; no ranking of people |
| [F27-7] Hostel page | Green chip "Cooks to count · 412 plates saved" under the food kicker (only with real data) |

Note for Build: the Home card sits above the week table (F26 #4 keeps the table always open).
