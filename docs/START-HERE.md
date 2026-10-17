# Start here

A one-page orientation for any new Claude (or person) picking up Hostelzy. **New account? Read `docs/HANDOVER.md` first** (updated 2026-10-06 for the second move). Last updated 2026-10-06 by the hub.

## 1. The product in 60 seconds
| Who | Does what in the app | Pays |
|---|---|---|
| **Tenant** | Finds a PG bed in Hyderabad, holds it free (1 h, or 2 h for Members), pays the ₹3,000 advance **straight to the owner** by UPI, and gets Hostelzy deals | ₹0 to Hostelzy |
| **Resident** | Lives there: pays rent (UPI → reference → owner confirms), food menu, complaints, notice and moves, reviews, rewards, reminders | ₹0 |
| **Owner / manager** | Runs the PG: beds, rooms and layouts, rates, deals, residents, enquiries, Fair Play | Plan A: ₹499 (≤30 beds) / ₹999 (31–80) / ₹1,499 (80+) a month, 30-day free trial |
| **Hostelzy team** | Onboards hostels (Add hostel wizard), checks payments, Fair Play cases, layout help | — |

Hostelzy **never holds money**. Trust comes from Hostelzy's own records: HZ codes on enquiries and
holds, matched against the residents the owner adds. Fair Play has 3 strikes. Rules: `DECISIONS.md`.

## 2. Where things are (2026-10-05)
| Area | State |
|---|---|
| Features F01–F25 | All built and merged (`BOARD.md`). Newest APK: the latest `apk-N` release |
| F26 + F27 | In the prototype only, on branches `f26/integration` and `feature/f27-save-food` (`HANDOVER.md` §2) |
| Design ↔ app | Main canvas v23 = 178 boards (F26 + F27); `main` app = 179 until F26 merges (`BOARD.md`) |
| Working method | **Prototype first** (`PROTOTYPE.md`): founder approves in the web prototype, then `main` + APK |
| Backend | Supabase (Mumbai) + Firebase Google sign-in + FCM push. Pending SQL is one file: `docs/sql/run-all-pending.sql` |
| Code quality | Cleaned, split by feature, `tools/check.sh` (`ARCHITECTURE.md`) |
| Launch | Waiting on the founder: SQL file, prototype review, Play Console, domain, map key, upload key, Finance answers (`HANDOVER.md` §2) |
| Play Store | New personal accounts need a 14-day closed test with 12 testers before production |

## 3. Map of the repo
| Path | What |
|---|---|
| `CLAUDE.md` | Rules for every chat (roles, approvals, hard rules) |
| `docs/BOARD.md` | Every feature and its stage, plus links |
| `docs/DECISIONS.md` | Everything agreed with the founder (read "Current rules" first) |
| `docs/SCREENS.md` | Every screen, sheet and state, with its id. The source of the 1:1 count |
| `docs/ARCHITECTURE.md` | How the code is organised, data flow, how to add a screen or migration, CI |
| `docs/FOUNDER-TODO.md` | The founder's manual steps (SQL runs, keys, accounts), in order |
| `docs/HANDOVER.md` | Moving to a new Claude account: state, what to republish, gotchas, first message |
| `docs/memory/` | The hub's memory: who the founder is, how to talk to them, the story so far, and every founder message word for word |
| `docs/HUB.md` | Chat session IDs and the check-in log |
| `docs/PROTOTYPE.md`, `docs/sql/`, `docs/pages/` | Prototype workflow, one-file SQL, sources of the visual pages |
| `docs/AUDIT-2026-10-03.md` | The gap audit that F24 closed (history) |
| `docs/features/Fxx-*.md` | One spec per feature: problem, stories, screens, rules, plus Design and Build sections |
| `docs/marketing/`, `docs/finance/`, `docs/brand/`, `docs/i18n/` | Owned by those chats |
| `hostelzy/` | Flutter app (`lib/`, `test/`, `android/`) |
| `supabase/migrations/`, `supabase/tests/`, `supabase/functions/` | Database, SQL tests, push Edge Function |
| `app/` | Public web pages (privacy, terms, delete-account, `r/` enquiry links, `j/` invite links) and the team console `app/console/` |
| `index.html`, `project/`, `chats/` | The original Claude Design prototype and handoff. Kept by founder decision; don't change |
| `.github/workflows/` | APK build + release on every push to `main`, checks, team-member tool |

## 4. Key links
| What | Link |
|---|---|
| Design canvas (Hostelzy · Main design) | https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx |
| Brand guide | https://claude.ai/artifact/29kRWoLpWYYvW9AGuC2jSi |
| APK releases | https://github.com/abdulfarhath/hostelzy/releases (always give the founder the `tag/apk-N` page) |
| Public pages | https://farhath.me/hostelzy/app/ · team console: https://farhath.me/hostelzy/app/console/ |
| Gap audit (visual) | https://claude.ai/artifact/M4uyXDSmthjLk8AVTwcQQS |
| Launch steps (visual) | https://claude.ai/artifact/WMb8J3gN6c8MGgRK2ycDhg |
| Prototype (clickable app) | https://claude.ai/artifact/EztxM6k1kud7ivGoG6K6iP |
| Setup steps (Supabase / GitHub / Firebase / Play) | https://claude.ai/artifact/N2k3RxnvPqFTxLrAtZXYbx (source `docs/pages/setup-steps.html`) |

Artifacts are private to the account that made them. On a new account they open only if the owner
shared them. The repo always has the same information in text.

## 5. Words used everywhere
| Word | Meaning |
|---|---|
| HZ code | `HZ-XXXX` reference on every enquiry and hold. Proves a tenant came through Hostelzy |
| Hold | Free bed reservation: 1 h, or 2 h for Members. The owner keeps or declines it |
| Via Hostelzy / Direct / Before | How a resident joined. Matched by phone within 60 days of an enquiry or hold |
| Member / Trusted tenant | Stay Rewards levels (₹100 next-stay credit, referrals, perks) |
| Strike 1 / 2 / 3 | Fair Play: warning / deals hidden 30 days / removed |
| Real vs demo APK | Same code. `DATA=supabase` (real data, empty states) vs `DATA=sample` (sample data, DEMO strip, ".demo" id) |
| `onServer` | The app is on the real backend. Off means sample/local state (demo and tests) |
| Founder step 4x | A numbered manual step in `FOUNDER-TODO.md`, usually "paste this SQL file and Run" |

## 6. Carrying on from a new account
1. Open a Claude Code session on `abdulfarhath/hostelzy` and name it **Hostelzy · Hub**. Tell it:
   "You are the Hostelzy hub. Read CLAUDE.md and docs/START-HERE.md, then docs/HUB.md."
2. The hub creates the other chats with `create_session` (repo source, title `Hostelzy · <Role>`), each
   with a prompt like: "You are Hostelzy · <Role>. Follow CLAUDE.md. Read docs/START-HERE.md. Your task: …".
   It records the new session IDs in `docs/HUB.md`.
3. The design canvas belongs to one account. If the new account can't edit it, Design reads it
   (`Artifact read`, `scope: files`) and republishes it as a new artifact, then updates the link here,
   in CLAUDE.md and in BOARD.md.
4. Flutter in cloud sessions: the `.claude/` SessionStart hook installs it. If it's missing, install
   Flutter 3.47.5 (the version CI uses), then run `tools/check.sh`.
5. Weekly usage limits are shared by every chat on an account. Pause idle chats and check-ins.
