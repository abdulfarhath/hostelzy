# F05 · Enquiry flow

**Stage:** Design approved (founder, 2026-10-01)

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
_Not started._
