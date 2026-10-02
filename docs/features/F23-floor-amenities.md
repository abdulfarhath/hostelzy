# F23 · Floor amenities (fridge, washing machine, water purifier…) + layout-first view

**Stage:** Spec ready · founder idea 2026-10-02 · **this feature needs the founder's approval of the
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

## Rules
- Residents: max 20 edits a day per hostel; the owner can mute a resident's edits (same as F19).
- Every change is logged (who, when) and visible to the owner and team.
