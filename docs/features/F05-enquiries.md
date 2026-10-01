# F05 · Enquiry flow

**Stage:** Built (2026-10-01) · waiting on founder merge

## Problem
A WhatsApp message can be edited or never sent, so it can't prove a tenant came from Hostelzy.

## What it does
- Tapping "Ask on WhatsApp" / "WhatsApp owner" first records an enquiry: HZ code, name, verified phone, hostel, bed, time.
- WhatsApp sheet shows a green note: "Srinivas has been told on Hostelzy, with your verified number and ref HZ-4821." Message ends with the ref and hostelzy.in/r/HZ-4821.
- Owner Today: "Enquiries from Hostelzy" list with verified phone, New/Contacted, WhatsApp and Call buttons.

## Rules
- One enquiry per tenant + hostel + bed (re-tapping reuses the code).
- Owner rule: not on this list = not from Hostelzy.

## Open questions
- Should Enquiries take a KPI tile on owner Today, or stay a section?

## Design
Canvas https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B (row "F05", boards 1–3). **Design approved by the founder on 2026-10-01**, as shown (default tweak settings). The design questions below were not answered at approval; build the defaults shown and keep them easy to change.

1. **Tenant: WhatsApp sheet.** Opens after "Ask on WhatsApp". Note at the top: "Srinivas has been told on Hostelzy, with your verified number and ref HZ-4821." Prefilled message ends with `Ref HZ-4821 · hostelzy.in/r/HZ-4821`. Open WhatsApp / Copy message, same as today's sheet.
2. **Owner Today: "Enquiries from Hostelzy".** Section under the KPI tiles, above Hold requests. Each row: name, phone with "verified", bed (or "Any bed"), HZ code, time, New/Contacted tag, WhatsApp + Call. WhatsApp is red while New, outline once Contacted (tapping either marks it Contacted). Footer: "Not on this list = not from Hostelzy. Ask for their HZ code." Interactive.
3. **Owner: one enquiry (sheet).** Tap the HZ code: phone verified by OTP, bed asked about, time, where it came from, the message, status. Hint: "If they join, add them in Manage → Residents with this number" (links to F06). WhatsApp, Call, Mark as contacted.
- Dark mode: board "F05 · 2 in dark mode". Every board has a Dark tweak.

**Design questions for the founder**
- Open question above (KPI tile or section): designed as a **section**. Board 2's "Enquiries tile" tweak swaps the Complaints tile for an Enquiries count, so you can compare.
- The tenant note is green as the spec says, but the design rules keep green for savings and deals. Board 1's "Note" tweak shows a neutral version. Pick one.

## Build
Branch `feature/f05-enquiries` (from `main`, 2026-10-01). Built fresh from boards 1–3; the
`draft/f05-enquiries` branch was only used as a reference.

**Model.** `Enquiry` in `lib/data.dart` (HZ code, name, verified phone, hostel, bed or "Any bed",
time, where it came from, message, New/Contacted). `AppState.enquire()` records it **before**
the WhatsApp sheet opens; one enquiry per tenant + hostel + bed (tapping again reuses the code).
Sample data: Ravi Teja HZ-4821, Sandeep Kumar HZ-4817 (new), Imran Shaikh HZ-4809 (contacted);
the tenant's own enquiries start at HZ-4822.

**Screens**
1. Tenant · WhatsApp sheet (from "Ask on WhatsApp" on the hostel page and "WhatsApp owner" on a
   hold): note "Srinivas has been told on Hostelzy, with your verified number and ref HZ-…",
   "To Srinivas · Anjani Residency", message ending `Ref HZ-… · hostelzy.in/r/HZ-…` (also in
   Copy message), footer line.
2. Owner · Today: "Enquiries from Hostelzy" under the KPI tiles, above Hold requests. Rows as
   designed; WhatsApp red while New, outline once Contacted; WhatsApp or Call marks it Contacted;
   "N new" / "All replied"; footer "Not on this list = not from Hostelzy…".
3. Owner · one enquiry (sheet `enq`, opened by tapping the HZ code): Phone, Asked about, When,
   From, Message, Status, the Manage → Residents hint, WhatsApp, Call, Mark as contacted.

**Design defaults (unanswered design questions, easy to change)**
- Enquiries stay a **section**; `enquiriesTile` in `screens_owner.dart` swaps the Complaints tile
  for an Enquiries count.
- Tenant note is **green**; `enquiryNoteGreen` in `shell.dart` gives the neutral version.

**Tests:** `test/flows_test.dart` → "enquiry recorded before WhatsApp; owner sees and contacts it"
and "WhatsApp owner from a hold records the bed". `flutter analyze` clean, `flutter test` 10/10.
Not in this branch: F02's money terms (PR #1), so this branch still shows the old deposit copy
until F02 merges.
