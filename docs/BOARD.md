# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Only the founder approves (spec, design, merge). Update this table whenever a feature moves.

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
| F13 | Backend: Supabase, real OTP, live sync, push | **Building** · part 1, B3, B5 (server rules + push), B6 (live sync), B7 (photos + team console), C (account deletion, invites, live writes, server sign-ups) merged 2026-10-02; push confirmed end to end on apk-46 | Build | Sign in with Google (phone typed, not verified). Not on the server yet: holds/booking, owner resident list, owner edits (rooms, rent, deals, rules, layouts, profile, UPI), reviews, Fair Play reports/cases, Stay Rewards, owner plan invoices in the app, managers/multi-hostel. Details in the feature file |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f14-onboarding`. In memory until F13 (backend) |
| F16 | AC / non-AC room types, pricing grid and filter | **Shipped** · merged 2026-10-02 | Build | PR #4 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F15 | Play Store launch: settings, account deletion, permissions, privacy | **Shipped** · merged 2026-10-02 | Build | Branch `feature/f15-play-store`. Outside-the-app checklist (Play account, domain pages, upload key, SHA-1) in the feature file |
| F17 | Make it real: remove demo/fake behaviour (honest payments, real WhatsApp/map/QR, no demo login) | **Shipped** · parts 1–3 + leftovers merged 2026-10-02 | Build | Honest login, real links, holds expire, UPI → UTR → owner confirms, real map, large screens with a left nav rail, honest toasts, owner screens follow the selected hostel. Group B needs F13 |
| F18 | Real-user bug fixes (back button, stay logged in, own name/phone, gated roles, crashes, keyboard, map location + area, owner edits layouts) | **Built** · all 10 groups merged 2026-10-02 (APK `apk-32`) | Build | From the founder's phone test of apk-29. Photos/gallery, delete v2 and the team console need the backend (F13 part 2) |
| F19 | Residents fix room layouts (any room in their hostel → owner approves; others see a "residents only" nudge) | **Built** · 2026-10-02 (v1 core merged #60; v1 extras merged #66) | Build | Design: https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR · Founder idea. Reward for approved fixes: founder to decide |
| F20 | Reminders: water every N min, my own tasks, hostel meal/rent reminders (on the phone) | **Built** · 2026-10-02 (PR feature/f20-reminders) | Build | Founder idea. Local notifications, works offline. Backup to the profile: follow-up PR (FOUNDER-TODO 4p) |
| F21 | Simpler UI/UX: one job per home screen, guest browsing, plain words, honest data, Telugu, accessibility | **Design approved** · founder, 2026-10-02 · **Wave 1 merged** (#65) · **Wave 2 merged** (#67) · **Wave 3 merged** (#68) · **Wave 4 Built** (PR feature/f21-w4) | Founder (W2–W4) | 24 fixes in 4 waves; wave 1 = fake-data bugs |
| F22 | Redesign every screen in the F21 style (simple, one job per screen, plain words) | **Designing** · Area 1 Tenant designed 2026-10-02 and **Built** 2026-10-02 (PR from `feature/f22-tenant`) | Design → Build | Founder: "your own decisions, never take my approval". Area by area, built in parallel |

## Plan (founder, 2026-10-02)
**Standing approval (founder, 2026-10-02):** every design is approved when it is finished, and Build
merges its own PRs once analyze and tests pass. See DECISIONS.md.

1. **Design** designs everything planned, in this order: F03 + F04 (updated) → F12 → F07 → F08 →
   F09 → F10 → F14 → F15. (F16, F05, F06 done.)
2. **Founder** reviews and approves the designs.
3. **Build** builds approved features in this order: F02 (merged) → F05 → F06 → F16 → F03 + F04 →
   F08 → F07 → F09 → F10 → **F17** → app icon → F12 → F14 → F15, then F13 backend when the accounts exist.

## Open questions for the founder
All 17 earlier questions are answered or decided (see `DECISIONS.md`, 2026-10-01 and 2026-10-02).

18. ~~F14 questions~~ **Decided 2026-10-02 (see DECISIONS.md).**

## Links
- **F21 Simpler UI (Design approved by the founder, 2026-10-02):** before → after demo https://claude.ai/artifact/DNTXZPEsMZTRSisLqvpAhG · full set https://claude.ai/artifact/4vYvJvF7cBs8CphXFzjBY7
- **F20 Reminders (Me → Reminders, water settings, add reminder, notifications with Done/Snooze, Today card, first-time offer; Design approved · 2026-10-02):** https://claude.ai/artifact/U9TnnagapmbzjJt9tM6K7K
- **F19 Residents fix their room layout (any room in the hostel, lock sheet + try mode for visitors, quick fixes, photo, “Checked by N residents”, limit + mute, owner compare, console; Design approved · 2026-10-02):** https://claude.ai/artifact/9apSaAYTzGsS8EdFQTZNBR
- **F18 Real app v2 (sign in, role gates, empty states, map v2, owner layout editor, photos, saved, delete v2, team console, small UX; Design approved · 2026-10-02):** https://claude.ai/artifact/BESe9fQLT3m86BqgihRVU1
- **All screens (the app as it is today, redrawn from the code 2026-10-02 after F18 and #37–#54, plus F19/F20 (built): 178 screens, 35 Updated, 70 New, light + dark; Design approved · standing approval):** https://claude.ai/artifact/QscJkLoFAh1MEHCZ1ckLgB
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
