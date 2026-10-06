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

After publishing, the count line is **App 170 · Canvas 170 (+49 variants, +24 dark, +9 not counted) · +258 archive**
(once Build's SCREENS PR lands with 179 − 12 + 3).
