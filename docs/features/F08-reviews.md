# F08 · Verified reviews and Hostelzy score

**Stage:** Shipped · 2026-10-02

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
Canvas https://claude.ai/artifact/SrKtvDbCkUG4ThnkdXsZ7F. **Design approved by the founder on 2026-10-02.**

1. **Resident: 30-day review.** Overall stars, 1–5 for Food, Cleanliness, Safety, Water and power, Owner; "Is the room layout accurate? Yes / Mostly / No" (F12); optional text. Shows as "Ravi T. · verified resident". Footer: only confirmed stays can review, one review per stay, editable.
2. **Resident: exit review.** "Did you get your advance back?" with the expected amount worked out from the locked deal (₹3,000 − ₹500 = ₹2,500): Yes, all / Only part / Not yet. Then overall stars and "Would you stay again?". The answer feeds the hostel's "advance returned" record.
3. **Tenant: reviews on the hostel page.** "4.4 · 38 verified residents · recent stays count more", category bars, two trust tiles ("Advance back in full 35 of 36", "Layout accurate 92%"), review cards with a "Verified stay" tag and how long they stayed, and the owner's reply shown under the review.
4. **Tenant: Explore ranked by Hostelzy score.** "Hostelzy score" is the first sort chip, with a one-line explanation and "How it works". Cards show rank #1–3, the score box, verified rating and the reason ("Advance back 35 of 36 · replies in 12 min").
5. **Owner: Hostelzy score breakdown.** 86, #1 of 9 in Madhapur, with a bar per factor (reviews, advance honesty, deal strength, reply speed, bed status fresh, complaints fixed in 72 h), tips on how to gain points, and Fair Play strikes taken off.
6. **Owner: reply to a review.** New / All / Low rating; reply box under a review; rule: one reply each, reviews can't be removed, only reported for abuse.
- Dark mode: board "3 in dark mode". Every board has a Dark tweak.

**Updated 2026-10-02 for DECISIONS "Design follow-ups"**
- Board 4: sort chip is "Recommended"; cards show ★ rating from verified reviews and "#N in Madhapur" with reasons ("Quick replies, beds kept up to date"); no score number.
- Board 5 (owner) is now "Your ranking": #1 of 9, factor bars with the weights (reviews 50%, reply speed 15%, beds kept up to date 15%, complaints resolved 10%, listing complete 10%) rated Strong / Good / Can improve; strikes lower the rank. No number shown.

## Build
Branch `feature/f08-reviews` (2026-10-02), boards 1–6 with the 2026-10-02 follow-ups.

**Model.** `Review` (verified stay, stars, categories, layout answer, exit advance answer, owner
reply, new flag) with sample reviews for Anjani; `ReviewStats` per hostel (category averages,
advance back in full of those who left, layout accurate %). `Hostel.rating` / `reviews` are now the
verified-review rating and count (Anjani ★ 4.4 · 38). Ranking: `factors()` gives each hostel's
verified reviews (rating, minus a little under 20 reviews), reply speed (from reply minutes), beds
kept up to date, complaints resolved and listing complete (sample values); weights 50 / 15 / 15 /
10 / 10 (DECISIONS); each Fair Play strike lowers it. The score number is never shown: tenants see
"#N near Hitec City" and the two strongest reasons ("Quick replies, beds kept up to date").

**Screens**
1. Resident · 30-day review (`rReview`, from a card on Home): overall stars, 1–5 per category,
   layout accurate Yes / Mostly / No, optional text, "Shows as Rahul V. · verified resident".
2. Resident · exit review (`rExit`, from "Review your stay" after giving notice): advance paid,
   maintenance, "You should get back" (F02 terms), Yes all / Only part / Not yet, stars, stay again.
   The answer updates the hostel's "advance back in full" record.
3. Tenant · Reviews (`reviews`, tap "★ 4.4 · 38 verified reviews ›" on the hostel page): big rating,
   category bars, "Advance back in full" and "Layout accurate" tiles, review cards with Verified
   stay, stay length, advance answer and the owner's reply.
4. Tenant · Explore: sort chips Recommended (default) / Nearest / Lowest price / Best deals (F03's
   toggle became a sort), the ranking explanation with "How it works" (sheet `rank`), "#N" on the
   photo, "★ 4.4 · 38" and "#1 near Hitec City · reasons" on each card.
5. Owner · Your ranking (`oRank`, from "Reviews and ranking" on Today): #N of 6 near Hitec City,
   what tenants see, one bar per factor with its weight, Strong / Good / Can improve and a tip,
   Fair Play strikes.
6. Owner · Reviews (`oReviews`): New / All / Low rating, Reply → reply box → Post reply (one reply,
   reviews can't be removed).

**Notes.** The ranking is among the 6 sample hostels "near Hitec City" (no areas yet). "Report for
abuse" is the rule text only. Live review data and real factor values come with F13.

**Tests:** `test/flows_test.dart` → "verified reviews, ranking and owner replies". `flutter analyze`
clean, `flutter test` 21/21.
