# F31 · No explanations anywhere · everything in priority order

**Stage:** founder rule (2026-10-18) → **Spec final (hub, same day, under the founder's delegation)** → Design 3 + Build 5 (wave 5, last).

**Founder (2026-10-18):** "Near the drink-water notification there is an explanation saying this thing does this thing. Big
apps like Airbnb never give explanations; Zoho never explains any button. I don't need any explanations anywhere. Everything
simple, neat and clean. In the owner's dashboard we show whether food is eaten on the top instead of what matters to the
owner. Everything is displayed by priority: what the user wants to see first. The drink water should be somewhere else, not
on the top. Keep this in mind and add it to the application."

## Rule A · No explanations (every screen, sheet, state, push, web page)
| Remove | Keep |
|---|---|
| Any grey helper sentence under a control, row or card that says what it is for or how it works ("Managers who help you run it", "Who's eating · the count closes 3 h before each meal", "Only if you chat on a different number…", "Owners see this name on your holds…", "Change it any time in Me → Reminders. Runs on this phone.", "A friendly nudge every 30 minutes…", "Talking through Hostelzy keeps your deal and your ₹100 reward.", "Then paste them in the hub chat…") | A subtitle that is a **value or a state**: "12 residents · 2 waiting", "3 active", "+91 98… · not verified", "No UPI yet", "Closes 5:00 pm · 31 eating", dates, counts, prices, "Rent on request", "Not available yet" |
| Intro paragraphs in sheets and empty states; "Why?" lines; tips, coach marks, "i" icons, tooltips; "You can also…" lines; marketing sentences inside the app | One-line irreversible warnings ("This can't be undone."), legal lines required by stores (Terms, delete account), the honest server state when the SQL is not run yet |
| Toasts longer than 6 words; push bodies that explain | Toast = the result ("Saved", "Sent to owner"); push = title + fact + buttons |
| Labels that describe purpose ("Turn on water reminders so you…") | Labels that name the action ("Send on WhatsApp", "Approve", "Add a hostel") |
Empty states: ≤ 6 words + one button. Kickers (small section labels) stay: they are labels, not explanations. Languages: the te/hi
packs drop the same lines.

## Rule B · Priority order (what the user came for, first)
| Screen | Order from the top (hide a block when it is empty or zero) |
|---|---|
| **S36 Owner Today** | Header · **money strip**: "Due today ₹X · Late ₹Y" (tap → Rent) · the needs-you tabs **Holds · Payments · Joining · Fixes** with counts, most urgent first · Fair Play card **only while a case is open** (no longer pinned on top) · This month (beds taken · free · rent pending · occupancy) · **Headcount card** (meals) · Still N free beds? · Confirm layouts · rates card |
| **S23 Resident Home** | Rent card (when due/late; otherwise the small paid line) · Next meal card · Food this week · the 3 actions (notice, swap, fix) · 30-day review card. **No water card, no reminder offer** on Home |
| **Reminders** | Live only in Me › Reminders (and the Notifications switches in Settings). The first-time sheet "Want water reminders?" is **removed** (sheet retired); the glasses/"rings next" card shows only inside Me › Reminders |
| **Owner Manage (S42…)** | Residents · Rates and UPI · Layouts · Meals · Photos · Deals · Complaints · Food menu · House rules · Tenant IDs (F29) · Team · Plan |
| **S79 Me (tenant/resident)** | Name + phone · Your hostel (F28, only when one exists) · Saved & Holds / My stay · Rewards · Reminders · Settings |
| **Settings** | Account · Notifications (switch labels only) · Language · About (version line) · Delete account last |
| Lists everywhere | Most urgent / newest first; "nothing" states are one short line |

## Not changed by F31
Colours, fonts, rules, square corners, the tab bars, screen count (minus the retired offer sheet), any feature's behaviour.
F26 revert #6 (the "₹100 reward" sentence) is superseded by Rule A: the sentence goes. The lock line "Owner's number shows after
you hold a bed." stays (it is a state).

## Screens
| Id | Change |
|---|---|
| S36 `oToday` | Reordered as above; money strip new; Fair Play card conditional |
| S23 `rHome` | No TodayCard / offer; order as above |
| H? `waterOffer` | **Retired** (sheet removed; Build names the id in SCREENS) |
| Manage, Me, Settings, every sheet with a helper line | Copy removed per Rule A; Build lists each removed line in its Build section (screen · old line) |

## Build (wave 5, Build 5 on `feature/w5-clean`, integrated last by Build 1)
1. Audit: grep every `T('…', s: 12|13, c: p.mu` / subtitle / `hint` string in `hostelzy/lib`, `app/`, l10n packs; classify Keep / Remove with the rule above; write the table into this file's Build section **before** editing.
2. Apply Rule A and Rule B. Retire the offer sheet and `maybeOfferReminders()`. Keep tests green; update the texts the tests assert.
3. `tools/check.sh` green; feature file Build section = the full table of removed lines and the new orders; `docs/handover/w5-build.md`; last commit "W5 DONE". No SCREENS/BOARD edits (the integrator does them: retire the offer sheet id, totals).

## Design (Design 3, boards)
Apply Rule A to **every** board (remove the helper lines; keep values/states) and Rule B to S36, S23, Manage, Me, Settings;
retire the waterOffer board (archive row). Ship `docs/design/v26/project/*.dc.html` (changed boards, same file names) +
`docs/design/v26/parts/f31.json` (`{"boards": {...changed entries if size changes...}, "retire": ["<waterOffer file>"]}`)
on branch `design/f31-clean`. When Build 5's table lands, re-check the boards against it and push again. The hub assembles v26.

## Not in the spec
Build 5 and Design 3 list extras here; the hub decides within the day.
