# Decisions

Agreed with the founder. The log below is newest last; don't contradict it, ask instead.
Older entries that were later replaced are marked **(replaced)**.

## Current rules at a glance (hub, 2026-10-03; the log below has the details)
| Area | Rule today |
|---|---|
| Roles | Tenant, resident, owner (+ manager). Hostelzy team via a Google account with the `team` claim |
| Login | Sign in with Google; the user types their phone ("Not verified"). SMS OTP later, when Firebase Blaze billing works. No OTP wording until then |
| Money in | Tenants pay Hostelzy ₹0. Owners pay Plan A ₹499 / ₹999 / ₹1,499 a month (≤30 / 31–80 / 80+ beds), 30-day free trial from go-live, by UPI `9059790014@axl` + UTR, checked by the team |
| Money out | Hostelzy never holds money. ₹3,000 advance + first month go straight to the owner. On leaving, the owner keeps ₹1,000–1,500 maintenance. 30-day notice, fee due on the joining date, electricity extra by meter, food included where served |
| Holds | Free 1 h (2 h for Members). No paid hold |
| Deals | Owner picks from a 6-deal menu, max 3 active. Headline = 6-month saving. Paused for tenants when the plan is 15+ days late or at strike 2 |
| Rewards | ₹100 next-stay credit (credited on the owner's invoice), referral ₹100 each. Monthly cap: founder to confirm (Finance Q2) |
| Fair Play | Owner adds every resident; phone matched within 60 days → Via Hostelzy / Direct. 3 strikes: warning / deals hidden 30 days / removed. Fixing a wrong "Direct" within 48 h = no strike; 3 fixes in 6 months = 1 warning. No move-off fee |
| Owner phone | Shown to a tenant only after a hold, an enquiry (recorded with an HZ code) or a stay |
| Ranking | Rank #N with reasons, never a score. Reviews 50%, reply speed 15%, fresh availability 15%, complaints resolved 10%, listing complete 10%. Featured spot for 80+ bed hostels |
| Layouts | **Owners draw and publish their own layouts** (the team helps on request, 48 h). An AC room needs an AC unit. Fan/AC coverage only when the layer is on. Residents can suggest fixes, the owner approves. **Every layout and the building view are open to everyone, no hold needed** (founder, 2026-10-05). Never gates, CCTV, exits or residents' names |
| Listings | Two tiers: **UNVERIFIED** (team-listed: photos, name, rent range, no beds/holds) and **✓ VERIFIED** (full checklist: rooms, a price for every type, linked owner, 8 photos, team visit). Availability confirmed every 3 days |
| Design | One job per screen, plain words, Archivo, red `#ec3013` for actions, green only for savings. Design = app 1:1 (`SCREENS.md`) |
| Web | Public pages at farhath.me/hostelzy/app/ until hostelzy.in. The site root farhath.me/hostelzy/ stays the old prototype |
| Brand | Name Hostelzy. Logo B3-a2 "Full room" |
| Approvals | Standing approval: chats decide and merge. Founder only for accounts, keys, SQL runs, payments and changes to money amounts |


## 2026-10-01

**Product**
- One app, three roles picked after sign-in (OTP replaced by Google sign-in, Plan B): tenant, resident, owner. No parent role.
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
- Reviews only from users with a confirmed stay (OTP verification comes later, see Plan B login).
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
- **(replaced 2026-10-02: owners draw their own layouts, see "Owner edits layouts")** The **Hostelzy team draws every room layout** (admin editor on a laptop). Owners don't draw; they
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
- **(replaced 2026-10-05: layouts are open to everyone, see "Layouts open to all")** Women's PGs: room layouts only for signed-in users; whole-floor plans only after a hold.
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
- **(replaced by "Logo final" B3-a2)** **Logo: concept C "H made of beds"** (7 bed blocks form an H, the middle one red = your bed),
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

**No fake behaviour** — founder, 2026-10-02
- The app must not pretend: no demo number/OTP fill, no "Paid"/"Yours"/"Sent"/"Told"/"Verified"
  unless it really happened, a real map, no demo tools in release builds. Full list and plan:
  `docs/features/F17-production-ready.md`. Payment flow: UPI to the owner → tenant enters UTR →
  "waiting for owner" → owner confirms → booked.

**Real map** — founder, 2026-10-02
- The map must look like Google Maps: real streets, pan/zoom, every hostel at its real location with
  a red price pin (same look as today). Now: `flutter_map` + OpenStreetMap tiles (no key, testing
  traffic only). At launch: switch to Google Maps (or a keyed tile provider) when the founder adds
  an API key. Distances come from real coordinates.

**Payments contact + login SMS** — founder / Ideas chat, 2026-10-02
- Hostelzy UPI ID: `9059790014@axl`. Support WhatsApp: `+91 90597 90014` (founder).
- **Update (founder, 2026-10-02): Plan B.** Firebase Blaze billing failed on the founder's card, so
  login starts with **Sign in with Google** (Firebase Auth Google provider, free Spark plan), linked to
  Supabase via Third-party Auth (Firebase). Users type their phone number; it shows as
  "Not verified" until SMS OTP is added later (when billing works). Matching and reviews still rely
  on owner-confirmed stays.
- *(Superseded for now)* **Phone login uses Firebase Phone Auth, not MSG91** *(Ideas chat)*: MSG91 needs Indian DLT
  sender registration (a business entity and paperwork), which the founder doesn't have. Firebase
  sends the OTP SMS itself; Supabase trusts Firebase sign-ins via its Third-party Auth. Needs the
  Firebase Blaze (pay-as-you-go) plan with a budget alert, and a stable app signing key (SHA-1).

**Owner edits layouts + map location** — founder, 2026-10-02
- **Owners edit their own room layouts directly** (move beds, fans, AC, windows, doors, washroom;
  add/remove items) and publish **without Hostelzy approval**. The Hostelzy team can still draw or
  fix layouts for owners who want help. Replaces "Hostelzy team draws every layout" (2026-10-02).
  Safety rules stay: AC room needs an AC unit, bed count = sharing, a bed with a resident can't be
  deleted, no gates/CCTV/exits.
- **Map:** "Use my location" (location permission) and **pick an area** (Ameerpet, SR Nagar,
  Madhapur, Hitec City, Kondapur, Gachibowli…) to see all hostels there.
- **The user enters their own name** (never prefilled with sample names).

**Web address for now** — founder, 2026-10-02
- `hostelzy.in` comes later. Until then the app's public pages live on GitHub Pages under the
  founder's domain at **farhath.me/hostelzy/app/** (privacy policy, terms, delete-account page,
  `r/HZ-…` enquiry links, `j/…` invite links). **farhath.me/hostelzy/** stays the old prototype
  page; don't touch it. All URLs come from one config value so the switch to hostelzy.in is one
  line.

**Residents fix their room layout** — founder, 2026-10-02
- A **confirmed resident of a hostel** can edit the layout of **any room in that hostel** as a
  suggestion and send it to the owner. The owner approves or rejects; approval publishes it.
- Everyone else still sees the **Edit room** button; tapping it says only residents can edit, with
  a nudge to book/join. Spec: F19.

**Reminders in the app** — founder, 2026-10-02
- The Hostelzy app reminds users to drink water (as often as every 20 min) and about their own
  tasks, plus hostel meal times and rent. Runs on the phone. Spec: F20.

**Simpler design for the whole app** — founder, 2026-10-02
- Founder approved the F21 Before → After demo and asked for **every screen** to be redesigned in that
  style, designed and built in parallel, with the chats deciding everything themselves. Spec: F22.

**Floor amenities + layout-first** — founder, 2026-10-02
- Tenants see shared things per floor (fridge, washing machine, water purifier…); owners and residents
  add them; no exact position needed. The room layout is the primary view for all roles; floor view is
  secondary. **F23 needs the founder's approval of the design before building** (only exception). **Approved by the founder 2026-10-02** ("yes for all"), including geyser in room washroom.

**Bring back the building and floor screens; one canvas for all designs** — founder, 2026-10-03
- Bring back the **Building view** (the whole building, Floor 1, Floor 2… with every room) and the
  **floor map with shared things** (washing machine, geyser, fridge, RO… on the floor), both dropped in
  the F22/F23 redesigns. Tenants see them from the hostel page and the bed picker, owners in Layouts.
  The women's-PG rule stays (full floor only after a hold). Spec: F25.
- Every earlier design (from the old account's artifacts) goes into the one main canvas, in an
  "Archive: earlier designs" area that is not counted in App N = Canvas N.
- **Map:** the app's map is the reference. The design copies real app screenshots, not the other way round.

**What comes back from old versions** — hub, on the founder's delegation, 2026-10-03
- Only the Building view comes back as a screen (with shared things on each floor). The owner floor plan, the menu week
  table, occupancy, plan tiers and invoice history come back as parts of existing screens. No room board. Details: F25.
- Rule from the founder: no redundant screens; every screen has its own purpose; keep it simple.

**Prototype first, then build** — founder, 2026-10-04
- Changes are tried in the clickable web prototype (`docs/PROTOTYPE.md`) first. The real app on `main` (and a new APK)
  changes only after the founder approves them there. No more installing every new APK to review.

**Layouts open to all** — founder, 2026-10-05
- Nobody ever sees "Hold a bed to see the floors". Room layouts, the building view and the bed picker are free to open
  for everyone, including guests and women's PGs. Replaces the women's-PG hold-first rule (F12, 2026-10-02). The safety
  rule stays: never show gates, CCTV, exits or residents' names.

**Unverified listings; residents can hold elsewhere** — founder, 2026-10-06
- The team may list hostels **before** they are verified: street photos, name, area and an expected rent **range**, marked
  **UNVERIFIED** (grey outline). No beds, holds or owner contact until verified. Tenants can tap "Tell me when verified",
  "Ask Hostelzy" (WhatsApp to support) and owners "Claim this hostel". Verified hostels (✓ VERIFIED, navy) sort first in
  each price band. Replaces "a listing goes live only when complete" for the unverified tier; a **verified** listing still
  needs the full checklist. Spec: F26 #21.
- **Find a bed** inside the resident app is the full tenant app (tenant tab bar). A resident **can hold a bed** at another
  hostel; their stay changes only when they move. Spec: F26 #17.

**F26 approved; green also for confirmed payments** — founder, 2026-10-06
- The founder approved the F26 proposal canvas (21 changes, rounds 1–3). Build starts on the prototype.
- Colours: red `#ec3013` is the only action colour (no orange). Green marks savings, Hostelzy deals **and a confirmed
  "Paid"**. Navy marks ✓ VERIFIED. Grey outline marks UNVERIFIED.

## Open (not decided yet)
See the "Open questions" list in `BOARD.md`.
