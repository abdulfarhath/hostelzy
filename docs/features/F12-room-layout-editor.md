# F12 · Room layout editor and room layers (with F11 seat-map booking)

**Stage:** Idea · spec in progress

## Problem
Tenants want to know exactly where their bed is and what's around it (fan, AC, window, washroom)
before visiting. Owners' rooms come in many shapes.

## What it does (phase 1)
- **Owner editor (phone):** pick a room shape from the library (rectangle, L, T, U, angled corner,
  narrow end, alcove), resize by edges, place items on a 1-ft grid: beds, bunk beds (2 beds),
  window, door, fan, AC (with direction), washroom zone, pillar. Undo/redo, draft → publish,
  copy layout to other rooms, mirror/flip.
- **Request a shape:** photo + paper sketch photo + measurements + voice note. Hostelzy draws it on a
  laptop admin editor (target 48 h), owner approves, the shape joins the library. Meanwhile the room
  shows a temporary rectangle "Layout coming soon".
- **Tenant room view = seat map (F11):** tap a bed like a movie seat; layer toggles (fans, AC,
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
  only after a hold (pending founder confirmation, BOARD Q15). Residents' names never shown on plans.
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
Draw custom shape wall by wall, AR measuring, sockets/cupboards/tables/lights/balcony, floor layout
editor, photos pinned to items, bed filters in Explore (window bed, lower bunk), Telugu/Hindi.

## Open questions
BOARD Q13–Q17.

## Design
_Not started (waiting for spec)._

## Build
_Not started._
