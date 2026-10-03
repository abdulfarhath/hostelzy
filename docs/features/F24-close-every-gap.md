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
**Main design v22** (https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx) · Design chat, 2026-10-02. 187 → **206 boards**.
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

**v23 (after #77 merged):** owner Food menu button "Save menu" (all 7 days); removed `r-stay`
(rConfirm, retired) and `r-where` (old Where sheet; the app has only the full-screen Where?). **204 boards.**

**v24 · 2026-10-03 (new artifact on the Design account, same URL as above).** Canvas copied 1:1 (205 boards),
then **+21 boards**, two new rows at the bottom. **226 boards.**
- *App states that had no board (audit §2):* `w1-exploreCached` (Offline banner, last list kept) · `w1-mapEmpty`
  (No hostels in this area yet) · `w1-holdsEnded` (Ended / Released) · `w1-meRefund` (Me › Your refund on top) ·
  `w1-rNotYet` (Rent: your stay isn’t on Hostelzy yet) · `w1-oTodayMoves` (Today: notice, move, refund cards) ·
  `w1-bedSheetLeaving` (Free from 31 Oct · “Rahul moved out”) · console `w1-cNotSetup`, `w1-cError` (with Try again).
- *F24 items:* `w1-oPriceFixed` (#13 owner bed sheet: price fixed + deal) · `w1-featured` (#20 “Featured in
  Madhapur”, then “Ranked by residents · never paid”) · `w1-editName` (#23 sheet) · `w1-aboutEmpty` (#23 empty
  field, “Use ‘Ravi Teja’” hint) · `w1-dealsPaused` (#21 “Hostelzy deals paused · Walk-in prices for now”) ·
  `w1-acRepair` (#7 red band, real date) · `w1-walkInHold`, `w1-walkInHeld` (#8) · `w1-didJoin` (#14 Yes, I joined /
  Not yet / Still deciding; no reward promise) · `w1-notifyReady` (#27 on state) · `w1-notifSwitches` (#22 incl.
  New free beds, Layout ready) · console `w1-cStrikes` (#18 Hostels with “Strike N of 3 · label · date”, deals back
  on a date).
- *Updated:* `oEditor` heading “Layout editor” (no “Hostelzy admin”), named shape tiles, “Shape not on the list? →
  Ask Hostelzy to draw it”, “Checks before publishing”; `cCases` strike button “Strike 1 of 3 · warning”; Main cover
  counts.

**v25 · 2026-10-03 (after #82–#93 merged).** **+13 boards, 27 updated → 239 boards** (214 unique screens;
the rest are 23 dark copies, the cover and the logo).
- *New:* `w2-waSheet` (Settings › Your WhatsApp number, owner) · `w2-ownerOnly` (manager opens plan/deals/rates/
  Fair Play) · `w2-reportAbuse` (Report this review, 4 reasons) · console `w2-cReported` (Reported reviews, Hide /
  Keep) · `w2-aPin` (Add hostel › Map pin) · `w2-qrCamera` (Use your camera?) · `w2-qrScan` (Scan the QR) ·
  `w2-oTodayRates` (Today: “Are your rates still right?” + strike card) · `w2-floorLocked` (women’s PG floor plan
  after a hold) · `w2-pickerList` (beds, cheapest first) · `w2-exploreNoMatch` (Nothing matches yet · Clear filters) ·
  `w2-foodWeek` (resident Food › whole week) · `w2-layoutWrong` (owner: Residents say this layout is wrong).
- *Updated to match the app:* `w1-editName` (“Change your name”, empty field, name as hint) · `w1-aboutEmpty` ·
  `w1-didJoin` (reward line, “Only the Hostelzy team sees your answer”) · `w1-notifyReady` (“We’ll tell you” box) ·
  `w1-notifSwitches` (3 rows) · `w1-walkInHeld` (one “Release hold”) · `w1-featured` (“Featured” tag only) ·
  `w1-cStrikes` is now the console **Fair Play case** (owner’s reply, photos, strikes line, rules agreed, Did you
  join? counts, “Strike 2 · deals hidden for 30 days”, signals) · `f24-trustedPerks` (3 perks, no lower-advance) ·
  `r-filters`, `f23-Filters` (Sort: Best deals) · `r-detail` (+dark) “Confirmed by the owner · 3 Oct” ·
  `gateOwn` (Manager at a PG? card) · `add-addR` (Lived here before Hostelzy) · `review` (Is the room layout right?
  Yes / Mostly / No) · `menu` (Meal times box) · every console board’s nav now matches the console (adds Rewards and
  Reported reviews).
- *For Build (board, app differs):* `w1-dealsPaused`: tenants see no “deals paused” text today, deals just vanish
  (F24 #21 says tenants can read it). `f24-oMeter` footer example should match the resident line
  “Electricity · 70 units ÷ 4 · ₹8/unit”.
- *Merged (v26):* removed `f19-Console`, `f19-ConsoleDark` (same page as `f24-cLayoutFixes`) and `room` (same screen as `f23-Room`). **236 boards, 212 unique.**

**v27 · 2026-10-03: matched 1:1 to `docs/SCREENS.md` (PR #94).** **App 182 · Canvas 182** (+42 variants, +21 dark,
+8 not counted). 253 boards.
- *New (21), items that had no board:* `w3-oRules` (S62 full rules) · `w3-holdGone` (T9) · `w3-roomSignIn`, `w3-roomLoading`,
  `w3-roomCapped`, `w3-roomError` (T11–T14) · `w3-scanOff`, `w3-scanError` (T16–T17) · `w3-foodNoMenu` (T19) ·
  `w3-stayNotYet` (T20) · `w3-noticeGiven` (T21) · `w3-rRoomNoLayout` (T22) · `w3-noRefund` (T23) · `w3-noCases` (T25) ·
  `w3-oLayoutNone`, `w3-oLayoutDrawing` (T26–T27) · console `w3-cLayoutEditor` (C5), `w3-cLoadError` (C13) ·
  web `w3-wRNoCode`, `w3-wJNoCode` (W4, W6), `w3-wRoot` (W1, the old prototype at the site root).
- *Retired (4), matched no item:* `demo` (demo APK only), `back` (a toast), `oCreate` (old Create a layout; now `f24-oShape`),
  `f12-Request` (old layout request; now `f24-oShapeReq`).
- *Not counted, kept:* `Main` (cover), `brand-logo`, `splash` (Android launch), `f14-Poster` (print), `f17-Desktop` (tablet
  layout, SCREENS §6), `f19-Push`, `f20-Notify`, `f20-NotifyDark` (system notifications).
- *v28 (after #95):* site root now redirects to `app/`; **retired `w3-wRoot`**. Web items renumbered to SCREENS (W1 `wHome` · W2 `wR` · W3 `w3-wRNoCode` · W4 `wJ` · W5 `w3-wJNoCode` · W6 `wPriv` · W7 `wTerms` · W8 `wDel`). **App 181 · Canvas 181**, 252 boards. *Correction (hub, 2026-10-03):* the site root stays the old prototype (DECISIONS “Web address for now”); `w3-wRoot` is back, tagged “[not counted] old prototype page, kept by founder decision”. **253 boards.**

<details><summary>Item → board map (181)</summary>

| Item | Board | Variants |
|---|---|---|
| S1 | `r-welcome` |  |
| S2 | `login` |  |
| S3 | `about` | `w1-aboutEmpty` |
| S4 | `role` |  |
| S5 | `gateRes` | `f24-mgrJoin` |
| S6 | `gateOwn` |  |
| S7 | `w2-qrScan` |  |
| S8 | `r-explore` | `r-exploreGuest`, `w1-featured`, `f20-HomeTenant` |
| S9 | `map` | `mapMe` |
| S10 | `saved` |  |
| S11 | `holds` | `w1-holdsEnded`, `w1-didJoin`, `r-error` |
| S12 | `add-whereFull` |  |
| S13 | `r-detail` | `f14-Visited`, `f23-Main`, `new-foodPeek`, `f24-detailOwner`, `w1-dealsPaused` |
| S14 | `gallery` |  |
| S15 | `reviews` |  |
| S16 | `picker` |  |
| S17 | `f23-Room` | `f24-roomLayersOn`, `w1-acRepair`, `f19-Checked` |
| S18 | `w2-pickerList` |  |
| S19 | `f12-Compare` |  |
| S20 | `hold` |  |
| S21 | `f09-MoveIn` |  |
| S22 | `rewards` |  |
| S23 | `r-home` | `f20-Home` |
| S24 | `food` |  |
| S25 | `w2-foodWeek` |  |
| S26 | `rent` | `f24-rentMeter` |
| S27 | `r-help` |  |
| S28 | `stay` |  |
| S29 | `notice` |  |
| S30 | `swap` |  |
| S31 | `f19-Main` | `f19-After` |
| S32 | `f19-Edit` | `f19-EditCheck`, `f19-Try` |
| S33 | `review` |  |
| S34 | `exitReview` |  |
| S35 | `f24-rRefund` |  |
| S36 | `r-today` | `f24-oTodayCards`, `w1-oTodayMoves`, `w2-oTodayRates`, `f19-Today`, `f23-Today` |
| S37 | `beds` |  |
| S38 | `oRent` |  |
| S39 | `r-manage` |  |
| S40 | `residents` |  |
| S41 | `f24-oEnquiries` |  |
| S42 | `complaints` |  |
| S43 | `deals` |  |
| S44 | `rates` |  |
| S45 | `menu` |  |
| S46 | `rules` |  |
| S47 | `invite` |  |
| S48 | `team` |  |
| S49 | `oPhotos` |  |
| S50 | `oCrop` |  |
| S51 | `oRooms` |  |
| S52 | `f24-oMeter` |  |
| S53 | `oLayouts` |  |
| S54 | `f23-Owner` |  |
| S55 | `oLayout` | `w2-layoutWrong` |
| S56 | `f24-oShape` |  |
| S57 | `oEditor` | `f12-Admin` |
| S58 | `oPublished` |  |
| S59 | `f19-Compare` |  |
| S60 | `f19-Approved` |  |
| S61 | `oReviews` |  |
| S62 | `w3-oRules` |  |
| S63 | `case` | `f24-oCasePhoto` |
| S64 | `f07-Strike` |  |
| S65 | `plan` |  |
| S66 | `aHome` |  |
| S67 | `aAdd1` |  |
| S68 | `aAdd2` |  |
| S69 | `f14-Rates` |  |
| S70 | `f14-Photos` |  |
| S71 | `f14-Residents` |  |
| S72 | `f24-aAddOwner` |  |
| S73 | `aAdd6` |  |
| S74 | `w2-aPin` |  |
| S75 | `aTrack` |  |
| S76 | `aPay` |  |
| S77 | `aCases` |  |
| S78 | `aTeam` |  |
| S79 | `me` | `add-meOwner`, `w1-meRefund`, `f20-Me` |
| S80 | `settings` | `w1-notifSwitches` |
| S81 | `f20-Main` |  |
| S82 | `permN` |  |
| S83 | `delAcc` |  |
| S84 | `delConfirm` |  |
| S85 | `delDone` |  |
| S86 | `gateMt` |  |
| H1 | `r-filters` | `f23-Filters` |
| H2 | `loc` |  |
| H3 | `r-signin` |  |
| H4 | `r-holdSheet` |  |
| H5 | `r-notify` |  |
| H6 | `wa` |  |
| H7 | `payAdv` |  |
| H8 | `f07-Report` |  |
| H9 | `f24-trustedPerks` |  |
| H10 | `new-foodWeek` |  |
| H11 | `w2-qrCamera` |  |
| H12 | `r-utr` |  |
| H13 | `f19-Lock` |  |
| H14 | `f19-Limit` |  |
| H15 | `f19-Send` |  |
| H16 | `f19-QuickFix` |  |
| H17 | `addTenant` |  |
| H18 | `bedSheet` | `w1-bedSheetLeaving`, `w1-oPriceFixed`, `w1-walkInHold`, `w1-walkInHeld` |
| H19 | `enquiry` |  |
| H20 | `add-addR` |  |
| H21 | `f09-Owner` |  |
| H22 | `add-utr` |  |
| H23 | `f24-oShapeReq` |  |
| H24 | `f14-Switcher` |  |
| H25 | `add-addRoom` |  |
| H26 | `add-addMgr` |  |
| H27 | `photoSheet` |  |
| H28 | `add-cPhoto` |  |
| H29 | `f19-Reject` |  |
| H30 | `f19-Mute` |  |
| H31 | `add-rank` |  |
| H32 | `w2-reportAbuse` |  |
| H33 | `f24-oRefund` |  |
| H34 | `f24-oLaundry` |  |
| H35 | `w2-waSheet` |  |
| H36 | `teamSheet` |  |
| H37 | `add-lang` |  |
| H38 | `w1-editName` |  |
| H39 | `f20-Water` |  |
| H40 | `f20-Add` |  |
| H41 | `f20-Offer` |  |
| H42 | `f23-Floor` |  |
| H43 | `f23-Add` |  |
| T1 | `r-skeleton` |  |
| T2 | `r-offline` |  |
| T3 | `w1-exploreCached` |  |
| T4 | `exploreEmpty` |  |
| T5 | `w2-exploreNoMatch` |  |
| T6 | `w1-mapEmpty` |  |
| T7 | `holdsEmpty` |  |
| T8 | `savedEmpty` |  |
| T9 | `w3-holdGone` |  |
| T10 | `w2-floorLocked` |  |
| T11 | `w3-roomSignIn` |  |
| T12 | `w3-roomLoading` |  |
| T13 | `w3-roomCapped` |  |
| T14 | `w3-roomError` |  |
| T15 | `f12-Soon` | `w1-notifyReady` |
| T16 | `w3-scanOff` |  |
| T17 | `w3-scanError` |  |
| T18 | `w1-rNotYet` |  |
| T19 | `w3-foodNoMenu` |  |
| T20 | `w3-stayNotYet` |  |
| T21 | `w3-noticeGiven` |  |
| T22 | `w3-rRoomNoLayout` |  |
| T23 | `w3-noRefund` |  |
| T24 | `r-agree` |  |
| T25 | `w3-noCases` |  |
| T26 | `w3-oLayoutNone` |  |
| T27 | `w3-oLayoutDrawing` |  |
| T28 | `f24-oShapeBack` |  |
| T29 | `w2-ownerOnly` |  |
| T30 | `delBlocked` |  |
| T31 | `gateUp` |  |
| C1 | `cOnb` |  |
| C2 | `cPay` |  |
| C3 | `cCases` | `w1-cStrikes` |
| C4 | `f24-cLayoutHelp` |  |
| C5 | `w3-cLayoutEditor` |  |
| C6 | `f24-cRewards` |  |
| C7 | `f24-cLayoutFixes` |  |
| C8 | `w2-cReported` |  |
| C9 | `cHostels` |  |
| C10 | `cSignin` | `cNotTeam` |
| C11 | `w1-cNotSetup` |  |
| C12 | `w1-cError` |  |
| C13 | `w3-cLoadError` |  |
| W1 | `wHome` |  |
| W2 | `wR` |  |
| W3 | `w3-wRNoCode` |  |
| W4 | `wJ` |  |
| W5 | `w3-wJNoCode` |  |
| W6 | `wPriv` |  |
| W7 | `wTerms` |  |
| W8 | `wDel` |  |

</details>

## Needs the founder 👤
SMS OTP (card for Firebase Blaze) · map key or MapTiler · Play upload key · Telugu/Hindi native check ·
demo key step · SQL runs · **monthly cap on Hostelzy-funded rewards (₹ amount)**.

## Build
### Status after 3 Oct 2026 (Build): every item built
| # | Done in | Notes |
|---|---|---|
| 1 | #78, #90 | Owner's number after a hold; owner WhatsApp; "Message resident" uses the real number |
| 2, 3 | #79, #90 | Real map pin, console Go live through `go_live()`, wizard rules/amenities saved |
| 4 | #77, #90 | Meal times from the menu |
| 5, 6 | #81 | |
| 7, 8, 22, 29 | #83 | |
| 9, 13, 14 | #86 | |
| 10, 11 | #84 | |
| 12, 23, 28 | #82 | 6-month headline counts monthly savings, not the (refunded) lower advance |
| 15 | #93 | "Layouts checked by N residents" on the hostel page |
| 16, 25, 26, 18 (case photo) | #85 | Trusted "lower-advance deals" left out: no such deal exists |
| 17, 19, 20, 21 | #87 | Founding-hostel featured spot waits for the founder (Q6) |
| 18 | #91, #93 | #93: strike 2 hides deals on the server too |
| 24 | #77 | |
| 27 | #89 | |
| 30, 31 | #80 | Founder: 6a–6c |
| Audit §3 | #88 (F05/F08/F13 S4), #89 (F12, F14 QR, brand), #92 (F03) | Skipped: partner pay (founder amount), "Founder to confirm" items |

**Founder:** run the SQL steps in `docs/FOUNDER-TODO.md` in the listed order (4y, 4z, then 4zk → 4zc).
**Design:** boards to add for screens Build added: Settings `name` sheet, `waNum` sheet, Owner only screen,
`revReport` sheet, console Reported reviews, `aPin`, `scan` + `scanCam`, `oMeter`, `laundry` + `perks` sheets,
owner Today "Are your rates still right?" card; and the "App state, no board" list in the audit §2.

**Canvas v25 fixes.** Branch `feature/v25-fixes`.
- Hostel page: when deals are paused (plan 15+ days late) or hidden (strike 2), a plain line "Hostelzy deals are
  paused for this hostel. Walk-in prices shown." instead of the deals vanishing (board `w1-dealsPaused`).
- oMeter footer example worded exactly like the resident rent line ("Electricity · 70 units ÷ 4 · ₹8/unit  ₹140";
  "Electricity  Not added yet").
- Explore offline with a saved list: the saved hostel cards now show under the "Offline · hostels as of…" banner
  (board `w1-exploreCached`; before, only the banner showed).
- `docs/SCREENS.md`: every screen, sheet and full-screen state in the release app, counted one by one.
- Tests: `test/v25_test.dart`, `test/platform_test.dart`.

**Cleanup (#93).** Branch `feature/f24-cleanup`.
- `20261003110000_f24_strike_deals.sql` (FOUNDER-TODO **4zc**): the deals read policy also leaves out hostels
  whose deals strike 2 hides (`deals_hidden`), so tenants can't read them on the server; owner, managers and team still can.
  New `hostel_layout_checks()`: distinct residents with an approved layout fix in 6 months, per hostel.
- App: hostel page shows "Layouts checked by N residents" (item 15) under the availability line; nothing when none.
- FOUNDER-TODO: all F24 SQL steps listed in the order to run them (file-name order).
- Tests: `supabase/tests/strikedeals_test.sql`, `hostelzy/test/checked_test.dart`.
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

**Wave A item 1: owner phone.** Branch `feature/f24-owner-phone`.
- **Server.** `owner_contacts(hostels[])` gives the owner's number: the owner's profile phone, else `hostel_leads.owner_phone`.
  - It only answers for hostels where the caller holds or enquired in the last 60 days, stays (or left in the last 60 days), or is staff or the team. That follows DECISIONS F07: the number shows after a hold.
  - SQL: `20261002231000_f24_owner_phone.sql` (FOUNDER-TODO **4w**). Tests: `supabase/tests/owner_phone_test.sql`.
- **App.** After live rows load, it fetches numbers for this user's held, enquired and stay hostels.
  - An enquiry fetches the number right after it is recorded, so the WhatsApp sheet opens with it.
  - Residents' Message owner, Remind and Talk to all use it.
  - A held hostel whose owner has no number says "Number not added yet".
  - Residents' phones stay with staff through `stays`, as before.
- **Tests:** `test/owner_phone_test.dart`.

**Wave A items 2 and 3: onboard a real hostel; rooms saved.** Branch `feature/f24-onboard`.
- **Server** (`20261002232000_f24_onboard.sql`, FOUNDER-TODO **4x**; tests: `supabase/tests/onboard_test.sql`):
  - `save_hostel(id, jsonb)`, team only: creates or updates a draft: basics, rate card, the owner's number in `hostel_leads`, and rooms.
  - `save_rooms(hostel, jsonb)`, staff or team: adds and changes rooms and beds. A room or bed with a resident, hold or booking is never removed.
  - `new_owner_invite` (`OWN-` code, works once, for 7 days) and `join_as_owner`: one owner account per hostel; the profile becomes owner.
  - `go_live(hostel)` checks there are rooms, a price for every room type, a linked owner and 8 photos. Then it sets the hostel live, records "Visited by Hostelzy" (`hostels.visited_on`) and creates `owner_plans` with the 30-day trial. Going live again never restarts the trial.
- **Wizard: 7 steps (Design v22 `aAddOwner`).**
  - In the real app it starts empty; the demo keeps the sample.
  - After the rate card it saves the draft.
  - Photos are real uploads, through the Photos screen for the draft.
  - Residents become stays on the server, so their beds show taken.
  - **Owner account** (step 6) takes the name and number and sends the sign-in link on WhatsApp. "Check again" shows **Linked**.
  - Go live adds the row "Owner account linked", and the server's reason shows if something is missing.
- **Owner's side.**
  - The link (`app/j/?c=OWN-…`) is kept until sign-in.
  - "I run a PG" shows "Run my PG on Hostelzy", which links the account and opens Today.
- **Drafts never show to tenants.** `Hostel.live` is checked in Explore and in the Where? list. "Visited by Hostelzy" comes from the server.
- **Owners' room changes** (add room, remove room or floor) save the whole list. If the server says someone is in a room, the change is undone and the toast says which room.
- **Tests:** `test/onboard_test.dart`. Updated: team_app, flows.

**Wave A item 5: notice, moves, move-out and refunds.** Branch `feature/f24-moveout`.
- **Server** (`20261002233000_f24_moves.sql`, FOUNDER-TODO **4y**; tests: `supabase/tests/moves_test.sql`):
  - `give_notice`, `ask_move` (a free bed in the same hostel) and `withdraw_move`, for residents.
  - `answer_move`: accepting a notice sets "free from <last day>" on the bed. Accepting a move moves the stay to the new bed, with that room's rent.
  - `mark_leaving` and `moved_out`: the stay ends, the bed is free, and the refund (advance minus what's kept) is due in 7 days.
  - `send_refund`, which needs the 12-digit UPI ref, and `confirm_refund` ("not received" tells the owner).
  - Each step pushes to the other side. Stays gain `leaving_on` and the refund columns.
- **Resident.**
  - Give notice and Ask to move are saved on the server.
  - The notice page shows Sent or **Accepted**, and Withdraw works.
  - The false "Room check with the warden, 10 am" step is gone.
- **Owner Today.**
  - "<name> gave notice" and "<name> asks to move to bed X", with Accept and Say no.
  - "Refund ₹X to <name>" (red when late or not received) opens **oRefund**.
- **Bed sheet.** "Mark as leaving" is saved. A leaving bed has "<name> moved out".
- **oRefund** (board): Advance / Kept / Refund / Pay to / Due, the UTR field, "Mark ₹X refunded".
- **rRefund** (board): "<owner> marked it refunded · UPI ref", then "Yes, I got ₹X" or "Not received". A former resident reaches it from Me › Your refund, or from the push.
- **Tests:** `test/moves_test.dart`; `home_today_test` counts the new Today items.

**Wave A item 6: real values instead of fake ones.** Branch `feature/f24-moveout`.
- **Server** (`20261002233500_f24_values.sql`, FOUNDER-TODO **4z**; tests: `supabase/tests/values_test.sql`):
  - `enquiries.contacted_at` and `holds.decided_at` are stamped by a trigger.
  - `hostel_signals()` gives per live hostel, as counts only: the median reply minutes over 60 days (with n), complaints in 30 days, current residents, photos, rooms and published layouts.
- **Reply time.** "Usually replies in ~N min" (or "~N h") shows only after 3 real replies. Before that it says "Replies through Hostelzy". The sample hostels keep their demo values.
- **Ranking.** Live hostels use real counts:
  - complaints per resident;
  - listing = photos plus layouts per room;
  - freshness of the bed confirmation;
  - an owner with no replies yet ranks in the middle, not at the top.
- **House rules.** A real hostel's page never shows rules its owner didn't add, only the ones from its terms. The owner's editor leaves Gate closes and Visitors empty to fill in.
- **Availability** ("N free · confirmed X days ago" from the server's bed confirmations) is with items 9/19 (owner tools).
- **Tests:** `test/values_test.dart`.

**Wave C items 30 and 31: platform.** Branch `feature/f24-platform`.
- **Offline list (30).**
  - Every time the hostels load, the server's rows are kept on the phone (`features/listings/cache.dart`).
  - If the server can't be reached at start, Explore shows that list with "Offline. Hostels as of <day>, <time>. Tap to try again", instead of an empty list.
  - It is never sample data. Drafts that already stay on the phone (layout fixes, menus typed before saving) are unchanged.
- **https App Links (30).** `farhath.me/hostelzy/app/r` and `/j` open the real app; the router already handled those paths. Verified opening needs `assetlinks.json` on farhath.me (FOUNDER-TODO **6c**).
- **Play build and staging (31).**
  - New workflow `android-aab.yml` (Actions › Play Store build, run by hand) makes the AAB, signed with the upload key from secrets. The Gradle `hostelzyUpload` config is used only when that key is present.
  - The `staging` choice builds against a second Supabase project (`HZ_ENV=staging`, its own URL and key); Settings then shows "STAGING".
  - Founder steps: **6a** upload key, **6b** staging project. No keys are in the repo.
- **Tests:** `test/platform_test.dart`.

**Wave 0: no fake or false lines; owners draw; deal headline; edit your name.** Branch `feature/f24-wave0`.
- **Fake lines out (gap audit §4).**
  - "Usually replies in ~0 min" can't show: #81 already says "Replies through Hostelzy" until 3 real replies.
  - "Confirmed by the owner today": a live hostel's bed confirmation is now *unknown* until the server has one. The hostel page shows just "N free beds", and an unknown hostel is never called stale. Real confirmations come with items 9/19.
  - "Complaint raised 30 Sep" is gone. The line reads "AC under repair. The owner is fixing it."
  - "Did you join?" answers toast just "Thanks." The real build shows the card only for a real ended hold, never the Anjani / 102-B sample. On the server the line says the ₹100 Member reward unlocks once the owner confirms the stay.
  - Owner plan 15+ days late, real build: "Your Hostelzy plan is N days late · Pay ₹X to keep your deals on" (the server doesn't pause deals yet, item 21). The demo keeps "Deals paused".
  - **Settings › Name (item 23)** opens the `name` sheet. The field starts empty with the current name as the hint, and **Save name** writes `profiles.name`. The existing "edit own profile" RLS allows it and `guard_profile` leaves the name alone, so no SQL is needed. Offline, the name stays as it was. Sign-up never pre-fills the name: the Google name is only the hint, and the profile saves the typed name.
- **Owners draw (DECISIONS 2026-10-02).** No more "the Hostelzy team draws it / adds the AC unit within 48 hours / Hostelzy draws its layout":
  - AC rooms: "Add it in the room's layout and publish".
  - New room: "Draw its layout when you're ready".
  - Layout coming soon: "The owner hasn't published this room's layout yet".
  - The 48 h promise stays only for a room *shape*: "Room not a rectangle? … the Hostelzy team draws the shape within 48 hours" (oShapeReq).
  - A help request reads "Help requested · WhatsApp us the photos", because it isn't sent to the team yet (item 11).
- **Deal headline (item 12, Design v22 `r-detail`).** A green box above the price table, from the hostel's best quote (the same one as the Explore ribbon):
  - **"Save ₹X in 6 months"** with its parts, e.g. "₹1,000 off the advance + ₹200 off every month".
  - With no 6-month saving it shows "₹X less upfront" or "₹X more back when you leave". Hostels with no deals show nothing.
- **No OTP wording (item 28):**
  - Poster: "Sign in with Google, one tap"; "never asks for your password or UPI PIN".
  - Room tab: "It takes one tap with Google", and the button is **Sign in**.
  - Add a manager: "signing in with Google and the code we send on WhatsApp".
  - Add resident toast: "confirms by joining with your invite code".
  - The all-screens overview and the jump panel list Sign in instead of OTP. So does the sample case event.
  - The SMS `otp` screen stays behind `phoneOtpLogin` (off) for when SMS sign-in exists.
- **Docs:** BOARD F13/F14/F18/F20/F24 rows; ARCHITECTURE "Today". There was no "170 frames" line left to fix.
- **Screens:** added the sheet `name` (Settings › Name; Design to add a board). Changed: hostel page (deal headline), Holds, owner Today plan banner, Room tab signed out, layout request sheet, Create layout, rate card. None removed.
- **Tests:** `test/wave0_test.dart`. Updated: `flows_test` (Google name is a hint; Room tab Sign in; help-requested label).
**Wave B items 10 and 11: Fan/AC layer toggle, room shapes, "Ask Hostelzy to draw it".** Branch `feature/f24-shapes`.
- **Layer toggle (10, DECISIONS F12, board `roomLayersOn`).**
  - The tenant Room tab and the resident's room view (`rRoom`) show fans and the AC as icons with labels only.
  - Under the plan: "Show: **Fan reach** · **AC airflow**" chips (AC only when the room has a unit). Both start off; tapping one draws the dashed fan circles or the airflow stripes.
  - Editors (owner, team, a resident's fix) still draw both, to place things.
- **Room shapes (11, board `oShape`).**
  - Create a layout: shape tiles Rectangle / L / T / U / Angled corner / Narrow end / Alcove / Custom, Width × Length, and "Start drawing · L shape".
  - The layout keeps its shape and walls (`outline`, feet). Tenants, residents and owners see the real walls: outside them is plain surface, with no grid.
  - Beds, fans, washroom and pillars stay wholly inside the walls; windows, doors and the AC may sit on any wall. A nudge or drag that would leave the walls doesn't move ("That's outside the walls."). New things go to the nearest free spot inside. Resizing grows the shape and keeps everything inside.
  - The editor's checks (owner, team, a resident's fix) add "Everything inside the L shape walls" or "Bed 204-B is outside the walls".
  - Mirror, flip, copy to same rooms, undo, history and residents' fixes carry the shape. The size line says "14 × 12 ft · L shape".
- **"Ask Hostelzy to draw it" (boards `oShapeReq`, `oShapeBack`).** No more WhatsApp.
  - Custom, "Ask Hostelzy to draw it" on Create, and Ask Hostelzy on a room open one sheet. It has what's different, the shape, up to 3 photos or a sketch (private, in the `fix-photos` bucket), and W × L.
  - The room then shows "Asked Hostelzy · 22 h left · done within 48 h". With no layout yet, it says "Hostelzy is drawing it".
  - When the team sends the drawing: "Hostelzy drew a new version · check and publish". The drawn room shows with "v1 · drawn by Hostelzy, <date>" and "You asked on … Drawn in N hours.", then **Publish v1** and "Ask Hostelzy to change it".
  - If the team sent only the walls, the app places the room's beds and things inside them first. Publishing closes the request. Tenants keep the live layout until then.
  - Room layouts list: "Help requested", or "Drawn · publish it".
- **Team.**
  - The in-app team editor's "Send to owner" answers an open request with the full drawing. The request shows in the editor with its due hours.
  - **Console Layout help** (board `cLayoutHelp`): owner requests, oldest due first, with hostel, room, shape, what they asked, photo count, hours left (or "Sent 3 Oct") and status (New / Drawing / Late / With owner).
  - The console's detail has the photos (signed links), Shape, From, and the owner's words. **Open in layout editor** marks the request Drawing and opens a wall editor: a preset shape at W × L, or typed corners for Custom, with an SVG preview on a 1-ft grid. **Send to owner** sends the walls; the owner's app places the beds and the owner publishes.
  - The Fair Play page's placeholder now links to Layout help. The in-app team mode had no layout-help placeholder, so nothing was replaced there.
- **Copy.** "The Hostelzy team is drawing this room" and "Layouts are drawn by Hostelzy after a visit" are gone from the Room tab. Owners draw; the 48 h is only for requests.
- **Server** (`20261003010000_f24_shapes.sql`, FOUNDER-TODO **4zk**; tests: `supabase/tests/shapes_test.sql`):
  - `layouts.shape` / `layouts.outline`; old rows stay rectangles. `put_layout`, undo (history) and `approve_layout` keep the shape.
  - `check_layout` checks the outline (3–40 corners inside W × L, a known shape) and that every bed is inside it.
  - `shape_requests`: owners and managers read their hostel's requests; the team reads and updates all. Writes go through `request_shape` (staff; a note or photo; ≤ 3 own photos; replaces an open request for the room; due in 48 h), `start_shape_request` and `send_shape_drawing` (team; checks the walls, and a full layout with beds gets the editor's checks; pushes "Hostelzy drew room N" to the hostel's staff), and `cancel_shape_request`.
  - `publish_layout` marks the room's sent request published. Staff may upload request photos under their own folder in `fix-photos`.
- **Screens.** No screens added or removed. Changed: `oCreate` (= `oShape`), sheet `layoutReq` (= `oShapeReq`), `oLayout` (+ `oShapeBack` state), picker Room tab (= `f23-Room` / `roomLayersOn`), `rRoom` (layer chips), `aLayout` (shape and request), console Layout help (`cLayoutHelp`).
- **Tests.**
  - `test/shapes_test.dart`: shapes maths and saving; layer chips off by default; an L-shaped room where a bed can't leave the walls, published and seen by a tenant; Custom → request with a photo on a fake server → the team's walls → Publish v1 with the beds inside; a missing table leaves the list as it was.
  - `flows_test` F12: Ask Hostelzy → team sends → Publish v3.
  - Console helpers: `supabase/functions/tests/console.test.ts`.

**Wave 2a items 7, 8, 22, 29: phone-only → server.** Branch `feature/f24-wave2a`.
- **Item 7, Working / Not working** (`20261003030000_f24_item_working.sql`, FOUNDER-TODO **4zz1**):
  - `set_item_working(hostel, room, item, working)`, staff or team only, changes the fan, AC or window in both copies of the room's layout. Tenants see "Fan · not working" / "AC under repair" straight away.
  - The AC also sets `rooms.ac_repair` and `rooms.ac_repair_since`. The room line now reads "AC under repair. Complaint raised <that day>. The owner is fixing it." Without a date it leaves the date out.
  - Not working raises one complaint for the hostel. `complaints.item` names the thing, and there is never a second open one. Working again closes it as Fixed ("Working again").
  - F23 things (geyser, fridge, RO…) do the same through a trigger on `amenities`, whoever marks them.
  - Nobody gets a push about their own mark. A resident's mark already tells the owner, so there's no second "New complaint" push.
  - App: the mark shows at once and the server's complaint date fills in. A room without a published layout says "Publish this room's layout first, then mark it". Offline, the mark is undone. On sample data, working again now resolves the sample complaint too.
- **Item 8, Hold for a walk-in** (`20261003031000_f24_walk_in.sql`, **4zz2**):
  - `hold_walk_in(bed)` / `release_walk_in(bed)`, staff or team only. The bed is `held` for every tenant for 1 hour (DECISIONS F04), with `beds.walk_in_until`. Tenants can't hold it meanwhile.
  - `expire_walk_ins()` (pg_cron every minute) puts it back to free, or to free soon.
  - App: the bed sheet's button saves to the server. A walk-in placed on another phone shows with its countdown, and Release ends it on the server. "isn't free any more" is said plainly.
- **Item 22, notification switches** (`20261003032000_f24_notify_switches.sql`, **4zz3**):
  - `profiles.notify` holds the Settings switches. `profiles.searched_areas` holds the last 5 areas picked in Where? or on the map.
  - Every queued push gets a `kind` (hold, rent, beds or none). A kind the user switched off is closed as "switched off" and never sent, and nobody is pushed about their own action.
  - `send-push` checks the switches again before sending. Before the SQL runs it sends as before (tests in `functions/tests/fcm.test.ts`).
  - **New free beds:** when a bed in a live hostel turns free, tenants with the switch on who searched that area get "A bed is free in <area>". That's at most one a day each (`beds_alert_at`), never to the hostel's staff or residents.
  - App: the switches and areas are saved on the profile, loaded at start and at sign-in, and kept on the phone too.
- **Item 29, team from the server** (`20261003033000_f24_team.sql`, **4zz4**):
  - `team_members`: team-only RLS. `team_hello()` makes the opening account Active, or matches a pending invite by number.
  - `team_tracker()`: every hostel with its stage. Lead…Data complete comes from `hostel_leads`, then Live, Trial or Paying from the hostel and its plan.
  - App: the real build has no sample leads and no "Founder 9000000100". Team tools load both lists. On the server the tracker button saves the stage, and "Live" goes through `go_live`'s checks. Trial and Paying follow the plan, so there's no button. "Send invite" saves a pending member.
  - The team home kicker says "sample data" only in the demo.
- **Screens:** none added or removed. Changed: tenant room / bed picker AC line (real date), team mode `aTrack` (no button on Live rows on the server), `aTeam` footnote, `aHome` kicker.
- **Tests:** `test/wave2a_test.dart`, `supabase/tests/wave2a_test.sql`, `supabase/functions/tests/fcm.test.ts`. Updated: `flows_test` (team kicker).

**Wave 3a items 17, 19, 20, 21: server rules.** Branch `feature/f24-wave3a`.
- **Item 17, owner-only areas (DECISIONS F14).** The plan and invoices, deals, rates (rate card, a room's rent and AC, the UPI ID) and Fair Play belong to the owner.
  - Server: only the owner (or the team) writes `rate_cards` and `deals`; a manager can't change a room's rent or AC (trigger on `rooms`; `save_rooms` still works for them when rent and AC stay as they are). Only the owner and the team read `owner_plans`, `invoices`, `fair_cases`, `strikes` and owner credits in `reward_ledger`. Only the owner replies to or fixes a case (also inside `fix_case` and `case_photo`, by a trigger), and only the owner uploads or reads case photos.
  - App: the app learns which hostels the user only manages (`hostel_staff.role`, no SQL needed). For a manager, Manage has no Deals, Rates and UPI or Your plan rows, and owner Today has no plan banner. A link, push or old screen to the plan, deals, rates or a Fair Play check shows **Owner only**: "Only the owner can …", what a manager runs, "Ask <owner> about …", and **Back to Manage**.
- **Item 19, AC unit on rate changes.** A room whose published layout has no AC unit can't be made AC, in Manage › Rates (on the toggle and again on Save) and on the server (rooms trigger, so also `save_rooms` and the team). The toast: "Room 204's layout has no AC unit. Add it in the room's layout and publish, then make the room AC." A room with no layout yet can be AC; publishing its layout still needs the unit. The rate card's note says the same. Rooms and floors maps the server's words too.
- **Item 20, featured spot (DECISIONS F10).** `hostel_flags()` gives each live hostel its beds and `featured`: more than 80 beds (the ₹1,499 tier, as `plan_price`) while the plan isn't 15+ days late. Under Recommended, featured hostels come first, labelled **Featured** on the card (with "· #1 near you" when it's also the best rank). Their rank number and reasons don't change. The ranking sheet says so: "Hostels with more than 80 beds get a featured spot at the top of Recommended… always marked Featured, and their rank doesn't change." In the demo, sample hostels use their own bed count.
  - Complaints in the ranking: `hostel_signals().complaints_30d` no longer counts the owner's, a manager's or the team's own "Not working" marks (4zz1) or anything the hostel's staff raised; residents' complaints count.
- **Item 21, deals pause + pushes.** `deals_paused(h)`: an unpaid invoice 15+ days past its due day. Tenants (and guests) can't read that hostel's `deals` row then, and `hostel_flags().deals_paused` says so, so the app shows walk-in prices only (`dealsPaused`). The owner's banner is back to "Deals paused: plan N days late · Tenants see walk-in prices only…".
  - Pushes through `push_outbox`, with `data.kind` so the Settings switches apply: a new invoice → the owner ("New Hostelzy invoice: ₹499", kind `plan`, always sent); `money_pushes()` daily at 9 am IST (pg_cron `hz-money-pushes`): plan 5 days late → the owner, 15 days → "Deals paused" → the owner (each once per invoice), and "Rent due today" → each resident on the app on their due day (the joining date's day, or the 1st, by the hostel's terms; not if this month's rent is already sent; kind `rent`, so the Rent switch applies). Managers get none of these.
- **Server:** `20261003050000_f24_server_rules.sql` (FOUNDER-TODO **4zx1**); tests `supabase/tests/wave3a_test.sql`. Until it runs: managers' rows are hidden in the app but the server lets them through, nothing is featured, deals don't pause for tenants, and no plan or rent pushes go out.
- **Screens:** added the state **Owner only** (manager reaching oPlan / oInvoice / oPayStatus / oCase / oStrike / Manage › Deals / Manage › Rates; Design to add a board). Changed: Manage list (manager role), owner Today plan banner (15+ days: walk-in prices line), rate card note and AC toast, Explore card (**Featured** tag), ranking sheet (featured line). None removed.
- **Tests:** `test/wave3a_test.dart`. Updated: `flows_test` F16 (204 can't go AC until its layout has the unit), `wave0_test` (15 days late: deals paused, walk-in prices only).

**Wave 2b: items 9, 13 and 14 on the server.** Branch `feature/f24-wave2b`.
- **Item 9, "Still N free beds?" (board `oTodayCards`).**
  - "Yes, all free" writes `beds.confirmed_at` for every bed of the hostel; a guard trigger stores the server's time whatever the phone sends, and it can't be cleared. Tenants read the newest one.
  - The hostel page says "N free beds · confirmed by the owner X days ago" from it; after 7 days (DECISIONS F14 / `staleAfterDays`) "Availability not confirmed". A hostel never confirmed shows just "N free beds", never "today".
  - Owner Today asks every 3 days; a real hostel never confirmed asks right away ("Not confirmed yet").
  - "Do your room layouts still match?" every 3 months: **All still correct** calls `confirm_layouts`, which stamps every published layout. The card's days come from the oldest published layout.
  - Push: `nudge_confirmations()` runs daily at 10:00 India time (pg_cron). Owners and managers of a live hostel get "Still N free beds?" when the beds weren't confirmed for 3 days (at most one every 3 days), and "Do your room layouts still match?" after 90 days (at most one every 30 days). They go through `push_outbox` like the other server pushes.
- **Item 13, "Your price is fixed".** A booking (advance hold) gets `holds.deal` from the server: the room type's rent, the hostel's advance, maintenance and notice, and the deals on at that moment. No deals with 2+ strikes, an overdue or paused plan, or when the deal covers the other room type. When the owner adds the resident, `stays.deal` is copied from their booked hold (same phone or account, 60 days). The app can't write either column.
  - Tenant: the booking page's "Your price is fixed" and "Rent" use the locked rent; "Hostelzy deal" lists the perks while paying and once booked.
  - Owner: the resident list shows "Hostelzy deal · price fixed · …"; the bed sheet has a **Hostelzy deal** row ("Price fixed · ₹7,800 monthly · …") for the resident or the booking on that bed.
- **Item 14, "Did you join?"**: the Holds card is **Yes, I joined / Not yet / Still deciding** (F07 spec), with "Only the Hostelzy team sees your answer, never the owner." The answer goes to `answer_joined` (own released or expired hold only) into `join_answers`, which only the team and the tenant who wrote it can read. The toast "Thanks. Only the Hostelzy team sees your answer." shows only after the server saved it; offline it says it couldn't save and the card stays. An answered hold isn't asked again. Console › Fair Play shows "Did you join? · <hostel>: Joined N · Not yet N · Still deciding N" (90 days) for the selected case's hostel.
- **SQL:** `20261003040000_f24_confirm_beds.sql` (FOUNDER-TODO **4zy1**), `20261003041000_f24_locked_deal.sql` (**4zy2**), `20261003042000_f24_did_you_join.sql` (**4zy3**). Tests: `supabase/tests/confirm_test.sql`, `lockeddeal_test.sql`, `joined_test.sql`; console `joinSummary` in `console.test.ts`.
- **Before the SQL runs:** "Yes, all free" already saves (staff may update their beds); "All still correct" and "Did you join?" say they couldn't save; locked perks show only on the booking phone, as before.
- **Screens:** none added or removed. Changed: Holds "Did you join?" card (3 answers + team-only line), owner Today free-beds card ("Not confirmed yet"), bed sheet (Hostelzy deal row), Residents list (deal line), booking page (locked rent), console Fair Play (answers line).
- **Tests:** `test/wave2b_test.dart`.
**Wave 1: boards with no app screen (#25, #26, #18 part, #16, manager join, refunds).** Branch `feature/f24-wave1-screens`.
- **Server** (`20261003020000_f24_wave1.sql`, FOUNDER-TODO **4zu**; tests: `supabase/tests/wave1_test.sql`):
  - `meter_readings` (one reading per room per month) and `save_meter(hostel, month, ₹ per unit, rows)`, staff or team only. Units since last month ÷ residents in the room × ₹ per unit, rounded up. A reading below last month's is refused. Residents read only their own room's rows. A new or changed amount pushes "Electricity for October: ₹140" to the room's residents. The ₹ per unit is the owner's own number, not a Hostelzy amount.
  - `tenant_level(user)` (internal) and `my_level()`: none, member or trusted. Trusted = Member + 6 months in confirmed stays + no rent paid more than 3 days after its due day. Owner complaints about tenants aren't recorded anywhere yet, so they don't count.
  - `holds.trusted` is set when a hold is placed; owners see "Trusted tenant" on it.
  - `beds.freed_at` is stamped when a bed turns free again from free soon or booked (someone moved out, a booking ended). A released or expired hold doesn't count. For the first hour only Trusted tenants can hold it ("Trusted tenants get the first hour on this bed. It opens to you at 4:05 pm"). That is the "first look"; it is enforced by the hold rules, not a separate notification.
  - `fair_cases.tenant_photo` and `owner_photo`, the private bucket `case-photos` (path `<hostel>/<uid>/<n>.jpg`), and `case_photo(case, path)` for the owner while the case is open. Owners can read only the photos on their own hostel's cases. The tenant's photo is attached by the Hostelzy team; the console screen for that is Wave 3 (#18, tenant reports in the console).
- **#25 Electricity by meter (boards `oMeter`, `rentMeter`).**
  - Owner: Rent › **Electricity** (shown when the hostel's electricity is extra). The page has ₹ per unit, then Room / Last month / Now / Units · each. An empty "Now" field has a red border and says "Type it". A first reading says "First reading · Units from next month". The button reads **Add to <Month> rent · N of M rooms**.
  - Resident: Rent shows "Electricity · 70 units ÷ 4 · ₹8/unit · ₹140" and the total includes it. Paying starts the month's payment with it. With nothing added yet it says "Electricity · Not added yet". The sample-only "Electricity · meter ₹420" line is gone; the demo keeps a consistent sample (210 units ÷ 4).
  - Before 4zu runs, the owner's page says "Electricity by meter starts after Hostelzy's next server update" and residents see "Not added yet".
- **#26 Laundry day (board `oLaundry`).**
  - Manage › House rules has a **Laundry day** row that opens the sheet: day chips, a "Machine free" seg (7 am – 12 pm / All day / Evening), and **Save laundry day**.
  - It is saved with the house rules as "Laundry day: Saturday · Evening" (no new SQL), so tenants also see it under House rules on the hostel page.
  - Resident: Me › Reminders › "From <hostel>" now has a working **Laundry day** row ("Saturday, Evening · reminder 8 pm Friday") with a switch, off by default. On, it rings every week at 8 pm the evening before, or at the end of the awake hours if those end earlier. With no day set, the row stays greyed.
- **#18 (part) Case photo (board `oCasePhoto`).** The owner's Fair Play check shows **Photo from <tenant>** ("Shown only to you and the Hostelzy team", tap to open a short-lived private link) when the case has one. **Add a photo to your reply** picks a photo, which goes up with **Send my reply**.
- **#16 Trusted perks (board `trustedPerks`).**
  - Stay Rewards has a row "Trusted tenant · what you get" that opens the sheet ("You're a Trusted tenant" when you are).
  - The sheet lists first look at new free beds (hold them 1 hour before everyone else), 2-hour holds, and "Trusted tenant" on hold requests.
  - **Left out:** "Lower-advance deals". No deal for Trusted tenants exists, so the sheet doesn't promise one, and the Stay Rewards step no longer says it.
  - On the server the level comes only from `my_level()`; local counters never make anyone Trusted.
  - Hold countdowns use the hold's own end from the server (`holds.expires_at`: 2 hours for Members). The owner's request card shows the tenant's real time left, not the owner's own level.
  - The owner's Trusted sheet now works for server holds ("Confirm hold" confirms on the server). Its "No complaints from owners" tick is gone, because Hostelzy doesn't check that.
- **Manager join (board `mgrJoin`).**
  - The existing `join_as_manager` RPC (S8) is used. "Join your PG" shows "Manager codes start with MGR. The owner sends it on WhatsApp; it works once, for 7 days." once the code starts with MGR, and hides the poster/No code help then.
  - "I run a PG" (owner gate) has "Manager at a PG? Join it with the MGR- code…", which opens that screen with `MGR-` filled in.
  - After joining, the app goes back to the role picker with "You're a manager at <PG> now. Pick "I run a PG" to start."
- **Refunds (boards `oRefund`, `rRefund`)** now match the boards.
  - `oRefund` is a sheet, not a full screen, opened from Today's refund card. The kicker reads "Left 1 Nov · Bed 204-B" and the title "Refund Rahul's advance". The rows are Advance / Kept on leaving / Refund / Pay to, then "UPI reference (UTR), 12 digits", **Mark ₹X refunded**, and "Due by <date>, 7 days after they left".
  - `rRefund` has the card "<owner> marked it refunded · <date>" with the amount and "To +91 … · UPI ref. …". The rows are Advance / Kept on leaving / Due by, then "Did ₹X reach your bank?" with **Yes, I got ₹X** / **Not received**. The date comes from `refund_sent_at`.
  - "Pay to" is the former resident's number (UPI); Hostelzy doesn't keep tenants' UPI IDs.
- **Screens:** added `oMeter` (screen), `laundry` and `perks` (sheets). Changed: `oRefund` from a screen to a sheet; `rRefund`, `oRent` (Electricity row), `rPay` (meter line), Manage › House rules (Laundry day row), Reminders (Laundry day row), `oCase` (photo), `rewards` (Trusted row), the Trusted badge sheet, role gates (manager join). Removed: none.
- **Tests:** `test/wave1_test.dart`, `supabase/tests/wave1_test.sql`. Updated: `moves_test` (refund boards), `resident_test` (meter line), `flows_test` (manager toast).

**Wave 4c: the rest of Wave A items 1, 2 and 4.** Branch `feature/f24-wave4c`.
- **Server** (`20261003090000_f24_wave4c.sql`, FOUNDER-TODO **4zp1**; tests: `supabase/tests/wave4c_test.sql`):
  - `profiles.whatsapp` (10 digits or empty) and `hostel_leads.owner_whatsapp`. `owner_contacts` now returns `(hostel_id, phone, whatsapp)` to the same people as before: the owner's own WhatsApp, else the team's note, else empty.
  - `save_hostel` also saves `rules` (house rules) and `amenities` (new `hostels.amenities`) when sent, and the owner's WhatsApp. It refuses a pin outside Hyderabad.
  - `go_live` also needs the pin: "drop the map pin at the gate".
  - `menus.breakfast_time / lunch_time / dinner_time` ("07:30-09:30" or empty) and `save_meal_times(hostel, {b, l, n})` for staff or the team: the same times on all 7 days, and each meal must end after it starts.
- **#1 Owner phone.**
  - The owner's bed sheet **Message <resident>** opens WhatsApp on the resident's own number (from `stays`), for a taken bed and for one marked leaving.
  - Settings › You has a **WhatsApp** row for owners ("Same as phone" or the number). It opens the sheet "Your WhatsApp number": **Save WhatsApp number**, and **Use my phone number** to clear it. The number is kept on the profile and on the phone.
  - Wizard step 6 has "Owner's phone" and "WhatsApp, if different". The sign-in link goes to the WhatsApp number.
  - Every WhatsApp link to an owner (Message owner, Remind, Talk to, notice, refunds, layout fixes, enquiries, plan reminders) uses `ownerWa(hostel)`: the WhatsApp number, else the phone. **Call** keeps the phone.
- **#2 Onboard a real hostel.**
  - Basics: the pin row opens the new screen **Map pin** (`aPin`). The pin stays in the middle and the map moves under it. **Use my location** asks for an exact GPS fix at the gate.
  - **Save pin** works only after the team moved the map or used their location, so a hostel is never saved on its area's centre. The draft sends only that pin, and the go-live row reads "Map pin dropped at the gate" with its coordinates.
  - Basics also has **Visitors**. The gate time and visitors go up as the hostel's house rules, the rest from the rate card's terms. Every amenity picked is saved (all in `tags`, plus `amenities`), not just three. A real draft starts with no gate time or visitors.
  - Console › Hostels › **Go live** calls `go_live()`, so it gets the checklist and the 30-day trial. The server's reason shows as "Not live yet: add 8 photos first." Pause is unchanged.
- **#4 Meal times.**
  - Owner Food menu has a **Meal times** box. When none are set it reads "Not set. Residents' meal reminders use the usual times…", with **Set meal times**. Once set, each meal has start and end steppers (15 minutes) and a **Use the usual times** link. They save with **Save menu**. Before 4zp1 runs, the menu saves and the toast says the times save after the server update.
  - Residents' meal reminders ring at the menu's start times, and "served till" uses its end times. A meal with no time keeps the usual one. Reminders › Meal times reads "From the food menu · …", or "Usual times, the menu has none yet · …". The times shown in Food, on Home and in the tenant's food peek and week sheet follow the menu too.
- **#3 leftover:** none. No "Hostelzy draws its layout" toast is left (Wave 0 removed it; `wave0_test` checks it).
- **Screens:** added `aPin` (screen) and `waNum` (sheet). Changed: `aAdd` step 1 (Visitors field, pin row opens `aPin`), `aAdd` step 6 (WhatsApp, if different), `aAdd` step 7 (pin row), `settings` (owner WhatsApp row), owner Food menu (Meal times box), owner bed sheet (Message resident with the number), Reminders (meal line), console Hostels (Go live). Removed: none.
- **Tests:** `test/wave4c_test.dart`, `supabase/tests/wave4c_test.sql`, console `goLiveWords` test. Updated: `onboard_test.sql` (sends a pin), `team_app_test`, `flows_test` and `onboard_test` (the pin screen), `owner_phone_test` (contacts with WhatsApp).
**Wave 4b: F12 women's PG floor + one editor at a time, F14 scan the invite QR, #27 "Tell me when it's ready", brand push icon + dark splash.** Branch `feature/f24-wave4b`.
- **Server** (`20261003070000_f24_wave4b.sql`, FOUNDER-TODO **4zs1**; tests: `supabase/tests/wave4b_test.sql`):
  - `sees_floor(h)`: the hostel's staff, the team, its residents, and a tenant with a hold there (asked, held or booked). The "read published layouts" policy now also needs it for a **Women** PG, so nobody else can list all its rooms (DECISIONS F12: whole-floor plans only after a hold).
  - `room_layout(hostel, room)`: one room's published layout for any signed-in (Google) user, so the Room tab still shows room layouts (DECISIONS F12). In a women's PG, before a hold, at most **6 different rooms a day per PG** (`layout_peeks`); after that "hold a bed to see more rooms here". Build's call: enough to compare rooms, too few to piece the floor together.
  - `layout_locks` + `lock_layout(hostel, room)` / `unlock_layout`: one editor per room. The lock lasts 10 minutes and the app refreshes it every 4 minutes while the editor is open. Others get the holder's first name ("The owner" / "A manager" / "The Hostelzy team" when the profile has no name). A trigger refuses any new published version (publish, an approved fix, undo) from anyone else while the lock is held: "<name> is editing this room. Try again when they're done."
  - `layout_waits` + `wait_for_layout(hostel, room)`: "Tell me when it's ready" (signed-in, live hostel, room without a layout, at most 30 open). When the room's layout is published, everyone waiting gets one push ("Room 204's layout is ready", `data.kind` = `hold`, so Settings › Holds and bookings switches it off) and the waits close. Later versions don't push again.
- **App:**
  - Room tab, women's PG on the server: a room missing from the list is fetched on its own ("Loading the layout…"). Past the day's rooms it shows the existing lock message "Floor plan shows after you hold a bed" with "Pick a bed from Plan". Offline: "Couldn't load this room" + Try again.
  - Layout editor: taking the lock on open, letting it go on back, on switching rooms (room chips) and after publishing. While someone else has it, the header says "<name> is editing this room", Publish / Send to owner is dimmed and says why, and **Check again** sits beside it. The server's refusal shows the same words. The room chips no longer crash on a room with no layout yet.
  - "Tell me when it's ready" (#27): saved on the server; the button turns into **We'll tell you** with "You get a notification when the owner publishes room 204's layout." The toast-only version is gone. Sample data keeps it on the phone.
  - F14 **Scan the QR** on Join your PG (`mobile_scanner`, Android CAMERA permission). The first time, a camera explainer sheet (`scanCam`: "Only to read the QR on your PG's Hostelzy poster…", **Allow camera** · "Your phone asks next", Type the code instead). Then the `scan` screen: camera square, "Point it at the QR on the Hostelzy poster…", **Type the code instead**. The QR's j/ link (or a bare code) fills in the code and asks to join; another app's QR says "That QR isn't a Hostelzy invite". Camera refused: "The camera is off for Hostelzy" with where to allow it. Without a camera (web, tests) the button says how to use the phone's camera.
  - Brand (docs/brand/app-assets.md): server pushes set `android.notification.icon = ic_stat_hostelzy` and colour `#EC3013` (`fcm.ts`); the manifest has the FCM default icon/colour; the new vector `ic_stat_hostelzy.xml` replaces the 5 PNGs; reminders use the red too. Splash: `splash_bg` #F3F2F2 / #161514 (Pal light/dark bg) with `splash_icon` light/dark, Android 12+ styles in `values-v31` and `values-night-v31`, and NormalTheme on the same ground (no white flash).
- **Screens:** added `scan` (screen) and `scanCam` (sheet). Changed: Join your PG (Scan the QR), tenant Room tab (Loading, women's PG lock, Couldn't load, We'll tell you), layout editor `aLayout` (lock line + Check again). Removed: none.
- **Tests:** `test/wave4b_test.dart`, `supabase/tests/wave4b_test.sql`, `supabase/functions/tests/fcm.test.ts`. Updated: `start_test`, `wave1_test` (button name).
**Wave 4a: enquiries and reviews gaps (audit §3).** Branch `feature/f24-wave4a`.
- **F05 enquiry link.** The WhatsApp message now ends with the booking code line and then the enquiry's https link (`enquiryLink`, e.g. `https://farhath.me/hostelzy/app/r/?c=HZ-4822`), the same link Android App Links open in the app. The owner taps it and lands on Today with that enquiry open.
- **F05 one open enquiry per bed (server).** The app now calls `send_enquiry(...)`. It returns the tenant's open enquiry for that hostel + bed, or one the owner answered in the last 60 days. Only when there is none does it record a new one. A unique index (`enquiries_one_open`) also stops a second open enquiry inserted directly. If the server refuses a duplicate, the app reuses the existing code and says "You already asked about this bed, so it's the same booking code: HZ-…". Old duplicates are kept: the newest stays open and the older ones point at it (`dup_of`).
- **F08 reviews (server).**
  - Each review is tied to the author's confirmed stay (`stay_id`, `room`). There is one 30-day review and one exit review per stay (unique index). Older duplicates are hidden, not deleted.
  - The 30-day review opens 30 days after `joined_on`. The owner and their staff can't review their own hostel.
  - The author can change their stars, words and answers (`edited_at`, shown as "· edited"), and nothing else.
  - Staff reply once ("you already replied to this review"). Hidden reviews leave the hostel page and the rating, but the author still sees theirs.
  - `report_review(review, why)`: anyone signed in, once each, never on their own review. `decide_review_report(review, hide)` is for the team only.
- **F08 app.**
  - Resident › My stay › "Review your stay" shows "Opens 21 Oct · after 30 days" until it opens, and tapping it says so. The Home card appears only once the review is open.
  - Once posted, the row reads "Change your 30-day review". The form comes back filled in and its button reads **Save changes**. The exit review works the same way ("Change your exit review").
  - Owner › Reviews: each card has **Report abuse** (sheet `revReport`: four reasons, **Send to Hostelzy**). Once sent it reads "Reported to Hostelzy". The server's refusals are shown in plain words.
- **Console › Reported reviews** (new nav item): open reports grouped by review, showing hostel, review, stars, reasons and since when, with **Hide** / **Keep**.
- **F13 S4 layout flag.**
  - On the server, a 30-day review answering "Is the room layout right? No" adds one to `layouts.disputes` for the author's room. Changing the answer, or the team hiding the review, takes it back. Publishing the room again resets it (unchanged).
  - The app reads `disputes`. Owner › Layouts shows "Residents say this layout is wrong" in red on that room. The room page has a red box with the count ("answered "No" in the 30-day review. Check the room, fix the layout and publish it again.").
  - Sample data flags the resident's own room instead of a fixed 204.
- **Server SQL:** `supabase/migrations/20261003060000_f24_enquiries_reviews.sql` → FOUNDER-TODO **4zr1**. Until it runs, enquiries insert as before (the app falls back when `send_enquiry` is missing), reviews work as before, and reports say they couldn't send.
- **Screens:** added the `revReport` sheet (Report this review) and the console view "Reported reviews". Changed: `rReview` / `rExit` (Save changes, one-per-stay line), `rStay` (review row), `rHome` (card only once open), `oRank` / Reviews (Report abuse), `oLayouts` and `oLayout` (layout-wrong flag), the WhatsApp sheet (link line). Removed: none.
- **Tests:** `test/wave4a_test.dart` (8), `supabase/tests/wave4a_test.sql`. Updated: `rls_test.sql` (the resident has 40 days; authors may edit, not reply), `reviews_test.sql` (40 days), `flows_test` / `tenant_test` (the message ends with the link).

**Wave 3b: item 18, Fair Play hardening.** Branch `feature/f24-wave3b` (2026-10-03). DECISIONS F07: strikes are 1 warning, 2 deals hidden for 30 days, 3 removed. A fix within 48 hours means no strike, and 3 fixes in 6 months = 1 warning.
- **Rules accepted on the server.** "Agree and continue" also calls `accept_fair_play()`, once per account, into `fair_play_accepts`. On sign-in the app asks the server. If the owner agreed on another phone, the rules aren't shown again. If they agreed on this phone before the server had it, it is sent then. Console › Fair Play shows "Fair Play rules: agreed 3 Oct" for the case's owner.
- **Joined before Hostelzy.**
  - `hostels.live_since` is set by the server when a hostel goes live (backfilled from `visited_on`). Owners can't change it.
  - `stays.via = 'before'` is allowed only for someone who moved in on or before that day. The owner can set it only while the hostel isn't live yet (onboarding). After go-live only the team can.
  - The wizard's residents step now saves its residents as "before" (it said so, but the server stored them as Direct).
  - Add resident has a "Lived here before Hostelzy" tick, shown only before go-live. If the server says no, the owner sees "Your hostel is live now, so only the Hostelzy team can mark someone as joined before Hostelzy."
  - These residents never count in the collusion signals.
- **Strikes now.**
  - `strike_state(h)` and the public `fair_standing()` return the count, when strike 2's hidden deals come back (30 days from the day it was given), whether the hostel is removed, and why the last strike came (`case` | `fixes`).
  - Strikes keep counting: DECISIONS gives no expiry for them, only for strike 2's hidden deals.
  - `deal_for_bed` uses the 30 days. The app's `dealsOf` uses `dealsHidden()`: hidden until the server's date. With no date (sample data, or before the SQL runs), strike 2 keeps them hidden as before.
  - The owner's Today card says "Deals hidden until 2 Nov", then "Deals back since 2 Nov".
- **Strike 3 hides the hostel on the server.**
  - `is_live()` and the hostels read policy leave out a hostel with 3 strikes. Tenants can't read it, its rooms, beds, deals or reviews, and can't hold or enquire there.
  - Its owner and the team still see it, and the owner's strike notice says why. Its plan is paused, so no more invoices.
- **3 fixes in 6 months = 1 warning, counted on the server.** `fix_case` stamps `fixed_at`. On the third uncounted fix in 6 months it adds a strike with reason `fixes` and marks those three fixes as counted. The owner's toast says "That's 3 fixes in 6 months, which counts as one warning (strike N of 3)". The strike notice says "Three fixes count as one warning".
- **All 6 signals on the server.** `fair_signals(hostel)` is team only. It returns one row per F07 signal:
  - held or enquired, then added as Direct (same name, another number);
  - hold cancelled, same bed taken by a Direct resident within 7 days;
  - tenant said "Yes, I joined" (Wave 2b `join_answers`) 3+ days ago and was never added;
  - a Direct resident paying less than the walk-in price while deals are on;
  - declining holds while occupancy rises. The new `holds.declined` is set when the owner or a manager (not the tenant) turns a hold down: 2+ declined and 2+ Direct residents added in 30 days;
  - tenant reports (90 days).
  Console › Fair Play shows the six for the selected case's hostel, each with its count and detail.
- **Tenant reports in the console (board `cCases` + Tenant reports).**
  - `fair_reports.status` is new → case | closed. **Open a case** runs `report_case()`, which opens an FP case for the owner. The case has the reason only, never the tenant's name or note.
  - **No case · close** closes the report. Tenants can only file new reports.
- **Case photo from the console.** In the case detail, **Attach tenant's photo** uploads to `case-photos` (`<hostel>/<team uid>/tenant-….jpg`) and sets `fair_cases.tenant_photo`. The owner's case shows "Photo from <tenant>" (Wave 1). The owner's and the tenant's photos open as signed links.
- **Correct strike labels everywhere.**
  - The team's strike goes through `give_strike()`, which writes "Strike 2 · deals hidden for 30 days". Before the SQL runs, the old insert is the fallback.
  - The console button says the next strike ("Strike 2 · deals hidden for 30 days"), not always "Strike · warning".
  - The app's aCases decision uses the same words (`strikeDecision`). The Today card, the strike notice and the aCases notes say "deals hidden for 30 days".
  - aCases "Live since" shows the real go-live date, not a made-up "1 Oct 2026".
- **Overlap with Wave 3a:** the only policies changed are the hostels read policy ("live hostels"), the tenant insert on `fair_reports` and the new team update on `fair_reports`. `fix_case` and `deal_for_bed` were redefined (owner/staff checks unchanged).
- **SQL:** `20261003080000_f24_fair_play.sql` (FOUNDER-TODO **4zf1**). Test: `supabase/tests/fairhard_test.sql`.
- **Screens:** none added or removed. Changed: sheet `addR` (Add resident: "Lived here before Hostelzy" tick before go-live), `oToday` Fair Play card (deals hidden until / back since), `oStrike` (server dates, deals back, 3-fixes wording), `aCases` (decision words, real "Live since"), console Fair Play `cCases` (case detail, six signals, Tenant reports with Open a case / No case · close, attach tenant's photo, strike button wording).
- **Tests:** `test/wave3b_test.dart`; console `strikeWords` / `standingLine` / `reportLine` in `supabase/functions/tests/console.test.ts`.

**Wave 4d: F03 gaps (audit §3).** Branch `feature/f24-wave4d`.
- **"Best deals" sort (F03).** Filters › Sort by now has **Recommended / Nearest / Best deals / Lowest price**, so the owner Deals screen's "find you in Best deals" is true. Best deals orders hostels by the 6-month saving (`DealQuote.save6`, the same number as the Explore ribbon and the hostel page headline, for the AC / Non-AC filter in use), then nearest. A hostel with no deal, deals hidden by 2 strikes (F07) or paused by a 15+ days late plan (Wave 3a `deals_paused`) counts as 0 and sorts last. Featured hostels (Wave 3a) lead only Recommended, never Best deals.
- **Rates "Confirmed by the owner · date" (F03 rule, DECISIONS F21 one price table).**
  - Server: `rate_cards.confirmed_at`, stamped with the server's time when a card is added or its rent changes. The owner's **Rates still right** (`confirm_rates(hostel)`) stamps all of them; it is owner (or team) only, like rates since Wave 3a. Saving the same price keeps the old date, and the phone can't set or clear it. Cards from before the SQL stay unconfirmed (null): no date is invented.
  - Tenant hostel page: under the price table, "**Confirmed by the owner** · 19 Sep" (the oldest card's date), or "**Not confirmed in over a month** · ask the owner before you visit." after 31 days. Nothing when unknown (never confirmed, or before the SQL runs).
  - Owner Today: **Are your rates still right?** (like the free-beds card): "Last confirmed 25 Aug" (or "Not confirmed yet"), the rate chips ("2 sharing non-AC · ₹8,000"), **Rates still right** and **Change** (opens Manage › Rates). It shows from 30 days, or at once when the server says the rates were never confirmed; never to a manager. Offline it says it couldn't save and stays.
  - Push: `nudge_rates()` daily at 10:15 India time (pg_cron `hz-rates-nudge`): "Are your rates still right?" to the hostel's owner only when the oldest rate wasn't confirmed for 30 days (or never), at most one every 30 days (`rate_nudges`). `data.kind` = `rates` (not a Settings switch, so always sent), `screen` = `oToday`.
  - Demo: sample confirm dates per hostel (`seedRatesConfirmed`; Greenview is 40 days old to show the warning).
- **Server SQL:** `supabase/migrations/20261003100000_f24_rates_confirm.sql` → FOUNDER-TODO **4zd1**. Until it runs, tenants see no date and owners get no card or push; the sort needs no SQL.
- **Screens:** none added or removed. Changed: Filters sheet (Best deals sort), tenant hostel page (rates confirmed line under the price table), owner Today (new **Are your rates still right?** card, Design to add it to `oTodayCards`).
- **Tests:** `test/wave4d_test.dart` (6), `supabase/tests/rates_confirm_test.sql`.

**Performance pass (no behaviour or UI change).** Branch `perf/app-efficiency`.
- **Fewer round trips.** Explore's hostel cards asked for their photos one query per card; photos asked for in the same frame now come in one `hostel_id in (...)` query (`HostelRepo.photosOfMany`). Reordering photos and saving room rates send their per-row updates together (`Future.wait`) instead of one after another. The listings load runs its four reads (hostels, strike standing, layout checks, layout checkers) side by side; `refreshListings` asks for listings, signals and flags together; app start asks for settings and hostels together; a hostel's menu and meal times come together. Every fallback for SQL that hasn't run yet is unchanged. No new SQL.
- **Realtime.** One refetch at a time: a refetch asked for while one runs waits for a single shared follow-up. A burst of changes is one refetch 400 ms after the last change, and a burst that never pauses still refetches every 2 s.
- **Signed photo links** (complaint, fix and case photos) are kept for 50 of their 60 minutes, so a rebuild doesn't ask for a new link and download the photo again.
- **Rebuilds.** The 1-second clock on Holds, Hold, Today and the code screen now rebuilds only the countdowns (`Ticking`: the hold timers, Today's "Needs you now", "Resend in"), not the whole app; with a sheet open, or when the day changes, everything rebuilds as before. Live rows index payments by hold and stay once instead of scanning all payments per hold and per resident.
- **Screens:** none added, removed or changed.
- **Tests:** `test/perf_test.dart` (5).
