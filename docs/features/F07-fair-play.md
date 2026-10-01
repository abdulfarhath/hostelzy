# F07 · Fair Play rules and collusion checks

**Stage:** Design approved · 2026-10-02 (founder: "approve all")

## Problem
Owner and tenant may agree to join off-app with the deal to skip Hostelzy.

## What it does
- Owner signup: Fair Play rules accepted by OTP.
- Signals: tenant held/enquired then added as Direct; hold cancelled and same bed taken within 7 days; app tenant never added but says "Yes, I joined"; Direct resident paying the deal price; owner declining holds while occupancy rises; tenant report "owner asked me to skip the app".
- Case flow: ask tenant (one tap) → owner gets evidence + 48 h to explain → founder decides → strike or close.
- Strikes (3): warning → deals hidden 30 days → removed. No move-off fee.
- Owner's phone shows only after a hold. Hostel page tells the tenant why ("Owner's number shows
  after you hold a bed. Talking through Hostelzy keeps your deal and your ₹100 reward.").

## Rules
- Penalties capped and fair (lesson from Urban Company).

## Open questions
None. Decided 2026-10-02.

## Design
Canvas https://claude.ai/artifact/1a7M3JyP9Vxy2kBataCXZ5. **Design approved by the founder on 2026-10-02.**

1. **Owner: Fair Play rules + OTP accept** (step 3 of signup). Four numbered rules: add every resident within 3 days; never take a Hostelzy tenant off the app; honour the deal and exit rules; keep beds and prices up to date. Then the strike ladder (1 warning · 2 deals hidden 30 days · 3 removed, "No fines"; 48 hours to explain), the OTP code and "I accept the Fair Play rules".
2. **Tenant: owner's number after a hold** (tweak Before / After a hold). Before a hold: masked number with a lock, the explainer line "Owner's number shows after you hold a bed. Talking through Hostelzy keeps your deal and your ₹100 reward.", and "Enquire on WhatsApp · saved with an HZ code" (F05). After a hold: the number shows, with Call and WhatsApp.
3. **Tenant: "Did you join Anjani Residency?"** A sheet after a hold ends: Yes, I joined / No / Still deciding. Note that answering unlocks the ₹100 Member reward. Link: "The owner asked me to skip the app".
4. **Tenant: report.** Options (pay without Hostelzy, lower price to skip the app, cancel my hold, something else) and an optional note. "The owner never sees your name… you keep your deal and reward either way."
5. **Owner: case FP-0142.** 48-hour countdown, evidence timeline from Hostelzy records (enquiry, hold, cancel, added as Direct, tenant said yes), then "Change Ravi to Via Hostelzy", an explanation box, a photo as proof, and Send my reply. Footer: "You have 0 strikes · Strike 1 is only a warning".
6. **Owner: strike notices** (tweak Strike 1 / 2 / 3). Strike ladder filled in, what happened, what changes, and links to the case and to reply.
7. **Founder admin: Cases** (1440 × 900). Queue with New / Waiting / Decide / Closed, one row per signal type from the spec. The case in the middle: signals, the owner's reply, the tenant's answer, then Close · no issue / Ask for more / Strike 1. Right: owner history and the decision rules.
- Dark mode: board "5 in dark mode". Every board has a Dark tweak.

**Updated 2026-10-02 for DECISIONS "Design follow-ups"**
- Board 5: "Change Ravi to Via Hostelzy · a mistake fixed within 48 h: case closed, no strike"; footer "3 fixes in 6 months = 1 warning". Board 1 note says the same.

## Build
_Not started._
