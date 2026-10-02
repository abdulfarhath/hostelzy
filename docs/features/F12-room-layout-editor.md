# F12 · Room layout editor and room layers (with F11 seat-map booking)

**Stage:** Design ready · 2026-10-02 (F11 seat map merged in)

## Problem
Tenants want to know exactly where their bed is and what's around it (fan, AC, window, washroom)
before visiting. Owners' rooms come in many shapes.

## What it does (phase 1)
- **Hostelzy team draws every layout** (decided 2026-10-02) on a laptop admin editor during or after
  the onboarding visit: room shape from the library (rectangle, L, T, U, angled corner, narrow end,
  alcove) or a new custom shape, items on a 1-ft grid: beds, bunk beds (2 beds), window, door, fan,
  AC (with direction), washroom zone, pillar. Copy to other rooms, mirror/flip, version history.
- **Owner in the app (phone):** sees each room's layout, **approves** it before it goes live, marks
  items Working / Not working, and taps **Request a change** (photo + paper sketch + measurements +
  voice note). Hostelzy redraws it **free, within 48 hours**; the owner approves the new version.
  Until a room's layout is approved it shows "Layout coming soon".
- **Tenant Room tab = seat map (F11):** a new **Room** tab beside the bed picker's Plan tab;
  tapping a room in Plan opens it in Room. In it: tap a bed like a movie seat; layer toggles (fans, AC,
  windows, washroom); automatic bed facts ("Under a fan", "Window side · street", "Near the door",
  "Lower bunk", "AC airflow"); compare two beds.

## Rules
- Layout beds ARE the bed-map beds (same IDs). Can't delete a bed with a resident. Adding a bed
  changes sharing type and asks the owner to confirm the price.
- **No pricing by position** (DECISIONS 2026-10-02). Price comes from sharing × AC/non-AC (F16).
- A room marked AC must have an AC unit placed.
- Fan covers ~4 ft radius → "Under a fan". Window has a "faces street / courtyard / building" property.
- Item status Working / Not working, shown honestly.
- Honesty: residents answer "Is the layout accurate?" in reviews; "Confirm layout" every 3 months;
  "Verified by Hostelzy visit" badge.
- Safety: layouts only for logged-in OTP users; never show gates, CCTV, exits; women's-PG floor plans
  only after a hold (decided 2026-10-02). Residents' names never shown on plans.
- Tenants see the last published layout; one editor at a time; version history kept.

## Problems considered
Room geometry (irregular shapes, pillars, alcoves, balconies, unknown sizes, feet vs metres, sloped
ceilings) · custom-shape requests (how to describe, waiting time, who draws, cost, approval) · phone
editor usability (small screen, overlaps, low digital literacy, language, weak network) · accuracy and
honesty (fake fans/AC, stale layouts, broken items) · bed-map sync (bunks, deleted/added beds) ·
item meaning (fan coverage, AC throw, window facing, shared washroom outside) · tenant readability
(too many symbols, colour-blind, cheap phones) · many rooms (copy, mirror) · safety/privacy
(women's PGs, scraping) · technical (JSON storage, versioning, concurrent edits, export as image) ·
business (founder's drawing time, owners who never draw → "Layout not added" + lower ranking).

## Later (phase 2)
Power sockets, owner draws/edits layouts on the phone (only if owners ask for it), draw custom shape wall by wall,
AR measuring, sockets/cupboards/tables/lights/balcony, floor layout
editor, photos pinned to items, bed filters in Explore (window bed, lower bunk), Telugu/Hindi.

## Open questions
None. All answered 2026-10-02 (see DECISIONS.md).

## Design
Canvas https://claude.ai/artifact/8uEkfu5EzRsDeZrkb8Gjaz. Awaiting founder approval. Sample room: Anjani 204, 18 × 15 ft, 3 sharing, AC, ₹8,200. Items: window (faces street), door, attached washroom, 2 fans (dashed ~4 ft circles), AC unit with its airflow. Layers are told apart by pattern (bar, dashed circle, stripes, hatching), not colour alone.

1. **Tenant: Room tab.** The bed picker segment is now Plan · Room · List · Building. It shows the room drawn on a 1-ft grid, with layer toggles for Fans, AC, Windows and Washroom. Beds are tapped like seats (Free, Taken, On hold, Selected) and never show names. The selected bed gets automatic facts ("Under a fan", "Window side · faces street", "In the AC airflow", "Door 4 m away") and the line "Same price as every bed here". Below: "Verified by Hostelzy visit · 28 Sep", then Compare beds and Hold bed. Interactive.
2. **Tenant: compare two beds.** The same map with two beds marked, then a side-by-side table (fan, AC, window, door, washroom, walls), with differences in bold. The last row shows the same price for both.
3. **Tenant: special states** (tweak "State"):
   - "Layout coming soon": dashed box, "The Hostelzy team is drawing this room", and "Tell me when it's ready".
   - Women's PG before a hold: Plan tab locked with "Floor plan shows after you hold a bed"; room layouts stay in the Room tab. Note: never shows gates, CCTV, exits or names.
   - Signed out: "Sign in to see room layouts" and Verify my phone.
4. **Owner: approve a layout** (Beds → room). Status bar shows "Check it and approve to go live · v2 drawn 1 Oct". Each item has a Working / Not working switch; when off, the item turns red on the map and the hint says tenants see "Not working" / "AC under repair" and a complaint is raised. Buttons: Approve layout and Request a change. Interactive.
5. **Owner: request a change (sheet).** "What's different?" text box, plus tiles for Room photo, Paper sketch, Voice note and More photos, and length × width in ft. Note: "Free. The Hostelzy team redraws it within 48 hours…". Send request. Interactive.
6. **Hostelzy admin: layout editor** (1440 × 900, laptop):
   - Top bar: breadcrumb, "v2 draft · v1 live", Copy to rooms…, Mirror, Flip, History, Send to owner for approval.
   - Left: the shape library (rectangle, L, T, U, angled corner, narrow end, alcove, custom) and the items palette (bed, bunk bed, window, door, fan, AC, washroom zone, pillar), with a reminder: no gates, CCTV, exits; sockets in phase 2.
   - Middle: the room at 160% on a 1-ft grid, AC selected.
   - Right: properties (wall, blows, reach, status); beds linked to the bed map ("204-A has a resident · can't delete"); checks (AC room has an AC unit, 3 beds = 3 sharing, window facing set, no gates/CCTV/exits); and the owner's request with the 48-hour countdown.
- Dark mode: board "1 in dark mode". Every board has a Dark tweak.

**Updated 2026-10-02 for DECISIONS "Design follow-ups"**
- Fans show as icons labelled FAN (red "FAN · NOT WORKING" when broken), the AC unit as "AC UNIT"; window, door and washroom are always labelled.
- Board 1 toggles are "Show fan reach" and "Show AC airflow", off by default; the circles and airflow appear only when switched on. Owner and admin boards show them.
- Plan stays the default tab; tapping a room opens Room (board 1 shows the Room tab open).

## Build
**Shipped 2026-10-02** · branch `feature/f12-room-layouts` (Build chat). Sample data in `AppState`; follows DECISIONS "No fake behaviour".

- **Model** (`lib/data.dart`): `RoomLayout` (size in ft, beds keyed by the bed-map letters, items: window with facing, door, washroom zone, fans, AC unit; version, live, pending, owner request, mirror/flip) and `LItem` (Working / Not working). `bedTraits` / `bedFacts` work out each bed's facts from the drawing: under a fan (4 ft reach), window side · facing, in/out of the AC airflow, door and washroom distance in metres, corner / one wall. Never a price by position.
- **Sample layouts**: every room of Anjani, Sai Sri, Nest 42 and Orchid gets a generated layout (2/3/4-sharing templates; window faces street on the first half of each floor). Greenview and Lakshmi have none, so they show "Layout coming soon". Anjani 204 has v2 waiting for the owner. Because these are generated, the map says **"Sample layout · real ones after a visit"** instead of "Verified by Hostelzy visit" (F17: no false "Verified").
- **Tenant Room tab** (bed picker: Plan · Room · List · Building; Plan stays the default, tapping a room tile in Plan opens Room): room chips, room line, "Show fan reach" / "Show AC airflow" (off by default), the map on a 1-ft grid (fan / AC / window / door / washroom always labelled; broken items in red), beds tapped like seats, the facts for the picked bed, "Same price as every bed here". Bottom: Compare beds + Hold bed X.
- **Compare** (`compare`): both beds on the map, a side-by-side table (differences in bold), same price row, Hold either.
- **Special states**: Layout coming soon (with "Tell me when it's ready", which honestly says alerts come once the app is online); women's PGs lock Plan and Building until the tenant holds a bed there ("See rooms in the Room tab"); signed out (`?auth=out`) shows "Sign in to see room layouts" + Verify my phone. Verifying the OTP sets `signedIn`.
- **Owner** (Beds → each room has "Layout ›", red "Approve layout ›" when a version waits): status bar, the map with layers, Working / Not working per fan, AC and window. Not working raises a complaint, turns the item red for tenants, and the AC sets the room's existing "AC under repair". Approve layout makes it live. Request a change sheet (text, photo / sketch / voice / more photos tiles, length × width) is saved on the layout as pending; the toast says it reaches the team once the app is online (F13).
- **Hostelzy admin editor** (`aLayout`, one column): breadcrumb, version line, room chips, Mirror and Flip (really change the drawing and the facts), History, the map, shape library, items with counts, the AC unit's properties, beds linked to the bed map ("Has a resident · can't delete"), checks (AC room has an AC unit, beds = sharing, window facing set, no gates/CCTV/exits), the owner's request, and Send to owner for approval (new version, pending).
- **Layout access + real editor (2026-10-02, branch `feature/layout-access`, founder feedback):**
  - Owner: every room card in **Beds** has a visible **Room layout** button (red **Approve layout** when a version waits). **Manage → Layouts** lists every room by floor with its state (Live / Waiting for approval / Change requested / Coming soon) and opens it.
  - **Hostelzy team mode:** **Me → Settings → Hostelzy team** asks for a team passcode (`teamPasscode` in `lib/app_config.dart`, TEMPORARY until F13 adds admin accounts) and opens **Hostelzy team** with Add hostel, Onboarding tracker, Payments check, Fair Play cases and **Layout editor** ("Team tools · sample data until the backend is connected"). Team screens have a back button; "Lock team tools on this phone" locks it again.
  - **Layout editor** (`aLayout`): tap a bed or item (fan, AC, window, door, washroom zone, pillar) to select it (red outline), **drag it on the 1-ft grid** or nudge it with ← ↑ ↓ →; **+ Bed / Fan / AC / Window / Door / Washroom / Pillar**; **Delete** (a bed with a resident can't be deleted; a new bed only for a bed of the room that isn't placed: more beds change the sharing and the price, so the owner confirms first); **Turn** (AC, window and door move to the next wall; washroom and pillar turn 90°); **room size** width / length ±1 ft (things on the far walls stay on them); Mirror ↔ / Flip ↕; **Undo / Redo**; window facing and Working / Not working for the selected item; **bed facts update live** (fan reach, AC airflow from wherever the AC is, window side on any wall). Checks: an AC room needs an AC unit, beds placed = sharing.
  - **Versions:** the first edit of a live layout keeps the published copy for tenants; "Send to owner for approval" makes the new version pending; the owner approves on Beds / Manage → Layouts and only then tenants see it. Working / Not working changes show to tenants at once.
  - Test: `layout access: owner Beds + Manage, team passcode, editor moves a fan, approval`.
- **Extras (2026-10-02, branch `feature/f12-extras`):** **bunk beds**: in the editor, select a bed and tap "Stack as bunk" (the nearest single bed becomes the upper bunk; "Unstack bunk" splits them); a bunk moves as one; the map shows the bed split into Upper / Lower, each tappable; facts and Compare show "Upper bunk" / "Lower bunk" (sample: Nest 42 room 101, D over C). **Copy to same rooms** copies the layout to every room with the same sharing and AC type as new versions for the owner to approve (Mirror ↔ / Flip ↕ for rooms drawn the other way). A resident answering **"No" to "Is the room layout accurate?"** in the 30-day review flags the layout: the editor shows it and Manage → Layouts tags the room "Resident: not accurate". **Every 3 months** owner Today asks "Do your room layouts still match?" (All still correct / Review). Test: `F12 extras: bunk beds, copy to same rooms, resident says not accurate, 3-monthly confirm`.
- **Not built yet:** custom room shapes (L, T, U…), dragging walls (sizes change with ±1 ft buttons), "Copy to rooms" (says so), resident "Is the layout accurate?" and the 3-monthly confirm, alerts for "Tell me when it's ready".
- Test: `room layouts: Room tab, bed facts, compare, locked states, owner approval, admin (F12)`.

