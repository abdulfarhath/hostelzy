# F08 · Verified reviews and Hostelzy score

**Stage:** Design ready · 2026-10-02

## Problem
Google reviews can be faked; tenants trust reviews from real residents.

## What it does
- Only OTP-verified users with a confirmed stay can review; one per stay. Owner can reply, not delete.
- Asked after 30 days (food, cleanliness, safety, water/power, owner) and at exit ("Did you get your advance back?").
- Shown as "4.4 · 38 verified residents" with category bars; weighted average, recent counts more.
- Hostelzy score for ranking: reviews, advance-refund honesty, deal strength, reply speed, bed map freshness, complaints fixed in 72 h, minus strikes.

## Rules
- Owner can't review own hostel.

## Open questions
None.

## Design
Canvas https://claude.ai/artifact/SrKtvDbCkUG4ThnkdXsZ7F. Awaiting founder approval.

1. **Resident: 30-day review.** Overall stars, 1–5 for Food, Cleanliness, Safety, Water and power, Owner; "Is the room layout accurate? Yes / Mostly / No" (F12); optional text. Shows as "Ravi T. · verified resident". Footer: only confirmed stays can review, one review per stay, editable.
2. **Resident: exit review.** "Did you get your advance back?" with the expected amount worked out from the locked deal (₹3,000 − ₹500 = ₹2,500): Yes, all / Only part / Not yet. Then overall stars and "Would you stay again?". The answer feeds the hostel's "advance returned" record.
3. **Tenant: reviews on the hostel page.** "4.4 · 38 verified residents · recent stays count more", category bars, two trust tiles ("Advance back in full 35 of 36", "Layout accurate 92%"), review cards with a "Verified stay" tag and how long they stayed, and the owner's reply shown under the review.
4. **Tenant: Explore ranked by Hostelzy score.** "Hostelzy score" is the first sort chip, with a one-line explanation and "How it works". Cards show rank #1–3, the score box, verified rating and the reason ("Advance back 35 of 36 · replies in 12 min").
5. **Owner: Hostelzy score breakdown.** 86, #1 of 9 in Madhapur, with a bar per factor (reviews, advance honesty, deal strength, reply speed, bed status fresh, complaints fixed in 72 h), tips on how to gain points, and Fair Play strikes taken off.
6. **Owner: reply to a review.** New / All / Low rating; reply box under a review; rule: one reply each, reviews can't be removed, only reported for abuse.
- Dark mode: board "3 in dark mode". Every board has a Dark tweak.

**Design questions for the founder**
- The score weights shown (30/20/15/10/10/15) are placeholders. Do you want to set them, or let the Ideas chat decide?
- Should tenants see the score number, or only the rank and the reasons?

## Build
_Not started._
