# F23 · Floor amenities (fridge, washing machine, water purifier…) + layout-first view

**Stage:** Design ready · demo for the founder: https://claude.ai/artifact/PjkPGAojZgLXFLWP56yvFf · waiting for the founder’s approval · founder idea 2026-10-02 · **this feature needs the founder's approval of the
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

## Rules
- Residents: max 20 edits a day per hostel; the owner can mute a resident's edits (same as F19).
- Every change is logged (who, when) and visible to the owner and team.
