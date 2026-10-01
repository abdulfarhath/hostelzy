# F16 · AC / non-AC room types, pricing grid and filter

**Stage:** Spec ready

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
Needs mockups: Explore chips + card price line, search sheet row, hostel page grid, bed picker labels, owner rate card.

## Build
_Not started._
