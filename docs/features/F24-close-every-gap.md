# F24 · Close every gap (app = canvas = everything we discussed)

**Stage:** Spec ready · founder, 2026-10-02 ("never miss a single screen or feature; canvas and app the
same"). Source: three audits (canvas vs app, every founder message, every doc/decision). ~170 items
checked; these are the ones missing or partial. Chats decide details; no approval needed (only items
marked 👤 need the founder).

## Wave A — make real hostels possible (blocks "20 hostels this month")
1. **Owner phone on the server**: add `owner_phone` (and owner WhatsApp) to hostels; used for "owner's
   number after a hold", enquiry WhatsApp, resident Message owner / Remind / notice / swap / Something
   wrong, owner→resident Message. Resident phone visible to staff for "Message resident".
2. **Onboard a real hostel end to end** (app team mode + console): hostel, floors, rooms, beds, rate
   card, terms, map pin, food, tags, photos, residents, **link the owner account** (owner role, not just
   managers). Go live only when the checklist is complete; go-live creates the plan row with the 30-day
   trial (`trial_ends`).
3. **Owner room/floor edits saved to the server** (add/remove rooms & floors, uneven floors).
4. **Food menu** per hostel in `menus` (owner Save, starts empty), resident Food + Home today, food
   rating saved, tenant "Food menu ›" peek, meal reminders use the menu's real times. *(Build already on it.)*
5. **Notice / swap / move-out** via `move_requests`; owner confirms; "Mark as leaving" saved; refund
   tracked (owner marks refund + UPI reference, tenant confirms).
6. Real values instead of fake ones: owner reply speed (from enquiry/hold reply times), ranking factors,
   availability "N free · confirmed X days ago" (server confirmations), "Visited by Hostelzy" (server
   field), house rules (no invented rules when empty).

## Wave B — owner & tenant features promised but partial
7. Item **Working / Not working** saved; tenants see it; raises a complaint; "AC under repair".
8. **Hold for a walk-in** saved on the server.
9. **"Still N free beds?" nudge** every 3 days (Today card + push); confirm saved; **confirm layouts
   every 3 months** saved.
10. **Fan / AC layer toggle** back on the room layout (rings only when the layer is on) — DECISIONS F12.
11. **Room shapes** L / T / U / custom beyond rectangles, and **"Request a shape — done in 48 h"** tracked
    (owner request → team queue in console → team draws → Send to owner → owner sees it).
12. **Deal headline = 6-month saving** with upfront part + "With Hostelzy vs Walk in" (DECISIONS F03),
    inside the single F21 price table.
13. "Your price is fixed" perks stored on the server (owner sees them).
14. "Did you join?" (Yes / Not yet / Still deciding) saved → Fair Play signal.
15. "Checked by N residents" on the hostel page too.
16. Trusted tenant perks: first look at new free beds, lower-advance deals; Members' 2-hour hold
    countdown uses the tenant's level from the server.
17. Owner-only areas (plan, deals, rates, Fair Play) enforced by role in app + RLS (managers can't).
18. Fair Play: rules acceptance saved; "Joined before Hostelzy" import path; strikes expire (30 days for
    strike 2) and strike 3 hides the hostel on the server; case photo proof back; all 6 signals on the
    server; tenant reports visible to the team in the console; "3 fixes in 6 months = 1 warning" counted;
    correct strike labels.
19. AC room must have an AC unit — also when changing rates (not only when publishing).
20. Featured spot for 80+ bed hostels in ranking (DECISIONS F10).
21. Deals pause for tenants when the owner's plan is 15+ days late (tenants can read "deals paused"),
    5-day-late reminder as push/WhatsApp, rent-due / invoice / availability pushes.
22. Notification switches honoured by the server; "New free beds" alerts.
23. Edit your name in Settings; name never pre-filled (empty field, Google name only as a hint).
24. Confirm your stay opens after joining with a code; camera explainer before first photo.
25. Electricity by meter: owner enters the meter reading/units → resident rent shows it.
26. Laundry day: owner sets it → resident reminder.
27. "Tell me when it's ready" (layout coming soon) as a real notify-me.
28. Remove false "verified by OTP" wording everywhere (poster, Trusted sheet, aAdd 5) until OTP exists.
29. In-app team tracker and team members from the server (no sample leads/"Founder 9000000100").

## Wave C — platform
30. Offline list cache + drafts; https App Links for r/ and j/ (when the domain exists).
31. Staging + production Supabase projects; Play AAB build in CI (upload key 👤).

## Canvas must add / fix (Design)
Owner Enquiries list; layer toggle on Room; shape picker + shape request flow; console layout queue,
Rewards page with Reverse, tenant reports; manager invite + join; "Still N free beds?" card on Today;
confirm-layouts card; electricity meter (owner) + meter line (resident); laundry day setting; refund
tracking (owner + tenant); deal headline (6-month saving); "Checked by N" on hostel page; Trusted perks;
case photo; remove "Publish for approval"/"Hostelzy admin" from oEditor; remove OTP wording; picker
opens on room plan (layout-first); owner block on hostel page (number after a hold).
Rule: every new screen in the app gets a board; same count both ways (CLAUDE.md).

## Design
**Main design v22** (https://claude.ai/artifact/QscJkLoFAh1MEHCZ1ckLgB) · Design chat, 2026-10-02. 187 → **206 boards**.
Row "F24 · Close every gap", plus the console row and the wizard row.

**Added** (already in the app, now drawn, 8): `oEnquiries` (Manage › Enquiries, HZ code per row,
WhatsApp/Call) · `oTodayCards` (Today: “Still 7 free beds?” + “Do your room layouts still match?”) ·
`mgrJoin` (Join your PG with an MGR- code + toast) · `oShapeReq` (Ask Hostelzy to draw it, 48 h) ·
`oShapeBack` (Hostelzy drew a new version · Publish v1) · `detailOwner` (owner block, tweak Before / After
a hold) · console `cRewards` (ledger with Reverse) · console `cLayoutFixes`.

**New** (Build adds, 11):
- `oMeter` Rent › Electricity: ₹ per unit, one “Now” reading per room, units and ₹ each (split by
  residents in the room), “Add to October rent · 4 of 5 rooms”.
- `rentMeter` resident rent line “Electricity · 70 units ÷ 4 · ₹8/unit · ₹140”.
- `oLaundry` House rules › Laundry day: day chips, “Machine free” seg, reminder 8 pm the evening before.
- `oRefund` owner: Advance / Kept / Refund / Pay to, UTR field, “Mark ₹2,000 refunded”, due 7 days after leaving.
- `rRefund` tenant: “Srinivas marked it refunded · UPI ref.”, “Yes, I got ₹2,000” / “Not received”.
- `aAddOwner` wizard step 6 of 7 “Owner account”: Not linked → “Send sign-in link on WhatsApp” (Google,
  once, 7 days) → Linked. Go-live is now step 7 with “Owner account linked” and “Bed status checked”.
- `oCasePhoto` Fair Play check: “Photo from Teja” proof + “Add a photo to your reply”.
- `oShape` Create a layout: shape tiles Rectangle / L / T / U / Angled corner / Narrow end / Alcove /
  Custom, W × L, “Start drawing · L shape”; Custom → request (48 h).
- `roomLayersOn` Room with “Show: Fan reach · AC airflow” on (rings). Default Room is now **off** (F12).
- `trustedPerks` “You’re a Trusted tenant”: first look at new beds (1 h early), lower-advance deals,
  2-hour holds, “Trusted tenant” on hold requests.
- console `cLayoutHelp`: owner requests table (shape, what they asked, due countdown, status) + detail
  with photos, “Open in layout editor”, “Send to owner”.

**Updated:** hostel page `r-detail` (+dark): green **“Save ₹2,700 in 6 months”** headline with “₹1,500 off
the advance + ₹200 off every month” on top of the single price table, and “Layouts checked by 6
residents”. `f23-Room` icons only + layer chips. `cCases` Fair Play + **Tenant reports** (Open a case /
No case · close). Console nav adds Rewards and Layout fixes. Wizard says “of 7”. `oEditor` “Layout
editor” + “Publish” (no approval, no “Hostelzy admin”); `f14-*` “Hostelzy team mode”. OTP wording gone:
poster (“Sign in · With Google, one tap”; “never asks for your password or UPI PIN”), Trusted sheet
(“Signed in to Hostelzy”), aAdd 5 (“confirms by joining with the invite code”), layout-coming-soon,
Add a manager. Picker frame: Floor view opens first only for guests or rooms with no layout (F23).

## Needs the founder 👤
SMS OTP (card for Firebase Blaze) · map key or MapTiler · Play upload key · Telugu/Hindi native check ·
demo key step · SQL runs · **monthly cap on Hostelzy-funded rewards (₹ amount)**.

## Build
**Wave A item 4: food menu, plus item 24 and dead code.** Branch `feature/food-menu-live`.
- **Menu on the server (`menus`).**
  - The owner opens Manage › Food menu. It loads that hostel's week and starts empty: the sample week only appears in demo builds.
  - A week typed on the phone before (F18) is offered as "Not saved yet".
  - **Save menu** writes all 7 days. Offline, nothing is lost.
  - The note under the menu says "Residents see this week in their Food tab" only after saving.
- **Resident.** Home "Today's food" and Food load the menu every time they open, so an owner's save shows the next time Food or Home opens. "hasn't put the menu on Hostelzy yet" shows only when there's truly no menu.
- **Breakfast rating.**
  - Good / Okay / Poor goes to `rate_meal`: confirmed residents only, one answer per meal per day.
  - The owner sees "Residents this week: Breakfast: N good · N okay · N poor" on the Food menu page, from `meal_votes`, as counts only.
  - The copy says the owner sees how many, never who.
- **Tenant (boards `new-foodPeek` and `new-foodWeek`, Design v21).**
  - The hostel page shows "Food menu · today, <day>": Breakfast, Lunch and Dinner, each with its time, then **Whole week ›**.
  - Whole week opens the Food menu sheet: Mon–Sun chips and three meals, with no rating.
  - A hostel that serves food but has no menu says "Menu not added yet". A hostel without food shows nothing.
  - The page loads the menu each time it opens.
- **Owner editor matches the v21 `menu` board.**
  - The footer note reads "Residents and tenants see it after you tap Save".
  - An empty hostel says "No menu yet. Tenants see "Menu not added yet"…".
  - Placeholders read "What's for breakfast?" and so on.
  - Save stays off until something changes.
  - The button reads **Save menu**, not "Save Monday": it saves the whole week.
- **SQL: `20261002230000_food_menu.sql`** (FOUNDER-TODO **4v**).
  - Anyone can read a live hostel's menu.
  - New `meal_ratings` table, with no read policy.
  - New functions `rate_meal` and `meal_votes`.
  - Tests: `supabase/tests/food_test.sql`.
- **Item 24, Confirm your stay: removed (Build's call, as the Ideas chat allowed).** On the server, the owner approving the invite sign-up is the confirmation: the stay is created confirmed. A second "Yes, that's right" screen would ask the resident to confirm something already done.
- **Item 24, camera explainer: not added.**
  - Photos come from Android's photo picker, which needs no camera permission. An "Allow the camera?" screen would ask for something the app never uses.
  - The permission screen is now notifications only. The "Location / Photos come in a later update" toasts are gone; location uses the Near me sheet.
  - This matches Design v21 retiring permL/permC.
- **Removed dead code:** the `oReviews` route (Manage goes to oRank), the `areas` sheet, the `joined` sheet (Holds has the inline "Did you join?" card) and the `rConfirm` screen.
- **Not in this PR:** "meal reminders use the menu's real times". `menus` has no times yet, and reminders use the fixed meal times shown in Food.
- **Tests:** `test/food_test.dart` (resident, owner on a fake server, an empty new hostel, the tenant peek and week sheet, 2× text). PR #77. Updated: flows, owner_manage, resident, start, tenant.
