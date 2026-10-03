# F25 · Restore missing screens (archive of earlier designs)

**Stage:** Design approved · 2026-10-03 (Design chat; founder task through the hub). Build: build the four NEW boards.

## Hub decision (founder delegated, 2026-10-03): what comes back, kept simple
Rule: every screen has its own job, with no two screens doing the same thing. Old views come back **inside existing screens**
where they fit, not as extra screens.

| Item | Decision | Where it lives |
|---|---|---|
| A1 Building view (G, F1, F2, F3 + rooms + beds) + shared things | **Bring back, as ONE screen.** NEW-1 and NEW-2 are merged: shared-thing chips sit on top of each floor row (red when not working); tap a floor → the existing floor sheet | Bed picker tab *Plan · Room · **Building*** (tenant); the hostel page links to it |
| NEW-2 separate floor map | **Merged into NEW-1** (no second screen) | — |
| A2 owner corridor floor plan, A3 owner "All floors" | **Not separate screens.** The owner's Beds gets the **same Building view** (one shared component) as a toggle *Rooms · **Building***; tap a bed → the existing bed sheet | Owner › Beds |
| A4 owner menu week table | **Bring back as a toggle** *By day · Week* on the existing menu screen (not a new screen) | Owner › Manage › Food menu |
| A6 owner occupancy | **Fold into the existing "This month" card:** add "78% full" and the occupancy bar. No 4 tiles ("Needs you now" already covers holds and complaints) | Owner › Today |
| A7 all plan tiers | **Small section on the existing plan screen**: the 3 tiers, yours marked | Owner › Your plan |
| A8 invoice history | **"Past invoices" list on the existing plan screen** | Owner › Your plan |
| A5 room board | **No.** It was sample data; a real one needs moderation. Kept as an idea | — |
| A9 confirm stay, A10 ₹299 hold | **Stay removed** (DECISIONS) | — |
| Prototype ideas (compare, SOS, parent view, P&L…) | **Not now.** Listed as ideas in BOARD "Ideas" | — |

Net effect: **+1 screen** (Building view, NEW-1). Everything else is a section or toggle in a screen that already exists.
Design also checks the main canvas for screens that do the same job and proposes merges in this file (with ids). Build merges
them only when one clearly duplicates another.

## Redundancy review (Design, 2026-10-03, canvas v33)
Checked every main board in pairs: same data and same action for the same role. Only clear duplicates are proposed for merging.

| Pair | Same job? | Proposal |
|---|---|---|
| **H17 `add` (Add tenant, centre tab) + H20 `addR` (Add a resident)** | Yes. Both put a person on a bed for the owner. Both save through `addStayLive` (`owner_sheets.dart:163`, `residents.dart:64`). Only the date differs: "Moves in" (future) vs "Joined on" (past) | **Merge into one sheet, "Add a resident"**. Keep the one date field, allowing past or future. Keep fee, advance and "Lived here before Hostelzy". The centre "+" tab and Residents › Add both open it. *Confident → told Build.* |
| **S76 `aPay` (team mode Payments check) + C2 console Payments** | Yes. The same team role matches the same owner UTRs with the same Mark paid / Not received | **Keep the console only.** It's desk work against the bank app. Remove aPay from the app's team tools. *Confident → told Build.* |
| **S77 `aCases` (team mode Fair Play cases) + C3 console Fair Play** | Yes. The same team role decides the same cases with the same strike buttons. The console has more (signals, photos, tenant reports) | **Keep the console only.** Remove aCases from the app. *Confident → told Build.* |
| S75 `aTrack` (team mode tracker) + C1 console Onboarding | Mostly. The same leads and stages; the app opens it after go-live on a visit | **Keep for now.** The team uses it on the phone during visits. Revisit once the console works well on phones. |
| S82 `perm` (Turn on notifications?) + H5 `holdNotify` (allow after the first hold) | The same ask, at different moments | **Keep both screens**, but a tenant should never see both. Tenants get only H5 after the first hold; S82 only for residents and owners at role pick. (Build: check `login.dart:186`.) |
| H12 `payUtr` (tenant/resident UPI ref) + H22 `utr` (owner plan UPI ref) | Same pattern, different payer and payee | **Keep.** Different role and money. Build can share one widget. |
| S2 `login` + H3 `signIn` sheet | Same Google button, different moment (start vs mid-action as a guest) | **Keep.** The sheet keeps the guest's place (hold, enquiry). |
| S25 resident Food › Week + H10 tenant Food menu week sheet | Same data, different role (resident tab vs tenant peek) | **Keep.** |
| S21 `moveIn` + S20 `hold` (Booked) | Overlap on "Pay at move-in", but moveIn has its own action ("I've moved in · open My stay") and the reward line | **Keep.** |

Net if Build takes the three confident merges: **App 181 → 178** (H17+H20 → one sheet; S76, S77 removed). The canvas follows the app:
I'll retire those boards once SCREENS.md drops them.

**v34 · after #107, #109, #110, #111:** NEW-1 → **[S87] Building view** (Ground floor row only when it exists; hostel page has
"See the whole building ›"). Variants: S37 Rooms · Building, S45 By day · Week, S65 All plans + Past invoices, S36 "83% full"
+ bar + "33 of 40 beds have a resident. Holds don't count." Retired to the archive: S76 aPay, S77 aCases, H17 Add tenant
(merged into H20). **v35:** S87 and the S37 Building variant now match `building_view.dart` (#109) exactly: "Cross-section · tap any free bed" (owner: "· tap a bed") + "N free", roof, F3/F2/F1/G labels with the free count, base slab, owner legend without "Your pick", and the note "Shared things sit on top of each floor. Tap a floor to see if they’re working." `aHome` now says "Payments and Fair Play cases are in the team console". **App 179 · Canvas 179.**

## Problem
Earlier designs lived in many separate artifacts on the old account. Some screens the founder remembers
(the whole-building view, a floor map with the shared things on it) never made it into the app.

## Design
Canvas: https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx (v33). At the bottom there's an **"Archive: earlier designs · not counted"**
area, with one row per source and every board titled `[archive · not counted] SRC · board → SCREENS id`. App N = Canvas N
counts only the main area.

- **Archive: 218 boards** from 16 sources:
  - the original Claude Design handoff (`project/HostelzyApp.dc.html`, 32 screens + the prototype itself)
  - 14 earlier design artifacts: F03, F05/06, F07, F08, F10, F14, F15, F17, F18, F19, F20, F21 before→after, F21 full, F23
  - 7 boards retired from the old main canvas
- **Couldn't open (not shared with this account, or deleted):** F12 room layouts `8uEkfu5EzRsDeZrkb8Gjaz`, F16 `1orwCNMz68vVRrMhfqtpKV`,
  design book `VV4W8tvmbEGf7YnX66ZUJB`. If the founder shares them with this account, I'll add them.

### MISSING in the app → new main boards (current F22 style, light + dark tweak), ready for Build
| New id | Board | What it is | Best earlier versions |
|---|---|---|---|
| **NEW-1** | `w4-building` | **Building view**: picker tab *Plan · Room · Building*. Every floor stacked (3, 2, 1, G), every room with its beds (free / hold / taken / your pick), the shared things listed under each floor, G = reception, no beds. Tap a free bed → Continue. | handoff `z-h0-12` (Building cross-section), F14 `z-f14-PickerFloors` |
| **NEW-2** | `w4-floorMap` | **Floor map with shared things**: picker Plan, one floor. Rooms either side of the corridor, stairs, WC, and the shared things **placed where they are**: Fridge, RO water, Washer (red when Not working). Geyser line for room washrooms. Tap a thing → floor sheet (H42). | handoff `z-h0-22` (corridor plan), F23 `z-f23-Floor` / `z-f23-Room` |
| **NEW-3** | `w4-oFloorPlan` | **Owner Beds › Floor plan** (seg *Floor plan · All floors*): same corridor map, each bed shows the resident's initials, Free, Hold or the free-from date; shared things placed, broken ones red with a "mark Fixed" line. Tap bed → bed sheet (H18). | handoff `z-h0-22`, F14 `z-f14-BedMapFloors` |
| **NEW-4** | `w4-oMenuWeek` | **Owner Food menu › Week table** (seg *Edit by day · Week table*): Mon–Sun × Breakfast / Lunch / Dinner, today highlighted, empty slots say "Not set". Tap a day to edit. | handoff `z-h0-27` (owner menu week table) |

Rules for Build:
- Shared things come from the F23 data (`amenities`). Each one needs a position on the floor: x/y on the floor grid, set by the owner in Layouts › Shared things.
- Women's PGs keep the hold-first lock (T10/T13). NEW-1 and NEW-2 show only after a hold there.
- Never draw gates, CCTV or exits.
- Add each new board to `docs/SCREENS.md` with a real id when it's built. Then rename `[NEW-n]` on the canvas.

### Archive board → SCREENS id
| Archive board | Matches SCREENS id | MISSING in app | Note |
|---|---|---|---|
| Original Claude Design handoff · Welcome (`z-h0-01-Welcome.dc.html`) | S1 (before) |  | older version of the same screen |
| Original Claude Design handoff · Mobile number (`z-h0-02-Mobile-number.dc.html`) | not counted (SMS OTP flag off) |  | not counted |
| Original Claude Design handoff · Enter the code (`z-h0-03-Enter-the-code.dc.html`) | not counted (SMS OTP flag off) |  | not counted |
| Original Claude Design handoff · Role (`z-h0-04-Role.dc.html`) | S4 |  |  |
| Original Claude Design handoff · Explore (`z-h0-05-Explore.dc.html`) | S8 (before) |  | older version of the same screen |
| Original Claude Design handoff · Search sheet (`z-h0-06-Search-sheet.dc.html`) | H1 (before) |  | older version of the same screen |
| Original Claude Design handoff · Map (`z-h0-07-Map.dc.html`) | S9 (before) |  | older version of the same screen |
| Original Claude Design handoff · Hostel page (`z-h0-08-Hostel-page.dc.html`) | S13 (before) |  | older version of the same screen |
| Original Claude Design handoff · WhatsApp sheet (`z-h0-09-WhatsApp-sheet.dc.html`) | H6 (before) |  | older version of the same screen |
| Original Claude Design handoff · Pick a bed · Plan (`z-h0-10-Pick-a-bed-Plan.dc.html`) | S16 (before) |  | older version of the same screen |
| Original Claude Design handoff · Pick a bed · List (`z-h0-11-Pick-a-bed-List.dc.html`) | S18 (before) |  | older version of the same screen |
| Original Claude Design handoff · Pick a bed · Building (`z-h0-12-Pick-a-bed-Building.dc.html`) |  | **MISSING** · NEW-1 |  |
| Original Claude Design handoff · Hold sheet (`z-h0-13-Hold-sheet.dc.html`) | H4 (before) |  | older version of the same screen |
| Original Claude Design handoff · Hold (`z-h0-14-Hold.dc.html`) | S20 (before) |  | older version of the same screen |
| Original Claude Design handoff · Resident home (`z-h0-15-Resident-home.dc.html`) | S23 (before) |  | older version of the same screen |
| Original Claude Design handoff · Pay rent (`z-h0-16-Pay-rent.dc.html`) | S26 (before) |  | older version of the same screen |
| Original Claude Design handoff · Food (By day / Whole week) (`z-h0-17-Food-By-day-Whole-week.dc.html`) | S24, S25 |  |  |
| Original Claude Design handoff · Help (`z-h0-18-Help.dc.html`) | S27 (before) |  | older version of the same screen |
| Original Claude Design handoff · Give notice (`z-h0-19-Give-notice.dc.html`) | S29 (before) |  | older version of the same screen |
| Original Claude Design handoff · Move bed (`z-h0-20-Move-bed.dc.html`) | S30 (before) |  | older version of the same screen |
| Original Claude Design handoff · Owner Today (`z-h0-21-Owner-Today.dc.html`) | S36 (before) |  | older version of the same screen |
| Original Claude Design handoff · Owner Beds · Floor plan (corridor, stairs, WC) (`z-h0-22-Owner-Beds-Floor-plan-corridor-stairs-WC.dc.html`) |  | **MISSING** · NEW-3 |  |
| Original Claude Design handoff · Bed sheet (`z-h0-23-Bed-sheet.dc.html`) | H18 (before) |  | older version of the same screen |
| Original Claude Design handoff · Add booking (`z-h0-24-Add-booking.dc.html`) | H17 (before) |  | older version of the same screen |
| Original Claude Design handoff · Owner rent (`z-h0-25-Owner-rent.dc.html`) | S38 (before) |  | older version of the same screen |
| Original Claude Design handoff · Complaints (`z-h0-26-Complaints.dc.html`) | S42 (before) |  | older version of the same screen |
| Original Claude Design handoff · Menu (Edit by day / Week table) (`z-h0-27-Menu-Edit-by-day-Week-table.dc.html`) |  | **MISSING** · week table → NEW-4 |  |
| Original Claude Design handoff · Rules (`z-h0-28-Rules.dc.html`) | S46 (before) |  | older version of the same screen |
| Original Claude Design handoff · Explore (dark) (`z-h0-29-Explore-dark.dc.html`) | S8 dark (before) |  | older version of the same screen |
| Original Claude Design handoff · Pick a bed (dark) (`z-h0-30-Pick-a-bed-dark.dc.html`) | S16 dark (before) |  | older version of the same screen |
| Original Claude Design handoff · Resident home (dark) (`z-h0-31-Resident-home-dark.dc.html`) | S23 dark (before) |  | older version of the same screen |
| Original Claude Design handoff · Owner Today (dark) (`z-h0-32-Owner-Today-dark.dc.html`) | S36 dark (before) |  | older version of the same screen |
| Original Claude Design handoff · The clickable prototype itself (all screens, jump list) (`HostelzyApp.dc.html`) | original prototype |  |  |
| F03 Deals · 1 · Tenant: hostel page with the deal (`z-f03-Main.dc.html`) | S13 (deal headline) |  |  |
| F03 Deals · 2 · Tenant: Explore with savings badges (`z-f03-Card.dc.html`) | S8 (Best deals sort, green price) |  |  |
| F03 Deals · 3 · Tenant: pay advance, deal locked (`z-f03-Book.dc.html`) | H7, S20 |  |  |
| F03 Deals · 4 · Owner: pick your deals (`z-f03-Owner.dc.html`) | S43 |  |  |
| F05 / F06 Enquiries and residents · F05 · 1 · Tenant: WhatsApp sheet with HZ ref (`z-f05-Main.dc.html`) | H6 |  |  |
| F05 / F06 Enquiries and residents · F05 · 2 · Owner Today: Enquiries from Hostelzy (`z-f05-Enquiries.dc.html`) | S41 |  |  |
| F05 / F06 Enquiries and residents · F05 · 3 · Owner: one enquiry (`z-f05-EnquiryDetail.dc.html`) | H19 |  |  |
| F05 / F06 Enquiries and residents · F05 · 2 in dark mode (`z-f05-EnquiriesDark.dc.html`) | S41 dark |  |  |
| F05 / F06 Enquiries and residents · F06 · 4 · Owner: Residents list (`z-f05-Residents.dc.html`) | S40 |  |  |
| F05 / F06 Enquiries and residents · F06 · 5 · Owner: add a resident (`z-f05-AddResident.dc.html`) | H20 |  |  |
| F05 / F06 Enquiries and residents · F06 · 6 · Owner: invite QR + approve (`z-f05-InviteQR.dc.html`) | S47 |  |  |
| F05 / F06 Enquiries and residents · F06 · 7 · Resident: confirm your stay (`z-f05-Confirm.dc.html`) | DROPPED (Confirm your stay retired, v23) |  | dropped on purpose |
| F05 / F06 Enquiries and residents · F06 · 4 in dark mode (`z-f05-ResidentsDark.dc.html`) | S40 dark |  |  |
| F07 Fair Play · 1 · Owner: Fair Play rules + OTP accept (`z-f07-Main.dc.html`) | S62 (OTP accept replaced by I agree) |  |  |
| F07 Fair Play · 2 · Tenant: owner number after a hold (`z-f07-Phone.dc.html`) | S13 variant (owner block) |  |  |
| F07 Fair Play · 3 · Tenant: “Did you join?” (`z-f07-Joined.dc.html`) | S11 (Did you join?) |  |  |
| F07 Fair Play · 4 · Tenant: report skip-the-app (`z-f07-Report.dc.html`) | H8 |  |  |
| F07 Fair Play · 5 · Owner: case + 48 h to explain (`z-f07-Case.dc.html`) | S63 |  |  |
| F07 Fair Play · 6 · Owner: strike notices 1 → 3 (`z-f07-Strike.dc.html`) | S64 |  |  |
| F07 Fair Play · 5 in dark mode (`z-f07-CaseDark.dc.html`) | S63 dark |  |  |
| F07 Fair Play · 7 · Founder admin: Cases (`z-f07-Admin.dc.html`) | S77 |  |  |
| F08 Reviews · 1 · Resident: 30-day review + layout accurate? (`z-f08-Main.dc.html`) | S33 |  |  |
| F08 Reviews · 2 · Resident: exit review, advance back? (`z-f08-Exit.dc.html`) | S34 |  |  |
| F08 Reviews · 3 · Tenant: reviews on the hostel page (`z-f08-Hostel.dc.html`) | S15 |  |  |
| F08 Reviews · 3 in dark mode (`z-f08-HostelDark.dc.html`) | S15 dark |  |  |
| F08 Reviews · 4 · Tenant: Explore ranked by score (`z-f08-Explore.dc.html`) | S8 (before, ranked list) |  | older version of the same screen |
| F08 Reviews · 5 · Owner: Hostelzy score breakdown (`z-f08-Score.dc.html`) | S61, H31 |  |  |
| F08 Reviews · 6 · Owner: reply to a review (`z-f08-Reply.dc.html`) | S61 |  |  |
| F10 Owner plan · 1 · Owner: plan + trial (`z-f10-Main.dc.html`) | S65 |  |  |
| F10 Owner plan · 2 · Owner: invoice with UPI QR (`z-f10-Invoice.dc.html`) | S65 (QR replaced by Pay by UPI) |  |  |
| F10 Owner plan · 3 · Owner: I’ve paid · UTR (`z-f10-Utr.dc.html`) | H22 |  |  |
| F10 Owner plan · 4 · Owner: Checking / Paid / Not received (`z-f10-Status.dc.html`) | S65 (status variants) |  |  |
| F10 Owner plan · 5 · Owner: overdue (5 / 15 days) (`z-f10-Overdue.dc.html`) | S36 (plan banner) |  |  |
| F10 Owner plan · 2 in dark mode (`z-f10-InvoiceDark.dc.html`) | S65 dark |  |  |
| F10 Owner plan · 6 · Founder admin: payments (`z-f10-Admin.dc.html`) | S76, C2 |  |  |
| F14 Onboarding · 1 · Admin wizard: basics (`z-f14-Main.dc.html`) | S67 |  |  |
| F14 Onboarding · 2 · Admin wizard: rooms floor by floor (`z-f14-Rooms.dc.html`) | S68 |  |  |
| F14 Onboarding · 3 · Admin wizard: rate card (`z-f14-Rates.dc.html`) | S69 |  |  |
| F14 Onboarding · 4 · Admin wizard: photos + sketches (`z-f14-Photos.dc.html`) | S70 |  |  |
| F14 Onboarding · 5 · Admin wizard: residents import (`z-f14-Residents.dc.html`) | S71 |  |  |
| F14 Onboarding · 6 · Admin wizard: go-live checklist (`z-f14-GoLive.dc.html`) | S73 |  |  |
| F14 Onboarding · 6 in dark mode (`z-f14-GoLiveDark.dc.html`) | S73 dark |  |  |
| F14 Onboarding · 7 · Tenant: Visited by Hostelzy + availability (`z-f14-Visited.dc.html`) | variant of S13 |  |  |
| F14 Onboarding · 8 · Owner: add a manager (`z-f14-Manager.dc.html`) | H26 |  |  |
| F14 Onboarding · 9 · Owner: hostel switcher (`z-f14-Switcher.dc.html`) | H24 |  |  |
| F14 Onboarding · 10 · Owner: “Still 4 free beds?” (`z-f14-FreeBeds.dc.html`) | S36 (Still N free beds?) |  |  |
| F14 Onboarding · 12 · Resident QR poster (A4) (`z-f14-Poster.dc.html`) | not counted (print poster) |  | not counted |
| F14 Onboarding · 11 · Founder admin: onboarding tracker (`z-f14-Tracker.dc.html`) | S75 |  |  |
| F14 Onboarding · 13 · Tenant: bed picker, uneven floors (`z-f14-PickerFloors.dc.html`) |  | **MISSING** · Building tab → NEW-1 |  |
| F14 Onboarding · 14 · Owner: bed map, uneven floors (`z-f14-BedMapFloors.dc.html`) | S37 |  |  |
| F15 Play Store screens · 1 · Settings (`z-f15-Main.dc.html`) | S80 |  |  |
| F15 Play Store screens · 2 · Delete account: what happens (`z-f15-Delete.dc.html`) | S83 |  |  |
| F15 Play Store screens · 3 · Delete: OTP or blocked (`z-f15-DeleteOtp.dc.html`) | T30 (OTP part not counted) |  |  |
| F15 Play Store screens · 4 · Delete: done (`z-f15-DeleteDone.dc.html`) | S85 |  |  |
| F15 Play Store screens · 1 in dark mode (`z-f15-MainDark.dc.html`) | S80 dark |  |  |
| F15 Play Store screens · 5 · Permission explainers (`z-f15-Permissions.dc.html`) | S82, H2 |  |  |
| F15 Play Store screens · 6 · Phone screen with consent line (`z-f15-Phone.dc.html`) | not counted (SMS OTP flag off) |  | not counted |
| F15 Play Store screens · 7 · Force update / maintenance (`z-f15-Update.dc.html`) | T31, S86 |  |  |
| F17 Make it real · 1 · Tenant: pay the advance by UPI (`z-f17-Main.dc.html`) | H7 |  |  |
| F17 Make it real · 2 · Tenant: enter the UTR (`z-f17-Utr.dc.html`) | H12 |  |  |
| F17 Make it real · 3 · Tenant: waiting / booked / not received (`z-f17-Status.dc.html`) | S20 (status variants) |  |  |
| F17 Make it real · 4 · Owner: “Received ₹3,000?” (`z-f17-OwnerConfirm.dc.html`) | S36 (Received ₹N? card) |  |  |
| F17 Make it real · 3 in dark mode (`z-f17-StatusDark.dc.html`) | S20 dark |  |  |
| F17 Make it real · 5 · Resident: pay rent (same flow) (`z-f17-Rent.dc.html`) | S26 |  |  |
| F17 Make it real · 6 · Owner: UPI ID in Manage → Rates (`z-f17-UpiId.dc.html`) | S44 |  |  |
| F17 Make it real · 7 · Tenant: honest WhatsApp sheet (`z-f17-WhatsApp.dc.html`) | H6 |  |  |
| F17 Make it real · 8 · Tenant: hold active / expired at 0:00 (`z-f17-Hold.dc.html`) | S20 |  |  |
| F17 Make it real · 9 · Tenant: real map (`z-f17-Map.dc.html`) | S9 |  |  |
| F17 Make it real · 9 in dark mode (`z-f17-MapDark.dc.html`) | S9 dark |  |  |
| F17 Make it real · 10 · Login without demo buttons (`z-f17-Login.dc.html`) | not counted (SMS OTP flag off) |  | not counted |
| F17 Make it real · 11 · Tablet / desktop full-screen (`z-f17-Desktop.dc.html`) | not counted · tablet/desktop layout (SCREENS §6) |  | not counted |
| F18 Real app v2 · 1 · Sign in with Google (`z-f18-Main.dc.html`) | S2 |  |  |
| F18 Real app v2 · 2 · Profile: name, phone, role (`z-f18-Profile.dc.html`) | S3 |  |  |
| F18 Real app v2 · 3 · Resident gate: ask your owner (`z-f18-ResidentGate.dc.html`) | S5 |  |  |
| F18 Real app v2 · 4 · Owner gate: list your hostel (`z-f18-OwnerGate.dc.html`) | S6 |  |  |
| F18 Real app v2 · 5 · Empty states (tweak) (`z-f18-Empty.dc.html`) | T4, T7, T8 |  |  |
| F18 Real app v2 · 2 in dark mode (`z-f18-ProfileDark.dc.html`) | S3 dark |  |  |
| F18 Real app v2 · 6 · Map v2: use my location, search this area (`z-f18-Map.dc.html`) | S9 |  |  |
| F18 Real app v2 · 7 · Location permission (`z-f18-Location.dc.html`) | H2 |  |  |
| F18 Real app v2 · 8 · Area picker (`z-f18-Areas.dc.html`) | S12 |  |  |
| F18 Real app v2 · 9 · Hostels in the area (`z-f18-List.dc.html`) | DROPPED (Map › List; Explore is the list since F22) |  | dropped on purpose |
| F18 Real app v2 · 6 in dark mode (`z-f18-MapDark.dc.html`) | S9 dark |  |  |
| F18 Real app v2 · 10 · Owner: room layouts (`z-f18-Rooms.dc.html`) | S53 |  |  |
| F18 Real app v2 · 11 · Owner: create a layout (`z-f18-Create.dc.html`) | S56 |  |  |
| F18 Real app v2 · 12 · Owner: layout editor (`z-f18-Editor.dc.html`) | S57 |  |  |
| F18 Real app v2 · 13 · Owner: live for tenants (`z-f18-Published.dc.html`) | S58 |  |  |
| F18 Real app v2 · 12 in dark mode (`z-f18-EditorDark.dc.html`) | S57 dark |  |  |
| F18 Real app v2 · 14 · Owner: photos (`z-f18-Photos.dc.html`) | S49 |  |  |
| F18 Real app v2 · 15 · Owner: crop + cover (`z-f18-Crop.dc.html`) | S50 |  |  |
| F18 Real app v2 · 16 · Tenant: photo gallery (`z-f18-Gallery.dc.html`) | S14 |  |  |
| F18 Real app v2 · 17 · Saved hostels (`z-f18-Saved.dc.html`) | S10 |  |  |
| F18 Real app v2 · 18 · Delete account v2 (`z-f18-Delete.dc.html`) | S84, S85 |  |  |
| F18 Real app v2 · 19 · Team console: sign in (`z-f18-Console.dc.html`) | C10 |  |  |
| F18 Real app v2 · 20 · Console: onboarding + add hostel (`z-f18-ConsoleOnboarding.dc.html`) | C1 |  |  |
| F18 Real app v2 · 21 · Console: payments (`z-f18-ConsolePayments.dc.html`) | C2 |  |  |
| F18 Real app v2 · 22 · Console: Fair Play + layout help (`z-f18-ConsoleCases.dc.html`) | C3, C4 |  |  |
| F18 Real app v2 · 23 · Press back again to exit (`z-f18-BackExit.dc.html`) | not counted (toast) |  | not counted |
| F18 Real app v2 · 24 · DEMO banner (`z-f18-Demo.dc.html`) | not counted (demo APK only) |  | not counted |
| F18 Real app v2 · 25 · Keyboard-safe: UTR (`z-f18-KeyboardUtr.dc.html`) | H12 (keyboard behaviour) |  |  |
| F18 Real app v2 · 26 · Keyboard-safe: add resident (`z-f18-KeyboardAdd.dc.html`) | H20 (keyboard behaviour) |  |  |
| F19 Residents fix their room layout · 0 · Non-resident: Edit room → lock sheet (`z-f19-Lock.dc.html`) | H13 |  |  |
| F19 Residents fix their room layout · 0b · Visitor try mode: only Send is locked (`z-f19-Try.dc.html`) | variant of S32 |  |  |
| F19 Residents fix their room layout · 0 in dark mode (`z-f19-LockDark.dc.html`) | dark |  |  |
| F19 Residents fix their room layout · 1 · Resident: any room in their hostel → Edit room (`z-f19-Main.dc.html`) | S31 |  |  |
| F19 Residents fix their room layout · 2 · Resident: editor in suggestion mode (`z-f19-Edit.dc.html`) | S32 |  |  |
| F19 Residents fix their room layout · 3 · Resident: a check fails (`z-f19-EditCheck.dc.html`) | variant of S32 |  |  |
| F19 Residents fix their room layout · 3b · Quick fix: wrong place / missing / broken / not in this room (`z-f19-QuickFix.dc.html`) | H16 |  |  |
| F19 Residents fix their room layout · 3c · Limit: 3 fixes waiting (`z-f19-Limit.dc.html`) | H14 |  |  |
| F19 Residents fix their room layout · 2 in dark mode (`z-f19-EditDark.dc.html`) | dark |  |  |
| F19 Residents fix their room layout · 4 · Resident: send to owner, optional photo (`z-f19-Send.dc.html`) | H15 |  |  |
| F19 Residents fix their room layout · 5 · Resident: waiting / approved / not approved (tweak) (`z-f19-After.dc.html`) | variant of S31 |  |  |
| F19 Residents fix their room layout · 6 · Tenant: “Checked by 3 residents” (`z-f19-Checked.dc.html`) | variant of S17 |  |  |
| F19 Residents fix their room layout · 7 · Owner: push (`z-f19-Push.dc.html`) | not counted · push notification (system) |  | not counted |
| F19 Residents fix their room layout · 8 · Owner: Today card + broken item as a repair (`z-f19-Today.dc.html`) | variant of S36 |  |  |
| F19 Residents fix their room layout · 9 · Owner: compare side by side (`z-f19-Compare.dc.html`) | S59 |  |  |
| F19 Residents fix their room layout · 10 · Owner: reject with a reason (`z-f19-Reject.dc.html`) | H29 |  |  |
| F19 Residents fix their room layout · 10b · Owner: mute a resident (`z-f19-Mute.dc.html`) | H30 |  |  |
| F19 Residents fix their room layout · 11 · Owner: approved and live (`z-f19-Approved.dc.html`) | S60 |  |  |
| F19 Residents fix their room layout · 9 in dark mode (`z-f19-CompareDark.dc.html`) | dark |  |  |
| F19 Residents fix their room layout · 12 · Team console: layout fixes, oldest first (`z-f19-Console.dc.html`) | C7 |  |  |
| F19 Residents fix their room layout · 12 in dark mode (`z-f19-ConsoleDark.dc.html`) | C7 dark |  |  |
| F20 Reminders · 1 · Me → Reminders: water, my reminders, hostel (tweak: notifications off) (`z-f20-Main.dc.html`) | S81 |  |  |
| F20 Reminders · 1a · Me: Reminders row (`z-f20-Me.dc.html`) | variant of S79 |  |  |
| F20 Reminders · 1 in dark mode (`z-f20-MainDark.dc.html`) | dark |  |  |
| F20 Reminders · 2 · Water settings (`z-f20-Water.dc.html`) | H39 |  |  |
| F20 Reminders · 3 · Add a reminder (`z-f20-Add.dc.html`) | H40 |  |  |
| F20 Reminders · 4 · Notifications with Done / Snooze (`z-f20-Notify.dc.html`) | not counted · notifications (system) |  | not counted |
| F20 Reminders · 4 in dark mode (`z-f20-NotifyDark.dc.html`) | not counted · notifications (system, dark) |  | not counted |
| F20 Reminders · 5 · Home Today card (resident) (`z-f20-Home.dc.html`) | variant of S23 |  |  |
| F20 Reminders · 5b · Today card on Explore (tenant) (`z-f20-HomeTenant.dc.html`) | variant of S8 |  |  |
| F20 Reminders · 6 · First-time offer after sign-in (`z-f20-Offer.dc.html`) | H41 |  |  |
| F20 Reminders · 5 in dark mode (`z-f20-HomeDark.dc.html`) | dark |  |  |
| F21 Before → after · Before · Welcome (`z-f21b-Main.dc.html`) | S1 (before) |  | older version of the same screen |
| F21 Before → after · After · Welcome: browse first (`z-f21b-w-after.dc.html`) | S1 |  |  |
| F21 Before → after · Before · Explore (`z-f21b-e-before.dc.html`) | S8 (before, ranked list) |  | older version of the same screen |
| F21 Before → after · After · Explore (`z-f21b-e-after.dc.html`) | S8 |  |  |
| F21 Before → after · Before · Hostel page (`z-f21b-d-before.dc.html`) | S13 (before) |  | older version of the same screen |
| F21 Before → after · Before · Hold sheet (`z-f21b-h-before.dc.html`) | H4 · Member variant (board `r-holdSheetMember`: "Hold free · 2 hours", `holds_sheets.dart:67`) |  | current rule (DECISIONS: 2 h for Members) |
| F21 Before → after · After · Hostel page (`z-f21b-d-after.dc.html`) | S13 |  |  |
| F21 Before → after · After · Hold or book (`z-f21b-h-after.dc.html`) | H4 |  |  |
| F21 Before → after · After · UPI reference, plain words (`z-f21b-u-after.dc.html`) | H12 |  |  |
| F21 Before → after · Before · Resident Home (`z-f21b-r-before.dc.html`) | original prototype (see h0 row) |  |  |
| F21 Before → after · After · Resident Home (`z-f21b-r-after.dc.html`) | S23 |  |  |
| F21 Before → after · Before · Owner Today (`z-f21b-t-before.dc.html`) | S36 (before) |  | older version of the same screen |
| F21 Before → after · After · Owner Today (`z-f21b-t-after.dc.html`) | S36 |  |  |
| F21 Before → after · Before · Owner Manage (`z-f21b-m-before.dc.html`) | original prototype (see h0 row) |  |  |
| F21 Before → after · After · Owner Manage (`z-f21b-m-after.dc.html`) | S39 |  |  |
| F21 Before → after · Before · Explore with no connection (`z-f21b-o-before.dc.html`) | T4 (before) |  | older version of the same screen |
| F21 Before → after · After · You’re offline · Retry (`z-f21b-o-after.dc.html`) | T2 |  |  |
| F21 Simpler UI, full set · W2 · Welcome: Find a bed first, language pick (W4) (`z-f21-Main.dc.html`) | S1 |  |  |
| F21 Simpler UI, full set · W2 · Explore as a guest (`z-f21-ExploreGuest.dc.html`) | variant of S8 |  |  |
| F21 Simpler UI, full set · W2 · Explore: one search, one filter row, photo cards, real cost (`z-f21-Explore.dc.html`) | S8 |  |  |
| F21 Simpler UI, full set · W2 · Where? one field (`z-f21-Where.dc.html`) | S12 |  |  |
| F21 Simpler UI, full set · W2 · Filters sheet with sort (`z-f21-Filters.dc.html`) | H1 |  |  |
| F21 Simpler UI, full set · W2 · Explore in dark mode (`z-f21-ExploreDark.dc.html`) | dark |  |  |
| F21 Simpler UI, full set · W2 · Hostel page: merged price table, House rules › (`z-f21-Detail.dc.html`) | S13 |  |  |
| F21 Simpler UI, full set · W2 · Hold free or pay to book, two equal options (`z-f21-Hold.dc.html`) | H4 |  |  |
| F21 Simpler UI, full set · W2 · Sign in at the first hold (`z-f21-SignIn.dc.html`) | H3 |  |  |
| F21 Simpler UI, full set · W2 · Notifications asked after the first hold (`z-f21-Notify.dc.html`) | H5 |  |  |
| F21 Simpler UI, full set · W2 · Plain words: UPI reference (`z-f21-Utr.dc.html`) | H12 |  |  |
| F21 Simpler UI, full set · W2 · Hostel page in dark mode (`z-f21-DetailDark.dc.html`) | S13 dark |  |  |
| F21 Simpler UI, full set · W3 · Resident Home: rent, 3 actions, food (`z-f21-Home.dc.html`) | S23 |  |  |
| F21 Simpler UI, full set · W3 · Help (tweak: empty) (`z-f21-Help.dc.html`) | S27 |  |  |
| F21 Simpler UI, full set · W3 · Owner Today: Needs you now (`z-f21-Today.dc.html`) | S36 |  |  |
| F21 Simpler UI, full set · W3 · Owner Manage: vertical list (`z-f21-Manage.dc.html`) | S39 |  |  |
| F21 Simpler UI, full set · W3 · Owner Today in dark mode (`z-f21-TodayDark.dc.html`) | dark |  |  |
| F21 Simpler UI, full set · W1 · Owner: I agree instead of a fake code (`z-f21-Agree.dc.html`) | T24 |  |  |
| F21 Simpler UI, full set · W1 · Resident: confirm your stay, no code (`z-f21-Stay.dc.html`) | DROPPED (Confirm your stay retired, v23) |  | dropped on purpose |
| F21 Simpler UI, full set · W4 · Loading skeleton (`z-f21-Skeleton.dc.html`) | T1 |  |  |
| F21 Simpler UI, full set · W4 · You’re offline · Retry (`z-f21-Offline.dc.html`) | T2 |  |  |
| F21 Simpler UI, full set · W4 · Inline error + Undo (`z-f21-Error.dc.html`) | variant of S11 |  |  |
| F23 Floor amenities · 1 · Hostel page: On each floor (`z-f23-Main.dc.html`) | variant of S13 |  |  |
| F23 Floor amenities · 1 in dark mode (`z-f23-DetailDark.dc.html`) | dark |  |  |
| F23 Floor amenities · 2 · Room plan first, “On floor 2” strip, geyser in the washroom (`z-f23-Room.dc.html`) | S17 |  |  |
| F23 Floor amenities · 3 · Floor sheet: counts and status (`z-f23-Floor.dc.html`) | H42 |  |  |
| F23 Floor amenities · 4 · Add: icon → where? → count → working? → Save (`z-f23-Add.dc.html`) | H43 |  |  |
| F23 Floor amenities · 5 · Owner: Layouts → Floor 2 → Shared things (`z-f23-Owner.dc.html`) | S54 |  |  |
| F23 Floor amenities · 6 · Filters: Washing machine, Fridge, RO water, Geyser in my washroom (`z-f23-Filters.dc.html`) | variant of H1 |  |  |
| Old main canvas: boards retired from the main area · demo (`z-old-demo.dc.html`) | not counted (demo APK only) |  | not counted |
| Old main canvas: boards retired from the main area · back (`z-old-back.dc.html`) | not counted (toast) |  | not counted |
| Old main canvas: boards retired from the main area · oCreate (`z-old-oCreate.dc.html`) | S56 (before shapes) |  | older version of the same screen |
| Old main canvas: boards retired from the main area · f12-Request (`z-old-f12-Request.dc.html`) | H23 (before) |  | older version of the same screen |
| Old main canvas: boards retired from the main area · f19-Console (`z-old-f19-Console.dc.html`) | C7 |  |  |
| Old main canvas: boards retired from the main area · f19-ConsoleDark (`z-old-f19-ConsoleDark.dc.html`) | C7 dark |  |  |
| Old main canvas: boards retired from the main area · room (`z-old-room.dc.html`) | S17 (before F23) |  | older version of the same screen |

**Member hold (hub check, v32):** the 2-hour Member hold is a current rule, not old pricing. The app covers it: the hold
sheet says "Hold free · 2 hours" for Members (H4), the sign-in sheet says "free 2-hour hold", and Rewards and Perks list
"2-hour holds". New variant board `r-holdSheetMember`. **For Build:** the line under the hold button still says
"If <owner> doesn't keep it within the hour…" for Members. It should say "within 2 hours" (`holds_sheets.dart`, the
`T(book ? … : …)` under `holdGo`). Only the ₹299 paid hold was dropped (DECISIONS).

### Map boards = real app screenshots (v31)
The founder says the app's map looks better than the old design, so the map boards now show Build's real
screenshots (`docs/design/screens/`, PR #105), uploaded to the canvas: `[S9] map`, `[dark] map-dark`, `[H2] loc`,
new `[dark] loc-dark`, `[S12] add-whereFull`, new `[dark] where-dark`. Map tiles aren't in the capture (the
capture machine can't reach OpenStreetMap). On a phone the tiles are there. Not swapped yet: `mapMe`
(variant), `w1-mapEmpty` (T6). They have no screenshot yet.

## Build
(Build writes here.)

### NEW-4 · Owner Food menu › Week table (S87) · Built 2026-10-03
- **What:** Manage › Food menu now opens with a seg **Edit by day · Week table** (`s.mView`, `day` by default). Week table
  (`_MenuWeek` in `lib/features/owner/owner_manage_screen.dart`) follows board `w4-oMenuWeek`: a 44 px day column +
  Breakfast / Lunch / Dinner, 12 px cells, 2 px rules, no sideways scroll on a 360 px phone (labels scale down at 2× text,
  cells wrap). Today's row is highlighted (`p.ab`, day in `p.ad`). Empty slots say **Not set** (muted).
- **Data:** the week being typed (`menuDraft`: the saved `menus` row + any unsaved edits). Nothing new on the server, no SQL.
  Unsaved edits behave as before: the footer **Save menu** saves the draft; the table repeats "Not saved yet…" while dirty.
- **Tap a day** → Edit by day on that day (`mDay`, `mView = 'day'`).
- **Lines under the table:** "Today is highlighted. Tap a day to edit it. Residents and tenants see the same week." plus,
  in red, "Sunday dinner is not set yet." (one slot) / "N meals are not set yet." / "No menu yet…" (empty week). Honest:
  residents see an empty slot, so the line doesn't claim they see "Not set".
- **Screens:** +1 → **S87** `oMore` · menu (week). App screens 86 → 87, release 160 → 161, overall 181 → 182.
  Canvas: rename `[NEW-4] w4-oMenuWeek` → `[S87]`.
- **Later (hub decision, same day):** the Week table is a toggle on S45, not its own screen. Its SCREENS row is folded into
  S45 and **S87 now belongs to the Building view** (below); `w4-oMenuWeek` is a variant of `[S45]`.
- **Tests:** `hostelzy/test/menu_week_test.dart` (seg switch, draft shown, "Not set", today highlighted, tap a day → Edit
  by day on it, Save still works, empty week, 360 px × 1×/2× text × light/dark).

### NEW-1 · Building view (S87), NEW-2 merged in · Built 2026-10-03
Follows the hub decision above: one new screen, no separate floor map, no owner corridor plan, no thing positions.
- **Picker tabs Plan · Room · Building** (`PickerTabs` in `lib/features/holds/picker_screen.dart`). The Room tab's old
  "Floor view" button is gone (the Plan tab keeps its `floorView` key). Plan and the cheapest-beds link are unchanged.
- **Building view** `lib/features/holds/building_view.dart` (`BuildingView`), the founder's pick: the 417c385 cross-section
  rebuilt with the kit: roof, F3/F2/F1 rows with a 40 px label column (free count under it), rooms with bed boxes
  (free / on hold / taken / your pick), base slab, legend. **Shared-thing chips on top of each floor row** (F23 data, floor
  things only; red "· not working"). Floors come from the real rooms; **G shows only when the data has floor 0** (rooms, or
  shared things there) with only those things and "Ground floor" (the old "Reception · dining hall · bike parking" was
  invented and is gone). Tap a free bed → picked → the existing Continue bar (a taken bed toasts). **Tap a floor (its
  label or its chips) → the existing floor sheet `amFloor` (H42).**
- **Reached from** the picker tab and the hostel page's new "See the whole building ›" (`openBuilding`).
- **Women's PGs:** the Building tab shows "Floor plan shows after you hold a bed" until a hold (same `floorLocked` as Plan).
- **Owner › Beds:** seg **Rooms · Building** (`s.obView`, Rooms first). Building is the same component (`tenant: false`);
  a bed opens the existing bed sheet (H18).
- **No SQL, no FOUNDER-TODO step.** (An earlier version of this branch had thing positions and a migration; removed.)
- **Screens:** +1 → **S87** `picker` (building), taking the id freed by the Week table, which is now noted as a toggle on
  S45 (Food menu) instead of its own row. S37 notes the Rooms · Building toggle, T10 also covers the Building tab.
  Totals: app screens 87 (86 before F25 + 1), release **161** (160 + 1), overall **182** (181 + 1).
  Canvas: `[NEW-1]` → `[S87]`; `[NEW-2]` and `[NEW-3]` retire (merged); `w4-oMenuWeek` becomes a variant of `[S45]`.
- **Tests:** `hostelzy/test/f25_test.dart` (hostel page → Building, floors top-down, G from data, chips + red, pick a free
  bed → Continue, taken bed toast, floor → amFloor, tabs; women's PG locked then open after a hold; owner Beds › Building,
  bed → bed sheet, back to Rooms; 360 px × 2× text × light/dark). `flows_test` picker-tabs test updated.

### A6, A7, A8 · Owner occupancy, all plans, past invoices (sections in S36 and S65) · Built 2026-10-03
No new screens (SCREENS count unchanged). No SQL.
- **A6 · Owner Today (S36 `oToday`), "This month" card:** under the three tiles, **"N% full"**, an occupancy bar and
  "X of Y beds have a resident. Holds don't count." (`occupancy()` + `_Occupancy` in
  `lib/features/owner/owner_today_screen.dart`). **What counts as full:** beds with a resident, i.e. state `booked`
  (taken) or `soon` (taken, the resident leaves soon) ÷ all beds of the selected hostel. Holds (`held`) and free beds are
  not full. Rounded to a whole percent. Hidden when the hostel has no beds yet. No new tiles. Bar: `p.tx` fill on `p.sf`.
- **A7 · Your plan (S65 `oPlan`), "All plans":** the three tiers straight from `planTiers` in
  `lib/data/plan.dart` (the same constants that price the invoice, DECISIONS F10: up to 30 beds / 31 to 80 / 80+, with the
  80+ note "Plus a featured spot in your area"). No new numbers in the screen. The owner's tier is marked **Yours** from
  `planTierOf(planBeds)` (real bed count) and shaded.
- **A8 · Your plan (S65), "Past invoices"** (replaces the old "Before" heading): this hostel's earlier invoices, newest
  first (`pastInvoices` in `lib/features/plan/plan.dart`: every loaded invoice for `ownHid` except the current one). The
  invoices were already loaded from the server for the plan screen (`invoices` table, RLS: the owner's own hostels), so no
  new repo method. Each row: month (from the due date), reference · amount, and **Paid** (team matched the UTR) /
  **Checking** (UTR being matched) / **Not paid** (due, late or UTR not found). Empty: **"No past invoices yet."** The
  free-trial line stays at the end of the list once the first invoice is out. Demo build: Anjani has no past invoices, so the
  empty state shows (no invented history).
- **Tests:** `hostelzy/test/owner_sections_test.dart` (occupancy % and bar width, holds don't count, a hold turned booked
  moves it; hidden with no beds; all three tiers from `planTiers`, Yours follows the bed count across 0/1/2; past invoices
  empty state, other hostels' invoices hidden, newest first, Paid / Checking / Not paid; 360 px × 2× text × light/dark).
  `owner_manage_test.dart` now expects "Past invoices" instead of "Before".

### Redundancy merges (Design review, 3 confident pairs) + one notification ask · Built 2026-10-03
App screens **−3** (SCREENS: app screens 85, sheets 42, release 158, overall 179). Ids are retired, not reused or renumbered:
**S76, S77, H17**. No SQL.
- **One "Add a resident" sheet (H20 `addR`; H17 `add` merged in and removed).** The owner's centre "+" tab, Manage ›
  Residents › Add and a free bed's "Add tenant to this bed" all open it (`openAddResident({bed})` in
  `lib/features/residents/residents.dart`; sheet `AddResidentSheet` in `residents_sheets.dart`; `AddSheet` and its
  `add*` state are gone). Fields: name, WhatsApp number (+91), bed (unassigned taken beds flagged first, then free and
  free-soon beds), **one date** (Yesterday · Today · Tomorrow · Pick date = a week back or a week ahead), monthly fee,
  advance, the rent/due-at-move-in line, and "Lived here before Hostelzy" (only before go-live and only for today or a
  past date; the server still checks). The date's label is **"Moves in"** when it is in the future and **"Joined on"**
  when it is today or past; a future date is a booking (button "Book the bed", toast "Booked bed N. Send them a welcome
  on WhatsApp.", `addStayLive(..., booking: true)`), today or past is a stay ("Added. X confirms by joining with your
  invite code."). Checks (union of both old sheets): a name of 2+ letters, a valid 10-digit mobile (6–9 first), a bed,
  and not a bed that already has a resident. Server path unchanged: `addStayLive`. Demo path: the resident is added
  Not confirmed (a future date shows "Moves in <date>", Due).
- **S76 `aPay` removed** (team payments in the app). The console's Payments (C2) does this job. Removed the screen,
  the Team home row, its state (`payTab`, `markPaid`, `notReceived`, `sendReminder`) and the repo's `checkInvoice`.
- **S77 `aCases` removed** (team Fair Play queue in the app). The console's Fair Play (C3) does this job. Removed the
  screen, the Team home row, its state (`adminTab`, `adminCase`, `decideCase`) and the repo's `decideCase`. The owner's
  own Fair Play screens (S62 `oRules`, S63 `oCase`, S64 `oStrike`) stay.
- **Team home (S66):** a plain line under the tools: "Payments and Fair Play cases are in the team console:
  farhath.me/hostelzy/app/console".
- **No double ask for tenants:** `offerPush()` (S82 `perm`) now returns for the tenant role too, not only at role pick;
  a tenant's only ask is H5 `holdNotify` after the first hold. Residents and owners keep S82 at role pick (and then never
  see H5, `pushAsked`).
- **Tests:** `flows_test.dart` "F25: one Add a resident sheet …" (+ tab and Residents › Add open the same sheet;
  Tomorrow / a week ahead → "Moves in", Yesterday / 5 days back → "Joined on"; checks; a future date books the bed;
  the same bed can't be added twice), "F25: Add a resident saves through addStayLive …" (server: future = booking toast and
  a joinedOn tomorrow, past = stay toast and 5 days back), "F25: a tenant never sees both notification asks …".
  `team_app_test.dart` "F25: plan payments and Fair Play cases are not in the app …". Tests that drove `aPay`/`aCases` now
  set the team's result directly (strike count, invoice paid) and keep their owner-side assertions; `owner_test.dart`
  bed sheet → the merged sheet.
