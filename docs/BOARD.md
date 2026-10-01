# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Only the founder approves (spec, design, merge). Update this table whenever a feature moves.

| ID | Feature | Stage | Owner chat | Notes |
|---|---|---|---|---|
| F01 | Core app from the Claude Design handoff (20 screens, 3 roles) | **Shipped** | Build | On `main`, APK `apk-1` |
| F02 | Fix the advance model (₹3,000 advance + exit maintenance) | **Shipped** · merged 2026-10-02 | Build | PR #1 squash-merged by founder's instruction; APK builds from `main` |
| F03 | Hostelzy deals: owner deal menu + tenant comparison + badges | **Built** (2026-10-02) | Build | PR #5 on `feature/f03-deals` (includes #2, #3, #4; merge those first). Waiting for founder to check and merge |
| F04 | Book with the advance, deal locked, HZ code | **Built** (2026-10-02) | Build | Branch `feature/f04-booking` (on top of #5; merge #2–#5 first). Waiting for founder to check and merge |
| F05 | Enquiry flow (HZ code before WhatsApp, owner enquiry list) | **Built** (2026-10-01) | Build | PR #2 on `feature/f05-enquiries`. Section (not tile), green note: defaults, switchable. Waiting for founder to check and merge |
| F06 | Owner resident list + phone confirmation + Via Hostelzy / Direct matching | **Built** (2026-10-01) | Build | PR #3 on `feature/f06-residents` (on top of F05, PR #2; merge #2 first). Matching window 60 days (decided 2026-10-02). Waiting for founder to check and merge |
| F07 | Fair Play rules, collusion checks, cases, strikes | **Spec ready** | Design | Decided 2026-10-02: 3 strikes, no move-off fee, phone after hold (tenant told why) |
| F08 | Verified-resident reviews + Hostelzy score ranking | **Spec ready** | Design | |
| F09 | Stay Rewards (next-stay discount, Trusted tenant, referrals) | **Spec ready** | Design | Decided 2026-10-02: ₹100 next-stay discount |
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Spec ready** | Design | Decided 2026-10-02: flat plan ₹499 / ₹999 / ₹1,499, 30-day trial |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Merged into F12** | — | The F12 Room tab is the seat map |
| F12 | Room layouts (Hostelzy draws) + tenant Room tab (seat map, fans, AC, windows, washroom) | **Design ready** · 2026-10-02 | Design | Boards 1–6 in the Room Layouts canvas. Awaiting founder approval |
| F13 | Backend: Supabase, real OTP, live sync, push | **Spec ready** · blocked | Build | Needs Supabase, Firebase, MSG91 accounts |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Spec ready** · 2026-10-02 | Design | Visits start now with a visit kit; app import after F13 |
| F16 | AC / non-AC room types, pricing grid and filter | **Built** (2026-10-02) | Build | PR #4 on `feature/f16-ac-rooms`. Deal display waits for F03. Waiting for founder to check and merge |
| F15 | Play Store launch: settings, account deletion, permissions, privacy | **Spec ready** · 2026-10-02 | Design | In-app screens. Store setup needs Play account + domain |

## Plan (founder, 2026-10-02)
1. **Design** designs everything planned, in this order: F03 + F04 (updated) → F12 → F07 → F08 →
   F09 → F10 → F14 → F15. (F16, F05, F06 done.)
2. **Founder** reviews and approves the designs.
3. **Build** builds approved features in this order: F02 (merged) → F05 → F06 → F16 → F03 + F04 →
   F08 → F07 → F09 → F10 → F12 → F14 → F15, then F13 backend when the accounts exist.

## Open questions for the founder
All 17 earlier questions are answered or decided (see `DECISIONS.md`, 2026-10-01 and 2026-10-02).

18. ~~F14 questions~~ **Decided 2026-10-02 (see DECISIONS.md).**

## Links
- Design handoff: `project/HostelzyApp.dc.html`, `chats/chat1.md`
- Deals mockups: https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn
- Enquiries & Residents mockups (F05, F06): https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B
- AC / Non-AC rooms mockups (F16): https://claude.ai/artifact/1orwCNMz68vVRrMhfqtpKV
- Room layouts mockups (F12): https://claude.ai/artifact/8uEkfu5EzRsDeZrkb8Gjaz
- Plan summary page: https://claude.ai/artifact/P8dsEAYo1GtvDyEc6SZN6y
- Architecture page: https://claude.ai/artifact/3mqzfR9Dec8azyaExbgcFP
