# F02 · Fix the advance model

**Stage:** Built (2026-10-01) · no design needed · waiting on merge

## Problem
The app copies a "2 months' deposit" model. Hyderabad and Chennai hostels charge a ₹3,000 advance plus the first month, and keep ₹1,000–1,500 maintenance from the advance on exit.

## What it does
- Hostel page rules: "Advance ₹3,000 · Exit maintenance ₹1,000" (per hostel values in `data.dart`).
- Hold steps: "Pay ₹3,000 advance + first month at move-in".
- Resident Pay rent: "Advance ₹3,000 · ₹2,000 back when you leave" instead of "₹15,200 held".
- Move out: refund = advance − maintenance, with notice date.
- Owner bed sheet / add booking: show advance and maintenance.

## Rules
- Values per hostel: advance, exit maintenance, notice days, fee due day.

## Open questions
- ~~Notice 15 or 30 days? Fee due on joining date or the 1st? Electricity included?~~ Answered 2026-10-01: 30 days, joining date, electricity extra.
- Food included in the fee, or extra? (rest of BOARD Q6)

## Design
Not needed: reuse existing screens, change copy and numbers only.

## Build
Branch `feature/f02-advance-model` (2026-10-01).

**Model.** New `Terms` per hostel in `lib/data.dart`: `advance` (₹3,000), `maintenance`
(₹1,000; Sai Sri and Nest 42 ₹1,500, Orchid ₹1,200), `noticeDays`, `dueOnJoining`,
`electricityExtra`; `refund = advance − maintenance`. Helpers `leaveDates`, `dueNote`,
`dueLeft` work from the sample "today" (1 Oct 2026). Food still comes from `Hostel.food`.

**Founder answers (2026-10-01, Build chat):** 30 days notice, fee due on the joining date,
electricity extra. These are the `Terms` defaults. Food: not answered yet, stays as each
hostel lists it (`Hostel.food`).

**Screens changed**
- Tenant · hostel page rules: Notice period, Advance "₹3,000 + first month at move-in",
  Exit maintenance "₹1,000 kept from the advance", Fee due, Electricity (no more "2 months' rent").
- Tenant · hold status, last step: "Pay ₹3,000 advance + first month at move-in."
- Resident · home rent card and Pay rent: due date from the joining date ("Due 14 Oct · 13 days left").
- Resident · Pay rent: "Advance ₹3,000 paid 14 Mar · ₹2,000 back when you leave" (was "₹15,200 held").
- Resident · Move out: notice period and last-day choices from `noticeDays`; refund
  block "Advance paid ₹3,000 / Exit maintenance − ₹1,000 / Refund ₹2,000 within 7 days";
  timeline "₹2,000 back to your UPI".
- Owner · bed sheet: "Advance ₹3,000 · ₹1,000 kept on exit"; "Mark as leaving" uses the notice date.
- Owner · add booking: Advance row and "Due at move-in" (advance + first month).
- Owner · More → Rules: Advance, Exit maintenance, Fee due, Electricity replace "Security deposit".
- Owner · rent list: Rahul and Nikhil's "Due" dates follow the joining-date rule.

**Not changed (belongs to F04):** hold options (free / ₹299 paid / ₹2,000 "Book now" token).

**Tests:** `test/flows_test.dart` → "advance model …" flow (tenant, resident, owner) and
"advance terms helpers". `flutter analyze` clean, `flutter test` 10/10.
