# F04 · Book with the advance, deal locked

**Stage:** Built (2026-10-02) · waiting on founder merge

## Problem
The prototype's ₹2,000 token and ₹299 paid hold don't match how Hyderabad hostels work.

## What it does
- Booking = pay the ₹3,000 advance (to the owner, not Hostelzy, see DECISIONS) with the deal locked and an HZ code.
- Free 1-hour hold stays for "I'll come and see".
- Locked-deal card lists every perk and "Back when you leave: ₹2,500".

## Rules
- Hostelzy never holds the money. Until payments exist, advance is paid at the hostel; the app records it.

## Open questions
None. Decided 2026-10-02: keep the free 1-hour hold, drop the ₹299 paid hold.

## Design
Canvas https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn, board 3 (Book). Updated 2026-10-02. Awaiting founder approval.
- "Pay the owner to book": "Pay Srinivas today ₹3,000". Footnote: paid by UPI straight to the owner, Hostelzy never holds the money.
- Two buttons: **Pay advance** (red) and **Hold free** ("1 hour · 2 h for Members"). No ₹299 paid hold anywhere.

## Build
Branch `feature/f04-booking` (2026-10-02), board 3, on top of F03 (`feature/f03-deals`, PR #5,
which includes #2–#4). Merge #2, #3, #4, #5 first; this PR's own diff is then F04 only.

- **Hold options:** only **Hold free** (1 hour; "2 h for Members" shown for F09) and **Pay
  advance**. The ₹299 paid hold and the ₹2,000 token are removed everywhere (sheet, hold status,
  Holds list, the all-screens notes).
- **Book bed sheet** (`sheet=hold`, now titled "Book bed 204-D"): room line with type and spot;
  "Pay the owner to book" box (advance refundable, "Pay Srinivas today ₹3,000", first month at
  move-in with the walk-in price struck); green **Your deal is locked** card with the HZ code and
  every perk (Hostelzy monthly fee, exit maintenance, laundry, notice…), or an "exit rules still
  locked" note when the room type has no deal; "Back when you leave ₹2,500 of your ₹3,000";
  footnote "You pay ₹3,000 by UPI straight to Srinivas. Hostelzy never holds your money…".
- **Pay advance** books the bed (taken), records an HZ code the same way as an F05 enquiry
  ("Book · Pay advance", so the owner sees it in "Enquiries from Hostelzy" and F06 matches the
  phone), and stores the advance paid and the locked perks on the hold. Payments are simulated
  (toast) until payments exist; the money goes to the owner, never Hostelzy.
- **Hold status screen:** "Booked · Yours. Advance paid to Srinivas. Show HZ-… when you move in";
  rows for amount paid, HZ code and the locked deal; timeline "Advance paid → Visit and move in
  (pay the first month)". Rent shown is the Hostelzy price.

**Tests:** `test/flows_test.dart` → "book with the advance: deal locked, HZ code, owner sees it";
the free-hold flow now taps "Hold free". `flutter analyze` clean, `flutter test` 19/19.
