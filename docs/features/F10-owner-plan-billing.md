# F10 · Owner plan and UPI payment check

**Stage:** Design approved · 2026-10-02 (founder: "approve all")

## Problem
Hostelzy earns from owners without holding money and without a company.

## What it does
- Flat plan by size: up to 30 beds ₹499/mo, 31–80 ₹999/mo, 80+ ₹1,499/mo. 30-day free trial.
- Owner → Plan: current plan, invoice with prefilled UPI QR (amount + invoice code), "I've paid" with 12-digit UTR, status Due → Checking → Paid.
- Founder admin: invoices with UTR, Mark paid / Not received.
- Overdue: reminder after 5 days; deals paused after 15.

## Rules
- Never trust screenshots; match UTR in the bank or merchant app.

## Open questions
None. Plan A decided 2026-10-02.

## Design
Canvas https://claude.ai/artifact/H9qRG67RPK2W5zN1ssYY4N. **Design approved by the founder on 2026-10-02.**

1. **Owner: Manage → Your plan.** Trial card ("18 days left · ends 2 Nov · first invoice ₹999"), the three plans by size (up to 30 beds ₹499, 31–80 ₹999 marked "Your plan · 32 beds", 80+ ₹1,499 with a featured spot), what's included ("No commission · Hostelzy never touches your tenants' money"), and the invoice list.
2. **Owner: invoice with UPI QR.** HZ-INV-1024, ₹999 due 2 Nov. The QR fills in the amount and the invoice code as the note. Pay to "Hostelzy · [HOSTELZY UPI ID]" (placeholder until you have the UPI ID). Open UPI app / I've paid.
3. **Owner: I've paid.** Due → Checking → Paid steps, a 12-digit UTR field, "Where to find it" help, and "No screenshots needed".
4. **Owner: payment status** (tweak Checking / Paid / Not received). Checking keeps the listing live; Paid offers a receipt; Not received offers Fix the UTR / WhatsApp Hostelzy.
5. **Owner: overdue** (tweak 5 days / 15 days late), shown on owner Today. At 5 days: a reminder banner ("Pay by 17 Nov to keep your deals showing"). At 15 days: "Deals paused: tenants see walk-in prices only. Listing, holds and residents keep working." Pay ₹999 / I've paid.
6. **Founder admin: payments** (1440 × 900). Tiles: to check, paying, on trial, overdue, this month's total. Table: hostel, invoice, amount, UTR, sent, status, with Mark paid / Not received / Send reminder. Header rule: "Match every UTR in the bank or merchant app. Never trust screenshots."
- Dark mode: board "2 in dark mode". Every board has a Dark tweak.

**Updated 2026-10-02:** board 1 shows a "Credit · ₹100 Member reward" line (F09). **Still open:** the UPI ID for the QR (placeholder until the founder decides).

## Build
_Not started._
