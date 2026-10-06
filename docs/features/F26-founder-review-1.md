# F26 · Founder's prototype review, round 1 (2026-10-05)

**Stage:** Ideas → **Designing** → proposal ready for the founder (2026-10-05; proposal canvas, separate from the main canvas until the founder approves).
Source: the founder clicked through the prototype (`docs/PROTOTYPE.md`) and dictated 20 changes. The hub shaped them.
Rules that still apply: one job per screen, no redundant screens, honest copy, Design = app 1:1.

## Decided by the founder already
- **#5 Badge:** one word, **✓ VERIFIED**, navy fill, white text (red outline rejected). Replaces "Visited by Hostelzy".
- **#7 Owner contact:** no contact before a hold. After a hold, **WhatsApp** and **Call** switch on (hostel page + Holds).
  WhatsApp opens with a ready message carrying the HZ code. Both lock again if the hold expires or is declined.
  "Enquire on WhatsApp" is removed. Changes DECISIONS F07 wording ("only after a hold" now means message AND call).

## Hub decisions on Build's review (2026-10-05, on the founder's delegation)
| # | Clash | Decision |
|---|---|---|
| 7 | Contact-after-hold removes the enquiry flow (F05) | **Enquiries removed.** Reply-speed ranking and the 60-day matching use holds. Owner Today has 3 groups (Holds · Payments · Fixes). `owner_contacts` → hold or stay only, and it locks again when a hold expires or is declined. DECISIONS updated after approval |
| 2 | Price sort hides the paid featured spot (F10) | Price ↑ default; **one featured hostel pinned on top with a "Featured" tag**; "Best deals" stays in the sort list |
| 5 | "VERIFIED" is a strong claim | Only when `visited_on` is set; one line under it: "Beds and prices checked by Hostelzy · <date>". Navy `Pal` token (light #1f3a5f, dark #33598a) |
| 3, 8 | Women's PGs: whole floor only after a hold | **Overruled by the founder 2026-10-05: no lock for anyone.** Layouts and the building view are open to all. 80+ beds: inline building collapses to "See all N rooms ›" |
| 12 | Residents send fixes, they don't publish | "Only residents can send a fix. Book a bed to join." |
| 9 | "Owner reviewing" must be true | New `holds.seen_at`, set when the owner opens the hold (SQL, bundle step). Steps: Sent → Owner reviewing → Kept / Declined |
| 15 vs 17 | Can a resident hold a bed elsewhere from Find a bed? | **Founder 2026-10-06: A, yes.** Find a bed = full tenant app; holds show under the tenant Holds tab |

Build estimate: ~53 h, 3–4 PRs (tenant · resident · owner · holds + contact). SQL: #7 (`owner_contacts`), #9 (`seen_at`).

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

## Round 2 (founder, 2026-10-06): changes to the proposal, to design first
| # | Change | Detail |
|---|---|---|
| 1, 2 | Simpler filter row | Search field with 📍 inside. One row under it: **[📍 Near me ✓] [Price ↑ ▾] [Filters ·n]**. Near me tapped again → Pick a place. Men / Women / Co-living / AC / Food move inside Filters. Sort dropdown: Price ↑ · Distance · Rating · Best deals |
| 21 | **UNVERIFIED listings** (new) | The team lists every hostel in an area first: photos, name, area, expected rent range ("Around ₹7,000–9,000 · expected, not confirmed"), no layouts. Badge **UNVERIFIED** grey outline (same spot as ✓ VERIFIED navy). No beds, holds or owner contact. Buttons: **Tell me when verified** (push when live), **Ask Hostelzy** (WhatsApp to support, hostel pre-filled), **Are you the owner? Claim this hostel ›**. Explore header "Madhapur · 12 verified · 84 listed". Verified first inside each price band. **Founder 2026-10-06: yes.** DECISIONS updated (two listing tiers) |
| 8 | Pick a bed without Plan / Room / Building tabs | Floor chips on top as a filter; below, every room's **drawn layout** (beds, fan, AC, window, door, washroom) in a scroll; the floor chips jump. Building view stays on the hostel page. **Edit this layout** button in **orange** (new Pal token: "try / play") |
| 4, 13 | Week table always open | No Today / Full week toggle anywhere; the 7-day table with today's row highlighted, on the hostel page and resident Home |
| 17 | Find a bed = the full tenant app | No "browsing as a tenant" strip. Tapping Find a bed switches to the tenant tab bar (Explore · Map · Saved · Holds · Me). Back via Me → "My stay ›" on top. Implies **A**: residents can hold a bed elsewhere |
| 20 | Owner Rent colours | **Paid** green, **Late** red, **Due** plain; Call + WhatsApp |

## Round 3 (founder, 2026-10-06): two fixes, then approved
| # | Fix |
|---|---|
| 8, 12 | **Edit this layout** is the app's primary red (#ec3013), not orange. The orange `or`/`oi` tokens are dropped |
| 17 | Resident inside Find a bed gets this tenant bar: **Explore · Map · Saved & Holds · My stay · Me**. Saved and Holds merge into one tab (two segments inside). **My stay** returns to the resident app. A plain tenant keeps Explore · Map · Saved · Holds · Me |

Everything else on the proposal canvas (v9) is approved as drawn. Paid in green is approved (DECISIONS: green also marks a confirmed payment).

## Tab bars after the change
- Tenant: Explore · Map · Saved · Holds · Me (unchanged)
- Resident: **Home · Rent · My stay · Find a bed · Me** (was Home · Rent · Food · Help · Me)
- Resident inside Find a bed: **Explore · Map · Saved & Holds · My stay · Me**
- Owner: Today · Beds · Add tenant · Rent · Manage (unchanged)

## Design
Proposal canvas: **Hostelzy · F26 proposal** https://claude.ai/artifact/QXYxc9NdqqtJCarAy2XS7g (Design, 2026-10-05).
It is **private until the founder shares it** (Share menu → anyone with the link). Design can't change sharing.
20 boards: 1 cover (the 21 changes → board) + 16 light + 3 dark. Canvas version 10 (2026-10-06): approved by the founder with round 3 (red Edit button; resident Find a bed bar Explore · Map · Saved & Holds · My stay · Me). Each shows **before** (the app now) next to **after**.

| Board | Changes | Shows |
|---|---|---|
| Cover | all | The 20 changes → board, tag legend, VERIFIED badge colour |
| [F26 #1 #2] Explore | 1, 2 | Pin inside the search field · one row **Near me ✓ · Price ↑ ▾ · Filters · n** · Filters sheet (Men / Women / Co-living / AC / Food / Rent) · header "Madhapur · 12 verified · 84 listed" · one Featured (80+ beds) on top |
| [F26 #21] UNVERIFIED listings | 21 | Explore card + hostel page: UNVERIFIED grey outline badge, "Around ₹7,000–9,000 · expected, not confirmed", no beds/holds/contact, Tell me when verified · Ask Hostelzy · Claim this hostel ›; both badges side by side |
| [F26 #3–#7] Hostel page | 3, 4, 5, 6, 7 | Top + scrolled, before → after: ✓ VERIFIED (navy `#1f3a5f`) only after a team visit, with "Beds and prices checked by Hostelzy · 12 Sep", inline Building view, week table, tag boxes gone, contact locked |
| [F26 #3–#7] Hostel page [dark] | 3–7 | After, dark (badge `#33598a` in dark) |
| [F26 #7] Owner contact | 7 | Locked (lock line, both buttons off) → unlocked (number, WhatsApp with HZ code, Call) |
| [F26 #8] Pick a bed | 8 | No Plan / Room / Building tabs. Floor chips filter and jump; every room's drawn layout (beds, fan, AC, window, door, washroom) in one scroll; **Edit this layout** in red |
| [F26 #3] Hostel page, 80+ beds | 3 | The inline building collapses to "See all 38 rooms ›". No lock anywhere: layouts, building view and bed picker are open to everyone, women's PGs included |
| [F26 #7 #9 #16] Holds | 7, 9, 16 | Steps Sent → Owner reviewing → Kept/Declined; 30-min "Still waiting. Call the owner?"; WhatsApp + Call; red dot |
| [F26 #10 #11] Me | 10, 11 | Saved and Holds rows gone; Log out in red |
| [F26 #12] Room layout | 12 | "Edit this layout" → try mode → Publish: "Only residents can send a fix. Book a bed to join." |
| [F26 #13–#17] Tab bars | 13–17 | Tenant (red dot on Holds), resident before/after, owner |
| [F26 #4 #13] Resident Home | 4, 13 | 7-day week table always open, today highlighted, no toggle; new tab bar |
| [F26 #4 #13] Resident Home [dark] | 4, 13 | After, dark |
| [F26 #14] My stay tab | 14 | Bed, move, notice, refund, review, layout fix, then Help (Help page folds in) |
| [F26 #17] Find a bed | 17 | Resident tab bar → Find a bed → tenant app with the bar Explore · Map · **Saved & Holds** (one tab, two segments) · **My stay** (back) · Me |
| [F26 #18] Owner Today | 18 | Holds · Payments · Fixes with counts (Enquiries removed everywhere), Fair Play pinned, empty "Nothing needs you now" |
| [F26 #18] Owner Today [dark] | 18 | After, dark |
| [F26 #19] Owner Beds | 19 | Building view only; tap bed → bed sheet, room → layout; Layouts › stays |
| [F26 #20] Owner Rent | 20 | **Paid** green, **Late** red, **Due** plain; Call + WhatsApp replace the bell; ready reminder text |

**Edit this layout** uses the primary red `#ec3013` (founder round 3; no new Pal token).
Also used on the canvas: VERIFIED navy `#1f3a5f` (dark `#33598a`), white text. UNVERIFIED = 2px outline in `mu`, text `mu`.
Note: Paid in green is the founder's round-2 call. It widens the "green only for savings and deals" design rule to Paid.

Design notes (for the founder's review):
- **#6** Explore cards have no tag boxes today; only the hostel page had them.
- **#16** For residents there are no holds (#15), so the red dot is tenant-only.
- Resident tab bar: Rent is a plain tab now (it was the red "Pay rent" centre tab). Rent on Home keeps its red Pay button.
- Owner Today keeps the app's Confirm / Decline wording on holds; the tenant sees Kept / Declined.
- Menu dinners on the boards are sample text.

After the founder approves: merge into the main canvas, update SCREENS.md (Food page and Help page retire; My stay and Find a bed strip are new), then Build.
After the founder approves: merge into the main canvas, update SCREENS.md (Food page and Help page retire; My stay and Find a bed strip are new), then Build.

## Main canvas
F26 merge published by the hub on 2026-10-06 (canvas version 20, Design's prepared merge from `design/f26-merge`). Because the canvas has a 512-file limit, the 19 pre-F26 copies (`z26-*`) are kept only in that branch, not on the canvas.

## Build
Prototype v4 has all 21 items + open layouts (branch `f26/integration`, PRs #121–#125). `main` only after the founder approves in the prototype.

### Not in the spec (hub audit of the diff, 2026-10-06): reverted
The founder: "I only wanted the changes I said." Build also changed these; all are being reverted on `f26/integration`:
| # | Screen | Unrequested change |
|---|---|---|
| 1 | Pick a bed | "See cheapest beds ›" list removed (S18 returns) |
| 2 | Filters | New "No food" chip |
| 3 | Filters | "Any" rent option dropped, chip order changed, "For" → "Who" |
| 4 | Explore cards | "#1 near you" gone; "Then by price…" kicker and "Lowest price" / "Nearest" tags added |
| 5 | Explore header | "N beds free now" replaced by "verified · listed" (now both) |
| 6 | Hostel page | "Talking through Hostelzy keeps your deal and your ₹100 reward." line removed |
| 7 | Resident Home | "How was breakfast?" card moved in from the retired Food page |
| 8 | Owner Today | The 3 bottom cards folded into the tabs |
| 9 | Owner Today | "Confirm hold" → "Confirm" |
| 10 | Owner Beds | "Rooms and rates ›" link removed |
| 11 | Try mode | Wording rewritten |
| 12 | Explore | Location on no longer switches the sort |

Checked and unchanged: AC / non-AC rent table, card prices, picker room lines, sample prices; every green use (deals, Hostelzy price, ₹100 reward, Paid).
Side-effects the spec forces (kept): enquiries retired (#7), meal reminders open Home (#13), Help as sheets and refund row in My stay (#14), Rooms list gone (#19), rank counts verified only (#21).
