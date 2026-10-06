# SCREENS: every screen, sheet and state in the release app

- **Date:** 2026-10-03 · **Counted on `main` at `fdbbef8`** (Build, by reading the code, not the canvas).
- **Why:** CLAUDE.md "Design ↔ app consistency". The Design chat matches the "Hostelzy · Main design"
  canvas 1:1 against this list. When a PR adds or removes a screen, update this file in the same PR.

## Totals

| Group | Count |
|---|---|
| App screens (routes + their separate pages/views) | **84** |
| App sheets (bottom sheets) | **42** |
| App full-screen states | **28** |
| **Release app total** | **154** |
| Team console (app/console): views 9 + states 4 | **13** |
| Web pages (app/): pages 6 + states 2 | **8** |
| **Overall total** | **175** |
| App screens (routes + their separate pages/views) | **86** |
| App sheets (bottom sheets) | **42** |
| App full-screen states | **31** |
| **Release app total** | **159** |
| Team console (app/console): views 9 + states 4 | **13** |
| Web pages (app/): pages 6 + states 2 | **8** |
| **Overall total** | **180** |
| App sheets (bottom sheets) | **41** |
| App full-screen states | **32** |
| **Release app total** | **157** |
| Team console (app/console): views 9 + states 4 | **13** |
| Web pages (app/): pages 6 + states 2 | **8** |
| App screens (routes + their separate pages/views) | **83** |
| App sheets (bottom sheets) | **44** |
| App full-screen states | **30** |
| **Release app total** | **157** |
| Team console (app/console): views 9 + states 4 | **13** |
| Web pages (app/): pages 6 + states 2 | **8** |
| **Overall total** | **178** |

**F25 merges (2026-10-03, −3):** H17 `add` merged into H20 `addR` (one "Add a resident" sheet; the id H20 is kept),
S76 `aPay` and S77 `aCases` removed (the team uses the console's Payments C2 and Fair Play C3). Ids are not reused or
renumbered, so the canvas board titles stay valid: **retired ids S76, S77, H17, H10 (F26)**.

**F26 bed picker + open layouts (2026-10-06, −4):** the picker has no Plan / Room / Building tabs; every room's drawn
layout is on one scroll (S16). **S18** "cheapest first" list removed (no entry point; every room with its price is on the
scroll). S87 stays (the Building component on the hostel page and owner Beds) but is **no longer a picker tab**. Layouts are
open to everyone: states **T10** (floor locked until a hold), **T11** (sign in to see room layouts) and **T13** (daily cap,
hold talk) removed. **Retired ids S18, T10, T11, T13.**

Subtotals: screens Start 7 · Tenant 15 · Resident 13 · Owner 30 · Team mode 11 · Shared 8.
Sheets Tenant 10 · Resident 6 · Owner 18 · Team 1 · Shared 7. States Tenant 14 · Resident 6 · Owner 6 · Shared 2.
**F26 tenant (2026-10-06, +1 screen, sheets ±0):** S88 `building` added (80+ bed hostel's building on its own
page); H44 `sort` added (Explore sort dropdown); H10 `foodWeek` retired (the hostel page shows the whole week inline).

Subtotals: screens Start 7 · Tenant 17 · Resident 13 · Owner 30 · Team mode 11 · Shared 8.
Sheets Tenant 10 · Resident 6 · Owner 18 · Team 1 · Shared 7. States Tenant 17 · Resident 6 · Owner 6 · Shared 2.
**F26 owner (2026-10-06, Build agent D):** S41 Manage › Enquiries and H19 `enq` (one enquiry sheet) retired
(enquiries are removed, F26 #7). New state T33 owner Today "Nothing needs you now". S36, S37 and S38 changed
(grouped Today, Building-only Beds, Rent Call + WhatsApp). Delta: screens −1, sheets −1, states +1.

Subtotals: screens Start 7 · Tenant 16 · Resident 13 · Owner 29 · Team mode 11 · Shared 8.
Sheets Tenant 10 · Resident 6 · Owner 17 · Team 1 · Shared 7. States Tenant 17 · Resident 6 · Owner 7 · Shared 2.
**F26 resident (2026-10-06, branch `feature/f26-resident`; screens −4 +2, sheets +2, states −1):** the resident tab bar is
Home · Rent · My stay · Find a bed · Me. **Retired:** S24 + S25 `food` (Food tab and its week table: the week is on Home,
always open), S27 `help` (Help folds into My stay as H44 + H45), S28 `rStay` (Me › My stay, replaced by the tab S89),
state 19 (`food` no menu: Home says it in one line). **New:** S88 `savedHolds` Saved & Holds (a resident inside Find a
bed), S89 `rStay` My stay (tab), H44 `complaint`, H45 `complaints`. Find a bed itself is the tenant screens (S8, S9, S79…)
with another tab bar (§7). Retired ids are not reused: **S24, S25, S27, S28, state 19**.

Subtotals: screens Start 7 · Tenant 16 · Resident 11 · Owner 30 · Team mode 11 · Shared 8.
Sheets Tenant 10 · Resident 8 · Owner 18 · Team 1 · Shared 7. States Tenant 17 · Resident 5 · Owner 6 · Shared 2.

## Counting rules

1. **Release app** = `flutter build --release --dart-define=DATA=supabase` (the Play/APK build). Things only in
   debug (`kDebugMode`), only in the sample "demo" APK (`DATA=sample`), or behind a flag that is off
   (`phoneOtpLogin = false`) are listed under "Not counted" and are not in the totals.
2. **Screen** = each `s.screen` key the shell maps to a widget (`lib/ui/shell.dart:386-458`, 68 keys), minus
   `otp` (flag off). Keys that draw the very same screen count once (`oPlan` = `oInvoice` = `oPayStatus`,
   `plan.dart:78`). A key whose body is switched wholesale into a **separate page** with its own title
   (Manage pages, wizard steps, Give notice / Move bed, Join / List your PG, picker Room / List view, Food week,
   Layouts › Shared things) counts once per page. Filter tabs inside one list (All / Due / Paid…) do not.
3. **Sheet** = each `s.sheet` key with a body in `_Sheet` (`shell.dart:674-718`, 42 keys). Every one has a
   real opener (file:line below). No `showDialog` / `showModalBottomSheet` / `Navigator.push` exists in `lib/`.
4. **Full-screen state** = a state that replaces the screen's whole main content (everything under its
   header/tabs, or the map's only card) with a different message or layout: empty, offline, loading, error,
   locked, "not set up", "owner only", "not on Hostelzy yet". **Not counted:** one-line empty text inside a
   list that still shows other content, inline error banners (`InlineError`), toasts, and status variants
   that keep the same layout and only change words/colours (listed at the end for Design).
5. **Console view** = each nav page in `app/console/console.js` `NAV` plus a detail view that replaces the page's
   detail pane with a different tool. **Web page** = each HTML file served from the repo root and `app/`.

## 1. App screens (84)
## 1. App screens (86)

### Start and sign-in (7)

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 1 | `welcome` | Welcome (red, "See the bed before you see the building") | `screens_start.dart:10` | App start (not signed in); Log out (`settings.dart:297`) |
| 2 | `login` | Sign in (Google); title changes with why (hold / list PG / join PG) | `screens_start.dart:119` | Welcome › Sign in; any sign-in gate (`features/session/guest.dart:74`) |
| 3 | `phone` | About you (name + WhatsApp number, "not verified") | `screens_start.dart:166` | After Google sign-in (`features/session/login.dart:53`); `state.dart:565` |
| 4 | `role` | What brings you here? (need a bed / live in a PG / run a PG) | `screens_start.dart:308` | After About you (`login.dart:82`); Me › Switch role |
| 5 | `roleGate` (resident) | Join your PG (invite code, Scan the QR, MGR- code) | `screens_start.dart:369` (`else` branch, `:428`) | Role › I live in a PG, without a stay (`features/map/map.dart:101`) |
| 6 | `roleGate` (owner) | List your PG (Request a visit, owner link, "Manager at a PG?") | `screens_start.dart:369` (`if (owner)`, `:386`) | Role › I run a PG, without a live hostel |
| 7 | `scan` | Scan the QR (invite poster) | `screens_start.dart:534` | Join your PG › Scan the QR (`features/links/links.dart:152,162`) |

### Tenant (15)
### Tenant (17)

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 8 | `explore` | Find a bed (tab). F26 #1 #2: search field with 📍 inside (→ Map at my location; the location explainer first); one row **Near me ✓ · Price ↑ ▾ · Filters · n**; one Featured (80+ beds) pinned on top, then "Then by price, lowest first" | `features/explore/explore_screen.dart` (`ExploreScreen`) | Tenant tab 1; role pick; guest browse (`guest.dart:65`) |
| 9 | `map` | Map (tab) | `map.dart:23` | Tenant tab 2 (also the side pane on tablets ≥1000 px) |
| 10 | `saved` | Saved (tab) | `screens_tenant.dart:1599` | Tenant tab 3; Me › Saved |
| 11 | `holds` | Holds (tab) | `screens_tenant.dart:461` | Tenant tab 4; Me › Holds; enquiry link for tenants (`links.dart:44`) |
| 12 | `where` | Where? (area / landmark / hostel search) = "Pick a place" | `guest.dart:11` | Explore search bar; Explore › Near me ✓ tapped again (F26 #2); location refused (`guest.dart:143`) |
| 13 | `detail` | Hostel page. F26: ✓ VERIFIED (navy) next to the name only after a team visit + "Beds and prices checked by Hostelzy · date"; Building view (S87) inline (80+ beds: "See all N rooms ›" → S88); the whole week's food table (today highlighted); no "On each floor" list, no tag boxes, no Visited block | `features/explore/hostel_screen.dart` (`DetailScreen`) | Hostel card (`screens_tenant.dart:378`), map card (`map.dart:231`), Saved |
| 10 | `saved` | Saved (tab) | `features/explore/explore_screen.dart` (`SavedScreen`) | Tenant tab 3 (F26 #10: no Me row) |
| 11 | `holds` | Holds (tab). F26 #16: red dot on the tab when a hold was kept or declined since Holds was last open | `features/holds/holds_screens.dart` (`HoldsScreen`) | Tenant tab 4 (F26 #10: no Me row); enquiry link for tenants (`links.dart:44`) |
| 12 | `where` | Where? (area / landmark / hostel search) | `guest.dart:11` | Explore search bar; location refused (`guest.dart:143`) |
| 13 | `detail` | Hostel page | `screens_tenant.dart:661` | Hostel card (`screens_tenant.dart:378`), map card (`map.dart:231`), Saved |
| 14 | `gallery` | Photos (full-screen gallery) | `photos.dart:291` | Hostel page › photo (`photos.dart:210`) |
| 15 | `reviews` | Reviews of a hostel | `reviews.dart:173` | Hostel page › reviews (`screens_tenant.dart:799`) |
| 16 | `picker` (plan) | Pick a bed · floor chips on top (jump to the floor); every room's drawn layout (beds, fan, AC, window, door, washroom) in one scroll, grouped by floor ("Floor 2 · 4 free"); each room: name + share · rent, "n free", red **Edit this layout** (F26 #12); a room without a layout shows its beds as boxes; tap a free bed → Continue (F26 #8) | `features/holds/picker_screen.dart` (`PickerScreen`, `_AllRooms`, `_RoomCard`) | Hostel page › See beds (`residents.dart:openPicker`); See the whole building (`openBuilding`); fixLock › Pick a bed |
| 17 | `picker` (room) | Room 101 · room layout, layers, bed facts, "Floor view" link back, red **Edit this layout** above the bar (F26 #12) | `features/layouts/layout_map.dart` (`RoomMode`) | Picker › a room's name (`room_layouts.dart:openRoom`) |
| 19 | `compare` | Compare two beds | `layout.dart:644` | Room view › Compare with another bed (`room_layouts.dart:122`) |
| 20 | `hold` | Your hold (timer / pay to book / booked / ended) | `screens_tenant.dart:1425` | After a hold (`residents.dart:312,426`); Holds row (`screens_tenant.dart:491`) |
| 21 | `moveIn` | Moving in · what to pay | `rewards.dart:152` | Hold › Moving in (`screens_tenant.dart:1496,1505`) |
| 22 | `rewards` | Stay Rewards | `rewards.dart:15` | Me › Stay Rewards (`screens_tenant.dart:589`) |
| 87 | `picker` (building) | Pick a bed · Building: cross-section (roof, F3…F1, G only when the data has a ground floor, base slab), shared-thing chips on top of each floor (red when not working), every room's beds; a free bed → Continue; a floor → floor sheet H42 (F25 NEW-1 `w4-building`, NEW-2 merged in). Same component on owner Beds › Building (S37) | `features/holds/building_view.dart` (`BuildingView`) | Hostel page (F26 #3); owner Beds › Building. **F26 #8: no longer a picker tab** |
| 87 | `picker` (building) | Pick a bed · Building: cross-section (roof, F3…F1, G only when the data has a ground floor, base slab), shared-thing chips on top of each floor (red when not working), every room's beds; a free bed → Continue; a floor → floor sheet H42 (F25 NEW-1 `w4-building`, NEW-2 merged in). Same component on owner Beds › Building (S37) | `features/holds/building_view.dart` (`BuildingView`) | Picker tab Building (`pickTab-building`); **F26 #3: inline on the Hostel page** (`HostelBuilding`, a free bed opens the picker on it) and on S88 |
| 88 | `building` | All N rooms: an 80+ bed hostel's Building view (S87 component) on its own page, back to the hostel page; a free bed opens the picker on it (F26 #3) | `features/explore/hostel_screen.dart` (`BuildingScreen`) | Hostel page › See all N rooms › (`seeAllRooms`, more than 80 beds) |

### Resident (11)

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 23 | `rHome` | Home (tab): rent card (red Pay), 3 actions, 30-day review card, **Food this week** table always open (today's row highlighted, F26 #4 #13), How was breakfast? | `features/residents/resident_screens.dart` (`ResidentHomeScreen`, `HomeWeek`) | Resident tab 1; after joining; meal reminder |
| 26 | `rPay` | Rent (tab) | `screens_resident.dart:191` | Resident tab 2 (plain tab, F26); Home › Pay / Pay rent |
| 89 | `rStay` | My stay (tab, F26 #14): bed card · Your bed (Move to another bed, Give notice, Your refund, Review your stay, Fix a room layout) · Help (Something wrong in your room? › H44, Your complaints › H45) | `features/residents/resident_screens.dart` (`StayScreen`) | Resident tab 3; Find a bed tab bar › My stay (`features/session/tabs.dart` `leaveFindBed`) |
| 88 | `savedHolds` | Saved & Holds (F26 #17): one tab, segments Saved · n / Holds · n (bodies = S10 / S11 without their titles); red dot on the tab (F26 #16) | `features/holds/saved_holds_screen.dart` (`SavedHoldsScreen`) | Find a bed tab bar, tab 3 (residents only; a plain tenant keeps Saved and Holds) |
| 29 | `move` (vacate) | Give notice | `screens_resident.dart:871` | My stay (S89) › Give notice |
| 30 | `move` (swap) | Move to another bed | `screens_resident.dart:871` (`else`, `:1000`) | My stay › Move to another bed |
| 31 | `rRoom` | Rooms · room layout (resident) | `layout_fixes.dart:22` | My stay › Fix a room layout (`features/layouts/layout_fixes.dart:101`) |
| 32 | `rFix` | Fix this room (layout fix editor); for a non-resident it is try mode: "Try a layout · Room N", "Move things to see how the room works for you", red **Publish** → H13 (F26 #12) | `layout_fixes.dart:157` | Rooms › Fix (`features/layouts/layout_fixes.dart:131`); tenant Edit this layout (S16, S17) |
| 33 | `rReview` | 30-day review | `reviews.dart:252` | Home › review card (`review_rules.dart:54`) |
| 34 | `rExit` | Exit review | `reviews.dart:317` | Give notice › Review your stay (`review_rules.dart:67`) |
| 35 | `rRefund` | Your refund (former resident) | `refunds.dart:69` | My stay › Your refund; Me › Your refund for a non-resident (`features/moves/moves.dart:180`) |

### Owner (29)

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 36 | `oToday` | Today (tab) · F26 #18: Fair Play card pinned on top, then **Holds · Payments · Fixes** tabs with counts (most urgent opens first; Holds = hold requests (Confirm / Decline), notices and bed moves, "Still N free beds?"; Payments = payments to confirm, refunds, "Are your rates still right?"; Fixes = layout fixes, quick fixes, repairs, broken shared things, a new layout to check, "Do your room layouts still match?"), then the This month card with "N% full" + bar (F25 A6). Empty: T33 | `screens_owner.dart:58` | Owner tab 1; role pick; hostel switch (`state.dart:231`) |
| 37 | `oBeds` | Beds (tab) · F26 #19: the Building view only (the S87 component; the Rooms list and its toggle are gone). A bed → H18; a room's number → its layout (S `oLayout` / `oCreate`); "Layouts ›" to create or copy one | `features/owner/owner_beds_screen.dart` | Owner tab 2 |
| 38 | `oRent` | Rent (tab) · F26 #20: tags Paid green, Late red, Due plain; **Call** + **WhatsApp** (ready reminder text, the resident's number) on every unpaid row, no bell | `screens_owner.dart:645` | Owner tab 4; Today › rent pending |
| 39 | `oMore` (home) | Manage (tab, list) | `screens_owner.dart:1043` (`_ManageList`) | Owner tab 5 |
| 40 | `oMore` · residents | Manage › Residents | `screens_owner.dart:1129` | Manage › Residents |
| 42 | `oMore` · complaints | Manage › Complaints | `screens_owner.dart:849` | Manage › Complaints |
| 43 | `oMore` · deals | Manage › Deals | `deals.dart:13` | Manage › Deals (`state.openDeals`, `state.dart:241`) |
| 44 | `oMore` · rates | Manage › Rates and UPI | `screens_owner.dart:1434` (`RateCard`) | Manage › Rates and UPI (`residents.dart:120`) |
| 45 | `oMore` · menu | Manage › Food menu (+ meal times; toggle Edit by day · Week table, the Week table is a variant here, not its own screen: F25 hub decision, board `w4-oMenuWeek`) | `screens_owner.dart:926` | Manage › Food menu (`food.dart:126`) |
| 46 | `oMore` · rules | Manage › House rules (+ laundry day) | `screens_owner.dart:1005` | Manage › House rules |
| 47 | `oInvite` | Invite residents (code, QR, share, poster) | `screens_owner.dart:1289` | Manage › Residents › QR (`screens_owner.dart:1157`) |
| 48 | `oTeam` | Team (owner's managers) | `onboarding.dart:1120` | Manage › Team (`screens_owner.dart:1077`) |
| 49 | `oPhotos` | Photos (owner) | `photos.dart:25` | Manage › Photos (`photos.dart:89`); wizard step 4 (`onboarding.dart:366`) |
| 50 | `oCrop` | Crop photo | `photos.dart:185` | Photos › after picking (`features/photos/photos.dart:104`) |
| 51 | `oRooms` | Rooms (add / change rooms) | `rooms.dart:11` | Beds › Rooms (`screens_owner.dart:1518`) |
| 52 | `oMeter` | Electricity (meter readings) | `stay_tools.dart:13` | Rent › Electricity (`features/meter/meter.dart:74`) |
| 53 | `oLayouts` (rooms) | Room layouts | `team.dart:113` | Manage › Room layouts (`screens_owner.dart:1073`) |
| 54 | `oLayouts` (things) | Layouts › Shared things (by floor) | `amenities.dart:333` (`OwnerSharedThings`) | Room layouts › Shared things tab (`team.dart:158`) |
| 55 | `oLayout` | Room N · layout (owner view) | `layout.dart:777` | Room layouts › a room (`owner_layouts.dart:133`) |
| 56 | `oCreate` | Create a layout · pick the shape | `layout.dart:1269` | Room layouts › Create (`owner_layouts.dart:34`) |
| 57 | `aLayout` | Layout editor (owner and team) | `layout.dart:989` | Room › Edit layout (`layout.dart:924`); Team home (`team.dart:54`) |
| 58 | `oPublished` | Layout published | `layout.dart:1372` | Editor › Publish (`owner_layouts.dart:99,115`) |
| 59 | `oFix` | A resident's layout fix (approve / reject) | `layout_fixes.dart:644` | Today › fix card (`features/layouts/layout_fixes.dart:263`) |
| 60 | `oFixDone` | Fix published | `layout_fixes.dart:750` | Fix › Approve (`features/layouts/layout_fixes.dart:301`) |
| 61 | `oRank` | Reviews and ranking | `reviews.dart:479` → `:395` | Manage › Reviews and ranking (`screens_owner.dart:1076`) |
| 62 | `oRules` | Fair Play rules | `fairplay.dart:90` | First owner role pick (`map.dart:pickRole`); Settings › Fair Play rules |
| 63 | `oCase` | Fair Play check (case + reply) | `fairplay.dart:336` | Today › case card (`screens_owner.dart:332`); push |
| 64 | `oStrike` | Strike notice | `fairplay.dart:471` | Today › strike card (`screens_owner.dart:332`) |
| 65 | `oPlan` = `oInvoice` = `oPayStatus` | Your plan · invoice · payment status (one screen) · Past invoices + All plans sections (F25 A7, A8) | `plan.dart:81/87/93` | Manage › Your plan (`screens_owner.dart:1078`); Pay (`plan.dart:333`); after UTR (`features/plan/plan.dart:106,120`) |

### Hostelzy team mode (11) — release, only for Google accounts with the `team` claim

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 66 | `aHome` | Hostelzy team (tools list; a line says Payments and Fair Play cases are in the team console, F25) | `team.dart:40` | Settings › Hostelzy team (`team_mode.dart:17,33`) |
| 67 | `aAdd` step 1 | Add hostel · Basics | `onboarding.dart:142` | Team › Add hostel (`state.dart:239`); tracker (`team_mode.dart:71`) |
| 68 | `aAdd` step 2 | Add hostel · Rooms, floor by floor | `onboarding.dart:218` | Wizard › Next |
| 69 | `aAdd` step 3 | Add hostel · Rate card | `onboarding.dart:406` | Wizard › Next |
| 70 | `aAdd` step 4 | Add hostel · Photos | `onboarding.dart:502` | Wizard › Next |
| 71 | `aAdd` step 5 | Add hostel · Current residents | `onboarding.dart:636` | Wizard › Next |
| 72 | `aAdd` step 6 | Add hostel · Owner account | `onboarding.dart:739` | Wizard › Next |
| 73 | `aAdd` step 7 | Add hostel · Ready to go live? | `onboarding.dart:789` | Wizard › Next |
| 74 | `aPin` | Map pin | `map.dart:287` | Wizard step 1 › Map pin (`onboarding.dart:202`; `features/onboarding/onboarding.dart:251`) |
| 75 | `aTrack` | Onboarding tracker | `onboarding.dart:1253` | Team › Onboarding tracker (`team.dart:49`); after go live |
| 78 | `aTeam` | Team members | `rooms.dart:113` | Team › Team members (`team.dart:56`) |

### Shared, every role (8)

| # | id | Name | Built at | How it's reached |
|---|---|---|---|---|
| 79 | `me` | Me (tab for tenant and resident; owner via Today avatar). F26 #10 #11: no Saved / Holds / My stay rows; **Log out** in red at the end | `features/session/me_screen.dart` | Tab 5 (also in the Find a bed bar); owner Today (`screens_owner.dart:89`) |
| 80 | `settings` | Settings | `settings.dart:73` | Me › Settings |
| 81 | `reminders` | Reminders | `reminders.dart:92` | Me › Reminders; reminder notification (`features/reminders/reminders.dart:77,234`) |
| 82 | `perm` | Turn on notifications? (explainer) | `settings.dart:309` | First role pick as **resident or owner** with push not yet allowed (`login.dart` `offerPush`). Never for tenants (F25: a tenant's only ask is H5) |
| 83 | `delAcc` | Delete account | `settings.dart:143` | Settings › Delete account |
| 84 | `delConfirm` | Delete · confirm with Google | `settings.dart:227` | Delete account › Continue (`state.dart:656`) |
| 85 | `delDone` | Your account is deleted | `settings.dart:278` | After delete (`sync.dart:291`) |
| 86 | `gate` | Back in a few minutes (maintenance) | `settings.dart:364` | Remote settings from Supabase (`state.dart:643`); `app_config.dart` switches |

## 2. App sheets (41)

All in `_Sheet`, `lib/ui/shell.dart:581`; the key's body line is `shell.dart:675-717`.

### Tenant (10)

| # | id | Title | Body class | Opened at |
|---|---|---|---|---|
| 1 | `search` | Filters (F26 #2: Who · Room · Food · Rent, then deals and shared things; no sort) | `features/explore/explore_sheets.dart` (`SearchSheet`) | Explore › Filters · n |
| 44 | `sort` | Sort by: Price ↑ (default) · Distance · Rating · Best deals (F26 #2) | `features/explore/explore_sheets.dart` (`SortSheet`) | Explore › Price ↑ ▾ (`sortBtn`) |
| 2 | `loc` | Use your location? | `map.dart:249` | Map › Near me (`map.dart:128`; `guest.dart:180`) |
| 3 | `signIn` | Sign in to hold / book / message | `guest.dart:105` | Guest taps Hold, Book or WhatsApp (`guest.dart:86`) |
| 4 | `hold` | Bed N (free hold or book with advance) | `shell.dart:877` | Picker › Continue (`screens_tenant.dart:1148`; `layout.dart:613`); hold again (`:1453`) |
| 5 | `holdNotify` | Bed N is held for you (allow notifications; the tenant's only notification ask, never together with S82, F25) | `guest.dart:129` | After the first hold (`guest.dart:203`) |
| 6 | `wa` | Ask the owner (WhatsApp enquiry) | `shell.dart:962` | Hostel page / hold › WhatsApp (`map.dart:158`; `sync.dart:197`; `state.dart:396`) |
| 7 | `payAdv` | Pay the advance | `payments.dart:59` | Book a bed (`residents.dart:313,427`) |
| 8 | `report` | Tell us what happened (private) | `fairplay.dart:288` | Holds › "The owner asked me to skip the app" (`screens_tenant.dart:544`) |
| 9 | `perks` | What Trusted tenants get / You're a Trusted tenant | `stay_tools.dart:209` | Rewards / first-look bed (`features/rewards/rewards.dart:74`) |

### Resident (8)

| # | id | Title | Body class | Opened at |
|---|---|---|---|---|
| 11 | `scanCam` | Use your camera? | `screens_start.dart:499` | Join your PG › Scan the QR, first time (`links.dart:150`) |
| 12 | `payUtr` | Enter the UPI reference (rent, also the tenant's advance) | `payments.dart:105` | After paying by UPI (`features/payments/payments.dart:35`; `state.dart:556`) |
| 13 | `fixLock` | Publish (try mode) / Fix this room?: "Only residents can send a fix" · Book a bed to join · Pick a bed · Keep trying (F26 #12) | `layout_fixes.dart:308` | Rooms › Fix (`features/layouts/layout_fixes.dart:116,187,367`) |
| 14 | `fixLimit` | Can't send yet | `layout_fixes.dart:342` | Fix limit reached (`features/layouts/layout_fixes.dart:119,391`) |
| 15 | `fixSend` | Send your fix | `layout_fixes.dart:386` | Fix editor › Send (`features/layouts/layout_fixes.dart:193`) |
| 16 | `quickFix` | Quick fix · item (fan, AC…) | `layout_fixes.dart:557` | Rooms › tap an item (`features/layouts/layout_fixes.dart:374`) |
| 44 | `complaint` | Something wrong in your room? (kicker Help · hostel): category chips, text, photo, Send to owner (F26 #14, was the Help tab) | `features/residents/help_sheets.dart` (`ComplaintSheet`) | My stay › Help › Something wrong in your room?; Home › Raise complaint; Your complaints (empty) |
| 45 | `complaints` | Your complaints: each with Sent / Being fixed / Fixed (F26 #14); empty: No complaints + Something wrong in your room? | `features/residents/help_sheets.dart` (`ComplaintsSheet`) | My stay › Help › Your complaints; after Send to owner |

### Owner (17)

| # | id | Title | Body class | Opened at |
|---|---|---|---|---|
| 18 | `bed` | Bed N (owner bed sheet) | `shell.dart:1322` | Beds › a bed (`screens_owner.dart:520`) |
| 20 | `addR` | Add a resident (the one sheet; F25: H17 `add` merged in). Name, WhatsApp number, bed, ONE date (label "Moves in" when in the future = a booking, "Joined on" when today or past), monthly fee, advance, "Lived here before Hostelzy" (before go-live, past dates only) | `features/residents/residents_sheets.dart` (`AddResidentSheet`) | Owner tab bar "+" (`shell.dart` `_openTab`); Residents › Add; bed sheet › Add tenant to this bed (all `residents.dart` `openAddResident`) |
| 21 | `trusted` | X is a Trusted tenant | `rewards.dart:249` | Today › hold request (`screens_owner.dart:161`) |
| 22 | `utr` | I've paid ₹N (plan invoice UTR) | `plan.dart:243` | Your plan › I've paid (`state.dart:170`) |
| 23 | `layoutReq` | Ask Hostelzy to draw it | `layout.dart:941` | Create a layout › Custom / Ask (`room_layouts.dart:210`) |
| 24 | `switch` | Switch hostel | `onboarding.dart:1046` | Today / Manage header (`screens_owner.dart:85,1085`) |
| 25 | `addRoom` | Add a room | `rooms.dart:89` | Rooms › Add (`features/onboarding/rooms_live.dart:33`) |
| 26 | `manager` | Add a manager | `onboarding.dart:1195` | Team › Add (`onboarding.dart:1187`) |
| 27 | `photo` | This photo (cover, label, delete) | `photos.dart:384` | Photos › a photo (`photos.dart:64`) |
| 28 | `cPhoto` | Photo (a complaint's photo) | inline `shell.dart:678` | Complaints › photo (`state.dart:469`) |
| 29 | `fixReject` | Reject this fix? | `layout_fixes.dart:723` | Fix › Reject (`layout_fixes.dart:711`) |
| 30 | `fixMute` | Mute this resident? | `layout_fixes.dart:619` | Fix › Mute (`layout_fixes.dart:693`) |
| 31 | `rank` | How the ranking works | `reviews.dart:486` | Reviews and ranking › rank tile (`reviews.dart:444`) |
| 32 | `revReport` | Report this review | `reviews.dart:509` | Reviews › Report (`review_rules.dart:132`) |
| 33 | `refund` | Refund X's advance | `refunds.dart:36` | Today › refund card (`features/moves/moves.dart:171`) |
| 34 | `laundry` | Laundry day | `stay_tools.dart:166` | House rules › Laundry day (`features/laundry/laundry.dart:40`) |
| 35 | `waNum` | Your WhatsApp number | `settings.dart:418` | Settings › WhatsApp, owners (`features/session/on_phone.dart:65`) |

### Team (1)

| # | id | Title | Body class | Opened at |
|---|---|---|---|---|
| 36 | `team` | Hostelzy team (check the team account) | `team.dart:13` | Settings › Hostelzy team, not yet unlocked (`team_mode.dart:18`) |

### Shared (7)

| # | id | Title | Body class | Opened at |
|---|---|---|---|---|
| 37 | `lang` | Language | `guest.dart:156` | Settings › Language (`settings.dart:118`), once Telugu/Hindi are checked |
| 38 | `name` | Change your name | `settings.dart:395` | Settings › Name (`on_phone.dart:33`) |
| 39 | `water` | Drink water | `reminders.dart:326` | Reminders › Water (`features/reminders/reminders.dart:257`) |
| 40 | `addRem` | Add a reminder / Edit reminder | `reminders.dart:437` | Reminders › Add (`features/reminders/reminders.dart:286`) |
| 41 | `waterOffer` | Want water reminders? | `reminders.dart:506` | 3rd app open (`features/reminders/reminders.dart:357`) |
| 42 | `amFloor` | On floor N (shared things) | `amenities.dart:149` | Hostel page / Rooms / Shared things › a floor (`features/amenities/amenities.dart:100`) |
| 43 | `amAdd` | Add to floor / Change item | `amenities.dart:226` | Floor sheet › Add (`features/amenities/amenities.dart:110`) |

## 3. App full-screen states (28)
## 3. App full-screen states (32)

| # | Screen | State | Condition | Built at |
|---|---|---|---|---|
| **Tenant (14)** |||||
| 1 | `explore` | Loading (2 grey skeleton cards) | `listState == 'loading'` while Supabase loads | `screens_tenant.dart:157`, `:229` |
| 2 | `explore` | You're offline · Retry | load failed, no cached list | `screens_tenant.dart:158`, `:246` |
| 3 | `explore` | Offline · hostels as of date (cached banner) | load failed, last list on the phone | `screens_tenant.dart:159` (banner + saved cards) |
| 4 | `explore` | No hostels in this area yet · Try area | nothing live, or area picked has none | `screens_tenant.dart:177` |
| 5 | `explore` | Nothing matches yet · Clear filters | filters exclude every hostel | `screens_tenant.dart:196` |
| 6 | `map` | No hostels here yet (card) | no hostel under the filters/area | `map.dart:163` |
| 7 | `holds` | No holds yet · Find a bed | `holds.isEmpty` | `screens_tenant.dart:548` |
| 8 | `saved` | Nothing saved yet · Find a bed | nothing saved | `screens_tenant.dart:1617` |
| 9 | `hold` | This hold isn't on this phone any more | hold id not found | `screens_tenant.dart:1432` |
| 12 | `picker` (room) | Loading the layout… | women's PG room fetched one by one (only until the F26 SQL 4zo1 runs) | `layout.dart:375` |
| 14 | `picker` (room) | Couldn't load this room · Try again (also "Couldn’t open this room yet · Floor view" for the old server's daily limit, until 4zo1 runs; no hold talk) | server fetch failed / `capped` | `layout.dart:390` |
| 15 | `picker` (room) | Layout coming soon · Tell me when it's ready | no published layout | `layout.dart:398` |
| 16 | `scan` | The camera is off for Hostelzy | camera permission denied | `screens_start.dart:540` |
| 17 | `scan` | The camera didn't start | scanner error | `screens_start.dart:540` |
| **Resident (6)** |||||
| 18 | `rPay` | Your stay isn't on Hostelzy yet | `myStay == null` | `screens_resident.dart:198` |
| 20 | `rStay` | Your stay isn't on Hostelzy yet | `myStay == null` | `screens_resident.dart:799` |
| 21 | `move` (vacate) | Notice given / Notice accepted | notice sent (not declined) | `screens_resident.dart:947` |
| 22 | `rRoom` | No layout yet | room has no layout | `layout_fixes.dart:99` |
| 23 | `rRefund` | No refund waiting | no open refund | `refunds.dart:83` |
| **Owner (7)** |||||
| 24 | `oRules` | Fair Play rules · before you go live (short + I agree) | `!fairAccepted && !fpFull` | `fairplay.dart:109` |
| 25 | `oCase` | Fair Play · No open cases | no case | `fairplay.dart:343` |
| 26 | `oLayout` | No layout yet (draw it / ask Hostelzy) | no layout, no request | `layout.dart:844` |
| 27 | `oLayout` | Hostelzy is drawing it | open shape request | `layout.dart:843` |
| 28 | `oLayout` | Hostelzy drew a new version · check and publish | request sent back | `layout.dart:845` |
| 29 | `oPlan`, `oCase`, `oStrike`, Manage › Deals / Rates | Owner only (manager) | `ownerOnlyWhat` ≠ null | `plan.dart:457`, `shell.dart:354` |
| 33 | `oToday` | Nothing needs you now (all three counts 0; "New holds, payments and fixes show up here.") | nothing waits for the owner (F26 #18) | `features/owner/owner_today_screen.dart` (`needsNothing`) |
| **Shared (2)** |||||
| 30 | `delAcc` | Can't delete yet (open hold / unpaid plan) | `deleteBlock != null` | `settings.dart:154` |
| 31 | `gate` | Update Hostelzy to continue | `appBuild < minBuild` | `settings.dart:370` |

## 4. Team console, app/console (13)

Firebase sign-in, `team` claim only. Built in `app/console/console.js`.

| # | id | View | Built at |
|---|---|---|---|
| 1 | `#onboarding` | Onboarding (stage columns, add lead, advance) | `console.js:109` |
| 2 | `#payments` | Payments (invoices, mark paid / not received) | `console.js:151` |
| 3 | `#cases` | Fair Play (case tabs, list + case detail, signals, strikes, tenant reports, case photo) | `console.js:180` |
| 4 | `#layout` | Layout help (requests table + request detail) | `console.js:311` |
| 5 | `#layout` › editor | Layout help · draw the walls (shape, W × L, Send to owner) | `console.js:316` (`editor`) |
| 6 | `#rewards` | Stay Rewards ledger (Reverse) | `console.js:395` |
| 7 | `#fixes` | Layout fixes (list + fix detail, approve / reject) | `console.js:420` |
| 8 | `#reviews` | Reported reviews (Hide / Keep) | `console.js:478` |
| 9 | `#hostels` | Hostels (Go live / Pause) | `console.js:507` |
| 10 | state | Sign in (Continue with Google; "isn't a Hostelzy team account" message) | `console.js:53` |
| 11 | state | Not set up yet (no Firebase config) | `console.js:37` |
| 12 | state | Couldn't start | `console.js:41` |
| 13 | state | Couldn't load (page error) | `console.js:96` |

Not counted: "Loading…" (`console.js:87`) and "Not found." for an unknown `#hash` (`console.js:94`).

## 5. Web pages (8)

| # | Path | Page | States |
|---|---|---|---|
| 1 | `app/index.html` | Hostelzy · Get the app | — |
| 2 | `app/r/` | A Hostelzy enquiry (HZ code, Open in Hostelzy) | +1: "This link has no HZ code" (`app/r/index.html:20`) |
| 3 | `app/j/` | You're invited to your hostel (invite code) | +1: "This link has no invite code" (`app/j/index.html:20`) |
| 4 | `app/privacy/` | Privacy policy | — |
| 5 | `app/terms/` | Terms of use | — |
| 6 | `app/delete-account/` | Delete your Hostelzy account | — |

Pages 6 + states 2 = 8.

## 6. Not counted (listed so nobody draws or builds them by mistake)

| Item | Why not counted | Where |
|---|---|---|
| `index.html` (site root) | Old web prototype page, kept by founder decision (DECISIONS "Web address for now": farhath.me/hostelzy/ stays the old prototype). Not part of the app. Self-contained: loads nothing from the repo | `index.html` |
| `otp` Enter the 6-digit code | `phoneOtpLogin = false` (SMS needs Firebase billing) | `screens_start.dart:243`, `app_config.dart` |
| About you as "Your mobile number · Step 1 of 2" | same flag | `screens_start.dart:182` |
| DEMO banner "Sample data. Nothing you do here is real." | only the `DATA=sample` demo APK | `shell.dart:341` |
| Prototype frame, jump list, phone frame | `kDebugMode` only | `shell.dart:111-280` |
| All-screens overview page (`?page=overview`), start-state URL params, `?plan=` demo states | `kDebugMode` only | `ui/overview.dart`, `main.dart:52` |
| Tablet / desktop layout (left rail, app column, map or brand pane) | layout of the same screens, not a screen | `shell.dart:79` (`_Wide`), `:482` (`_Rail`) |
| Toast (with Undo), tab bar | chrome on every screen | `shell.dart:364`, `:528` |
| `moveIn` / sheet bodies with missing data → empty `SizedBox` | defensive fallback, nothing drawn | e.g. `rewards.dart:159` |

## 7. Status variants (same layout, not counted; for Design to check)

- `hold`: Held · free · Held · owner confirmed · Pay to book · Waiting for owner · Not received · Booked · Hold ended · Released (`screens_tenant.dart:1463-1517`).
- `oPlan`: Free trial · Due · N days late · Checking · Paid · Not received (`plan.dart:23`).
- `rPay`: Due · Waiting · Not received · Paid (`screens_resident.dart:236-248`).
- `oStrike`: Strike 1 · 2 (deals hidden / deals back) · 3 removed (`fairplay.dart:479`).
- `login`: Sign in · to hold a bed · to list your PG · to join your PG (`screens_start.dart:125`).
- `me`, `settings`: rows differ by role. `detail`: owner block before / after a hold.
- Tab bars (F26): tenant Explore · Map · Saved · Holds · Me; resident Home · Rent · My stay · Find a bed · Me; a resident
  inside **Find a bed** (S8 Explore, S9 Map, S88 Saved & Holds, S79 Me) Explore · Map · Saved & Holds · My stay · Me;
  red dot on Holds / Saved & Holds after a kept or declined hold (`ui/shell.dart` `_tabsOf`, `_tabIcon`).

## Finding while counting (for Build)

`explore` cached state (#3 in §3): the `if / else if` chain at `screens_tenant.dart:157-196` shows **only the
"Offline · hostels as of…" banner** when `listState == 'cached'`; the cached hostel cards (already applied in
`main.dart` `_goLive`) are in the final `else` and never render. Design's board `w1-exploreCached` shows the last
list kept. **Fixed in the same PR (2026-10-03):** the saved cards now show under the banner (`test/platform_test.dart`).
