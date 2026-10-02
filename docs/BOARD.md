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
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Design approved** · 2026-10-02 (founder, "approve all") | Build | Owner Plan canvas |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Merged into F12** | — | The F12 Room tab is the seat map |
| F12 | Room layouts (Hostelzy draws) + tenant Room tab (seat map, fans, AC, windows, washroom) | **Design approved** · 2026-10-02 (standing approval) | Build | Boards 1–6 in the Room Layouts canvas |
| F13 | Backend: Supabase, real OTP, live sync, push | **Spec ready** · blocked | Build | Needs Supabase, Firebase, MSG91 accounts |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Design approved** · 2026-10-02 (founder, "approve all") | Build | Onboarding canvas |
| F16 | AC / non-AC room types, pricing grid and filter | **Shipped** · merged 2026-10-02 | Build | PR #4 merged to `main` on the founder's instruction (with uneven floors, PR #7) |
| F15 | Play Store launch: settings, account deletion, permissions, privacy | **Design approved** · 2026-10-02 (founder, "approve all") | Build | Play Store Screens canvas |

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
- Reviews mockups (F08): https://claude.ai/artifact/SrKtvDbCkUG4ThnkdXsZ7F
- Stay Rewards mockups (F09): https://claude.ai/artifact/Fqh4QhVks7STMjaktHqpja
- Owner Plan mockups (F10): https://claude.ai/artifact/H9qRG67RPK2W5zN1ssYY4N
- Onboarding mockups (F14): https://claude.ai/artifact/ANjRUNhkyGSzeCLQNFVm4T
- Play Store Screens mockups (F15): https://claude.ai/artifact/PBCza1yUDPzNVc2QHDrAN4
