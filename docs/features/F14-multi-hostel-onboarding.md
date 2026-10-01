# F14 · Onboarding hostels: Add hostel tool, multi-hostel, invite QR

**Stage:** Spec ready · 2026-10-02

## Problem
The founder wants 20 hostels live this month, onboarded in person, mostly alone. Each visit must
be fast, the listing must be accurate from day one, and tenants need enough choice in one area.

## Key insight
The app still runs on sample data. Real hostels need the backend (F13). So visits **start now**
with a paper/phone visit kit (checklist + Google Sheet + photos in a Drive folder per hostel), and
everything is imported into the app once F13 + F14 are built. Owners sign up for a "launch list";
their 30-day trial starts on the day their listing goes live, not on the visit day.

## Where (density beats count)
20 hostels spread over Hyderabad = 1–2 per area = no choice for tenants. Pick **2 clusters**, ~10
hostels each, e.g. **Ameerpet / SR Nagar** (students, coaching) and **Madhapur / Hitec City /
Kondapur** (IT). Tenant marketing starts only in those clusters.

## The visit (~45 min)
1. **Pitch (5 min):** free 30 days, then ₹499/mo; verified enquiries with HZ code; residents app for
   rent and complaints; no commission, Hostelzy never touches the money.
2. **Owner signs up** with OTP, reads and accepts the Fair Play rules (F07) out loud with the founder.
3. **Add hostel** (founder's admin mode, owner watching):
   - Basics: name, gender (men / women / co-living), map pin, area, food, rules, amenities, gate time.
   - **Room generator:** floors × rooms per floor × sharing × AC/non-AC → beds created in one go,
     then fix the odd rooms.
   - **Rate card** (F16): price per sharing × AC/non-AC, advance, maintenance, notice (F02).
   - **Photos taken by the founder** (consistent quality): front, each room type, washroom, food,
     common area. Minimum 8.
   - Room measurements + sketch per room type, so the team can draw layouts (F12).
   - **Current residents** (name, phone, bed): grandfathered as Direct (F06).
   - Optional: pick up to 3 deals (F03).
4. **Leave behind:** printed A4 QR poster for residents ("Join your hostel on Hostelzy: pay rent,
   raise complaints") and a small "Book on Hostelzy" sticker for the gate.

## Rules
- **Goes live only when complete:** owner OTP verified, ≥ 8 photos, every room type priced, bed
  status checked on the visit, map pin checked. Badge: **"Visited by Hostelzy"** with the date.
- **Owner and Manager roles.** Many PGs are run by a manager/warden. The owner can add managers by
  phone: they run beds, residents, enquiries, complaints, food. Only the owner sees billing, deals,
  rate card and Fair Play notices.
- **One owner, many hostels:** a hostel switcher on owner screens; one plan per hostel.
- **Availability stays fresh:** a WhatsApp/push nudge every 3 days ("Still 4 free beds?" Yes /
  Update). Beds not confirmed for 7 days show "Availability not confirmed" and rank lower.
- **Hostelzy admin mode** (founder + team): create draft hostels, hand them to the owner by OTP,
  edit anything, see onboarding progress. Hidden from everyone else.
- Non-exclusive: owners can stay on other sites.

## Owner objections (pitch answers)
| Owner says | Answer |
|---|---|
| "I'm already full" | Free management app now; next vacancy fills faster, with verified tenants |
| "I don't use apps" | We set it up; your manager runs it; WhatsApp updates |
| "What does it cost?" | 30 days free, then ₹499/mo for up to 30 beds. No commission |
| "Fair Play rules are strict" | They protect honest owners from fake reviews and copycats |
| "I'm on NoBroker / Housing" | Keep them. We're Hyderabad PGs only, with deals and verified tenants |

## Founder's tracker (admin)
Lead → Visited → Signed up → Data complete → Live → Trial → Paying. One row per hostel, with
the area, the owner's phone, the next step and the date.

## Decisions (2026-10-02, Ideas chat on the founder's delegation; founder can change)
1. First clusters: **Ameerpet / SR Nagar** and **Madhapur / Hitec City / Kondapur**.
2. **Visits start now** with the visit kit; data is imported when F13 + F14 are built.
3. **Manager accounts are in the first version.**
4. The founder visits alone for now; admin mode supports adding team members later.

## Design
_Not started._

## Build
_Not started. Depends on F13 (backend)._
