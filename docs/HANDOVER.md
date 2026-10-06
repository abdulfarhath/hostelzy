# Handover to a new Claude account (2026-10-06)

The founder is moving Hostelzy to a new Claude account (the second move; the first was 2026-10-05).
**Everything that matters is in this repo.** Chats on the old account can't be reached from the new one, and
artifacts (pages) belong to the account that made them. Read this file, then `START-HERE.md`, `CLAUDE.md`,
`DECISIONS.md` ("Current rules" first) and `BOARD.md`.

## 1. Where things stand
| Area | State |
|---|---|
| `main` | F01–F25 built and merged. Newest APK: the latest `apk-N` release |
| **F26** (21 UX changes, founder review) | Built on branch **`f26/integration`** (+ PRs #121 B picker, #122 A tenant, #123 D owner, #124 C resident, #125 E holds+listings). **Not merged**: the founder has not approved the prototype yet |
| **F26 reverts (NOT started at the move)** | The founder found 12 changes Build made without being asked. **None reverted yet**: `f26/integration` @ 22517ec = green build bc66a72 (prototype v4) + Build's note. Full asked-vs-built list: `docs/F26-CHANGE-LIST.md`. List: `features/F26-founder-review-1.md` → "Not in the spec". Build's progress note: `docs/handover/build-2026-10-06.md` on `f26/integration` |
| AC / non-AC prices | No per-hostel price changed. What changed is the order: default sort Price ↑ (was Recommended) + a pinned Featured card, so a different hostel's price shows first. Still to check: picker per-room rent, hostel-page rent table, bestQuote. **Ask the founder for a screenshot** |
| **F27 Save food** | Founder approved the design 2026-10-06. Build started on **`feature/f27-save-food`** @ 0c3db81 ("WIP", ~2,500 lines, checks not run; rebase after the reverts). New screens S90 Week plan, S91 Owner Meals. SQL step 4zf27 |
| Design ↔ app | Main canvas **v23**: 178 counted boards = F26 + F27. After the reverts: S18 "See cheapest beds" returns and a few boards change (Design's v24, not done). Design's note: `docs/handover/design-2026-10-06.md` on `design/f26-merge` |
| **Working method** | **Prototype first** (`PROTOTYPE.md`). And the new rule in `CLAUDE.md`: **only what the spec says**, extras need the hub's OK first |
| Database | All pending SQL is in **one file**: `docs/sql/run-all-pending.sql` (rerun-safe). F26 adds 4zo1 + 4ze26 and F27 adds 4zf27 on their branches; they join the file on `main` when merged |

## 2. Branches that matter
| Branch | What | Next |
|---|---|---|
| `main` | Released app + all docs | — |
| `f26/integration` | F26 combined + the 12 reverts | Finish reverts → `tools/check.sh` → republish prototype → founder approves → merge to `main` |
| `feature/f27-save-food` | F27 Save food | Rebase on reverted F26 → build → prototype |
| `design/f26-merge` | Design's canvas merges: `docs/design/f26-merge/`, `v22/`, `v23/` (each a `project/canvas.json` + changed boards) | v24 after the reverts |
| `claude/hostelzy-app-review-ca51b6` | Old hub's docs branch (all merged) | Can be deleted |

## 3. Waiting on the founder
| # | Task | Where the steps are |
|---|---|---|
| 1 | Review the F26 prototype after the reverts; approve or send notes | `PROTOTYPE.md` |
| 2 | Screenshot of the AC / non-AC price that looked wrong | — |
| 3 | Run `docs/sql/run-all-pending.sql` in Supabase + the check query (re-run after F26/F27 merge) | `sql/README.md`, `pages/setup-steps.html` (S1) |
| 4 | Fix demo-app sign-in (Google Cloud key: add `app.hostelzy.hostelzy.demo`) | setup steps F1 |
| 5 | Map screenshots from the phone (cloud blocks map tiles) | — |
| 6 | Finance questions, Play Console, upload key, hostelzy.in, MapTiler key, 12 testers × 14 days | `finance/plan.md` §0, setup steps |
| 7 | **Share the old artifacts** (Share → anyone with the link) before leaving the old account, so the new one can read and re-home them: main canvas, F26 proposal canvas, prototype, setup steps | §4 |

## 4. Restart the team on the new account
1. **GitHub:** in the new Claude account, connect GitHub (Settings → Connectors) with the founder's GitHub user so it reaches `abdulfarhath/hostelzy`.
2. **Cloud environment:** default network is enough. Optional: allow `tile.openstreetmap.org` for real map screenshots.
3. Start one Claude Code session on the repo called **"Hostelzy · Hub"** and paste the message in §7.
4. The hub creates **Build** and **Design** only (save the weekly limit) with `create_session`, records the IDs in `HUB.md`,
   and hands them their handover notes (§1).
5. **Pages to republish** (old links stay readable only if the founder shared them):
   | Page | Source | Old link |
   |---|---|---|
   | **Design canvas (main)** | Design reads the old canvas (`Artifact read`, scope `files`) or rebuilds from `design/f26-merge` folders | 6n9U2zJw3jri1SeAUz1gCx (v23) |
   | F26 proposal canvas (F26 + F27 boards) | Read and republish | QXYxc9NdqqtJCarAy2XS7g (v11) |
   | Prototype | `tools/prototype.sh` on `f26/integration` → `build/prototype/` + `docs/prototype/index.html` | EztxM6k1kud7ivGoG6K6iP (v4) |
   | Setup steps | `pages/setup-steps.html` | N2k3RxnvPqFTxLrAtZXYbx |
   | Launch steps | `pages/launch-steps.html` | WMb8J3gN6c8MGgRK2ycDhg |
   | Gap audit / missing screens / lost building / at a glance | `pages/*.html` | M4uyX…, 9xtrs…, LfM32…, LrqaB… |
   | Brand guide | Brand rebuilds from `docs/brand/` | 29kRWoLpWYYvW9AGuC2jSi |
   After republishing, update the links in `CLAUDE.md`, `START-HERE.md`, `BOARD.md` and this file.

## 5. Gotchas we already hit (don't repeat them)
| Gotcha | Fix |
|---|---|
| **Build changed things nobody asked for** (F26: 12 extras) | Rule in `CLAUDE.md`: only what the spec says; extras listed and OK'd first. The hub audits every feature diff against its spec before showing the founder |
| Artifacts belong to one account | Read and republish, then update the links |
| A child chat's Artifact publish needs the founder's approval in that chat; Design may refuse relayed approvals | Design pushes a `canvas.json` + changed boards to a branch; the hub publishes from the repo |
| Canvas artifact holds at most **512 files** | Old copies stay in the branch only (z26-*, the 32 z-h0 stubs were dropped). Check the count before publishing |
| Publish to an artifact needs a fresh read of it in that session | `Artifact read` (path `project/canvas.json`) first |
| Prototype artifacts: no service worker, no CDN, web file types only | `tools/prototype.sh` strips them |
| `owner_contacts` changed return type | The bundle drops it first; keep every migration rerun-safe |
| Site root `index.html` = founder's old prototype | Never touch it |
| Making the repo private on the free plan turns off GitHub Pages | Only with GitHub Pro or after moving the pages |
| Play Store installs need Play's signing SHA in Firebase | Setup steps F2 |
| All chats share one weekly limit | Run only the chats needed; pause check-ins when idle |

## 6. How the founder likes to work
- One hub chat. Answers are **visual and tabular**, ADHD-friendly: next action first, short rows, colour = meaning.
- "Take your own decisions", but money amounts, accounts and keys stay with the founder.
- **Change only what the founder said.** Prototype first; no surprise APKs. APK links are the GitHub release page.
- Design = app 1:1, no duplicate screens, every screen has one job, nothing discussed gets lost.
- Green `#1f7a3d` marks money saved (deals, Hostelzy price, ₹100 reward) and a confirmed Paid. Red `#ec3013` is the only action colour.

## 7. First message to paste into the new hub
```
You are the Hostelzy hub (founder's single chat). Read docs/HANDOVER.md, then docs/START-HERE.md,
CLAUDE.md, docs/DECISIONS.md ("Current rules" first), docs/BOARD.md and docs/features/F26-founder-review-1.md.
Then: 1) create Build and Design chats with create_session, record them in docs/HUB.md, and give each its
handover note (docs/handover/build-2026-10-06.md on f26/integration, docs/handover/design-2026-10-06.md on
design/f26-merge); 2) Build finishes the 12 F26 reverts, reports the AC/non-AC price check, and republishes
the prototype on this account; 3) Design re-homes the main canvas (v23) and the F26 proposal canvas;
4) update the links in the docs and merge. Change only what I ask for.
Reply to me with one table: what you set up, the new links, and my next 3 actions.
Always answer me in short visual tables.
```
