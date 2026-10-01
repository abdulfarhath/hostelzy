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

**Design questions for the founder**
- Fan and AC "reach" circles are drawn as dashed outlines and stripes. Clear enough on a cheap phone, or show only the fact chips by default with layers off?
- The Room tab comes second (Plan · Room · List · Building). Should Room be the default tab once a room has an approved layout?

## Build
_Not started._
