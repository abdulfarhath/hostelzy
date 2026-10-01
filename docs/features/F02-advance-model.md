# F02 · Fix the advance model

**Stage:** Spec ready · no design needed

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
- Notice 15 or 30 days? Fee due on joining date or the 1st? Electricity/food included? (BOARD Q5, Q6)

## Design
Not needed: reuse existing screens, change copy and numbers only.

## Build
_Not started._
