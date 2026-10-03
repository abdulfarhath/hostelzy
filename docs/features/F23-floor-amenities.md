# F23 · Floor amenities (fridge, washing machine, water purifier…) + layout-first view

**Stage:** **Design approved by the founder, 2026-10-02** ("yes for all", Ideas chat) · demo https://claude.ai/artifact/PjkPGAojZgLXFLWP56yvFf · goes into "Hostelzy · Main design", then Build.
design before building** (founder's explicit exception to the "no approvals" rule).

## Problem
Tenants care a lot about shared things on their floor: is there a fridge, a washing machine, an RO
water purifier? Today that's buried or missing. Exact positions don't matter; "Floor 2 has a fridge"
is enough.

## Who adds them
- **Owner / manager**: add, edit, remove any time (goes live at once).
- **Residents of that hostel**: can add or mark "not working" on any floor (goes live at once, tagged
  "Added by a resident"; the owner gets a note and can correct or remove it).
- Tenants (not staying) only see them.

## The list (icons, tap to add)
Fridge · Washing machine · Water purifier (RO) · Water cooler · Geyser · Microwave · Induction / stove ·
Iron + board · TV · Wi-Fi router · Drying stand · Shoe rack · Lift · Dustbin · **Other (type a name)**.
Each item: count (1, 2, 3…) and status **Working / Not working**. No position on the map.
Not shown (safety, DECISIONS): CCTV, gates, exits.

## Where it shows
- **Hostel page (tenant)**: a short "On each floor" block. One row per floor:
  `Floor 2 · Fridge · Washing machine · RO` with icons; "Not working" items greyed with a small tag.
- **Room layout screen (all roles)**: a slim strip above the room plan: "On this floor: Fridge · RO ·
  Washing machine". Tapping it opens the floor's list.
- **Filters (tenant)**: "Washing machine on the floor", "Fridge on the floor", "RO water".
- **Resident Home**: nothing new on Home; reachable from My room / the layout strip.
- **Owner Manage → Layouts**: per floor "Shared things" list with + Add.
- Broken items feed the existing F19 "Broken → repair" card on owner Today.

## Layout-first view (founder, 2026-10-02)
For **all roles**, the **room layout (plan) is the primary view**; the floor/building overview is a
secondary toggle. Applies to the tenant bed picker, resident "My room", owner Layouts and the team tools.

## Screens to design (small demo first, for founder approval)
1. Tenant hostel page with "On each floor".
2. Room layout (primary) with the "On this floor" strip, plus the floor toggle as secondary.
3. Floor sheet: list of items with counts and status.
4. Add sheet (owner and resident): icon grid → count → Working / Not working → Save.
5. Owner Manage → Layouts → Floor 2 → Shared things.
6. Filters with the 3 new chips.

## Design
**Design ready · 2026-10-02, waiting for the founder’s approval** (demo: https://claude.ai/artifact/PjkPGAojZgLXFLWP56yvFf). Not added to All screens and not handed to Build until the founder approves in the Design chat.
1. **Hostel page** (`Main`, `DetailDark`): an "On each floor" block, one row per floor with icon chips (Lift, Fridge, RO water, Washing machine, Geyser ×2…). A broken item is struck through and grey with a red "NOT WORKING" tag. Header note: "Updated by residents · 1 Oct".
2. **Room plan first** (`Room`): room chips 203 / 204 / 205, with **Floor view** as an outlined secondary button. A slim grey **On floor 2** strip of icon chips sits above the plan; tapping it opens the floor sheet.
3. **Floor sheet** (`Floor`): rows with icon, count (×2), note and a Working / Not working tag ("Added by a resident · 1 Oct · owner told"), plus Add a thing / Something broke.
4. **Add sheet** (`Add`): ① a 5-column icon grid of 15 items (Other last), ② a − 1 + stepper, ③ a Working / Not working seg, then Save ("Save · Washing machine on floor 2").
5. **Owner** (`Owner`): Floor 2 with seg Rooms | Shared things, floor chips, a "A resident changed this floor" banner, rows with who/when and an edit button, "Add a shared thing", and a note that broken things go to Today as a repair.
6. **Filters** (`Filters`): "On the floor" chips with icons: Washing machine, Fridge, RO water.
**Room-level items (added 2026-10-02):**
- The add sheet has a **Where?** step: `On the floor` · `In room washroom` (picked for Geyser) · `In the room`, then room chips 201…206 plus "All rooms on this floor"; Save reads "Geyser in 4 room washrooms".
- The hostel page shows "Geyser in 4 of 6 rooms" in the floor row.
- On the room plan, the washroom block shows a geyser icon with "WASHROOM · GEYSER", and the bed card says "Geyser in washroom". The "On floor 2" strip keeps only shared items.
- The floor sheet and owner list show the geyser as "in the room washroom of 201, 202, 204, 205".
- Filters add "Geyser in my washroom".

## Room-level items: geyser in the washroom (founder, 2026-10-02)
Some things live **inside a room**, not on the floor. Most common: a **geyser in the room's attached
washroom**. So every item has a **where**: *On the floor* (shared) or *In room washroom / In room*.
- Add sheet: after picking the icon, one more row **Where?** → `On the floor` · `In room washroom`
  (default for Geyser) · `In the room`. Picking a room option shows room chips (201, 202… or
  "All rooms on this floor").
- Tenant hostel page, floor row: `Floor 2 · Fridge · Washing machine · RO · Geyser in 4 of 6 rooms`.
- Room plan: the washroom block gets a small geyser icon + "Geyser" label; the room card / bed sheet
  says "🚿 Geyser in washroom".
- Filter: "Geyser in my washroom" (rooms with attached washroom + geyser).
- Not working works the same (greyed + repair card).

## Main design canvas
After approval, F23 goes into the main canvas, renamed **"Hostelzy · Main design"** (same URL as
"All screens": https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx).

**Done 2026-10-02 (Main design v20).** The founder confirmed in the Design chat ("approve all"). The row
"F23 · Floor amenities, room plan first · built in #75" has 8 boards: hostel page "On each floor" (light
and dark), room plan first with the "On floor 2" strip, "Floor view" and WASHROOM · GEYSER, the floor
sheet, the add sheet, owner Layouts → Shared things, filters, and a new **owner Today** board ("Broken:
Washing machine, floor 2 · Marked by a resident" with one **Fixed** button, as built).

## Rules
- Residents: max 20 edits a day per hostel; the owner can mute a resident's edits (same as F19).
- Every change is logged (who, when) and visible to the owner and team.

## Build
**Built 2026-10-02** (merged, #75). Server: `supabase/migrations/20261002220000_f23_amenities.sql` (FOUNDER-TODO **4u**).
- **Data:** `amenities` (hostel, floor, kind, name for "Other", count, working, place = floor / room washroom / room, rooms) and `amenity_log` (who changed what, when; staff and team only). No names in `amenities`, so tenants never see who added something.
- **Who can change it:** owners, managers and the team (staff), and residents with a confirmed stay in that hostel. Residents: at most 20 changes a day; residents muted in F19 can't; the owner gets a push for every resident change. Everything goes through `save_amenity` / `remove_amenity`. SQL tests: `supabase/tests/amenities_test.sql`.
- **Hostel page:** "On each floor", one row per floor with icon chips; broken things struck through with NOT WORKING; room items read "Geyser in 2 of 4 rooms"; "Updated by residents · date" when a resident changed something. A row opens the floor sheet.
- **Room plan first (all roles):** the bed picker opens on the room plan (room chips for the floor, "Floor view" one tap away) when you're signed in and the room has a layout; guests and rooms without a layout start on the floor view. Above the plan, "On floor N" shows the shared things; the washroom says "WASHROOM · GEYSER" and the bed card "Geyser in washroom".
- **Floor sheet:** each thing with count, where and status ("Added by a resident · date · owner told"); Add a thing / Something broke (tap what isn't working) for staff and the hostel's residents; tenants only see it.
- **Add sheet:** 15 kinds (Other with a name), Where? (On the floor · In room washroom · In the room, with room chips and "All rooms on this floor"; a geyser starts in the washrooms of rooms with an attached bath), How many, Working / Not working, "Save · Geyser in 2 room washrooms". Change and Remove from the same sheet.
- **Owner:** Manage → Room layouts has Rooms | Shared things; floor chips, "A resident changed this floor" banner, a change button per thing, Add a shared thing. Broken things show on Today as "Broken: Washing machine, floor 2" with **Fixed**.
- **Filters:** "On the floor": Washing machine, Fridge, RO water (working ones), Geyser in my washroom.
- **Before 4u runs:** hostels still load (the app retries without the amenities list); lists stay empty and saving says it couldn't.
- Not built from the spec: a free-text position ("near the stairs"), because the spec says positions don't matter; the owner sees "a resident", not the name (the name is in the log for the team).
- Tests: `test/amenities_test.dart` (6 flows + 2× text); older picker tests use the floor view.
