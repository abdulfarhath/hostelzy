# F16 · AC / non-AC room types, pricing grid and filter

**Stage:** Built (2026-10-02) · waiting on founder merge

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
Branch `feature/f16-ac-rooms` (from `main`, 2026-10-02), boards 1–5.

**Model.** Each hostel has a rate card in `AppState.rates` (`rateKey(ac, share)` → rent) and each
`Room` has `ac` and `acRepair`; a room's rent always comes from the rate card (`applyRates`), so
bed position and floor no longer change the price (the old floor-3 +₹300 is gone). Sample data:
non-AC prices as before (Anjani 2/3/4 sharing ₹9,800 / ₹8,700 / ₹7,600), AC ₹1,200 more
(Anjani ₹11,000 / ₹9,900, no 4-sharing AC); mixed hostels have AC on floors 2–3 for 2–3 sharing;
Nest 42 is AC only; Sai Sri, Greenview, Orchid, Lakshmi are non-AC. Anjani room 201 is
"AC under repair". I kept the app's existing price levels rather than the mockup's sample
numbers (₹9,000 / ₹7,000 / ₹6,000 · ₹11,000 / ₹8,200) so rents already shown elsewhere (Rahul's
₹7,600, rent list) stay consistent.

**Screens**
1. Explore: AC and Non-AC chips after All; each card shows one line per room type (tag, free
   beds, "from ₹X/mo"), only the filtered line when a filter is on; hostels without that type drop
   out. The bed dots are replaced by these lines, as in the mockup.
2. Search sheet: "Room: Any / AC / Non-AC" between Sharing and Monthly budget; summary and
   "Show N hostels" follow it; budget uses the cheapest room of the chosen type.
3. Hostel page: "Rent by room type" is the sharing × Non-AC / AC grid with free beds per cell,
   "—  Not offered" for missing cells, and the two notes. Single-type hostels show one column.
4. Bed picker: Room chips (only at hostels with both kinds; the Explore filter carries over);
   tiles get an AC / Non-AC tag and fade when they don't match; header "3 sharing · AC · ₹9,900/mo";
   "AC UNIT" on the plan; "AC under repair" note; bottom line repeats type and price; List mode
   follows the filter.
5. Owner: Beds → "Rooms and rent": rate card with walk-in inputs, "Not offered · + Add", room list
   per floor with a Non-AC / AC switch (refuses a type with no price), note about the 48-hour AC
   unit, Save rate card (rents update everywhere).

**Waits for F03 (deals):** the green deal cells / strip on the hostel page and the deal line on the
rate card; the rate card's Hostelzy column shows "Same as walk-in" until deals exist. Board 6
belongs to F03. Residents' room type comes from their room (F06 is a separate PR).

**Design defaults:** rate card lives under Beds; electricity note follows F02 terms (no separate
AC power line).

**Tests:** `test/flows_test.dart` → "AC / non-AC: filter, price grid, picker, owner rate card".
`flutter analyze` clean, `flutter test` 11/11.
