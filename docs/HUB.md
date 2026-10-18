# Hostelzy hub

The founder talks to one chat only: **Hostelzy · Hub**. The hub hands out tasks, reads the other chats' branches and
`get_session`, nudges anyone who stops, and reports milestones. Each chat follows CLAUDE.md for its role.
Started 2026-10-03; re-homed on the current account 2026-10-17.

## Chat structure (founder, 2026-10-18: "structure all the chats")
One hub, two standing chats, three on-demand chats. Only the chats with work run (shared weekly limit).

| Chat (title in the sidebar) | Session | Runs | Does | Writes to |
|---|---|---|---|---|
| **Hostelzy · Hub** | session_01KGJ32QudaatuZ4vkirbgAS | Always | Founder's single contact: ideas → specs, decisions, status, approvals, publishing pages | `docs/` (not marketing, finance, brand) |
| **Hostelzy · Build** | session_01VYdxL9M4tryAVSw5paPAtw | Standing | Builds exactly the spec, prototype first, merges after the founder approves, APK | `hostelzy/`, `supabase/`, `app/`, `tools/`, SCREENS, BOARD status, FOUNDER-TODO steps |
| **Hostelzy · Design** | session_01VKwqzkiTRrHcK6K1kpurt6 | Standing | Canvas 1:1 with the app; new boards from the spec before Build starts | `docs/design/`, feature files' Design section, canvas count line |
| **Hostelzy · Marketing** | not created yet | On demand | Owner pitch, hostel collection sheet, tenant growth, reels, launch plan | `docs/marketing/` |
| **Hostelzy · Finance** | not created yet | On demand | Budget, pricing, rewards caps, bills | `docs/finance/` |
| **Hostelzy · Brand** | not created yet | On demand | Logo assets, Play Store pack, brand guide | `docs/brand/` |

How a feature flows: founder idea (hub) → spec `docs/features/Fnn-*.md` + DECISIONS (hub) → boards on the canvas (Design)
→ code + prototype (Build) → founder approves in the prototype (hub relays) → merge + APK (Build) → canvas v+1 (Design, hub publishes).

Rules of the structure:
- **Model (founder, 2026-10-18): every Hostelzy chat runs Fable 5.1 at Max effort.** Hub, Build and Design are on it now. A new chat is created with `model: claude-fable-5-1`; the effort level is set by the founder in the chat's model menu (the hub cannot set it from here).
- Child chats can't message the hub on this account; the hub reads their branches and session state instead. Each child
  ends its turn with a pushed commit whose message says what is done.
- On-demand chats are created with `create_session` when a task needs them, given one task, and left idle after.
- Old chats from earlier accounts (Marketing, Finance, Brand of 2026-10-03; "ctx hub") are retired; their work is in `docs/`.
- Session IDs above are the only live ones. Replace this table when a chat is recreated.

## 2026-10-03 team (first account, retired)
| Chat | Session | Role | First tasks |
|---|---|---|---|
| Hub (Ideas & status) | session_01A5To8Q2sCiWqGnd2nK3BMy | Founder's single contact; specs, decisions, status | Gap audit (`AUDIT-2026-10-03.md`) |
| Build | session_01VYdxL9M4tryAVSw5paPAtw | Code, PRs, merges | Merge #81 + #80 → Wave 0 fakes → Wave 1 screens → Waves 2–4 |
| Design | session_01VKwqzkiTRrHcK6K1kpurt6 | Canvas 1:1 with the app | Re-home the canvas on this account → missing boards → sync after every merge |
| Marketing | session_01KA73QpupxUuTHjhpiEd3jn | Owner pitch, tenant growth, reels | Launch plan, pitch, growth, reels |
| Finance & Growth | session_0191SJ1qAdm8xL7m212nsCqQ | Budget, pricing, bills | Founder questions with numbers, bills, P&L |
| Brand | session_01B7f1F6GRrhJzbixSRgjuAH | Name + logo assets | Play Store pack, push icon + splash, brand guide |

Check-in: routine "Hostelzy hub check-in", every 2 hours.

## Check-in 2026-10-03 10:51 UTC
| Chat | Status |
|---|---|
| Build | ✅ Every audit item merged (#80–#93). APK apk-87. 307 tests pass. Waiting: founder SQL (4y, 4z, 4zc, 4zk, 4zu…), keys 6a–6c, Q6 Founding spot, partner ₹/hold |
| Design | ⛔ Blocked: Artifact permission needs the founder's Approve. Canvas moved to https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx. Queued: boards for the new screens |
| Marketing | ✅ Launch plan, pitch, growth, 15 reels + 5 posters. 3 founder questions in README |
| Finance | ✅ Founder questions with numbers, bills, P&L (50 hostels → break-even Feb 2027) |
| Brand | ✅ Play Store pack, push icon + dark splash, brand guide https://claude.ai/artifact/29kRWoLpWYYvW9AGuC2jSi |

## Check-in 2026-10-03 12:51 UTC: all chats done
| Chat | Status |
|---|---|
| Build | ✅ #80–#95 merged. 309 tests. docs/SCREENS.md: 181 screens |
| Design | ✅ Canvas v28: App 181 · Canvas 181 (+42 variants, +21 dark, +8 not counted) |
| Marketing / Finance / Brand | ✅ Done |
Check-in routine paused: nothing left for the chats. Waiting on the founder: SQL steps, phone test, accounts, 2 money answers.

## 2026-10-05: handover to a new Claude account
The sessions above belong to the old account and are retired. The new account's hub creates fresh chats
(see `HANDOVER.md` §3) and replaces the table at the top with their session IDs.

## 2026-10-17 release
| What | Where |
|---|---|
| **APK apk-105** (F26 + F27, the build the founder approved as prototype v6) | https://github.com/abdulfarhath/hostelzy/releases/tag/apk-105 |
| apk-104 (F26 only, from the first merge) | https://github.com/abdulfarhath/hostelzy/releases/tag/apk-104 |
| Merged | F26 #141 (squash; #121–#125 closed as superseded) · F27 #140 |
| Founder SQL | one re-run of `docs/sql/run-all-pending.sql` covers 4zo1, 4ze26, 4zf27 (FOUNDER-TODO) |
| Screens | app 157, overall 179 (`docs/SCREENS.md`); Design: S18 back, S90 + S91 new |

## 2026-10-06 F26 status
| Piece | State |
|---|---|
| Prototype v4 (https://claude.ai/artifact/EztxM6k1kud7ivGoG6K6iP) | **All of F26** (#1–#14, #16–#21, open layouts; #15 became "residents can hold") + settings copy for the waitlist push. Waiting for the founder's review |
| Build PRs | #121 B, #122 A, #123 D, #124 C, #125 E + branch f26/integration (bc66a72, main merged in): all green (367 tests, 40 SQL files). app/r page now points to the app (web 7, overall 176). Not merged until the founder approves in the prototype |
| SQL | 2 new migrations (4zo1 open layouts, 4ze26 contact/hold steps/listings) are in `docs/sql/run-all-pending.sql`; one re-run covers everything |
| Main canvas | **v23** = F26 (v20–v22) + F27 Save food (S90, S91 new), 178 boards = Build's SCREENS on f26/integration + F27 (hub published from the repo; Design's own publish stays permission-blocked, so Design pushes to `design/f26-merge` and the hub publishes) |
| F27 Save food | **Approved** by the founder 2026-10-06. Main canvas v23 has it. Build: branch feature/f27-save-food on top of f26/integration, prototype next (SQL 4zf27 bundled) |

## 2026-10-06: second handover to a new Claude account
The sessions in the table at the top belong to the account being left. The new account's hub creates fresh chats
(see `HANDOVER.md` §4) and replaces the table with their IDs. State at the move: F26 reverts in progress on
`f26/integration`, F27 started on `feature/f27-save-food`, main canvas v23, prototype v4 (old account).

## 2026-10-17: hub resumed (session_01KGJ32QudaatuZ4vkirbgAS)
Founder: "continue, there are few chats left, use them". The old Build and Design chats are on this account, so they are reused.
| Chat | Session | Task |
|---|---|---|
| Hub | session_01KGJ32QudaatuZ4vkirbgAS | Founder contact |
| Build | session_01VYdxL9M4tryAVSw5paPAtw | 12 F26 reverts → price check → prototype republish → F27 finish (extras on hold) |
| Design | session_01VKwqzkiTRrHcK6K1kpurt6 | Canvas v24 (reverts) → hub publishes |
Marketing, Finance, Brand: not started (save the limit).

### 2026-10-17 20:30 UTC
| Piece | State |
|---|---|
| F26 12 reverts | Done on f26/integration (46098a4), check.sh green. Price check: same as main (only Explore order differs) |
| F27 | Done on feature/f27-save-food, draft PR #140 (do not merge before F26). 6 extras approved by the founder |
| Prototype v6 (F26 reverts + F27) | NEW link https://claude.ai/artifact/Euhs4QdxQWgizgpzuuRj5g (old EztxM6… is gone). Waiting for the founder's review |
| Main canvas | Old artifact gone. v23 source on design/f26-merge (be73cea, docs/design/main-canvas/). Design prepares v24; hub publishes as a new artifact |
| Messaging | Child chats can't send_message the hub; hub reads their branches / get_session |

### 2026-10-17 20:58 UTC: both re-homed on this account
| Page | New link |
|---|---|
| Main canvas v24 (179 counted boards, 472 files, 6 map shots re-uploaded) | https://claude.ai/artifact/WfdWH9dH8f9wxKmjoGgVLU |
| Prototype v6 | https://claude.ai/artifact/Euhs4QdxQWgizgpzuuRj5g |
Source of truth for the canvas: `docs/design/main-canvas/` on design/f26-merge @ 8b39f3d. Waiting on the founder: prototype review.

### 2026-10-17 release
| Piece | State |
|---|---|
| F26 → main | PR #141 merged (071b159) → apk-104 |
| F27 → main | PR #140 merged (9ccda7a) → **apk-105** https://github.com/abdulfarhath/hostelzy/releases/tag/apk-105 (real + demo). Tests green |
| Supabase functions deploy | 🔴 401 Invalid access token on both pushes: the founder's SUPABASE_ACCESS_TOKEN expired. FOUNDER-TODO step 0b |
| Founder | Run run-all-pending.sql once (4zo1, 4ze26, 4zf27); re-create the token; test apk-105 |
Build and Design: idle; nothing queued. Next feature waits on the founder's ideas.
