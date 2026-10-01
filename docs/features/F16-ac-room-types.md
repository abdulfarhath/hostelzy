# F16 · AC / non-AC room types, pricing grid and filter

**Stage:** Design approved (founder, 2026-10-02)

## Problem
One hostel often has both AC and non-AC rooms at different prices. The app has a single hostel-level
"AC" flag and one price per sharing type.

## What it does
- **Pricing grid per hostel:** sharing (2/3/4…) × AC / non-AC. Owner fills only the cells that exist.
  Bed position never changes the price.
- **Explore:** AC and Non-AC filter chips. Hostel card shows "AC from ₹X · Non-AC from ₹Y" (or one, if only one kind).
- **Search sheet:** new row "Room: Any / AC / Non-AC".
- **Hostel page:** "Rent by room type" becomes the sharing × AC grid with free beds per cell.
- **Bed picker:** AC label on room tiles; room header "3 sharing · AC · ₹8,200"; AC filter within the hostel.
- **Owner:** rate card per cell (walk-in vs Hostelzy price); each room marked AC or non-AC.
- **Deals (F03):** a deal can target all rooms, AC only, or non-AC only.
- **Residents:** room type stored, so rent, swap price differences and reports know it.

## Rules
- A room marked AC must have an AC unit in its layout (F12).
- AC "not working" keeps the room type; tenant sees "AC under repair" and a complaint is raised.
- Any separate AC electricity charge is listed separately from the room fee (see BOARD Q6).

## Open questions
- Does any hostel charge AC electricity separately? (ties to BOARD Q6)

## Design
Canvas https://claude.ai/artifact/1orwCNMz68vVRrMhfqtpKV. Awaiting founder approval. Sample hostel: Anjani Residency. Non-AC 2/3/4 sharing ₹9,000 / ₹7,000 / ₹6,000; AC 2/3 sharing ₹11,000 / ₹8,200; no 4-sharing AC room.

1. **Explore.** New "AC" and "Non-AC" chips after "All". Each card shows one line per room type: `AC` tag, free beds, "from ₹8,200/mo"; a second line for `Non-AC`. Hostels with only one kind show one line. With a filter on, only that line shows and non-matching hostels drop out. Interactive.
2. **Search sheet.** New "Room: Any / AC / Non-AC" row between Sharing and Monthly budget. The "Show N hostels" count follows it. Interactive.
3. **Hostel page.** "Rent by room type" is now a grid: rows 2/3/4 sharing, columns Non-AC / AC. Each cell shows the price and free beds. A missing type shows "— Not offered". Notes underneath: "Every bed in a room type costs the same" and "Electricity extra, by the room's meter". Cells covered by the Hostelzy deal turn green with the walk-in price struck through, plus a green "Hostelzy deal: ₹200 off every month · all rooms" strip. Tweak "Deal": All rooms / AC only / Non-AC only / No deal.
4. **Bed picker.** "Room: Any / AC / Non-AC" chips above the floors. Room tiles carry an AC / Non-AC tag; tiles that don't match the filter fade out. The room header reads "3 sharing · AC · ₹8,200/mo"; the plan shows the AC unit; the hold button repeats the price. Room 201 shows the "AC under repair" note. Interactive.
5. **Owner: Rooms and rent** (from the Beds tab). Rate card: one row per sharing × AC/Non-AC with the walk-in price input and the Hostelzy price next to it (green when a deal applies). "Not offered · + Add" for a missing type. Green deal line: "₹200 off every month · all rooms · Change". Room list with a Non-AC / AC switch per room, and a note that the Hostelzy team adds the AC unit to the layout within 48 hours. Save rate card. Interactive.
6. **F03 deal per room type.** The F03 deal table is unchanged, with a "Non-AC · 3 sharing / AC · 3 sharing" switch above it. If the deal doesn't cover the chosen type: "No Hostelzy deal on non-AC rooms. You pay the walk-in price here." plus a link to the covered type. Tweak "Deal" (default AC only).
- Dark mode: boards "1 in dark mode" and "3 in dark mode". Every board has a Dark tweak.

**Design questions for the founder**
- AC electricity: the grid says "Electricity extra, by the room's meter" for all rooms (DECISIONS 2026-10-02). If some hostels charge AC electricity separately, add an "AC power" line under the grid?
- Rate card lives under the Beds tab ("Rooms and rent"). OK, or in Manage?
- Deals target is shown read-only on the rate card ("Change" opens the F03 deal picker); the F03 picker itself is not redesigned.

## Build
_Not started._
