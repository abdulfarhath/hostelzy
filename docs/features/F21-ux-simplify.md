# F21 · Simpler UI/UX (Airbnb-level clarity)

**Stage:** Spec ready · founder asked 2026-10-02 ("minimal, easy for all users, like Airbnb").
Source: code audit of every screen (Ideas chat, 2026-10-02). Ideas chat decides details (standing approval).

## Principle
Each home screen has **one job**: Explore = find a bed · resident Home = rent and food · owner Today =
what needs you now. Everything else lives in Me / Manage with a badge when it needs attention.
Plain words, one verb per flow, real data only.

## Fix list (do in this order)
**Wave 1: honesty bugs (break DECISIONS "no fake behaviour")**
1. Resident screens show hard-coded sample data (Anjani Residency, Room 204, ₹8,020, Srinivas, Thursday
   menu, fake "Room 204 board" posts) → bind to the resident's real hostel/rent/owner/menu; hide the board
   until real. (`ui/screens_resident.dart`, `ui/shell.dart:581`)
2. Owner onboarding asks for an SMS code that is never sent and accepts any 6 digits; same pattern in
   ConfirmStayScreen → replace with an "I agree" checkbox + 3 plain bullets; details in Settings → Fair Play.
3. Avatar initials hard-coded "SR"/"RV" → from the user's name.

**Wave 2: first impression + booking**
4. Browse as a guest: Welcome's main button "Find a bed" → Explore; Google + phone asked at first hold or
   enquiry; small "I run a PG" link for owners. (Women's PG layouts still need sign-in, per DECISIONS.)
5. No prompts on first arrival: water-reminder offer only after the 3rd app open; notifications asked
   after the first hold/enquiry ("so the owner's reply reaches you").
6. Hostel cards lead with the first real photo (fallback "No photos yet").
7. Explore top: one search bar + one filter row; sort moves into the filter sheet; remove the ranking
   paragraph; show rank once.
8. One typed "Where?" field (areas + landmarks + hostel names) used by Explore and Map; Search tab → Saved.
9. Card shows real cost: "₹7,600/mo · ₹10,600 to move in · electricity extra".
10. One verb: "Hold free · 1 hour" and "Pay ₹3,000 to book" as two equal options; pre-select what the
    user tapped.
11. Refund in the same line: "Advance ₹3,000 · ₹1,800 back when you leave".
12. Plain words: HZ code → **Booking code**; UTR → **UPI reference (12 digits, in your UPI app)** with a
    hint image; "Deal locked" → **Your price is fixed**; explain Member once.
13. Detail page: merge the deal into the rent table (Hostelzy price + walk-in price struck through);
    rules collapsed under "House rules ›".
14. Bed picker: Plan stays default (DECISIONS F12); Building folds into Plan; List becomes a
    "See cheapest beds" link.

**Wave 3: resident + owner**
15. Resident Home: quick actions (Pay rent, Raise complaint, Message owner) right under the rent card;
    Give notice → Me › My stay; layout-fix card off Home (stays on room pages).
16. Help: "Send to owner" (not warden), empty state, add photo, show the new complaint inline with status.
17. Owner Today: one **Needs you now** list on top sorted by deadline (holds with countdown, payments to
    confirm, enquiries, layout fixes); KPIs below; rank → Manage.
18. Owner Manage: vertical list of rows with icon + one-line status ("Deals · 2 active").
19. Owner plain words: "Came from the app / Walked in / Joined before Hostelzy"; centre tab "Add tenant".

**Wave 4: everywhere**
20. Telugu first, then Hindi: strings to ARB files; language pick on Welcome.
21. Accessibility: `Tap` gets button semantics + 48×48 hit area; body text ≥ 13–14px (no 10–11px info
    text); text scaling up to 2.0.
22. Skeleton cards while loading; a real "You're offline · Retry" state (never "No hostels" when offline).
23. Inline errors with Retry; toasts only for success; Undo for Release hold / Remove saved.
24. Consistency: one Log out (Settings); theme toggle in Settings; same filter labels everywhere
    ("Co-living", "Under ₹8,000"); "All" clears every filter; active-filter count.

## Design
Redraw only the screens that change; update the All screens canvas with "Updated" tags.

## Build
One PR per wave. Flow tests for guest browsing → first hold sign-in, owner Today queue, offline state.

### Wave 1 · Built · 2026-10-02 (branch `feature/f21-honesty`)
- **Resident screens show the resident's real stay.** On the server, Home, Pay rent, Food, Help, Move out / swap and the review headers use the user's own confirmed stay: hostel, room, bed, rent, join day, owner. Demo builds still show the Anjani sample.
  - Server data: `liveFromRows` now returns `myStay`, the user's own stay row.
  - The "Room 204 board" is gone everywhere.
  - Today's food uses today's weekday. Meal tags (Done / Next / Later) follow the clock.
  - Until the menu is on the server, a resident sees "<owner> hasn’t put the menu on Hostelzy yet". The sample menu is never shown on the server.
- **Rent on the server is real.** "Pay ₹X by UPI" first starts this month's rent payment (`payments`, kind `rent`, with `stay_id`), then UPI → UTR → owner confirms, the same as advances.
  - This also fixes a crash: the old code looked up the sample payment `rent204B`, which doesn't exist on the server.
  - The sample history and the electricity line show only in demo builds.
- **Notice and swap on the server go to the owner on WhatsApp.** The app no longer says "Saved on Hostelzy" when nothing is saved there.
- **No fake codes.**
  - Fair Play: "I agree to the Fair Play rules" checkbox; the rules stay under Settings → Fair Play rules.
  - Confirm stay: "Yes, this is me" in demo builds. On the server it's "Enter the invite code", the real confirmation path, where the owner's approval links the stay.
  - Add resident: "Add resident" (it was "Add and send code"), and the "Waiting OTP" filter is now "Not confirmed".
- **Avatar initials** come from the user's name (they were "SR" / "RV").
- **Tests:** `test/honesty_test.dart` ("F21 W1: …", 2 tests). The test caught two text overflows on Pay rent with longer owner names; both are fixed.

