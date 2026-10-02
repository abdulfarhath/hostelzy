# F22 · Redesign every screen (F21 style)

**Stage:** Design approved · all 5 areas designed 2026-10-02 (chats decide; founder confirmed in the Design chat) · founder, 2026-10-02 ("I really like the after… do every screen, your own
decisions, never take my approval").

## Rules (from the approved F21 demo)
- **One job per screen**, one clear red primary action, everything else secondary or in a sheet.
- **Photo first** wherever a hostel/room appears.
- **Plain words**: Booking code, UPI reference, "Your price is fixed", "Came from the app".
- **Real numbers in one line** (rent · move-in cost · what's extra).
- Lists over sideways scrolls; vertical rows with icon + one-line status.
- States everywhere: skeleton, empty (what to do next), offline + Retry, inline error + Retry, Undo.
- Accessibility: 48dp targets, body ≥ 14px, no info in 10–11px caps, text scaling to 2.0.
- Telugu-ready copy (short labels, no idioms).
- Keep brand: Archivo, #ec3013, 2px rules, square corners, green only for savings, light + dark.

## Order (Design area by area; Build follows each area in parallel)
1. Tenant: Explore, Map, Search/filters, Hostel page, Picker, Hold/Book, Saved, Holds, Me, Settings
2. Resident: Home, Rent/Pay, Food, Help, Move/Swap, Notice, Reviews, Rewards, Reminders
3. Owner: Today, Beds, Rent, Manage + every Manage page, Invite, Layouts/Rooms/Photos, Plan/Invoices,
   Fair Play, Team
4. Onboarding + Hostelzy team in app + team console website + web pages
5. Leftovers: permission, gate, delete account, F19/F20 screens

## Design
The redesign goes into the **All screens** canvas in place, area by area, with each new board tagged "Redesigned": https://claude.ai/artifact/QscJkLoFAh1MEHCZ1ckLgB

### Area 1 · Tenant: done 2026-10-02 (founder confirmed in the Design chat)
Board names are the frame titles on the canvas (screen id · what it shows · Redesigned).

**Half A, Explore / Map / Search (build first):**
- `explore`: One Where? bar, one filter row, photo cards, real cost
- `explore`: Browsing as a guest
- `where sheet`: areas, landmarks and hostels in one field
- `filters sheet`: Sort lives here, Clear all
- `explore`: No hostels in this area yet (empty, "Try Hitec City")
- `explore`: Loading (skeleton) · You’re offline · Retry
- `map`: Where? on top, one photo card (View), "Search this area" after a pan, and a location button instead of the area picker
- `map`: Near me
- `loc sheet`: Use your location? ("Allow location" / "Type an area instead")
- `explore` (dark) and `map` (dark)

**Half B, Hostel / Picker / Hold / Saved / Me:**
- `detail`: photo first, one price table, House rules ›, plus dark. Deal pages are gone: the deal now lives in the price table.
- `reviews`: score summary with 4 bars, then verified stays with owner replies
- `picker`: Plan | Room, floor chips with free counts, room cards with bed boxes, "See cheapest beds ›", one bottom bar "Bed 204-D · ₹5,800/mo · Continue"
- `detail · Room`: one bed with plain facts, "Checked by 3 residents", Compare link
- `hold sheet`: Hold free · 1 hour / Pay ₹3,000 to book
- `sign-in sheet`: at the first hold; `perm sheet`: notifications after the first hold
- `wa sheet`: Ask Srinivas, with the booking code
- `payAdv sheet`: ₹3,000 to the owner's UPI ID, "Pay with a UPI app", "I’ve paid · enter UPI reference"
- `payUtr sheet`: UPI reference in plain words
- `hold`: one status card with a tweak for Held / Waiting for owner / Booked / Not received / Ended. Each state has a big number, one line and one or two actions. This replaces the old hold, status and expired boards.
- `holds`: one list with tags and countdowns, and "Did you join …?" inline (replaces the joined sheet); `holds` empty state; inline error with Retry and an Undo toast
- `saved`: photo rows with an Undo toast; `saved` empty state
- `me`: one list (Saved, Holds, Stay Rewards, Reminders, Settings, Help) plus "Switch role ›". No Log out and no theme toggle.
- `settings`: You / Notifications / App (Language, Look Light/Dark/Auto, Privacy and terms, Hostelzy team), then Log out and Delete account; plus dark

Kept as they are: gallery, Visited by Hostelzy, compare, layout coming soon, report sheet, move-in reward. Delete account screens are redesigned in Area 5.

### Area 2 · Resident: done 2026-10-02
- `rPay`: Rent, one screen with a tweak for Due / Waiting for owner / Paid.
  - big amount card (dark when paid); rows Rent / Electricity / Pay to
  - "Paid before" list; "Advance ₹3,000 · ₹2,000 back when you leave"
  - actions: "Pay ₹8,020 by UPI" + "I’ve paid · enter UPI reference" / "Remind Srinivas" + "Fix the UPI reference" / "Share receipt"
  - plus dark
- `food`: day strip, then today's 3 meals (Done / Next / Later), "How was breakfast?" Good / Okay / Poor, and "Whole week ›" in the header.
- `me › My stay`: a bed card, then Move to another bed / Give notice / Review your stay / Fix a room layout, and the advance line. Give notice moves out of Home.
- `move · notice`: 3 last-day choices, optional reason chips, "₹2,000 back to your UPI within 7 days", "Give notice for 1 Nov".
- `move · swap`: free beds with the rent difference, then "Ask to move to 201-C".
- `rReview`: 4 rows of 40px stars, an optional line, Post review. `rExit`: "Did you get your ₹2,000 back?" (Yes / Not yet / No), overall stars, optional line.
- `rewards`: dark status card (Member · ₹100 · 2-hour holds), 3 steps to earn, Invite a friend.
- Already redesigned via F21: Home, Help, Confirm your stay. Reminders (F20) stay as built.

### Area 3 · Owner: done 2026-10-02
- `oBeds`:
  - floor chips with free counts
  - 2-column room cards with bed boxes (free / hold / taken / selected red)
  - legend and "Rooms and rates ›"
  - tapping a bed opens the **bed sheet**: resident, room, rent, since and how they came; Message / Mark as leaving
  - plus dark
- `oRent`: Collected ₹ and "Still to come" with a progress bar; seg All / Due / Late / Paid; rows with a tag and a 44px bell to remind; plus dark.
- `oMore · Residents`:
  - search bar; chips "Came from the app / Walked in / Joined before Hostelzy"
  - "2 taken beds have no resident" banner; rows with plain tags; a QR button for Invite
- **Add tenant** (centre tab sheet): name, +91 phone, bed, move-in date, "How did they find you?" (Hostelzy app / Walked in / Before Hostelzy), and the booking-code hint.
- `oInvite`: QR next to the code, Share link / Print poster, "Waiting for you" with Approve / ✕, "Make a new code".
- `enquiry sheet`: Booking code first, WhatsApp / Call, "add him with this booking code".
- Manage pages:
  - **Deals:** up to 3 switches; active ones in green
  - **Rates and UPI:** one table of room type / walk-in / Hostelzy price, one UPI ID, Test with ₹1, "Rooms and floors ›"
  - **Complaints:** seg Open / Being fixed / Fixed, one action per row
  - **Food menu:** day chips, 3 fields, "Copy Friday to Saturday", Save
  - **House rules:** plain fields
  - **Reviews and ranking:** one page, with score and rank tiles, a "To rank higher" line and Reply buttons
- `oPlan + oInvoice`: **one screen** with a tweak for Free trial / Due / Checking / Paid / Late. Each has a big status card, Plan / Pay to / Invoice rows, and one or two actions. It replaces plan, invoice, UTR, status and overdue. Plus dark.
- `oCase` (Fair Play check):
  - "Reply within 47 hours" banner
  - what happened, as a timeline with flagged steps in red
  - reply box; "Send my reply" / "Change him to “Came from the app”"
- `oTeam`: you plus managers, with "Managers can’t see your plan, deals, rates or Fair Play notices", and Add a manager.
- Removed: the Still-free-beds card (now an item in "Needs you now").
- Kept: switcher, trusted sheet, strike notices, and the layouts / rooms / photos row (already one job per screen).

### Area 4 · Onboarding + Hostelzy team in the app: done 2026-10-02
- `login`: logo, "Sign in to hold a bed", "So owners know who’s coming. No passwords, no codes.", the Google button, "Keep browsing as a guest", Terms line. Plus dark.
- `phone`: About you, with just two fields (name, +91 phone with a "Not verified" tag) and "We’ll check it by SMS later". Plus dark.
- `role`: "What brings you here?" with three big rows (I need a bed / I live in a PG / I run a PG); "You can switch later in Me".
- `roleGate`:
  - resident: "Join your PG", a code field with Join, "Scan the poster QR", a "No code?" box with "Send my number on WhatsApp", "Not in a PG yet? Find a bed ›"
  - owner: "List your PG", one line on visit / free trial / no commission, PG name, area chips, Request a visit / WhatsApp Hostelzy
- `aAdd`: one wizard frame with a 6-segment progress bar and "Add hostel · step n of 6". Drawn: 1 Basics, 2 Rooms floor by floor (floor cards with room chips, Copy floor above, Add floor), 6 Ready to go live? (checklist with red open items, "Go live · 1 thing left") plus dark. Steps 3–5 keep the same frame; their content is unchanged.
- `aTrack`: seg by stage, then rows with a next-step button and Add hostel.
- `aPay`: "Match each UPI reference in the bank app", seg To check / Late / Paid, rows with Mark paid / Not received.
- `aCases`: seg New / Waiting / Decide / Closed, inline No issue / Ask more / Strike 1, and the decide rule.
- Kept: team sheet, aHome, aTeam, the layout editor, the team console website (already one job per page) and the web pages.

### Area 5 · Leftovers: done 2026-10-02
- `perm`: three sheets asked in context, not at start:
  - notifications after the first hold ("Get a message when Srinivas replies?")
  - location from the map
  - camera from the camera button
- `delAcc`: "Deleted" and "Kept, without your name" as two short lists; Continue / Keep my account.
- `delConfirm`: account card plus "Confirm with Google". `delDone`: "Your account is deleted" and Close.
- Kept: update / maintenance gate, open-hold block, F19 and F20 rows (designed in this style already), DEMO strip, back-to-exit toast.

**F22 design is complete:** 88 boards are tagged Redesigned on All screens.

The F21 boards are rolled in as Redesigned: Welcome, resident Home, Help, Confirm your stay, owner Today (+ dark), Manage, Fair Play "I agree".

## Build
One PR per area; flow tests per area; keep server behaviour unchanged.

### Area 3 · Owner: built 2026-10-02 (merged, #73)
- **Beds:** floor chips with free counts, rooms as cards with bed boxes (the open bed shows red), legend, "Rooms and rates ›". The red "New layout" button stays on a room when Hostelzy drew a version to publish.
- **Bed sheet:** status, resident, room, rent, since and how they came, advance; Message / Mark as leaving (taken), Release hold (held), Add tenant to this bed / Hold for a walk-in (free); "Room … layout ›".
- **Rent:** Collected and Still to come with a bar; seg All / Due / Late / Paid with counts; rows with a plain tag and a 44px bell.
- **Residents:** search (name, phone or bed), invite QR button, filter chips, the "taken beds have no resident" banner with Add resident, short tags.
- **Add tenant:** Name, +91 Phone, Bed, Moves in, one rent line, Add tenant. No "How did they find you?" or booking-code field: the server links an app tenant by phone number, so the sheet says to use the number they booked with.
- **Invite:** QR next to the code, Share link / Print poster, "Waiting for you · N" with Approve / ✕, "Make a new code".
- **Enquiry sheet:** booking code first, phone, what they asked about, the message; WhatsApp / Call; "add them with this phone number so it counts".
- **Manage pages:** Deals (up to 3 switches, green when on, real cost per row), Rates and UPI (one table, UPI ID, Test with ₹1, "Rooms and floors ›"), Complaints (Open / Being fixed / Fixed, one action per row), Food menu (day chips, 3 fields, copy to next day; saved as you type), House rules, Reviews and ranking as one page (score and rank tiles, "To rank higher" from real data, Reply).
- **Your plan:** one screen for Free trial / Due / Late / Checking / Paid / Not found; `oPlan`, `oInvoice` and `oPayStatus` all show it. Late says deals pause from day 15 (not earlier); Paid shares a receipt (there is no invoice download).
- **Fair Play check:** "Reply within N hours" from the real deadline, timeline with flagged steps in red, reply box, Send my reply / Change <name> to "Came from the app". "Add a photo as proof" is gone (it did nothing).
- **Team:** you and managers with tags, the note on what managers can't see, Add a manager.
- Tests: `test/owner_test.dart` (Half A) and `test/owner_manage_test.dart` (Half B), older tests updated.

### Area 2 · Resident: built 2026-10-02 (merged, #72)
- **Rent:** one amount card (dark when paid), rows Rent / Electricity / Pay to, "Paid before", the advance line, and the action at the bottom: Pay by UPI + enter UPI reference / Remind <owner> + Fix the UPI reference / Share receipt.
- **Food:** day strip, today's meals tagged Done / Next / Later (from the clock), "How was breakfast?" Good / Okay / Poor, "Whole week ›" in the header.
- **Me › My stay** (new screen `rStay`): the bed card, then Move to another bed / Give notice / Review your stay / Fix a room layout, and the advance line. Me shows one "My stay" row.
- **Give notice:** 3 last-day buttons, an optional reason (tap again to clear), the refund line, "Give notice for …" at the bottom.
- **Move to another bed:** free beds with the difference from your own rent (not a fixed ₹7,600), "Ask to move to …" at the bottom.
- **30-day review:** a row of stars per category; overall is their average; the layout question and an optional line stay.
- **Exit review:** "Did you get your ₹X back?" first, overall stars, an optional line (now saved with the review).
- **Stay Rewards:** one dark card, 3 steps to earn (what keeps you from Trusted is said on step 2), Invite a friend and your code.
- Kept from the data model, not the boards: the five review categories, and the exit choices "Yes / Only part of it / Not yet" (the server stores all, part, not). The exit review does not say "Shown as Former resident", because only a deleted account is shown that way.
- Tests: `test/resident_test.dart` (5 flows + 2× text on 7 screens), older tests updated.

### Area 1 · Tenant: built 2026-10-02 (merged, #71)
- **Map:** Where bar + location button on top, "Search this area", one hostel card at the bottom (photo, cost to move in, View). Location off or failing goes to typing an area.
- **Explore empty:** "No hostels in X yet" with "Try <nearest area with hostels>".
- **Me:** one list with a status on each row (Saved, Holds, Stay Rewards, Reminders, Settings, Help on WhatsApp), "Switch role ›".
- **Settings:** You / Notifications / App groups; Look is Light / Dark / Auto; Log out and Delete account at the end. Help moved to Me.
- **Saved:** photo rows with an unsave heart (Undo for 5 s); empty state with "Find a bed".
- **Holds:** one row per hold with a plain label (Waiting for owner, Held, Booked); "Did you join X?" asked inline with the report link; empty state.
- **Hold status:** one card per state (Held for you · free, Held · owner confirmed, Pay to book, Waiting for owner, Not received, Booked, Hold ended) with one main and one other action.
- **Pay sheet:** "Pay to <owner>", UPI ID, what comes back, "Hostelzy never holds your money".
- **WhatsApp sheet:** the whole message shown, Open WhatsApp / Copy message, "The booking code keeps your Hostelzy price". The message ends "Booking code HZ-…".
- **Picker:** floor chips with free counts, rooms as cards with bed boxes, legend + "See cheapest beds ›", bottom bar "Bed 204-D · ₹X/mo" + Continue.
- **Room view:** room in the title, fan and AC airflow always drawn, one bed's facts, "Compare with another bed ›", Edit room (F19), bottom bar "Same price for every bed here" + Continue.
- **Reviews:** score beside the category bars, the advance/layout facts in one line, stays with "<owner> replied:", the "Owners can reply, not delete" rule.
- **Notifications ask:** only what the app does (owner confirms your hold, rent reminders); "hold about to end" is not promised.
- Kept from the data model: the five review categories the server stores (not the board's four), so nothing on the server changes.
- Tests: `test/tenant_test.dart` (6 flows) plus the older flow tests updated to the new words.

