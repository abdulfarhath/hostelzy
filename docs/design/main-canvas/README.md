# Main canvas, full source (v25, 2026-10-18)

Live canvas: https://claude.ai/artifact/WfdWH9dH8f9wxKmjoGgVLU (v24, published by the hub 2026-10-17; the old artifact was deleted). This folder holds **all** of it: `project/canvas.json` and the 472 board files. It also has `shots/`, the map screenshots used by 6 boards (map, map-dark, loc, loc-dark, add-whereFull, where-dark). Those boards point at `/_blob/` asset URLs that died with the artifact.

To bring the canvas back on any account, in one go and with no redrawing:
1. Create a new Design artifact (Artifact quickstart, intent `design`, then publish with the Design `type_url`, title "Hostelzy · Main design").
2. Upload the 6 screenshots in `shots/` as assets. Replace the old `/_blob/…` URLs in those 6 boards with the new ones.
3. Publish `project/canvas.json` plus all `project/*.dc.html` files to the new URL. Use `root` = this folder. At most 255 files per call, so send two calls with `canvas.json` in the last one.
4. Put the new URL in CLAUDE.md, START-HERE.md, BOARD.md and HUB.md.

## v24 (2026-10-17)
Built on v23: the 12 F26 reverts from Build's `f26/integration` and the final F27 ids (SCREENS on `feature/f27-save-food`: overall 179).
- **S18** "See cheapest beds" list is back (‹ Back to the plan). **S16** shows the legend and "See cheapest beds ›".
- **S8 Explore** and the boards that draw it (dark, resident bar, unverified, H1, H44):
  - header "Hyderabad · N beds free now · N verified · M listed"
  - "#1 near you" back, no "Then by price" kicker
  - location on → Distance sort, with H44 showing Distance
- **H1** Filters: main's sheet (For, Room, Budget with Any, Food included), without the Sort by group.
- **S13**: "Talking through Hostelzy keeps your deal and your ₹100 reward." is back under the lock line.
- **S36**: "Confirm hold". **S37**: "Rooms and rates ›".
- **S32** try mode and **H13**: main's wording, with Book a bed / See beds.
- Counts: **179 counted** (+52 variants, +24 dark, +10 not counted, 207 archive), 472 files.

## v25 (2026-10-18): F30 · F29 · F28, founder GO, Design approved
Built on v24. **496 boards, 497 files** (36 new, 12 archive boards moved to git only: the 7 `z-old-*` "old main canvas" boards and the 5 F25 drafts, now in `docs/design/archive/`).
Counted **188** (179 + T34, S92, S93, S94, H48, H49, H50, W9, W10) · variants 74 · dark 29 · not counted 10 · archive 195.

New boards (rows "F30 · F28 (app)", "F29", "F28 web + console" under the F27 row):
- **[T34]** signInWall + dark · [variant of S8] first-visit hint line · [variant of S8] end of list "Can't find your PG? Add it"
- **[S92]** addHostel + dark + partner variant · **[S93]** myAdd + dark + 6 variants (Owner asked · Owner agreed · Verified · Paid · Still waiting · Queued)
- [variant of S79] "Your hostel · Owner asked" row · [variant of S22] ₹200 / ₹20 rows
- [variant of S36] Joining tab · **[H48]** askJoin · **[S94]** joinForm + dark + done variant · **[H49]** joinReview + dark + tick variant + Drive variant · **[H50]** drive + Connected variant + Not available yet variant
- **[W9]** app/list/ + sent variant · **[W10]** poster A4 · [variant of C14] To call · To refresh · Partners · [variant of C15] "added by Ravi (resident)"

Updated in place: H1 (Verified only switch), T4 exploreEmpty ("Add it"), S79 (Add a hostel row), T20 (Add my hostel, tab header), S38 + dark (Call · WhatsApp on paid rows too), S40 (Call · WhatsApp · Notify on every row, Add resident · Ask to join), C14 (segments).

**Web ids:** the specs say W8 `app/list/` and W9 poster, but the canvas already uses W8 for `app/delete-account/` (Design numbered the two web states W3 and W5 on 2026-10-03). To keep one board per id the canvas uses **W9 = app/list/, W10 = poster**. Hub to decide: change the two spec ids, or tell Design to realign web ids to the SCREENS table (W1–W6 pages, states as variants).

Not drawn (not in the hub's list): S39 Manage "Tenant IDs" row, S9 map pins with the Verified switch (screenshot boards), W3/W4 `app/j/` join-token copy (Build's wording), the S94 Drive-camera path and the masking guide (wave 4).
