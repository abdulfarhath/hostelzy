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

## 2026-10-02

**Room pricing**
- Price is set by the owner per **sharing type × AC / non-AC**. A single hostel can have both AC and
  non-AC rooms. **No pricing by bed position** (window, fan, etc.).
- Tenants can filter by **AC / non-AC** (Explore chips, search sheet, bed picker).
- In the room layout (F12), a room marked AC must have an AC unit placed.

**Money terms (F02, founder answers 2026-10-01)**
- Notice period **30 days**. Monthly fee is due on the **joining date** (not the 1st).
- **Electricity is extra**; **food is included** in the fee where the hostel serves meals.

**Room layouts (F12)**
- The **Hostelzy team draws every room layout** (admin editor on a laptop). Owners don't draw; they
  approve layouts, mark items working / not working, and request changes in the app.
- New room shapes and layout changes are **free**, done **within 48 hours**.

## 2026-10-02 · Founder answers + delegated decisions

Founder answered Q7, Q10, Q11, Q12 and told the Ideas chat to decide the rest ("take all other
decisions yourself"). Delegated decisions are marked *(Ideas chat)*; the founder can overturn any.

**Owner pricing (F10)** — founder
- **Plan A: flat monthly plan** by hostel size: up to 30 beds **₹499/mo**, 31–80 beds **₹999/mo**,
  80+ beds **₹1,499/mo** (plus a featured spot in its area). **30-day free trial.** No per-join fee.
- Paid by UPI QR, checked by UTR (as decided 2026-10-01).

**Stay Rewards (F09)** — founder
- Next-stay discount is **₹100** (not ₹300), paid by Hostelzy, on the first month of the next
  Hostelzy hostel. Referral reward stays ₹100 each after the friend's first month *(Ideas chat)*.

**Fair Play (F07)**
- **No move-off fee** for owners — founder.
- **Owner's phone number is shown only after a hold** — founder. Tenants are told clearly why: the
  hostel page says "Owner's number shows after you hold a bed. Talking through Hostelzy keeps your
  deal and your ₹100 reward." Before a hold, contact is through "Enquire on WhatsApp" (F05), which
  is recorded with an HZ code.
- **3 strikes** *(Ideas chat)*: 1) warning, 2) deals hidden for 30 days, 3) removed from Hostelzy.
  A proven fake "Direct" for a tenant who came from the app counts as one strike.
- **Matching window 60 days** *(Ideas chat)*: an app enquiry/hold matches a resident added up to
  60 days later (people often visit, wait for salary, then join).

**Deals (F03)** *(Ideas chat)*
- Headline saving = **saving over the first 6 months**, with the upfront part shown under it
  ("₹1,500 off advance + ₹200/month"). 6 months is a typical stay and stays honest.
- The **6-deal menu stays as designed**; no local deals added for now.
- **Max 3 active deals** per owner (per room type, F16).

**Holds (F04)** *(Ideas chat)*
- **Keep the free 1-hour hold** (2 hours for Members, F09). **Drop the ₹299 paid hold**: Hostelzy
  never holds money, and the advance is paid straight to the owner.

**Room layouts (F12)** *(Ideas chat)*
- Women's PGs: room layouts only for logged-in (OTP) users; whole-floor plans only after a hold.
  Every hostel: never show gates, CCTV, exits or residents' names.
- **No power sockets in phase 1** (phase 2).
- The room view **sits beside the bed picker's Plan tab** as a new **Room** tab. Tapping a room in
  Plan opens it in Room.

**Onboarding (F14)** *(Ideas chat)*
- First clusters: Ameerpet / SR Nagar and Madhapur / Hitec City / Kondapur (~10 hostels each).
- Visits start now with a visit kit; data goes into the app after F13 + F14.
- Owner + Manager roles in the first version. A listing goes live only when complete
  ("Visited by Hostelzy" badge). Availability confirmed every 3 days.

**Process** — founder, 2026-10-02
- The Design chat designs **every planned feature**. The founder reviews and approves the designs;
  the Build chat then builds the approved features in the board's order.

**Uneven floors** — founder, 2026-10-02
- Each floor has its own number of rooms (and can have none). Room numbers are the owner's own.
  Screens must never assume the same rooms on every floor. Details: F14 "Uneven floors".

**Design follow-ups** *(Ideas chat, on the founder's delegation, 2026-10-02)*
- **F07:** if the owner fixes a wrong "Direct" within the 48 hours, the case closes **without a
  strike**. Three such fixes in 6 months = one warning.
- **F08:** tenants see the **star rating from verified reviews** (e.g. ★ 4.3 · 18 reviews) and the
  rank with reasons ("#2 in Hitec City: quick replies, beds kept up to date"). The internal score
  number is not shown. Score weights: reviews 50%, enquiry reply speed 15%, availability kept fresh
  15%, complaints resolved 10%, listing complete (photos, layouts) 10%. Strikes lower the rank.
- **F09:** the ₹100 next-stay discount is given by the owner at move-in and **credited on the
  owner's next Hostelzy invoice** (no cash moves from Hostelzy; during the trial it carries to the
  first invoice).
- **F12:** fans and AC are shown as icons with text labels; coverage circles appear only when that
  layer is switched on. **Plan stays the default tab**; tapping a room opens Room.
- **F16:** **no separate AC electricity line**: one line "Electricity extra, by meter" for every
  room. The rate card lives in **Manage → Rates** (and step 3 of Add hostel).
- **F10 UPI ID:** needs the founder (placeholder until then).

**Standing approval** — founder, 2026-10-02
- The founder approves **every design, current and future**, and **every merge**, in advance:
  "approve everything, design everything, don't wait for my approvals, keep building".
- So: Design marks each finished design **Design approved** itself (noting "standing approval").
  Build builds approved features in the board's order and **merges its own PR to `main`** once
  `flutter analyze` is clean and `flutter test` passes (each merge publishes an APK).
- Quality gates stay: flow test per feature, analyze clean, tests pass, Build section filled in.
- Still needs the founder in person: accounts and money (Supabase, Firebase, MSG91, Google Play,
  domain), and anything that changes `DECISIONS.md` business rules.

**Name, logo, accounts** — founder, 2026-10-02
- **Name stays "Hostelzy"** for now; the founder may rename later. No rename work until then.
- Founder: "take your own decisions and keep building". The Ideas chat decides open product
  questions from here and records them here.
- **Logo: concept C "H made of beds"** (7 bed blocks form an H, the middle one red = your bed),
  picked by the Ideas chat on the founder's delegation, from the Brand chat's 6 concepts
  (https://claude.ai/artifact/MQMKQkVhsePEJ755s1Vrq1). Brand chat refines it; Build makes it the
  app icon.
- **Supabase/Firebase/MSG91 keys and the payments setup (UPI ID) will be added by the founder
  later.** Build everything else on sample data now; keep keys and the UPI ID as clearly marked
  placeholders/config, never hard-coded.

**Logo final** — founder, 2026-10-02 (Brand chat)
- Logo is **B3-a2 "Full room"**: window, bunk, fan, **AC unit with dotted air lines**, 3 beds, your
  bed red (replaces concept C, which is dropped). Canvas:
  https://claude.ai/artifact/7AQacMXpVCZUFpDn89ET4D. Brand chat makes the final files in
  `docs/brand/assets/`; Build puts them in the app (launcher icon, splash, login). Name stays
  **Hostelzy**.

## Open (not decided yet)
See the "Open questions" list in `BOARD.md`.
