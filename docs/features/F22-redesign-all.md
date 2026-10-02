# F22 · Redesign every screen (F21 style)

**Stage:** Designing · Areas 1–2 (Tenant, Resident) designed 2026-10-02 · founder, 2026-10-02 ("I really like the after… do every screen, your own
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

The F21 boards are rolled in as Redesigned: Welcome, resident Home, Help, Confirm your stay, owner Today (+ dark), Manage, Fair Play "I agree".

## Build
One PR per area; flow tests per area; keep server behaviour unchanged.
