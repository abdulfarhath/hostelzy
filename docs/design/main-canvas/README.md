# Main canvas, full source (v23, 2026-10-06)

The canvas artifact was deleted. This folder holds **all** of it: `project/canvas.json` and the 472 board files. It also has `shots/`, the map screenshots used by 6 boards (map, map-dark, loc, loc-dark, add-whereFull, where-dark). Those boards point at `/_blob/` asset URLs that died with the artifact.

To bring the canvas back on any account, in one go and with no redrawing:
1. Create a new Design artifact (Artifact quickstart, intent `design`, then publish with the Design `type_url`, title "Hostelzy · Main design").
2. Upload the 6 screenshots in `shots/` as assets. Replace the old `/_blob/…` URLs in those 6 boards with the new ones.
3. Publish `project/canvas.json` plus all `project/*.dc.html` files to the new URL. Use `root` = this folder. At most 255 files per call, so send two calls with `canvas.json` in the last one.
4. Put the new URL in CLAUDE.md, START-HERE.md, BOARD.md and HUB.md.
