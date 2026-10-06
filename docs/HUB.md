# Hostelzy hub

The founder talks to one chat only: **Hostelzy app review** (the hub). New account? See `docs/START-HERE.md` §6. The hub hands out tasks, checks every
2 hours, nudges anyone who stops, and reports milestones. Each chat follows CLAUDE.md for its role.
Started 2026-10-03.

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

## 2026-10-06 F26 status
| Piece | State |
|---|---|
| Prototype v4 (https://claude.ai/artifact/EztxM6k1kud7ivGoG6K6iP) | **All of F26** (#1–#14, #16–#21, open layouts; #15 became "residents can hold") + settings copy for the waitlist push. Waiting for the founder's review |
| Build PRs | #121 B, #122 A, #123 D, #124 C, #125 E + branch f26/integration (bc66a72, main merged in): all green (367 tests, 40 SQL files). app/r page now points to the app (web 7, overall 176). Not merged until the founder approves in the prototype |
| SQL | 2 new migrations (4zo1 open layouts, 4ze26 contact/hold steps/listings) are in `docs/sql/run-all-pending.sql`; one re-run covers everything |
| Main canvas | **v21** = F26 merge + follow-up, 177 boards = Build's SCREENS on f26/integration (hub published from the repo; Design's own publish stays permission-blocked, so Design pushes to `design/f26-merge` and the hub publishes) |
| F27 Save food | 8 boards on the proposal canvas v11 (https://claude.ai/artifact/QXYxc9NdqqtJCarAy2XS7g). Waiting for the founder's review; main canvas untouched |
