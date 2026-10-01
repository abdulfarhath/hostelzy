# F14 · Onboarding hostels: Add hostel tool, multi-hostel, invite QR

**Stage:** Design approved · 2026-10-02 (founder: "approve all")

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
   - **Room generator, floor by floor** (floors differ, see "Uneven floors" below): add a floor →
     number of rooms on it → default sharing and AC/non-AC → "Copy previous floor" to save time →
     fix the odd rooms. Beds are created from this.
   - **Rate card** (F16): price per sharing × AC/non-AC, advance, maintenance, notice (F02).
   - **Photos taken by the founder** (consistent quality): front, each room type, washroom, food,
     common area. Minimum 8.
   - Room measurements + sketch per room type, so the team can draw layouts (F12).
   - **Current residents** (name, phone, bed): grandfathered as Direct (F06).
   - Optional: pick up to 3 deals (F03).
4. **Leave behind:** printed A4 QR poster for residents ("Join your hostel on Hostelzy: pay rent,
   raise complaints") and a small "Book on Hostelzy" sticker for the gate.

## Uneven floors (founder, 2026-10-02)
Real buildings are not a neat grid. One floor may have 3 rooms, the next 6, the ground floor none.
- **Each floor has its own room count.** No "rooms per floor" number for the whole hostel.
- **Floors with no beds are allowed** (ground floor with kitchen, office, parking). They are
  stored but hidden from tenants.
- **Floor names:** Ground, 1, 2, 3 … and Terrace. A building can start at Ground or at 1.
- **Room numbers are the owner's own,** editable and unique in the hostel: gaps (101, 102, 105),
  letters (A1, G-02) and different counts per floor are all fine. Default suggestion: floor × 100
  + n (G01, G02 on the ground floor).
- **Every room keeps its own sharing and AC/non-AC,** so one floor can mix 2-, 3- and 4-sharing.
- **Later changes** (Manage → Rooms): add or remove a room or a whole floor. A room or floor with a
  resident or an active hold can't be removed.
- **Tenant bed picker and owner bed map:** floor tabs show only floors that have beds, each with
  its free-bed count. The floor plan grid adapts to any number of rooms (1 to 20+), wrapping into
  rows; it never assumes 4 rooms.
- **Room layouts (F12)** are per room, so they are not affected.
- **Sample data** must include uneven floors (e.g. Ground 0 rooms, 1st 3 rooms, 2nd 5, 3rd 2) so the
  tests cover it.

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
Canvas https://claude.ai/artifact/ANjRUNhkyGSzeCLQNFVm4T. **Design approved by the founder on 2026-10-02.**

Add hostel wizard (Hostelzy admin mode on the founder's phone during the visit; 6-step progress bar and a red "Hostelzy admin mode" tag):
1. **Basics.** Name, who it's for, map pin checked at the gate, food, gate time, total beds, amenities.
2. **Rooms, floor by floor** (updated for "Uneven floors"). One block per floor, each with its own room count. Ground floor can be "No beds (kitchen, office) · hidden from tenants". Room numbers are editable (101, 102, 105 · 204A). Each floor has "Copy previous floor"; at the bottom, Add floor / Add terrace. Changed rooms are marked in red. Sample: Ground 0, 1st 3, 2nd 5, 3rd 2 = 10 rooms, 29 beds.
3. **Rate card.** Only the room types used, with a missing price flagged in red. Money terms: advance, amount kept on leaving, notice, fee due date. Optional "Pick deals now".
4. **Photos.** 8-photo minimum by type (front, each room type, washroom, food, common area, gate sticker) with counter; sketch + measurements done per room type for F12.
5. **Residents.** Type one / paste a list; "18 of 27 taken beds"; tagged Before Hostelzy (grandfathered, F06); each gets a WhatsApp code.
6. **Go-live checklist** (tweak Not ready / Ready): owner OTP, Fair Play accepted, ≥ 8 photos, every room type priced, bed status checked, map pin checked. "Go live" stays locked until all six are done. Note: the 30-day trial starts on the go-live day.

After go-live:
7. **Tenant: "Visited by Hostelzy · 1 Oct 2026"** badge on the hostel page (photos by our team, beds and prices checked in person), plus availability (tweak: "5 free beds · confirmed 2 days ago" / "Availability not confirmed").
8. **Owner: add a manager** (sheet over Manage → Team). Name and phone; manager can: beds and holds, residents, enquiries, complaints, food; only the owner: plan and billing, deals, rate card, Fair Play notices. Invite by OTP.
9. **Owner: hostel switcher.** Tap the hostel name on Today to see every hostel with its status (Live / Trial), "Add another hostel (the Hostelzy team visits)"; one plan per hostel.
10. **Owner: "Still 4 free beds?"** The WhatsApp nudge and the in-app card listing the beds, with Yes, all 4 free / Update; the 7-day rule is spelled out.
11. **Founder admin: onboarding tracker** (1440 × 900). Columns Lead → Visited → Signed up → Data complete → Live → Trial → Paying, one card per hostel (area, phone, next step), cluster filter, "Live 4 of 20 this month".
12. **Resident QR poster (A4).** "Join your hostel on Hostelzy", large QR, three benefits (pay rent, complaints, food menu), Scan → Verify → Confirm, the link, and "Hostelzy never asks for your OTP or password".
Uneven floors:
13. **Tenant: bed picker Plan** (tweak 2nd floor · 5 rooms / 1st floor · 3 rooms). Floor tabs show only floors with beds, each with its free count; room tiles wrap into rows of 4; the room header shows sharing · AC · price.
14. **Owner: bed map.** Every floor stacked with its own rooms (3 / 5 / 2), bed squares by state, the Ground floor shown as "No beds · hidden from tenants", and "Add or remove rooms (not rooms with a resident or hold)".
- F16 board 4 (bed picker) shows a 4-room floor as one case; boards 13 and 14 here are the uneven reference.
- Dark mode: board "6 in dark mode". Every phone board has a Dark tweak (the poster is for print).

## Build
_Not started. Depends on F13 (backend)._
