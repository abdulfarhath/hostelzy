# v25 publish set

`project/canvas.json` (full index on main canvas v24) + the 44 changed boards. Details, counts and the Design 2 / web-id notes: `docs/design/main-canvas/README.md`, section v25. Publish with `root` = this folder, `file_path` = `project/canvas.json`, plus every other file under `project/`.

## Published 2026-10-18 15:50 UTC (hub) · 461 boards
The artifact's 512-entry cap counts the Design type's own files (~21) and the uploaded assets (6) as well as `project/`,
so the real room for boards is about **480 files**. To fit v25 the hub also took **35 archive boards** off the canvas
(`z-f20-*` 11, `z-f21b-*` 17, `z-f23-*` 7; all `[archive · not counted]`): they stay in git under
`docs/design/main-canvas/project/`. `project/canvas.json` here is the published index: **461 boards, 188 counted**.
Rule from now on: v26+ must not add files net; new boards need an archive board removed first.
