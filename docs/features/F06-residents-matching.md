# F06 · Resident list and join matching

**Stage:** Built (2026-10-01) · waiting on founder merge

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
Branch `feature/f06-residents` (2026-10-01). Built on F05 (`feature/f05-enquiries`, PR #2) for
the enquiry matching, with F02 (`feature/f02-advance-model`, PR #1) merged in for the money terms.
Merge #1 and #2 first; this PR's own diff is then F06 only.

**Model.** `Resident` gains phone, `via` (hz / direct / before), `since`, matched `ref`,
`confirmed`, advance and join time; tag = Waiting OTP until confirmed. `AppState.matchFor()`:
a phone counts as **Joined via Hostelzy** if it enquired about (F05), held or booked a bed at the
hostel within `matchWindowDays` (**60 days**, decided 2026-10-02) before joining; otherwise **Direct**.
Sample data: Anjani's 23 taken beds now have residents except 103-A and 202-B (flagged); the
first import is "Before Hostelzy"; Sai Kiran and Nikhil Goud are Via Hostelzy, Teja Naidu
Direct, Ravi Teja (303-D, HZ-4821) Waiting OTP. Two invite sign-ups wait for approval
(Abhishek P 103-A, Naveen Goud 202-B). New residents count as paid at move-in (advance + first
month, F02), so the owner's Rent pending doesn't change; Rent → Collected now includes the
first import.

**Screens**
4. Owner · Manage → **Residents** (new first segment; Manage now opens on it). Red banner for
   taken beds with no resident and the add-by date (today + 2 days, `addResidentDays`), Add
   resident, Invite QR, filter chips with live counts, rows with initials, bed, joined / since,
   HZ code when matched, and the four tags. Waiting OTP first, then new joins, then the import.
5. Owner · **Add a resident** sheet (`addR`): name, WhatsApp number with the live match line,
   bed chips (beds with no resident first, in red, then free beds), Joined on (Today /
   Yesterday / Pick date → last week's dates), monthly fee (from the room) and advance (from
   F02 terms), "Add and send code" → Waiting OTP.
6. Owner · **Invite residents** (`oInvite`): placeholder QR, `hostelzy.in/j/ANJ-7Q2`, Share
   link / Print poster (toasts), the 3 steps, "Waiting for you" with Approve / ✕. Approving
   adds a confirmed resident, matched like any other.
7. Resident · **Confirm your stay** (`rConfirm`): details incl. "When you leave" from F02 terms
   (₹1,000 kept · ₹2,000 back · 30 days notice), 6-digit code, Yes, this is me / Something's
   wrong (WhatsApp to the owner), then "You're confirmed" and Go to my stay.
- The older "Add booking" sheet now also matches the number and adds the tenant as Waiting OTP.

**Design defaults (unanswered design questions)**
- Residents is a segment in Manage (not a sixth tab).
- "Joined via Hostelzy" is owner-only; the resident's confirm screen doesn't show it.
- Window: 60 days (decided 2026-10-02), `matchWindowDays` in `lib/data.dart`.

**Not built yet:** the 3-day rule isn't enforced (only shown as the banner's date); real QR,
share and print come with the backend (F13).

**Tests:** `test/flows_test.dart` → "owner adds a resident; phone matched to the enquiry;
resident confirms" and "invite QR: owner approves or removes sign-ups". The complaints test now
taps the Complaints segment (Manage opens on Residents). `flutter analyze` clean,
`flutter test` 14/14.
