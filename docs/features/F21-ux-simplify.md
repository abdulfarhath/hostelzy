# F21 · Simpler UI/UX (Airbnb-level clarity)

**Stage:** Design ready · **waiting for founder approval** (founder asked to see a small Before → After demo first; Waves 2–4 wait; Wave 1 honesty bugs go ahead) · design: https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7 · spec ready, founder asked 2026-10-02 ("minimal, easy for all users, like Airbnb").
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
**Design approved · 2026-10-02** (standing approval). Canvas "Hostelzy · F21 Simpler UI": https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7. The screens are also on the All screens canvas as an "F21" row tagged Updated.
Phone boards 390×844, with dark copies of Explore, the hostel page and owner Today. Same tokens; green only for the Hostelzy price.

**W1 (agreements):** Build can start without other design. The two agreement screens replace the fake SMS codes:
- `Agree`: owner "Fair Play rules" with 3 numbered bullets, "Full rules: Settings → Fair Play ›", an **I agree** checkbox row, then "Agree and continue".
- `Stay`: resident "Confirm your stay" with bed, rent and advance bullets, a **This is correct** checkbox, "Yes, that’s right" and "Something wrong? Message Srinivas ›".
- Avatar initials come from the user's name (as in all boards).

**W2:**
- `Main` (Welcome): the main button is **Find a bed** (straight to Explore); "No sign-in needed to look around."; small links "I run a PG · I live in a PG · Sign in". The language row English / తెలుగు / हिन्दी is item 20 (W4) but is placed here.
- `ExploreGuest`, `Explore`, `ExploreDark`:
  - title "Find a bed"
  - one **Where?** bar, then one row: Filters (with a count badge) plus quick chips
  - photo-first cards with a Save heart, rank shown once ("#1 near you") and a green Hostelzy price ribbon only when there's a deal
  - the real-cost line: "₹7,600/mo · ₹10,600 to move in · electricity extra"
  - the tab bar: Explore · Map · **Saved** · Holds · Me; the Search tab is gone
- `Where`: one typed field with Near me, then results grouped as Landmarks / Areas / Hostels. The same field is used on the Map.
- `Filters`: Sort by (Recommended / Nearest / Lowest price), For, Room, Budget, Food, then **Clear all** and "Show 4 hostels".
- `Detail`, `DetailDark`:
  - photo hero
  - "Rent per month" with "Advance ₹3,000 · ₹2,000 back when you leave"
  - one table: Hostelzy price in green with the walk-in price struck through
  - **House rules ›** folded into a row
  - bottom bar "From ₹5,800/mo · ₹8,800 to move in" and "Pick a bed"
- `Hold`: two equal cards, **Hold free · 1 hour** (pre-selected) and **Pay ₹3,000 to book**, with the bed, rent and refund line, then "Hold bed 204-D free".
- `SignIn`: sign-in happens at the first hold ("Sign in to hold this bed"). `Notify`: notifications are asked after the first hold ("so Srinivas’s reply reaches you").
- `Utr`: plain words, **UPI reference** ("12 digits, in your UPI app under the payment") with a hint picture of where to find it.

**W3:**
- `Home` (resident): rent card, then 3 actions (Pay rent / Raise complaint / Message owner), then today's food. No notice or layout-fix cards.
- `Help` (tweak: Empty):
  - category chips, a text box, a camera button and **Send to owner**
  - the new complaint appears inline as "Sent · Srinivas sees it in the app"; other states are "Being fixed" and "Fixed"
  - empty state: "No complaints"
- `Today`, `TodayDark` (owner):
  - **Needs you now · 4**, soonest first: the hold with a countdown, "Received ₹7,000?", a new enquiry, a layout fix, each with its own buttons
  - "This month" KPIs below
  - centre tab **Add tenant**
- `Manage`: one vertical list with an icon and a one-line status, plus red count badges. The rows are Residents, Complaints, Deals, Rates and UPI, Food menu, House rules, Photos, Room layouts, Reviews and ranking, Team, Your plan.

**W4:**
- `Skeleton`: grey placeholder cards while loading.
- `Offline`: "You’re offline" with Retry; never "No hostels".
- `Error`: an inline "Couldn’t load your holds" with Retry, plus an Undo toast ("Hold on bed 204-D released · Undo").
- Plain words everywhere: Booking code, UPI reference, "Your price is fixed".


## Build
One PR per wave. Flow tests for guest browsing → first hold sign-in, owner Today queue, offline state.
