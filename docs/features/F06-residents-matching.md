# F06 · Resident list and join matching

**Stage:** Design approved (founder, 2026-10-01)

## Problem
Owners can take app tenants off-app. Matching phone numbers shows who joined via Hostelzy.

## What it does
- Owner → Residents: add name, phone, bed, join date, fee, advance. Or invite QR/link residents scan to self-register; owner approves.
- Resident confirms by OTP; only then counted.
- Match: phone enquired/held/booked at this hostel within the window before join date → "Joined via Hostelzy", else "Direct".
- Taken beds without a verified resident are flagged.

## Rules
- First import when a hostel joins is grandfathered.
- New residents must be added within 3 days.

## Open questions
None. Matching window 60 days (decided 2026-10-02).

## Design
Canvas https://claude.ai/artifact/ESZuLcHxCsxE8bgavAFj2B (row "F06", boards 4–7). **Design approved by the founder on 2026-10-01**, as shown (default tweak settings). The design questions below were not answered at approval; build the defaults shown and keep them easy to change.

4. **Owner: Manage → Residents.** New first segment in Manage (Residents · Complaints · Menu · Rules). Red banner for taken beds with no resident ("Beds 204-A and 301-C. Add who's staying there by Sat 3 Oct."). Add resident (red) + Invite QR. Filter chips with counts: All, Via Hostelzy, Direct, Waiting OTP, Before Hostelzy. Rows: initials, name, bed, join date (+ HZ code when matched), tag. Interactive filters.
   - Tags: **Via Hostelzy** (black fill), **Direct** (outline), **Waiting OTP** (red tint, not counted yet), **Before Hostelzy** (grey; the grandfathered first import).
5. **Owner: add a resident (sheet).** Name, WhatsApp number, live match line under the number ("Joined via Hostelzy. This number asked about your hostel on Hostelzy today (HZ-4821)" or "Direct. No Hostelzy enquiry, hold or booking from this number in the last 30 days"), bed chips (beds with no resident first, in red), joined on, monthly fee, advance paid. CTA "Add and send code". Tweaks: Match (Via Hostelzy / Direct), Window (30 / 60 days, BOARD Q8).
6. **Owner: invite QR.** QR + link `hostelzy.in/j/ANJ-7Q2`, Share link / Print poster, 3 steps (scan → code → you approve), "Waiting for you" list with Approve / ✕. Interactive.
7. **Resident: confirm your stay.** "Srinivas added you at Anjani Residency": name, bed, joined on, fee, advance, exit terms. 6-digit WhatsApp code, "Yes, this is me" / "Something's wrong". After confirming: "You're confirmed". Interactive.
- Dark mode: board "F06 · 4 in dark mode". Every board has a Dark tweak.

**Design questions for the founder**
- Residents as a segment in Manage (shown), or a sixth place of its own? The tab bar already has five.
- Board 7 shows "30 days notice" and "₹1,000 kept" as sample values; BOARD Q5 (notice period) is still open.
- Should a resident ever see "Joined via Hostelzy"? The design keeps the tag owner-only.

## Build
_Not started._
