# Decisions

Agreed with the founder. Newest last. Don't contradict these; ask instead.

## 2026-10-01

**Product**
- One app, three roles picked after OTP: tenant, resident, owner. No parent role.
- Hyderabad first. Start dense in one area (e.g. Madhapur / Hitec City / Kondapur / Gachibowli).
- Pixel-faithful to the Claude Design prototype (`project/HostelzyApp.dc.html`).

**How hostels charge (Hyderabad / Chennai norm)**
- To move in: **₹3,000 advance + first month's fee** (e.g. ₹7,000). Then only the monthly fee.
- On leaving: owner keeps **₹1,000–1,500 maintenance** from the advance, returns the rest.
- No "2 months' deposit": the current app copy is wrong and must be fixed (F02).

**Hostelzy deals**
- Owners pick deals from a menu; only tenants who book through Hostelzy get them.
- Comparison "With Hostelzy vs Walk in" with the saving in rupees.
- Fixed exit rules (maintenance amount + notice) are always on.

**Trust and anti-cheating**
- Tenant → owner WhatsApp hand-off: Hostelzy records the enquiry first (HZ code, verified phone).
  Trust comes from Hostelzy's own record, not the message text.
- Owners must add every resident (name + phone). Phone numbers are matched with app enquiries/holds
  to tell "Joined via Hostelzy" from "Direct".
- Collusion (owner + tenant joining off-app) → owner is warned, then banned. Rules are shown and
  accepted when the owner joins.
- Reviews only from OTP-verified users with a confirmed stay.
- Tenants get a discount on their **next** hostel after joining one through Hostelzy (loyalty).

**Business**
- No company or GST registration at the start. Hostelzy never holds tenants' or owners' money:
  the advance is paid directly to the owner.
- Owners pay Hostelzy by UPI QR; payment verified manually by UTR (Option 1).
- Tenants pay Hostelzy nothing.

**Tech**
- Flutter app (Android first, web build too). Repo: github.com/abdulfarhath/hostelzy.
- Backend: Supabase (Mumbai), Free plan while building, Pro (~$25/mo) at launch.
- Firebase for push and crash reports. GitHub Actions builds the APK on every push to `main`.
- Budget-conscious: ≈ ₹2,600/month at launch.

## Open (not decided yet)
See the "Open questions" list in `BOARD.md`.
