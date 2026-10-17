# Main canvas, full source (v24, 2026-10-17)

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
