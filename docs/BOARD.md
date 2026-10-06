# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Standing approval: chats approve and merge themselves (CLAUDE.md). Update this table whenever a feature moves. New here? Read `docs/START-HERE.md`.

| ID | Feature | Stage | Owner chat | Notes |
|---|---|---|---|---|
| F01 | Core app from the Claude Design handoff (20 screens, 3 roles) | **Shipped** | Build | On `main`, APK `apk-1` |
| F02 | Fix the advance model (₹3,000 advance + exit maintenance) | **Shipped** · merged 2026-10-02 | Build | PR #1 squash-merged by founder's instruction; APK builds from `main` |
| F03 | Hostelzy deals: owner deal menu + tenant comparison + badges | **Shipped** · merged 2026-10-02 | Build | PR #5 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F04 | Book with the advance, deal locked, HZ code | **Shipped** · merged 2026-10-02 | Build | PR #6 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F05 | Enquiry flow (HZ code before WhatsApp, owner enquiry list) | **Shipped** · merged 2026-10-02 | Build | PR #2 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F06 | Owner resident list + phone confirmation + Via Hostelzy / Direct matching | **Shipped** · merged 2026-10-02 | Build | PR #3 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F07 | Fair Play rules, collusion checks, cases, strikes | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f07-fair-play`. Founder case queue is one column in the app |
| F08 | Verified-resident reviews + Hostelzy score ranking | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f08-reviews`. Rank shown as #N with reasons, never a number |
| F09 | Stay Rewards (next-stay discount, Trusted tenant, referrals) | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f09-stay-rewards`. ₹100 credits feed F10 invoices |
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f10-owner-plan`. UPI ID is a placeholder until the founder gives it |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Merged into F12** | — | The F12 Room tab is the seat map |
| F12 | Room layouts (Hostelzy draws) + tenant Room tab (seat map, fans, AC, windows, washroom) | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f12-room-layouts`. Sample layouts are labelled as samples until real visits (F13/F14) |
| F13 | Backend: Supabase, Google sign-in, live sync, push | **Built** · part 1, B3, B5, B6, B7, C and S1–S8 merged 2026-10-02 (holds, residents, owner edits, reviews, Fair Play, Stay Rewards, plan invoices, managers on the server); push confirmed end to end on apk-46 | Build | Sign in with Google (phone typed, not verified; SMS check later, needs Firebase Blaze). Gaps left are tracked in F24. Details in the feature file |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f14-onboarding`. On the server since S8 (managers) and F24 Wave A 2+3 (#79: real hostels, owner link, go live with trial) |
| F16 | AC / non-AC room types, pricing grid and filter | **Shipped** · merged 2026-10-02 | Build | PR #4 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F15 | Play Store launch: settings, account deletion, permissions, privacy | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f15-play-store`. Outside-the-app checklist (Play account, domain pages, upload key, SHA-1) in the feature file |
| F17 | Make it real: remove demo/fake behaviour (honest payments, real WhatsApp/map/QR, no demo login) | **Shipped** · parts 1–3 + leftovers merged 2026-10-02 | Build | Honest login, real links, holds expire, UPI → UTR → owner confirms, real map, large screens with a left nav rail, honest toasts, owner screens follow the selected hostel. Group B needs F13 |
| F18 | Real-user bug fixes (back button, stay logged in, own name/phone, gated roles, crashes, keyboard, map location + area, owner edits layouts) | **Built** · all 10 groups merged 2026-10-02 (APK `apk-32`) | Build | From the founder's phone test of apk-29. Photos/gallery, delete v2 and the team console followed on the backend (F13 B7, C) |
| F19 | Residents fix room layouts (any room in their hostel → owner approves; others see a "residents only" nudge) | **Built** · 2026-10-02 (v1 core merged #60; v1 extras merged #66) | Build | Design: https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR · Founder idea. Reward for approved fixes: founder to decide |
| F20 | Reminders: water every N min, my own tasks, hostel meal/rent reminders (on the phone) | **Built** · 2026-10-02 (PR feature/f20-reminders) | Build | Founder idea. Local notifications, works offline. Backed up to the profile when signed in (FOUNDER-TODO 4p) |
| F21 | Simpler UI/UX: one job per home screen, guest browsing, plain words, honest data, Telugu, accessibility | **Design approved** · founder, 2026-10-02 · **Wave 1 merged** (#65) · **Wave 2 merged** (#67) · **Wave 3 merged** (#68) · **Wave 4 merged** (#69) · all 4 waves in main | Founder (W2–W4) | 24 fixes in 4 waves; wave 1 = fake-data bugs |
| F22 | Redesign every screen in the F21 style (simple, one job per screen, plain words) | **Design approved** · all 5 areas designed 2026-10-02 (All screens, 88 boards tagged Redesigned) · **Area 1 Tenant merged** (#71) · **Area 2 Resident merged** (#72) · **Area 3 Owner merged** (#73) · **Areas 4–5 merged** (#74) · **Built**: every area in main | Build | Founder: "your own decisions, never take my approval". Area by area, built in parallel |
| F23 | Floor amenities (fridge, washing machine, RO… per floor; owner + residents add) + room layout as the primary view | **Design approved** · founder, 2026-10-02 ("yes for all", in the Ideas chat) · demo https://claude.ai/artifact/PjkPGAojZgLXFLWP56yvFf · **Built** 2026-10-02 (merged #75; SQL: FOUNDER-TODO 4u, founder to run) | Build | Founder exception: approve design before build |
| F24 | Close every gap: real hostel onboarding, owner phone, menu, move-out, fake values → real, shapes, layer toggle, Fair Play signals, canvas = app 1:1 | **Built** · every item 2026-10-03 (status table in the feature file) · Wave A 4 (#77), 1 (#78), 2+3 (#79) merged 2026-10-02; Wave A 5+6 (#81) and Wave C 30+31 (#80) merged 2026-10-03 (SQL 4v–4z, 6a–6c: founder) · **Wave 0** (fake lines out, owners-draw copy, 6-month deal headline, Settings › Name, no OTP wording) merged 2026-10-03 (#82) · **Wave 2a** (items 7, 8, 22, 29 on the server; SQL 4zz1–4zz4) merged 2026-10-03 (#83) · **Wave 1 shapes** (items 10 + 11: Fan/AC layer chips, room shapes, "Ask Hostelzy to draw it" in the app + console Layout help; SQL 4zk) merged 2026-10-03 (#84) · **Wave 1 screens** (meter, laundry day, case photo, Trusted perks + first look, manager join, refund sheets; SQL 4zu) merged 2026-10-03 (#85) · **Wave 2b** (items 9, 13, 14 on the server: free beds + layouts confirmed, locked deal perks, "Did you join?"; SQL 4zy1–4zy3) merged 2026-10-03 (#86) · **Wave 3a** (items 17, 19, 20, 21: owner-only areas, AC unit on room changes, featured spot, deals pause + money pushes; SQL 4zx1) merged 2026-10-03 (#87) · **Wave 4a** (enquiry link, one enquiry per bed / review per stay, review rules + report abuse, "layout is wrong" flags the room; SQL 4zr1) merged 2026-10-03 (#88) · **Wave 4b** (women's PG floor plan on the server, one editor at a time, scan invite QR, push icon + dark splash, "Tell me when it's ready"; SQL 4zs1) merged 2026-10-03 (#89) · **Wave 4c** (owner WhatsApp + resident number, real map pin, console Go live via go_live, wizard rules/amenities saved, menu meal times; SQL 4zp1) merged 2026-10-03 (#90) · **Wave 3b** (#18 Fair Play hardening: rules accepted on the server, "before" residents, strike 2 lifts after 30 days, strike 3 hides the hostel, 6 signals, tenant reports + case photo in the console; SQL 4zf1) merged 2026-10-03 (#91) · **Wave 4d** (Best deals sort, rates "Confirmed by the owner · date" + monthly check; SQL 4zd1) merged 2026-10-03 (#92) · **Cleanup** (#18 deals hidden on the server, item 15 "Layouts checked by N residents"; SQL 4zc) merged 2026-10-03 (#93) · **Performance pass** (photos in one query, parallel reads, one refetch at a time, countdown-only rebuilds; no SQL, no UI change) Built 2026-10-03 | Design + Build | 3 audits + gap audit 2026-10-03; waves 0 → 1 (boards) → 2 (phone-only → server) → 3 (server rules) → 4 |
| F25 | Restore missing screens (archive of earlier designs; 4 NEW boards for Build) | **Design approved** 2026-10-03 · **NEW-4 owner menu Week table** Built (merged #107; now a toggle on S45, not its own screen) · **NEW-1 Building view (S87; NEW-2 merged in, owner Beds › Rooms · Building)** Built 2026-10-03 (PR #109, branch `feature/f25-floor-maps`; no SQL) · **A6 occupancy (S36), A7 all plans + A8 past invoices (S65)** Built 2026-10-03 (PR open, branch `feature/f25-owner-sections`; sections in existing screens, no SQL) · **Redundancy merges** Built 2026-10-03 (PR open, branch `feature/f25-merge-duplicates`; one Add a resident sheet H20, S76 `aPay` + S77 `aCases` removed (console only), H17 retired; tenants get only H5; app −3; no SQL) | Design + Build | Feature file `docs/features/F25-restore-missing-screens.md` |
| F26 | Founder's prototype review, round 1: 20 UX changes (search map icon, near me + price sort, building view inline, week menu, VERIFIED badge, contact after hold, grouped owner Today, resident My stay + Find a bed…) | **Design approved** · founder 2026-10-06 · **Building** (prototype first) | Build + Design | Spec `F26-founder-review-1.md`. Approve on the proposal canvas → main canvas → prototype → main |
| F27 | Save food: "Are you eating?" per meal, owner headcount, plates saved | **Designing** · 2026-10-06 (founder idea) | Design → Build | Spec `F27-save-food.md`. Design only until the founder approves |

## Now (2026-10-03)
| Next | Who |
|---|---|
| Code cleanup, no UI change (lints, dead code, split big files, efficiency, `tools/check.sh`, SessionStart hook) | Build |
| Run SQL steps 4d → 4zc, test the newest APK, open Play Console + domain + map key + upload key | Founder (`FOUNDER-TODO.md`) |
| Answer the money questions Q1–Q9 | Founder (`docs/finance/plan.md` §0) |
| First 3–5 live hostels in one area, then tenant marketing | Founder + Marketing (`docs/marketing/launch-plan.md`) |
| Play closed test (12 testers, 14 days), then production | Founder + Build |

## Open questions for the founder
Money questions Q1–Q9 with recommendations: `docs/finance/plan.md` §0. Marketing M1–M3: `docs/marketing/README.md`.
Kept out by Build until confirmed: Building view, owner corridor floor plan, menu week table (dropped in the F22 redesign).

## Ideas (not planned yet)
From the first prototype: compare hostels, "make an offer", safety tab, SOS / emergency, move-in handover, parent view of a stay,
owner staff / mess headcount / expenses and P&L, chains of hostels, bed-level pricing, a room notice board.

## Links
- **F21 Simpler UI (Design approved by the founder, 2026-10-02):** before → after demo https://claude.ai/artifact/DNTXZPEsMZTRSisLqvpAhG · full set https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7
- **F20 Reminders (Me → Reminders, water settings, add reminder, notifications with Done/Snooze, Today card, first-time offer; Design approved · 2026-10-02):** https://claude.ai/artifact/U9TnnagapmbzjJt9tM6K7K
- **F19 Residents fix their room layout (any room in the hostel, lock sheet + try mode for visitors, quick fixes, photo, “Checked by N residents”, limit + mute, owner compare, console; Design approved · 2026-10-02):** https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR
- **F18 Real app v2 (sign in, role gates, empty states, map v2, owner layout editor, photos, saved, delete v2, team console, small UX; Design approved · 2026-10-02):** https://claude.ai/artifact/BESe9fQLT3m86BqgihRVU1
- **Screens count (Design, 2026-10-03, matched 1:1 to `docs/SCREENS.md`):** App 179 · Canvas 179 (+46 variants, +23 dark, +9 not counted: cover, logo, Android splash, poster, tablet layout, 3 system notifications, old prototype page at the site root kept by founder decision) · **+223 archive** (earlier designs + retired boards, not counted) (earlier designs, not counted). Every board title starts with its SCREENS id (`[S8]`, `[H18]`, `[T3]`, `[C5]`, `[W4]`) or `[variant of …]` / `[dark]` / `[not counted · …]`. Map: F24 Design section, v27.
- **Hostelzy · Main design** (moved to the Design chat's account 2026-10-03; old copy QscJkLoFAh1MEHCZ1ckLgB is read-only): https://claude.ai/artifact/6n9U2zJw3jri1SeAUz1gCx
- **Design book (all designs in one place, for the team):** https://claude.ai/artifact/VV4W8tvmbEGf7YnX66ZUJB
- Design handoff: `project/HostelzyApp.dc.html`, `chats/chat1.md`
- Deals mockups: https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn
- Enquiries & Residents mockups (F05, F06): https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B
- AC / Non-AC rooms mockups (F16): https://claude.ai/artifact/1orwCNMz68vVRrMhfqtpKV
- Room layouts mockups (F12): https://claude.ai/artifact/8uEkfu5EzRsDeZrkb8Gjaz
- Plan summary page: https://claude.ai/artifact/P8dsEAYo1GtvDyEc6SZN6y
- Architecture page: https://claude.ai/artifact/3mqzfR9Dec8azyaExbgcFP
- Fair Play mockups (F07): https://claude.ai/artifact/1a7M3JyP9Vxy2kBataCXZ5
- Reviews mockups (F08): https://claude.ai/artifact/SrKtvDbCkUG4ThnkdXsZ7F
- Stay Rewards mockups (F09): https://claude.ai/artifact/Fqh4QhVks7STMjaktHqpja
- Owner Plan mockups (F10): https://claude.ai/artifact/H9qRG67RPK2W5zN1ssYY4N
- Onboarding mockups (F14): https://claude.ai/artifact/ANjRUNhkyGSzeCLQNFVm4T
- Make It Real mockups (F17): https://claude.ai/artifact/7deh6fqgzmxdytYgjnwuhz
- Play Store Screens mockups (F15): https://claude.ai/artifact/PBCza1yUDPzNVc2QHDrAN4
