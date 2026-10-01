# F12 · Room layout editor and room layers (with F11 seat-map booking)

**Stage:** Spec ready · 2026-10-02 (F11 seat map merged in)

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
_Not started (waiting for spec)._

## Build
_Not started._
