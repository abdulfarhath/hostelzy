# F03 · Hostelzy deals

**Stage:** Built (2026-10-02) · waiting on founder merge

## Problem
Tenants need a reason to book through Hostelzy instead of walking in; owners need a cheap way to fill beds.

## What it does
- **Owner:** Manage → Deals: pick up to 3 from the menu (lower exit maintenance, monthly discount, first month off, lower advance, free extra, no joining fee). Shows "tenant saves / year", "costs you / month", deal strength.
- **Tenant hostel page:** green "Hostelzy deal" table, With Hostelzy vs Walk in: monthly fee, advance, to move in, exit maintenance, back when you leave, extras. One headline saving.
- **Explore:** "Save ₹X" ribbon on photos, perk chips, walk-in price crossed out, "Best deals" sort.

## Rules
- Fixed exit rules (maintenance + notice) always on, at no cost to the owner.
- Deal price only through a Hostelzy booking.
- Rates confirmed by owner monthly ("Confirmed by owner · date").
- All savings in rupees, never percentages. Green = savings only; red stays for actions.

## Open questions
None. Decided 2026-10-02: headline = saving over first 6 months (upfront part shown under it), 6-deal menu as is, max 3 active deals.

## Design
Canvas https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn · boards 1 (hostel page), 2 (Explore), 4 (owner deal picker, interactive). Updated 2026-10-02 for DECISIONS 2026-10-02. Awaiting founder approval.
- Board 1: headline is now "You save in the first 6 months ₹1,200", with "₹200 less to move in + ₹200/month" under it and "Plus ₹1,000 more back when you leave" beside it. New line under the exit rules: "Owner's number shows after you hold a bed. Talking through Hostelzy keeps your deal and your ₹100 reward."
- Board 2: ribbons use the 6-month saving ("Save ₹1,200 in 6 mo"); a lower-advance deal reads "₹1,000 less upfront".
- Board 4: the owner summary shows "Tenant saves · 6 months" and "N of 3 picked"; the menu still holds 6 deals and stops at 3.
- Deals per room type (AC / non-AC): see F16 board 6.

## Build
Branch `feature/f03-deals` (2026-10-02), boards 1, 2, 4 and F16 board 6. Built on F16
(`feature/f16-ac-rooms`, PR #4) for deals per room type, with F05 + F06 (PRs #2, #3) merged in.
Merge #2, #3, #4 first; this PR's own diff is then F03 only.

**Model** (`lib/data.dart`): the 6-deal menu with fixed amounts (₹200/month off, ₹500 off the
first month, advance ₹1,000 lower, exit maintenance down to ₹500, free weekly laundry, no ₹1,000
joining fee), `Deals` per hostel (up to 3, target all / AC only / non-AC only, confirmed date)
and `DealQuote` (walk-in vs Hostelzy: monthly fee, first month, advance, joining fee, to move in,
exit maintenance, back when you leave, 6-month saving, upfront saving, ribbon text).
Sample deals: Anjani (exit, monthly, laundry · all rooms), Sai Sri (exit, lower advance),
Greenview (first month off, exit), Orchid (monthly · non-AC), Nest 42 and Lakshmi none.

**Screens**
- Tenant · hostel page: green "Hostelzy deal" table, With Hostelzy vs Walk in, headline
  "You save in the first 6 months ₹1,200" with "₹200 less to move in + ₹200/month" and "Plus ₹500
  more back when you leave"; Non-AC / AC switch (F16 board 6) with "No Hostelzy deal on non-AC
  rooms… See the deal on AC rooms"; exit-rules line (always on); bottom bar "₹X walk in" struck,
  "₹Y to move in", **Book with deal** (opens the picker on that room type). The F16 grid turns
  green with the walk-in price struck for covered rooms, plus the "Hostelzy deal: … · all rooms" strip.
- Tenant · Explore: green ribbon on the photo ("Save ₹1,200 in 6 mo", "₹1,000 less upfront"),
  perk chips, Hostelzy price with walk-in struck on the F16 type lines, "No Hostelzy deal yet",
  and a **Best deals** chip that sorts by the 6-month saving.
- Owner · Manage → **Deals** (new segment): menu of 6 with tenant saving and cost to the owner,
  max 3 (a 4th shows "Pick up to 3"), All rooms / AC only / Non-AC only, always-on exit rules,
  "Tenant saves · 6 months", "Costs you / month", "N of 3 picked · strength", Publish deals
  (sets "Confirmed by owner" to today). The Rooms and rent rate card shows the Hostelzy price and
  a "Deal: … · Change" line that opens the picker.

**Not built here:** "Owner's number shows after you hold a bed" (board 1) belongs to F07 Fair
Play, because "Ask on WhatsApp" (F05) still opens before a hold; booking with the advance and the
locked deal are F04. Manage's 5 segments share the width by label length so they don't wrap.

**Tests:** `test/flows_test.dart` → "Hostelzy deals: Explore badges, deal table, owner picks
deals" and "deal quote maths". The earlier flows now tap "Book with deal" on Anjani (it has a
deal). `flutter analyze` clean, `flutter test` 18/18.
