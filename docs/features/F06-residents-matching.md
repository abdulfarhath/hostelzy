# F06 · Resident list and join matching

**Stage:** Spec ready

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
BOARD Q8.

## Design
Needs mockups: Residents tab, add resident, invite QR, resident confirmation.

## Build
_Not started._
