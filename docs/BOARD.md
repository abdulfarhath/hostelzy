# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Only the founder approves (spec, design, merge). Update this table whenever a feature moves.

| ID | Feature | Stage | Owner chat | Notes |
|---|---|---|---|---|
| F01 | Core app from the Claude Design handoff (20 screens, 3 roles) | **Shipped** | Build | On `main`, APK `apk-1` |
| F02 | Fix the advance model (₹3,000 advance + exit maintenance) | **Built** · no design needed | Build | PR #1 on `feature/f02-advance-model`, 10/10 tests pass. Waiting for founder to check and merge |
| F03 | Hostelzy deals: owner deal menu + tenant comparison + badges | **Design ready** | Design | Mockups 1, 2, 4 in the Deals canvas. Q1–3 decided 2026-10-02: update mockups (6-month headline, max 3 deals), then founder approves |
| F04 | Book with the advance, deal locked, HZ code | **Design ready** | Design | Mockup 3 in the Deals canvas. Q4 decided: drop ₹299 hold, keep free 1-h hold. Update mockup, then founder approves |
| F05 | Enquiry flow (HZ code before WhatsApp, owner enquiry list) | **Design approved** · 2026-10-01 | Build | Boards 1–3 in the Enquiries & Residents canvas (2026-10-01). Draft code on branch `draft/f05-enquiries` (unapproved) |
| F06 | Owner resident list + phone confirmation + Via Hostelzy / Direct matching | **Design approved** · 2026-10-01 | Build | Boards 4–7 in the Enquiries & Residents canvas (2026-10-01). Matching window 60 days (decided 2026-10-02) |
| F07 | Fair Play rules, collusion checks, cases, strikes | **Spec ready** | Design | Decided 2026-10-02: 3 strikes, no move-off fee, phone after hold (tenant told why) |
| F08 | Verified-resident reviews + Hostelzy score ranking | **Spec ready** | Design | |
| F09 | Stay Rewards (next-stay discount, Trusted tenant, referrals) | **Spec ready** | Design | Decided 2026-10-02: ₹100 next-stay discount |
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Spec ready** | Design | Decided 2026-10-02: flat plan ₹499 / ₹999 / ₹1,499, 30-day trial |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Merged into F12** | — | The F12 Room tab is the seat map |
| F12 | Room layouts (Hostelzy draws) + tenant Room tab (seat map, fans, AC, windows, washroom) | **Spec ready** · 2026-10-02 | Design | Design after F16 |
| F13 | Backend: Supabase, real OTP, live sync, push | **Spec ready** · blocked | Build | Needs Supabase, Firebase, MSG91 accounts |
| F14 | Onboarding: Add hostel tool, managers, multi-hostel, invite QR, admin mode | **Idea** · spec in progress | Ideas | Visits start now with a visit kit; app import after F13. 4 founder questions |
| F16 | AC / non-AC room types, pricing grid and filter | **Design ready** | Design | Boards 1–6 in the AC / Non-AC Rooms canvas (2026-10-02). Touches F03, F04, F12. No position-based pricing |
| F15 | Play Store launch: signing, privacy policy, account deletion, closed test | **Idea** | Ideas | Needs Play account + domain |

## Suggested order
F02 → F16 → F03 + F04 → F05 → F06 → F08 → F07 → F09 → F10 → F13/F14 → F15. F12 design after F16.

## Open questions for the founder
All 17 earlier questions are answered or decided (see `DECISIONS.md`, 2026-10-01 and 2026-10-02).

18. F14: which 2 areas first? Start visits now with a visit kit? Manager accounts? Founder alone on visits?

## Links
- Design handoff: `project/HostelzyApp.dc.html`, `chats/chat1.md`
- Deals mockups: https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn
- Enquiries & Residents mockups (F05, F06): https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B
- AC / Non-AC rooms mockups (F16): https://claude.ai/artifact/1orwCNMz68vVRrMhfqtpKV
- Plan summary page: https://claude.ai/artifact/P8dsEAYo1GtvDyEc6SZN6y
- Architecture page: https://claude.ai/artifact/3mqzfR9Dec8azyaExbgcFP
