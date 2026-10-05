# F26 · Founder's prototype review, round 1 (2026-10-05)

**Stage:** Ideas → **Designing** (proposal canvas, separate from the main canvas until the founder approves).
Source: the founder clicked through the prototype (`docs/PROTOTYPE.md`) and dictated 20 changes. The hub shaped them.
Rules that still apply: one job per screen, no redundant screens, honest copy, Design = app 1:1.

## Decided by the founder already
- **#5 Badge:** one word, **✓ VERIFIED**, navy fill, white text (red outline rejected). Replaces "Visited by Hostelzy".
- **#7 Owner contact:** no contact before a hold. After a hold, **WhatsApp** and **Call** switch on (hostel page + Holds).
  WhatsApp opens with a ready message carrying the HZ code. Both lock again if the hold expires or is declined.
  "Enquire on WhatsApp" is removed. Changes DECISIONS F07 wording ("only after a hold" now means message AND call).

## The 20 changes
| # | Area | Change | Notes for Design |
|---|---|---|---|
| 1 | Tenant search bar | 📍 icon inside the search field → opens the map at my location | Search field keeps its text; icon on the right |
| 2 | Tenant Explore | Chips **Near me** / **Pick a place** + sort **Price ↑** (default) · Distance · Rating | "Pick a place" = area or landmark |
| 3 | Hostel page | Building view (S87) shown inline; "On each floor" list removed | Shared-thing chips sit on each floor row |
| 4 | Hostel page + resident Home | Food menu is always the whole-week table; no "today" card | Same table component everywhere |
| 5 | Hostel page | ✓ VERIFIED badge (navy) next to the name | Replaces "Visited by Hostelzy" |
| 6 | Hostel page + Explore cards | Remove the 4 tag boxes (3 meals, AC rooms, power backup, washing machine) | Nothing replaces them |
| 7 | Hostel page + Holds | Contact locked until hold; then WhatsApp + Call | Lock line: "Message and call the owner after you hold a bed" |
| 8 | Pick a bed | All rooms at once; floor chips only scroll to the floor | No per-floor tabs |
| 9 | Holds | Steps Sent → Owner reviewing → Kept/Declined; red dot on the Holds tab; after 30 min "Still waiting. Call the owner?" | Push on keep/decline already exists |
| 10 | Me | Remove the Saved and Holds rows | They are tabs |
| 11 | Me | Log out in red | — |
| 12 | Room layout (tenant) | "Edit this layout" button → try mode; Publish → "Only residents can publish. Book a bed to join." | F19 try mode exists; add the entry button |
| 13 | Resident | Food tab removed; Home "Full week" expands the week table in place (no Food page) | — |
| 14 | Resident | New **My stay** tab (bed, notice/move, refund, Help inside) | Help screen folds into My stay |
| 15 | Resident | No Holds anywhere | — |
| 16 | Resident/Tenant | Hold result notification (exists) + red dot | — |
| 17 | Resident | **🔍 Find a bed** tab = tenant Explore with a top strip "You're browsing as a tenant · ← My stay" | Nothing about the stay changes |
| 18 | Owner Today | Grouped: Holds (n) · Payments (n) · Enquiries (n) · Fixes (n) tabs with counts; most urgent open first; Fair Play alert pinned on top; empty = "Nothing needs you now" | Replaces the long card list |
| 19 | Owner Beds | Building view only ("Rooms" list removed); tap a bed → bed sheet; tap a room → its layout | Layouts page stays for create/copy |
| 20 | Owner Rent | **Call** + **WhatsApp** buttons replace the 🔔 Remind bell | WhatsApp opens with a ready reminder text |

## Tab bars after the change
- Tenant: Explore · Map · Saved · Holds · Me (unchanged)
- Resident: **Home · Rent · My stay · Find a bed · Me** (was Home · Rent · Food · Help · Me)
- Owner: Today · Beds · Add tenant · Rent · Manage (unchanged)

## Design
Proposal canvas: (Design fills in) · Boards: one per changed screen, before → after where useful, light; dark for the 3 biggest.
After the founder approves: merge into the main canvas, update SCREENS.md (Food page and Help page retire; My stay and Find a bed strip are new), then Build.

## Build
Not started. Prototype first (`docs/PROTOTYPE.md`); `main` only after the founder approves in the prototype.
