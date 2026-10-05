# Handover to a new Claude account (2026-10-05)

The founder is moving Hostelzy to a new Claude account. **Everything that matters is in this repo.**
Chats on the old account can't be reached from the new one, and artifacts (pages) belong to the account
that made them. Read this file, then `START-HERE.md`, `CLAUDE.md`, `DECISIONS.md` ("Current rules" first) and `BOARD.md`.

## 1. Where things stand
| Area | State |
|---|---|
| App | F01–F25 built and merged. Newest APK: the latest `apk-N` release (apk-103 on 2026-10-05). 331 Flutter tests, 38 SQL test files, green |
| Design ↔ app | **App 179 · Canvas 179** (`SCREENS.md`). Canvas: https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx (shared "anyone with the link", read-only for a new account) |
| **Working method** | **Prototype first** (`PROTOTYPE.md`): the founder reviews changes in the clickable web prototype, and changes reach `main` (and an APK) only after the founder approves |
| Prototype | https://claude.ai/artifact/EztxM6k1kud7ivGoG6K6iP (old account). Rebuild with `tools/prototype.sh` + `docs/prototype/index.html` and publish on the new account |
| Database | All SQL the founder still has to run is in **one file**: `docs/sql/run-all-pending.sql` (rerun-safe, tested). New migrations: `tools/sql-bundle.sh` |
| Code | Cleaned and split by feature (`ARCHITECTURE.md`). `tools/check.sh` runs every check; `.claude/` SessionStart hook installs Flutter 3.47.5 |
| Money | Finance **Budget v3** (2026-10-04): ₹10k/month lean plan, founder pays Play Console + Supabase Pro. See `finance/plan.md` |
| Marketing / Brand | Launch plan, pitch, reels, posters, Play Store pack, brand guide: `marketing/`, `brand/` |

## 2. Waiting on the founder (nothing else is blocked)
| # | Task | Where the steps are |
|---|---|---|
| 1 | Run `docs/sql/run-all-pending.sql` in Supabase + the check query | `sql/README.md`, page `pages/setup-steps.html` (S1) |
| 2 | Fix demo-app sign-in (Google Cloud key: add `app.hostelzy.hostelzy.demo`) | setup steps F1 |
| 3 | Click through the prototype and send change notes | `PROTOTYPE.md` |
| 4 | Map screenshots from the phone (the design's map has no streets; this cloud blocks map tiles) | Design puts them on the map boards |
| 5 | Share 3 old-account artifacts so Design can archive them: F12 `8uEkfu5EzRsDeZrkb8Gjaz`, F16 `1orwCNMz68vVRrMhfqtpKV`, design book `VV4W8tvmbEGf7YnX66ZUJB` | — |
| 6 | Finance questions (`finance/plan.md` §0), Play Console, upload key, hostelzy.in, MapTiler key, 12 testers × 14 days | setup steps G1, P1, G2, F2, P2 |
| 7 | Telugu check; SMS OTP when a card works; repo private **last** (breaks GitHub Pages on the free plan) | `FOUNDER-TODO.md` |

## 3. Restart the team on the new account
1. **GitHub:** in the new Claude account, connect GitHub (claude.ai → Settings → Connectors / "Connect GitHub") with the
   founder's GitHub user so the Claude app can reach `abdulfarhath/hostelzy`.
2. **Cloud environment:** default network access is enough (Flutter downloads from storage.googleapis.com). Optional:
   add `tile.openstreetmap.org` to Allowed domains so real map screenshots work.
3. Start one Claude Code session on the repo called **"Hostelzy · Hub"** and paste the first message in §6.
4. The hub creates the chats it needs with `create_session` (titles `Hostelzy · Build`, `· Design`, `· Marketing`,
   `· Finance & Growth`, `· Brand`). It starts with **Build + Design** only, to save the weekly limit, and records the
   session IDs in `HUB.md`.
5. **Pages to republish on the new account** (sources are in the repo; the old links stay readable only if shared):
   | Page | Source | Old link |
   |---|---|---|
   | Prototype | `tools/prototype.sh` → `build/prototype/` | EztxM6k1kud7ivGoG6K6iP |
   | Setup steps (Supabase / GitHub / Firebase / Play) | `pages/setup-steps.html` | N2k3RxnvPqFTxLrAtZXYbx |
   | Launch steps | `pages/launch-steps.html` | WMb8J3gN6c8MGgRK2ycDhg |
   | Missing screens (history search) | `pages/missing-screens.html` | 9xtrsGFcdAtgsiWdAdPU4W |
   | Lost building screens | `pages/lost-building-screens.html` | LfM32L6tptFh6pZ2JwMM2y |
   | Gap audit (closed) | `pages/gap-audit.html` | M4uyXDSmthjLk8AVTwcQQS |
   | At a glance | `pages/at-a-glance.html` | LrqaBUry9QadrPp4xfSByi |
   | **Design canvas** | Design reads the old canvas (`Artifact read`, scope `files`) and republishes it as a Design artifact | 6n9U2zJw3jri1SeAUz1gCx |
   | Brand guide | Brand rebuilds from `docs/brand/` | 29kRWoLpWYYvW9AGuC2jSi |
   After republishing, update the links in `CLAUDE.md`, `START-HERE.md`, `BOARD.md` and this file.

## 4. Gotchas we already hit (don't repeat them)
| Gotcha | Fix |
|---|---|
| Artifacts belong to one account; a new account can't edit them | Read and republish, then update the links |
| Child chats need artifact permission approved by the founder once | Tell the founder to tap "Approve / Always allow" in that chat |
| Map tiles are blocked in the cloud environment, so screenshots have no streets | Founder's phone screenshots, or allow `tile.openstreetmap.org` |
| Prototype artifacts: no service worker, no CDN, only web file types | `tools/prototype.sh` already strips them (`AssetManifest.bin`, NOTICES, skwasm). `.frag` → text/plain, `.arb` → application/json |
| `flutter` warns when run as root | Harmless in the cloud container |
| `owner_contacts` changed return type; a plain rerun fails | Bundle drops it first; keep every migration rerun-safe |
| Site root `index.html` = the founder's old prototype page | Never touch it (founder decision) |
| Making the repo private on the free plan turns off GitHub Pages (privacy, delete-account, console) | Only with GitHub Pro or after moving the pages |
| Play Store installs need Play's signing SHA-1/256 in Firebase, or Google sign-in fails | Setup steps F2 |
| All chats share one weekly limit; the old account hit it | Run only the chats needed; pause check-ins when idle |

## 5. How the founder likes to work
- One hub chat. Answers are **visual and tabular**, ADHD-friendly: next action first, short rows, colour = meaning.
- "Take your own decisions", but money amounts, accounts and keys stay with the founder.
- Prototype first; no surprise APKs. APK links are always the GitHub release page.
- Design = app 1:1, no duplicate screens, every screen has one job, nothing discussed gets lost.

## 6. First message to paste into the new hub
```
You are the Hostelzy hub (founder's single chat). Read docs/HANDOVER.md, then docs/START-HERE.md,
CLAUDE.md, docs/DECISIONS.md ("Current rules" first), docs/BOARD.md and docs/FOUNDER-TODO.md.
Then: 1) republish the pages in HANDOVER §3.5 on this account (prototype first, via tools/prototype.sh),
2) create Build and Design chats with create_session and record them in docs/HUB.md,
3) have Design re-home the canvas, 4) update the links in the docs and merge.
Reply to me with one table: what you set up, the new links, and my next 3 actions.
Always answer me in short visual tables.
```
