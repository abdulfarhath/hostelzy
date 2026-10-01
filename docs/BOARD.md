# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Only the founder approves (spec, design, merge). Update this table whenever a feature moves.

| ID | Feature | Stage | Owner chat | Notes |
|---|---|---|---|---|
| F01 | Core app from the Claude Design handoff (20 screens, 3 roles) | **Shipped** | Build | On `main`, APK `apk-1` |
| F02 | Fix the advance model (₹3,000 advance + exit maintenance) | **Shipped** · merged 2026-10-02 | Build | PR #1 squash-merged by founder's instruction; APK builds from `main` |
| F03 | Hostelzy deals: owner deal menu + tenant comparison + badges | **Design approved** · 2026-10-02 | Build | Mockups 1, 2, 4 in the Deals canvas, updated 2026-10-02 (6-month headline, max 3 deals, owner number after hold) |
| F04 | Book with the advance, deal locked, HZ code | **Design approved** · 2026-10-02 | Build | Mockup 3 in the Deals canvas, updated 2026-10-02 (pay the owner, free hold, no ₹299 hold) |
| F05 | Enquiry flow (HZ code before WhatsApp, owner enquiry list) | **Design approved** · 2026-10-01 | Build | Boards 1–3 in the Enquiries & Residents canvas (2026-10-01). Draft code on branch `draft/f05-enquiries` (unapproved) |
| F06 | Owner resident list + phone confirmation + Via Hostelzy / Direct matching | **Design approved** · 2026-10-01 | Build | Boards 4–7 in the Enquiries & Residents canvas (2026-10-01). Matching window 60 days (decided 2026-10-02) |
| F07 | Fair Play rules, collusion checks, cases, strikes | **Design ready** · 2026-10-02 | Design | Fair Play canvas. Awaiting founder approval |
| F08 | Verified-resident reviews + Hostelzy score ranking | **Spec ready** | Design | |
| F09 | Stay Rewards (next-stay discount, Trusted tenant, referrals) | **Spec ready** | Design | Decided 2026-10-02: ₹100 next-stay discount |
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Spec ready** | Design | Decided 2026-10-02: flat plan ₹499 / ₹999 / ₹1,499, 30-day trial |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Merged into F12** | — | The F12 Room tab is the seat map |
| F12 | Room layouts (Hostelzy draws) + tenant Room tab (seat map, fans, AC, windows, washroom) | **Design approved** · 2026-10-02 (standing approval) | Build | Boards 1–6 in the Room Layouts canvas |
| F13 | Backend: Supabase, real OTP, live sync, push | **Spec ready** · blocked | Build | Needs Supabase, Firebase, MSG91 accounts |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Spec ready** · 2026-10-02 | Design | Visits start now with a visit kit; app import after F13 |
| F16 | AC / non-AC room types, pricing grid and filter | **Design approved** · 2026-10-02 | Build | Boards 1–6 in the AC / Non-AC Rooms canvas (2026-10-02). Touches F03, F04, F12. No position-based pricing |
| F15 | Play Store launch: settings, account deletion, permissions, privacy | **Spec ready** · 2026-10-02 | Design | In-app screens. Store setup needs Play account + domain |

## Plan (founder, 2026-10-02)
**Standing approval (founder, 2026-10-02):** every design is approved when it is finished, and Build
merges its own PRs once analyze and tests pass. See DECISIONS.md.

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
- Fair Play mockups (F07): https://claude.ai/artifact/1a7M3JyP9Vxy2kBataCXZ5
