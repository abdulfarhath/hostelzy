# F05 · Enquiry flow

**Stage:** Spec ready

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
Needs a small mockup for the owner Enquiries section. Draft code: branch `draft/f05-enquiries` (unapproved).

## Build
_Not started._
