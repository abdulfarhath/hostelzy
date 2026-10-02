# F09 · Stay Rewards

**Stage:** Shipped · 2026-10-02

## Problem
Make tenants want every stay recorded on Hostelzy, so collusion costs them.

## What it does
- Member (first stay via Hostelzy): ₹100 off the next Hostelzy hostel's first month, 2-hour free holds.
- Trusted tenant (6 months, rent on time, no owner complaints): badge owners see, lower-advance deals (owner-funded), first look at newly free beds.
- Referral: ₹100 each after the friend's first month.

## Rules
- Hostelzy-funded rewards capped monthly (e.g. ₹3,000).

## Open questions
None. ₹100 decided 2026-10-02.

## Design
Canvas https://claude.ai/artifact/Fqh4QhVks7STMjaktHqpja. **Design approved by the founder on 2026-10-02.**

1. **Tenant: Me → Stay Rewards** (tweak Level: Member / Trusted tenant / Not a member yet).
   - Member: level card ("since 1 Oct · first stay via Hostelzy at Anjani Residency"), ₹100 off your next hostel (paid by Hostelzy, green), 2-hour free holds, and Trusted tenant progress (4 of 6 months: rent on time, no owner complaints, 6 months).
   - Trusted tenant: badge owners see, lower-advance deals, first look at free beds, plus the Member perks.
   - Not a member yet: what you get after a first stay.
   - Every version: invite a friend, code RAVI-100, Share, "₹100 each after your friend's first month", "1 friend joined · ₹100 on the way".
2. **Owner: Trusted tenant badge.** A hold request on owner Today shows a "Trusted tenant" tag; tapping it explains what it means (6 months, rent on time, no complaints, phone verified). It never shows which hostels they stayed at before.
3. **Tenant: 2-hour hold for Members.** The hold sheet: "Free hold · 2 hours (Member perk)" next to "Pay advance ₹3,000 straight to the owner". Note: everyone else gets 1 hour.
4. **Tenant: ₹100 reward at move-in.** Move-in summary: first month ₹6,400, green "Member reward · paid by Hostelzy −₹100", pay ₹6,300. Note that the owner still gets the full ₹6,400.
- Dark mode: board "1 in dark mode". Every board has a Dark tweak.

**Updated 2026-10-02 for DECISIONS "Design follow-ups"**
- Board 4: the owner gives ₹100 off at move-in; "Hostelzy credits that ₹100 on Ramesh's next Hostelzy invoice". No cash from Hostelzy. Perks no longer say "paid by Hostelzy".
- F10 board 1 shows the matching credit line ("Credit · ₹100 · comes off your first invoice").

## Build
Branch `feature/f09-stay-rewards` (2026-10-02), boards 1–4 with the 2026-10-02 follow-ups.

**Model.** Tenant `level` none → member → trusted. A tenant becomes a **Member** after a first stay
through Hostelzy: answering "Yes, I joined" (F07) or moving in from a Hostelzy hold or booking.
Members get 2-hour free holds (`holdSecs`, everyone else 1 hour) and ₹100 off the next hostel's
first month, used once at move-in. The owner gives the ₹100 off and Hostelzy records a ₹100 credit
for that owner's next invoice (`ownerCredits`, used by F10); no cash moves from Hostelzy.
Trusted-tenant progress shows months on time out of 6. Referral code `RAHUL-100`, ₹100 each.

**Screens**
1. Tenant · Me → **Stay Rewards** (`rewards`): level card, perks (Member / Trusted / not a member
   yet), Trusted tenant progress for Members, invite a friend with the code and Share.
2. Owner · hold request with a **Trusted tenant** tag (sample: Karthik M); tap → sheet `trusted`
   with the four checks, "we don't share which hostels…", Confirm hold.
3. Tenant · hold sheet: "Hold free · 2 hours · Member perk" for Members (F04's sheet).
4. Tenant · **Your move-in** (`moveIn`, from "Moving in · see what to pay" on a hold): advance,
   first month, green "Member reward −₹100", Pay at move-in, the owner-credit note, Your reward,
   "I've moved in · open My stay".

**Tests:** `test/flows_test.dart` → "Stay Rewards: Member, 2-hour holds, ₹100 at move-in, Trusted
badge". `flutter analyze` clean, `flutter test` 23/23.


**Share + earned Trusted (2026-10-02, branch `feature/f09-share-trusted`):** "Share" on Stay Rewards opens the phone's share sheet (`share_plus`) with the real referral text and code (also used for the owner's invite link and the rent receipt). **Trusted tenant is computed** from the stay record: Member + 6 months in Hostelzy hostels + rent never late + no owner complaints; otherwise Member, with the progress checks showing the real state (late months, owner complaints). Stay data is sample until the backend keeps it (F13). Test: `Stay Rewards: share my code, Trusted tenant earned from the stay (F09)`.
