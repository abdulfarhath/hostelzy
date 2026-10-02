# F21 · Simpler UI/UX (Airbnb-level clarity)

**Stage:** **Design approved by the founder, 2026-10-02** (demo https://claude.ai/artifact/DNTXZPEsMZTRSisLqvpAhG) · all waves go ahead · design: https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7 · spec ready, founder asked 2026-10-02 ("minimal, easy for all users, like Airbnb").
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
**Design ready · 2026-10-02, waiting for the founder’s approval.** Demo for the founder, 7 before → after pairs with a one-line "what changed" each: https://claude.ai/artifact/DNTXZPEsMZTRSisLqvpAhG. Full set: "Hostelzy · F21 Simpler UI" https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7. The All screens canvas gets the "Updated" tags only after approval.
Phone boards 390×844, with dark copies of Explore, the hostel page and owner Today. Same tokens; green only for the Hostelzy price.

**W1 (agreements): cleared to build now** (Ideas chat, 2026-10-02: these are honesty fixes; W2–W4 wait for the founder). The two agreement screens replace the fake SMS codes:
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

### Wave 1 · Built · 2026-10-02 (merged, #65)
- **Resident screens show the resident's real stay.** On the server, Home, Pay rent, Food, Help, Move out / swap and the review headers use the user's own confirmed stay: hostel, room, bed, rent, join day, owner. Demo builds still show the Anjani sample.
  - Server data: `liveFromRows` now returns `myStay`, the user's own stay row.
  - The "Room 204 board" is gone everywhere.
  - Today's food uses today's weekday. Meal tags (Done / Next / Later) follow the clock.
  - Until the menu is on the server, a resident sees "<owner> hasn’t put the menu on Hostelzy yet". The sample menu is never shown on the server.
- **Rent on the server is real.** "Pay ₹X by UPI" first starts this month's rent payment (`payments`, kind `rent`, with `stay_id`), then UPI → UTR → owner confirms, the same as advances.
  - This also fixes a crash: the old code looked up the sample payment `rent204B`, which doesn't exist on the server.
  - The sample history and the electricity line show only in demo builds.
- **Notice and swap on the server go to the owner on WhatsApp.** The app no longer says "Saved on Hostelzy" when nothing is saved there.
- **No fake codes** (designs `Agree` and `Stay`).
  - **Fair Play:** a new owner sees the 3 plain rules, "Full rules: Settings → Fair Play ›", an **I agree** checkbox and **Agree and continue**. The full rules and the strike ladder open from the link and from Settings.
  - **Confirm stay:** 3 lines (bed, rent with its due day, advance with the refund), "Something wrong? Message <owner> ›", a **This is correct** checkbox and **Yes, that’s right**. On the server the confirmation goes through the invite code, which is the real path; the owner's approval links the stay.
  - **Add resident:** the button says "Add resident" instead of "Add and send code". The "Waiting OTP" filter is now "Not confirmed".
- **Avatar initials** come from the user's name (they were "SR" / "RV").
- **Tests:** `test/honesty_test.dart` ("F21 W1: …", 2 tests). The test caught two text overflows on Pay rent with longer owner names; both are fixed.

### Wave 2 · Built · 2026-10-02 (merged, #67)
Designs `Main`, `ExploreGuest`, `Explore`, `Where`, `Filters`, `Detail`, `Hold`, `SignIn`, `Notify`, `Utr`.
- **Look around as a guest.** Welcome's main button is **Find a bed** (straight to Explore, "No sign-in needed to look around."), with links **I run a PG · I live in a PG · Sign in**.
  - Explore shows "Browsing as a guest · Sign in" until the user signs in.
  - Sign-in is asked at the first hold or enquiry, in a sheet: "Sign in to hold this bed" / "Sign in to message <owner>".
  - After Google + name and phone, the hold (or enquiry) goes ahead by itself, and the user is back on the bed picker.
  - Closing the sheet drops it.
  - The language row on the board is Wave 4 (item 20). It isn't shown until the languages exist.
- **No prompts on arrival.**
  - The water-reminder offer waits for the 3rd app open (`opens` is counted on the phone).
  - Tenants are no longer asked for notifications when they pick their role. After their first free hold they see "Bed X is held for you · Turn on notifications so <owner>’s reply reaches you", once.
  - Owners and residents are still asked after sign-in, as before.
- **The notification promise is real.** Migration `20261002200000_f21_hold_reply_push.sql` adds a push to the tenant when the owner (or a manager) keeps or declines a waiting hold: "Bed 101-C is kept for you" / "Bed 101-C wasn’t kept". Nothing is sent when the tenant releases the hold themselves. Test: `supabase/tests/holdpush_test.sql`. FOUNDER-TODO **4r**.
  - The board's "and we remind you before the hour ends" is left out: nothing sends that reminder yet.
- **Explore.**
  - Title "Find a bed", kicker "Hyderabad · N beds free now".
  - One **Where?** bar, then one row: **Filters** (with a count badge) + Men / Women / Co-living / AC / Under ₹8,000. The sort chips and the ranking paragraph are gone.
  - Photo-first cards:
    - the first real photo ("No photos yet" otherwise) and a save heart
    - "#1 near you" once, on the first card when sorted by Recommended
    - a green "Hostelzy price ₹X" when the deal lowers the rent; other deals keep their headline ("₹1,000 less upfront")
    - "Men · Madhapur · 1.6 km from Hitec City · 9 free"
    - "₹7,600/mo · ₹10,600 to move in · electricity extra": the cheapest bed that fits the filters, with move-in = rent + advance (+ joining fee)
- **Where?** is one typed screen used by Explore and the Map. It has Near me, then **Landmarks** ("N hostels within 5 km"), **Areas** ("Coming soon" when empty) and **Hostels** by name, which open the hostel page. The Map's area button is the same bar now.
- **Filters sheet:**
  - Sort by (Recommended / Nearest / Lowest price), For, Room (sharing + AC / Non-AC), Budget, Deals ("Hostelzy deals only") and Food. "Best deals" is no longer a sort; the **Hostelzy deals** chip on Explore keeps deals findable (Ideas chat, 2026-10-02)
  - **Clear all** and "Show N hostels"
  - The title shows "Filters · 2"
  - The Search tab is now **Saved**
- **Hostel page:**
  - one rent table, with the Hostelzy price in green, "₹9,000 walk in" struck through and "N free"
  - a footer line with the deal ("Hostelzy price: ₹200 off every month · ₹500 exit · Free laundry"; "AC rooms only" when it is)
  - "Rent per month · Advance ₹3,000 · ₹2,500 back when you leave"
  - "Same price for every bed of a type. Food included. Electricity extra, by meter."
  - **House rules ›** folded into one row
  - the bottom bar "From ₹7,400/mo · ₹10,400 to move in · 9 free" with **Pick a bed**
  - The separate deal block (`DealBlock`) is gone. The visit block and tags moved below the rules.
- **Hold:** two equal cards, **Hold free · 1 hour** (picked first; 2 hours for Members) and **Pay ₹3,000 to book**, then the bed, rent and refund line and one button: "Hold bed 204-D free" / "Pay ₹3,000 to book". With a deal, the booking card shows the deal and the booking code.
- **Plain words:**
  - HZ code → **Booking code**
  - UTR → **UPI reference** ("12 digits, in your UPI app under the payment"), with a small drawing of a UPI receipt and its three names (UPI Ref. No., UTR, Transaction ID). This covers tenant and resident screens and the owner's payment check.
  - "Deal locked" → **Your price is fixed**
  - Owner invoices to Hostelzy (Plan) say "UPI reference" too, shown once as "UPI reference (UTR)" (Ideas chat, 2026-10-02). Only the Hostelzy team console keeps "UTR".
- **Bed picker:** Plan and Room only. Building folds into Plan's floors, and the list is a **See cheapest beds ›** link.
- **Tests:** `test/guest_test.dart` ("F21 W2: …", 3 tests). It covers Welcome → Find a bed → guest Explore → Where? → Filters → hostel page → hold → sign-in → the hold placed by itself; the Welcome links and the enquiry sign-in; and app-open counting. The older flow tests that used the old words and layout were updated.

### Wave 3 · Built · 2026-10-02 (branch `feature/f21-w3`)
Designs `Home`, `Help`, `Today`, `TodayDark`, `Manage`.
- **Resident Home** has one job: the rent and today's food.
  - Header "Hello, <name>" with the avatar.
  - Rent card, then three actions right under it: **Pay rent**, **Raise complaint**, **Message owner**.
  - Then the 30-day review prompt (until it's done) and today's food.
  - The notice / swap tiles and the layout-fix card are gone from Home. They are in **Me › My stay**: Room layouts · fix any room, Swap bed, Give notice.
- **Help:**
  - category chips (Wi-Fi, Water, Electricity, Cleaning, Food, Other) and a text box
  - a camera button (one photo, compressed like hostel photos; tap again to remove it) and **Send to owner** (was "Send to warden")
  - The new complaint shows inline right away: **Sent** · "Just now · <owner> sees it in the app" on the server, and an honest "Saved on this phone · tell <owner> on WhatsApp too" in demo builds.
  - Statuses read **Sent / Being fixed / Fixed**.
  - Empty state: "No complaints · When something breaks, tell <owner> here. You’ll see when it’s fixed."
- **Complaint photos on the server.** Migration `20261002210000_f21_complaint_photo.sql` adds:
  - `complaints.photo`
  - a private `complaint-photos` bucket. The resident uploads into their own folder at a hostel they live in; the resident, that hostel's staff and the team can read it.
  - a trigger: the photo must be the author's own at that hostel, and can't be changed later
  - Test: `supabase/tests/complaintphoto_test.sql`. FOUNDER-TODO **4s**.
  - Owners see "See photo" on the complaint (a 1-hour private link).
- **Bug fixed:** on the server, complaints were saved with an empty bed (`myBedLabel` was always '' there). It now uses the resident's own bed, which also fixes the default room for layout fixes.
- **Owner Today:**
  - **Needs you now · N**, soonest first:
    - holds with their countdown (Confirm hold / Decline; Trusted tenant badge)
    - "Received ₹X?" (Yes, received / Not received)
    - new enquiries (WhatsApp)
    - layout fixes (Compare), quick fixes (Got it / Not right) and repairs (Start work / Not broken), with their photo (F19 extras)
  - Then **This month**: beds taken, free beds, rent pending.
  - The Fair Play card, the plan banner, "confirm your free beds" and "confirm layouts" stay.
  - The big occupancy bar, the 4 KPI tiles, the rank card and the separate lists are gone.
- **Owner Manage** opens on one vertical list with an icon, a one-line status and red counts where something waits:
  - Enquiries, Residents, Complaints, Deals, Rates and UPI, Food menu, House rules, Photos, Room layouts, Reviews and ranking, Team, Your plan
  - A row opens its section with a back button, so the 6-tab strip and the button row are gone.
  - **Enquiries** is an extra row (not on the board). It keeps the full list with Call and "Not on this list = not from Hostelzy", which Fair Play relies on.
  - Reviews and ranking opens the ranking, with "Read and reply to reviews ›".
- **Owner plain words:**
  - Residents are tagged **Came from the app / Walked in / Not confirmed / Joined before Hostelzy** (were Via Hostelzy / Direct / Before Hostelzy). Fair Play says "Change Teja to “Came from the app”".
  - The centre tab is **Add tenant** (was Booking).
- **Tests:**
  - `test/home_today_test.dart` ("F21 W3: …", 4 tests): resident Home and My stay; Help with a photo, the inline status and the owner's photo; the server upload path; owner Today's list and Manage's list.
  - Older flow tests were updated to the new places.


### Wave 4 · Built · 2026-10-02 (branch `feature/f21-w4`)
Designs `Skeleton`, `Offline`, `Error`, plus items 20–24.
- **Languages (item 20), checked strings only** (Ideas chat, 2026-10-02).
  - Strings live in `hostelzy/assets/l10n/app_te.arb` and `app_hi.arb`, keyed by the English text. `T` looks each string up in the picked language and falls back to English, so screens need no rewiring.
  - **No machine translation in the app:** both files are empty in this build, and empty values never count.
  - The picker (Settings → Language, and a row on Welcome) shows a language only once it has strings, labelled "తెలుగు (beta)" until `"@@reviewed": true`. Until then Settings says "Telugu and Hindi come once a native speaker has checked the words."
  - The language choice is saved on the phone.
  - `docs/i18n/te-review.md` lists the 281 fixed owner, resident and shared strings for a native speaker to fill in. FOUNDER-TODO **4t**.
- **Accessibility (item 21):**
  - Every `Tap` is a button for screen readers.
  - Small targets accept taps up to 48×48 around them without changing the layout.
  - Text under 12px is raised to 12; small capital labels stay at 11.
  - Text scaling goes up to 2× (it was capped at 1.3).
    - `Cta` buttons, the Google button and the rows that overflowed now wrap or flex, so 32 screens render at 2× with no overflow.
    - The bed map (a floor drawing) and the Welcome headline grow at most 1.3×, or shrink to fit.
- **Loading and offline (item 22):**
  - Grey skeleton cards show while hostels load.
  - "You’re offline · Hostels show again when you’re back online. Your saved hostels and holds are still here. · Retry", never "No hostels".
  - Retry reconnects to the server.
- **Errors and Undo (item 23):**
  - "Couldn’t load your holds · Check your internet · Retry" shows inline when the live refresh fails.
  - **Release hold** and **Remove saved** show an Undo toast for 5 seconds. A released hold is only released on the server once Undo has passed.
- **Consistency (item 24):** Log out and the theme are in Settings only, so Me no longer has them. The filter labels already match from Wave 2.
- **Tests:** `test/everywhere_test.dart` ("F21 W4: …", 18 tests):
  - Undo for holds and saved
  - skeleton, offline and Retry
  - the inline error for holds
  - button semantics, the 48×48 tap and text sizes
  - 12 screens at 2× text
  - languages: beta, fallback and no picker without strings
  - Settings-only Log out and theme

## Decisions during build (Ideas chat, 2026-10-02)
- Welcome language row appears only in W4 when Telugu/Hindi really exist (no fake options).
- Notify sheet promises only what's real; tenants get a server push when the owner keeps/declines a hold.
- Tenants are asked for notifications after their first hold; owners/residents after sign-in.
- "UPI reference" everywhere, including the owner plan invoice (shown once as "UPI reference (UTR)").
- "Best deals" sort removed; a "Hostelzy deals only" filter chip stays.
- W3: Manage gets an "Enquiries" row (full list + "Not on this list = not from Hostelzy", needed by Fair Play).
- W3: complaint photos are real (private bucket; resident, staff, team can read).
- W3: owner words "Came from the app / Walked in / Not confirmed / Joined before Hostelzy"; centre tab "Add tenant".
- W3: "Reviews and ranking" is one Manage row.
