# v26 · F31 boards: no explanations, priority order (Design 3, 2026-10-18)

**Design approved** (Design 3, under the founder's delegation). Built on the **published v25** index (`docs/design/v25/project/canvas.json`, 461 boards, 188 counted; board sources in `docs/design/main-canvas/project` on `design/f26-merge` @ `4bb7aca`). The hub assembles v26: copy `project/*.dc.html` over the same file names, apply `parts/f31.json` to the live `canvas.json` (`boards` = new title for each listed file, positions unchanged; `retire` = files the hub deletes from the artifact). **No files net**: 216 changed in place, 0 added, 4 deleted.

| | |
|---|---|
| Boards changed | **216** (same file names as the originals; all carry `· Updated (F31)` in the title). 32 lines were already gone in v25 (the hub's own Rule A pass), so 11 boards needed nothing |
| Boards retired | **4** → the hub deletes them (the archive rows are git-only since v25): `f20-Offer` (H41 "Want water reminders?" sheet), `f20-Home` + `f20-HomeDark` (Home with the water Today card), `f20-HomeTenant` (water card on Explore) |
| Counted screens | 188 − 1 (H41) = **187**, if Build's SCREENS agrees. Variants −2, dark −1 |
| Colours, fonts, rules, corners, tab bars | unchanged |

How it was made: `scripts/f31.py` (run from the repo root; `scripts/hz.py` is a span-accurate HTML finder so every other byte of a board stays identical). Rule A is the `A` table at the top of the script: one line per board and per removed or trimmed sentence. Re-run it to rebuild `project/` and `parts/` from the main canvas.

## Rule A · what went, what stayed
Removed on every board that had one: the grey helper sentence under a control, row or card; sheet intro paragraphs; tips, coach marks and "You can also…" lines; marketing sentences; option descriptions in pickers; design notes drawn inside the phone (the "WhatsApp opens with…" preview on S38, the UPI receipt mock on H12, "Not on this list = not from Hostelzy", console footnotes).

Stayed: values and states (counts, dates, prices, "not verified", "No UPI yet", "Closes 5:00 pm · 31 eating"), one-line warnings, legal lines, the honest server state ("Not available yet."), user-written content (reviews, complaints, WhatsApp message bodies), rules text on the Fair Play rules page and the I-agree screen, web-page copy that is the page's content (privacy, terms, delete account, the APK install note).

Trimmed to the value where a sentence mixed both, for example:
| Board | Before | After |
|---|---|---|
| S36 Fair Play card | Reply in 47 h · pinned until you answer | Reply in 47 h |
| S13 | Same price for every bed of a type. Food included. Electricity extra, by meter. Confirmed by the owner · 3 Oct | Food included. Electricity extra, by meter. Confirmed by the owner · 3 Oct |
| S65 | Pay by 20 Oct to keep your deals showing. From day 15 deals pause; … | Pay by 20 Oct. |
| S45 empty | No menu yet. Tenants see "Menu not added yet" … | No menu yet. |
| H23 | Free. The Hostelzy team draws it within 48 hours. Tenants keep seeing … | Free · within 48 hours |
| S92 | Owner's phone is never shown to tenants. ₹200 when the owner agrees and Hostelzy verifies the hostel. | ₹200 when verified |
| H37 | Telugu and Hindi come once a native speaker has checked the words. Until then … | Telugu and Hindi · not available yet |
| S86 | We're making Hostelzy better. Your holds, payments and data are safe. Expected back by 6:30 pm. | Back by 6:30 pm. |
| F27 push | Chapati, dal. Tap Skip if you won't be here. Closes at 5:00 pm. | Chapati, dal · closes at 5:00 pm |
| S79 / owner Me | Live in a PG or run one? Switch role › | Switch role › |

## Rule B · orders drawn
- **S36 Owner Today** (`r-today`, dark, `f26-todayEmpty`, `f29-todayJoining`): header · **money strip** "Due today ₹6,000 · Late ₹16,300 ›" (tap → Rent) · Needs you · tabs **Holds · Payments · Joining · Fixes** (Joining only when its count is > 0) · the list · Fair Play card **after** the list, only while a case is open · This month · **Dinner tonight** headcount card near the bottom. T33 (all zero): no strip, no tabs, "Nothing needs you now", This month. The older variants (`f19-Today`, `f23-Today`, `f24-oTodayCards`, `w1-oTodayMoves`, `w2-oTodayRates`) get the money strip first and keep their cards below.
- **S23 Resident Home** (`r-home`, `f26-homeDark`): rent card · next meal card · food this week · the 3 actions **Give notice · Swap bed · Raise complaint** · **30-day review card** ("How is your stay? · Open till 2 Nov · Review"). No water card, no reminder offer. The actions and the review card sit below the week table, so they are off-screen on the 844-px board (the screen scrolls).
- **Owner Manage** (`r-manage` and the three `f29-drive*` boards that show it behind the sheet): Residents · Rates and UPI · Room layouts · **Meals** (new row, "Dinner · 34 of 40 eating") · Photos · Deals · Complaints · Food menu · House rules · Reviews and ranking · **Tenant IDs** (new row, "Drive not connected") · Team · Your plan.
- **S79 Me**: already Name + phone · Add a hostel / Your hostel · Stay Rewards · Reminders · Settings · Help · Log out; only the helper subtitles went. `f20-Me` reordered to Saved hostels · Stay Rewards · Reminders · Settings · Switch role · Log out.
- **Settings** (`settings`, dark, `w1-notifSwitches`, `add-lang`, `w1-editName`): **Account** (was "You") · Notifications with switch labels only · App: Language, Look, Privacy and terms, Hostelzy team, **About · Hostelzy 1.0.0 (1)** · Log out · Delete account last.

## Not in the spec (hub decides)
1. Retired 3 boards besides the offer sheet: `f20-Home`, `f20-HomeDark`, `f20-HomeTenant` only existed to show the water Today card on Home / Explore, which Rule B removes. They are in `parts/f31.json › retire` with the sheet. The water Today card itself still shows inside Me › Reminders (S81 `f20-Main`).
2. Spec lists "Saved & Holds / My stay" as a Me row; v25's S79 has no such rows (they are tabs since F26/F28). Not added.
3. Spec's Manage order omits "Reviews and ranking"; kept it after House rules. "Meals" and "Tenant IDs" rows are new on the Manage board (the spec names them; Build had not drawn them yet).
4. The 3 Home actions are drawn as Give notice · Swap bed · Raise complaint ("fix" read as the complaint sheet H45, not a layout fix). Rename if Build picks other words.
5. H31 "How the ranking works" is a sheet made only of explanation ("Reviews count only from residents with a confirmed stay…"). Left as is; retire it if Build drops it.
6. Money strip sample values: Due today ₹6,000, Late ₹16,300 (the two late rows on S38).
7. Build's "WhatsApp opens with …" message previews (S38) and the UPI receipt mock (H12) were design notes inside the phone; they are gone from the boards but still in git (`docs/design/main-canvas/project`).

## Next
When Build 5's table of removed lines lands in `docs/features/F31-no-explanations-priority.md › Build`, re-check the `A` table in `scripts/f31.py` against it, add any line Build removed that the boards still show, rebuild, push again.
