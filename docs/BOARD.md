# Hostelzy board

Stages: `Idea → Spec ready → Designing → Design ready → Design approved → Building → Built → Shipped`.
Only the founder approves (spec, design, merge). Update this table whenever a feature moves.

| ID | Feature | Stage | Owner chat | Notes |
|---|---|---|---|---|
| F01 | Core app from the Claude Design handoff (20 screens, 3 roles) | **Shipped** | Build | On `main`, APK `apk-1` |
| F02 | Fix the advance model (₹3,000 advance + exit maintenance) | **Spec ready** · no design needed | Build | Copy/data change across tenant, resident, owner screens |
| F03 | Hostelzy deals: owner deal menu + tenant comparison + badges | **Design ready** | Design | Mockups 1, 2, 4 in the Deals canvas. Waiting on open questions 1–3 |
| F04 | Book with the advance, deal locked, HZ code | **Design ready** | Design | Mockup 3 in the Deals canvas. Waiting on open question 4 |
| F05 | Enquiry flow (HZ code before WhatsApp, owner enquiry list) | **Design ready** | Design | Boards 1–3 in the Enquiries & Residents canvas (2026-10-01). Draft code on branch `draft/f05-enquiries` (unapproved) |
| F06 | Owner resident list + phone confirmation + Via Hostelzy / Direct matching | **Design ready** | Design | Boards 4–7 in the Enquiries & Residents canvas (2026-10-01). Waiting on open question 8 |
| F07 | Fair Play rules, collusion checks, cases, strikes | **Spec ready** | Design | Waiting on open questions 9, 11, 12 |
| F08 | Verified-resident reviews + Hostelzy score ranking | **Spec ready** | Design | |
| F09 | Stay Rewards (next-stay discount, Trusted tenant, referrals) | **Spec ready** | Design | Waiting on open question 10 |
| F10 | Owner plan + UPI payment check (owner billing, founder admin) | **Spec ready** | Design | Waiting on open question 7 |
| F11 | Seat-map bed booking (pick a bed like a movie seat) | **Idea** | Ideas | To be worked out in the Ideas chat |
| F12 | Room layout editor (owner) + room layers (tenant: fans, AC, windows, washroom) | **Idea** · spec in progress | Ideas | Problems listed in the feature file; waiting on 5 founder answers |
| F13 | Backend: Supabase, real OTP, live sync, push | **Spec ready** · blocked | Build | Needs Supabase, Firebase, MSG91 accounts |
| F14 | Multi-hostel + "Add hostel" tool + owner invite QR | **Idea** | Ideas | Needed before onboarding 20 hostels |
| F16 | AC / non-AC room types, pricing grid and filter | **Spec ready** | Design | Touches F03, F04, F12. No position-based pricing |
| F15 | Play Store launch: signing, privacy policy, account deletion, closed test | **Idea** | Ideas | Needs Play account + domain |

## Suggested order
F02 → F16 → F03 + F04 → F05 → F06 → F08 → F07 → F09 → F10 → F13/F14 → F15. F11 and F12 after they are specced.

## Open questions for the founder
1. Headline saving: over 12 months, 6 months, or upfront only? (F03)
2. Is the 6-deal menu right? Any local deals to add? (F03)
3. Max 3 deals per owner? (F03)
4. Keep the free 1-hour hold next to "Pay advance"? Drop the ₹299 paid hold? (F04)
5. Notice period 15 or 30 days? Fee due on the joining date or the 1st? (F02)
6. Electricity and food included in the fee, or extra? (F02)
7. Owner pricing: A flat monthly plan, or B per matched join? (F10)
8. Matching window: 30 or 60 days? (F06)
9. Strikes: 3, or ban on the 2nd? (F07)
10. ₹300 next-stay discount paid by Hostelzy: OK? (F09)
11. Optional move-off fee for owners: yes or no? (F07)
12. Show the owner's phone only after a hold: yes or no? (F07)
13. Room layouts: does the founder draw them during onboarding visits, or owners from day one? (F12)
14. Custom room-shape requests: free during the pilot, 48-hour turnaround? (F12)
15. Women's PGs: layouts only after login, floor plans only after a hold? (F12)
16. Phase-1 layout items: add power sockets now? (F12)
17. New room view replaces the bed picker's Plan tab, or sits beside it? (F12)

## Links
- Design handoff: `project/HostelzyApp.dc.html`, `chats/chat1.md`
- Deals mockups: https://claude.ai/artifact/F4zedqxzj4cfsrJe6Y92Wn
- Enquiries & Residents mockups (F05, F06): https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B
- Plan summary page: https://claude.ai/artifact/P8dsEAYo1GtvDyEc6SZN6y
- Architecture page: https://claude.ai/artifact/3mqzfR9Dec8azyaExbgcFP
