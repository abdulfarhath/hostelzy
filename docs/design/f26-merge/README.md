# F26 merge for the main canvas (prepared, not yet published)

The founder-approved F26 boards, merged into the main canvas
(https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx), ready to publish as one update.
Saved here so the work survives the Design chat's session.

- `project/canvas.json` is the full main-canvas index after the merge. Its base is canvas version 1791042530-a082.
- `project/*.dc.html` holds only the changed and new boards. `z26-*` files are the pre-F26 copies for the archive row.
- `scripts/` holds the generators (`m26.py` runs `f26.py`, which builds on `w1–w4.py`). The paths inside are from the Design session.

To publish: Artifact publish with `url` = the main canvas, `root` = this folder, `file_path` = `project/canvas.json`,
and every other file under `project/` in `files`. If the main canvas changed since its base version, re-read its
`canvas.json` first and merge.

After publishing, the count line follows Build’s final SCREENS totals (Build sends them after the C + E prototype update).


## Follow-up after main canvas v20 (published by the hub without the z26 copies)
`followup/project/` is a fresh `canvas.json` based on main canvas v20 (1791258440-5b24). It adds only the files that changed:
- S87 and H6 come back as main boards (H6 is "Message <name>").
- New: S89 My stay tab, H44 sort, H45 complaint, H46 complaints, H47 claim, C14 Listed, C15 Claims, and a try-mode variant of S32.
- H13 hint icon is a pencil. S12 is titled "Pick a place".
- S28 and T11 are retired.
- Console navigation gains Listed and Claims on every console board.
- 499 files (the limit is 512). Counted boards: 177, matching Build's SCREENS on f26/integration (c96d4ea).
Publish it the same way: `root` = `followup`, `file_path` = `project/canvas.json`, plus every other file under `project/`.
