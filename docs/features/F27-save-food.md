# F27 · Save food: "Are you eating?" headcount (founder idea, 2026-10-06)

**Stage:** Ideas → Designing → **Design approved** (founder, 2026-10-06, proposal canvas v11) → **Building** (prototype first, on top of F26).

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

## Build (after approval)
`meal_rsvp` (stay, date, meal, eating bool, answered_at), `hostels.meal_cutoff_hours`, counts RPC, 2 pushes (resident reminder,
owner headcount at cut-off), plates-saved totals. Rerun-safe migration, bundle, FOUNDER-TODO step.

## Design
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
