# Resume card (read this first, read nothing else until a task needs it)

Goal: continue on a new account with as few tokens as possible. Don't re-read the whole docs/ folder, don't redraw or rebuild anything that already exists.

## Design chat
- Canvases stay where they are (shared to the new account with edit access):
  - Main https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx: v23, 178 counted boards, 472 of 512 files.
  - F26 proposal https://claude.ai/artifact/QXYxc9NdqqtJCarAy2XS7g: v11, reference only.
- Generator scripts and saved boards are on branch `design/f26-merge` (`docs/design/`). Details, only when needed: `docs/handover/design-2026-10-06.md`.
- Next job: **v24**. Revert boards to match Build's reverts (list in the handover, "Pending v24"). Change only those boards and ship them as `docs/design/v24/` (canvas.json + changed boards).
- Rules: one board per SCREENS id, under 512 files, draw only what the spec says.

## Build chat
- State: F26 integration branch `f26/integration` (SCREENS 176 + F27 S90/S91 = 178). Reverting 12 extras (list in the handover, "Pending v24"). F27 Save food is design-approved and not built yet (`docs/features/F27-save-food.md`).
- Read only the feature file for the task and `tools/check.sh` before merging.

## Token rules for every chat
- Read the one file the task needs, not START-HERE / BOARD / DECISIONS in full. Grep `docs/DECISIONS.md` for the topic instead.
- No screenshots or re-render checks unless something looks broken.
- Reply in 3–5 lines. Push, don't re-explain.
