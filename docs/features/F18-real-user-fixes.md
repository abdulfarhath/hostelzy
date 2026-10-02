# F18 · Real-user bug fixes (from the founder's phone test, apk-29)

**Stage:** Built · Design approved 2026-10-02 (standing approval) · design: https://claude.ai/artifact/BESe9fQLT3m86BqgihRVU1 (anything not drawn there follows existing screens; F17 rules apply)

Founder found on a real phone: back button exits/jumps to start, login forgotten after reopening,
dummy numbers on code screens, name prefilled, no "use my location" / area picker, owner can't edit
layouts. A full user-journey audit (Ideas chat, 2026-10-02) found the rest. Root causes: release
APK runs on sample data only, nothing is saved on the phone, every user is the sample identity
(Rahul / Srinivas / Anjani 204-B), no PopScope, no Scaffold (keyboard covers inputs).

## Fix order (Build)
1. **Back button**: PopScope on the app body. Close sheet → `back()` → tab home → "Press back again
   to exit". (A1)
2. **Stay logged in**: shared_preferences + FirebaseAuth.currentUser restore at startup; save name,
   phone, role, theme, holds, saved hostels, HZ codes; open the role's home, not Welcome; logout
   fully resets; `signedIn` defaults false. (A2, C4, C5, D3, H5)
3. **Own identity, no sample people**: Name field (prefill from Google, editable) + phone (6–9 start,
   10 digits); `me.name / me.phone / me.hostel / me.bed` everywhere (Me, Settings, enquiries,
   payments, reviews, rewards code, resident home, rent, complaints, move-out, owner messages).
   Never fall back to a sample number: show "Add your number". (A3, A4, B1–B14, B17, C2)
4. **Roles gated**: owner only for team-approved/added hostels (team mode for now) or an invite;
   resident only after an owner adds them / confirmed stay. Others see an honest "Ask your owner to
   add you" / "List your hostel" screen. Release builds don't seed sample residents, cases,
   invoices, sign-ups, enquiries. (B15, B16, B18, B21)
5. **No contact/payments to fake numbers or IDs**: block WhatsApp/call/UPI to sample numbers and
   `sample.*@upi`; owner enquiry WhatsApp passes the phone; warden number from the hostel. (B19,
   B20, E3, F1)
6. **Keyboard + small phones**: viewInsets padding on sheets and screens, scrollable Phone/Login/
   Role/Permission screens, scrollable Manage tabs, allow text scaling (clamped). (H1–H4)
7. **Crashes**: hostel tags (D4), ownerPhones! / owner substring (D5), empty rooms (D6),
   layout editor nulls (G2), go-live reduce (G3), NaN at 0 beds/residents (F2, F3), rate drafts
   after hostel switch (F6), hostelById orElse (H9), appToday getter (H8).
8. **Map**: geolocator + location permissions, "Use my location" centres and sorts by distance;
   **area picker** (Ameerpet, SR Nagar, Madhapur, Hitec City, Kondapur, Gachibowli, KPHB…) filters
   to hostels in that area; "Search this area" after panning; card and pins follow filters. (A5, D7)
9. **Owner edits layouts directly** (DECISIONS 2026-10-02): owner opens the editor for own rooms,
   "Publish" goes live with no approval; create a layout for rooms without one; "Ask Hostelzy for
   help" optional. (A6)
10. **Smaller fixes**: Terms/Privacy links (C1), role screen back (C3), "from ₹X" recomputed and ₹0
    blocked (D8), saved hostels list (D9), released bed returns to previous state (D10), compare
    uses room label (D11), max 2 active holds per tenant (D12), food week from today (E1), review
    "edit" copy (E5), Fair Play hours computed (F4), rules/menu saved locally (F5), deals per hostel
    (F7), walk-in hold expiry (F8), release updates hold record (F9), add-booking validation (F10),
    UPI ID format (F11), plan dates from start date (F12), layout photo uses image picker or is
    removed (F15), team passcode lockout after 5 tries (G1, stopgap).

**Groups 8–10 · map v2, owner edits layouts, smaller fixes** (branch `feature/f18-map-layouts-small`):
- **Map v2 (8), design "Map", "Location", "Areas":**
  - Top bar: an area button (📍 All areas / area / This area / Near me) and **List**.
  - The **Areas** sheet: search, Near me, a 2-column grid with hostel counts, and "Soon" for empty areas (Kukatpally, Jubilee Hills, Begumpet added).
  - **Search this area** appears after a pan and filters to 3 km around the new centre.
  - **Use my location** opens the explainer ("Use your location?", Allow location / Pick an area instead), then Android asks (`geolocator`, `ACCESS_COARSE_LOCATION`).
    - Allowed: the map centres on you with a "you are here" dot, sorting switches to nearest, and distances read "km from you".
    - Denied or off: the area picker opens with an honest message. A position is never invented.
  - Pins and the card show only hostels that pass the filters (Explore follows the same area filter), prices show in full, and there's an empty card ("No hostels in X yet") when nothing matches. `lib/locate.dart` has `GeoLocator` / `NoLocator`.
- **Owner edits layouts (9), DECISIONS 2026-10-02, design "Rooms", "Create", "Editor", "Published":**
  - Manage → Layouts is **Room layouts**: All / Live / Draft / No layout filters with counts, Live / Draft / No layout tags, an "edited …" or "changes not published" line, and the note "You edit and publish your own layouts…".
  - A room without a layout opens **Create a layout**: length × width in ft (6–60), **Copy Room X instead** (same sharing and AC), "Ask Hostelzy to help" by WhatsApp, and **Start drawing**. Only the rectangle shape is offered; L, alcove and angled shapes aren't built.
  - The owner's room view has **Edit layout** / **Ask Hostelzy**. When the team drew a version it shows **Publish vN**.
  - In the editor, **Publish** goes live at once (safety checks still apply: AC unit in AC rooms, beds = sharing, window facing, a bed with a resident can't be deleted). Tenants keep the previous version until then.
  - **Live for tenants** has Done, Edit again, and **Undo publish · go back to vN** (or hide a first layout again).
  - New layouts stay hidden from tenants until published. The team editor's button is now "Send to owner".
- **Smaller fixes (10):**
  - Terms and Privacy policy are real links (C1).
  - The role screen has a back button (C3).
  - "from ₹X" is computed from the rate card, and prices under ₹1,000 or blank can't be saved (D8).
  - **Saved hostels** is a real list from Me (D9).
  - A released bed goes back to its previous state (free or free soon) (D10).
  - Compare and the layout title use the room label (D11).
  - A tenant holds at most 2 beds at a time (D12).
  - Food opens on today's weekday (E1).
  - The review copy no longer promises editing (E5).
  - Fair Play's 48 hours run from when the case opened (F4).
  - House rules and the menu are kept on the phone (F5).
  - Deals were already per hostel (F7, F17).
  - Walk-in holds free themselves after 1 hour (F8).
  - Releasing a hold, by the tenant or the owner, updates the hold record (F9).
  - Add-booking checks the name, a valid mobile and a free bed (F10).
  - The UPI ID must look like name@bank, and paying an invalid one is blocked (F11).
  - The trial and first invoice run from the plan's start date (F12).
  - Layout help has no fake "photo added" tiles; photos go to Hostelzy on WhatsApp until uploads exist (F15).
  - The team passcode locks for 15 minutes after 5 wrong tries (G1).
- Tests:
  - `map v2: area picker, search this area, use my location (F18)`;
  - `owner edits and publishes layouts without approval (F18)`;
  - `smaller fixes: holds, walk-ins, saved list, prices, UPI ID, passcode lockout (F18)`;
  - the old approval-flow tests updated to the owner-publishes wording.
- **Not in this build** (design boards beyond the F18 fix list): owner photo upload, crop and the tenant gallery (needs storage, F13 part 2; `image_picker` not added); delete account v2 with Google re-auth (backend); the team web console.

## Needs the backend (F13 part 2; keep honest "once online" wording until then)
Owner confirms holds/payments from their phone (D1, D2), server HZ codes, shared notice/complaints
(E4), real codes for confirm-stay/Fair Play/delete (E2, F13, H7 — delete must re-auth with Google
and delete the Firebase user + server data), notifications (H6), real admin accounts (G1),
`DATA=supabase` release once real hostels exist (C6).

## Design

**Design approved · 2026-10-02** (standing approval). Canvas "Hostelzy · Real app v2": https://claude.ai/artifact/BESe9fQLT3m86BqgihRVU1
Phone boards 390×844 (light, with Dark tweak; dark copies on each row); team console 1440×900.

1. **Sign in:** Main (Continue with Google; use the official Google button asset), Profile (name from Google, editable; phone +91 "Not verified"; role), ResidentGate ("Ask your owner to add you"), OwnerGate ("List your hostel": request a visit, WhatsApp Hostelzy +91 90597 90014), ProfileDark.
2. **Empty states:** Empty (tweak: no hostels in this area / no holds / no saved hostels / no residents / no enquiries / no complaints).
3. **Map v2:** Map ("Search this area" chip after a pan), Location (Use my location + permission explainer), Areas (area picker sheet), List (hostels in this area), MapDark.
4. **Owner layout editor:** Rooms (pick a room), Create (no layout yet: Create layout, or Ask Hostelzy to help), Editor (edit room; safety rules stay), Published ("Live for tenants"), EditorDark.
5. **Photos and saved:** Photos (owner upload: pick, order, cover, progress, failed + retry), Crop, Gallery (tenant), Saved (saved hostels).
6. **Delete account v2:** Delete (tweak: Confirm with Google / Deleted).
7. **Team web console (1440):** Console (sign in with Google), ConsoleOnboarding (tracker + add hostel), ConsolePayments (UTR check), ConsoleCases (Fair Play cases + layout help queue).
8. **Small UX:** BackExit ("Press back again to exit" toast), Demo (DEMO banner while on sample data), KeyboardUtr and KeyboardAdd (sheets stay above the keyboard, CTA visible).

## Build

**Groups 1–3 · back button, stay logged in, own identity** (branch `feature/f18-back-login-identity`):
- **Back button (1):** `PopScope` on the shell → `AppState.handleBack()`: close the sheet → previous screen → the role's home tab (or Welcome when signed out) → "Press back again to exit" (second press within 2 s closes the app).
- **Stay logged in (2):**
  - `lib/store.dart` (`PrefsStore` on shared_preferences; `NoStore` / `MemoryStore` in tests) keeps signed-in state, name, phone, role, theme, holds (with their HZ codes), saved hostels, the user's own enquiries and Fair Play acceptance. It's saved whenever any of them change.
  - At startup `main.dart` loads it before the first frame. `restore()` brings it back: the beds the user holds are marked again, and a signed-in user opens on their role's home, not Welcome.
  - A Google account only counts while Firebase still has it signed in (`SignIn.current`).
  - Fresh starts are signed out (`signedIn` defaults false).
  - **Log out** forgets everything: holds released, saved hostels, enquiries, name, phone, role, and the phone's saved copy.
- **Own identity (3):**
  - Sign-up asks **Your name** (prefilled from Google, editable; never a sample name) and **Mobile number** (10 digits starting 6–9).
  - `meName` / `meFirst` / `meShort` replace "Rahul Varma / Rahul V." in Me, Settings, Stay Rewards, enquiries, advance payments, hold requests, reviews ("Shows as …"), resident greeting, complaints, notice and warden messages, and owner messages.
  - `myPhone` no longer falls back to `90000 00001`; Me shows **Add your number** instead.
  - The resident's stay (Anjani 204-B) is still sample data in debug builds; group 4 gates it in release.
- Test: `back button, stay logged in, own name and phone (F18)`. Sample-flow tests now sign in a named user first.

**Groups 4–7 · gated roles, no fake contacts, keyboard + small phones, crashes** (branch `feature/f18-roles-contacts-crashes`):
- **Gated roles (4):**
  - `AppState.samples` (debug builds and tests only) seeds sample residents, hold requests, enquiries, sign-ups, cases, complaints and payments; the Play Store build starts with none.
  - Picking **I live in a Hostelzy PG** or **I run a hostel** without access opens the design's gate screens, with the user's own name in the header:
    - **ResidentGate:** "Ask your owner to add you" shows your number with "Send it to your owner on WhatsApp", the invite-QR row ("Scan the invite QR" says to use the phone camera; no in-app scanner yet) and "Not in a PG yet? Find a bed".
    - **OwnerGate:** "List your hostel" has 3 steps, the hostel name, area chips, **Request a visit** (a WhatsApp to Hostelzy with name, area and phone) and "WhatsApp Hostelzy · +91 90597 90014".
  - Owners get in through team mode or a hostel the team put live; residents wait for the backend (F13 part 2).
  - The design's **DEMO** banner ("Sample data. Nothing you do here is real.") shows in the Play Store build while the listings are samples.
- **No fake contacts (5):**
  - In the Play Store build, WhatsApp and calls to sample numbers (`90000…`) and UPI to `sample.*@upi` are blocked with an honest toast.
  - The owner's enquiry reply WhatsApp now carries the tenant's phone.
  - "Message warden" (a made-up Ravi) becomes **Message owner** with the hostel's number.
- **Keyboard + small phones (6):**
  - The bottom inset follows the keyboard (tabs hide while typing) and sheets sit above it.
  - Login, About you, OTP, Role and Permission screens scroll (`FillScroll`) when they don't fit.
  - Manage's six tabs scroll sideways under 460 px, and its header hides while typing.
  - Text follows the phone's size, capped at 1.3×.
- **Crash guards (7):**
  - hostels with fewer than 4 tags (D4);
  - a missing owner phone or a blank owner name (D5, plus `maskPhone` on an empty number);
  - hostels or floors with no rooms (D6: rate card floor, add-rate fallback, compare with no eligible room);
  - the layout editor on a room with no layout, which now creates a starting layout (G2);
  - go-live with no rooms, which is blocked by a new "At least one room with beds" check (G3);
  - 0 beds or 0 expected rent shows 0% instead of NaN (F2, F3);
  - `hostelById` for an unknown id returns "Hostel no longer listed" (H9);
  - `appToday` is now a getter, so the date moves on overnight (H8).

  Rate drafts after a hostel switch (F6) were already cleared in F17.
- Test: `gated roles, no fake contacts, small phones, crash guards (F18)` covers:
  - the release gates and DEMO banner;
  - blocked sample WhatsApp, call and UPI;
  - Login, About you, Role, Permission and Manage at 320×568 with the keyboard open (no overflow);
  - a one-tag hostel, an unknown hostel id, an editor on a room without a layout, and the go-live check.


**B7 · photos · 2026-10-02** (branch `feature/b7-photos`, design boards 14–16):
- **Owner Photos** (Manage → Photos):
  - albums: Hostel plus room types;
  - a 3-column grid with the cover first, order numbers and labels;
  - long-press and drag to reorder;
  - uploads show their progress (prepared 50%, uploaded 100%); failed tiles say "Failed · Retry";
  - Add photos; a minimum of 8;
  - tap a photo to make it the cover or remove it.
- **Crop:** 4:3 listing, Square or Free; "Set as cover photo"; what the photo shows, or its room type.
  - The phone centre-crops, fits the photo in 1600 px and saves a JPEG at quality 80 (`package:image`), so a 3–5 MB photo becomes about 200–400 KB.
  - Picked with `image_picker`.
- **Tenant gallery:** the hostel page shows the cover and "See N photos". The gallery has a dark viewer (swipe), category chips with counts, thumbnails and "Photos by the owner".
  - Hostels without photos say "No photos yet". The fake "1 / 12" is gone.
- **Server:** `20261002050000_b7_photos.sql`:
  - a public `hostel-photos` bucket with random file names;
  - the `hostel_photos` table: label, order, one cover per hostel;
  - RLS: only that hostel's staff or the team upload, change or remove, and only in that hostel's folder; tenants see live hostels' photos.
  - Tests: `supabase/tests/b7_test.sql`.
- **Sample data never pretends to upload:** "Photos upload in the real Hostelzy app."
- Manage's header buttons scroll sideways on small phones; the 320 px check now covers Manage, Photos and Gallery.
- Tests: `B7: photos are cropped…` and `B7: owner adds, orders and removes photos…`.

**go_router · 2026-10-02** (branch `feature/go-router`; this was the follow-up to group 1):
- `MaterialApp.router` with `lib/router.dart`. AppState keeps the screens and the back stack, so Android back works as before through PopScope.
- Deep links from the web pages: `hostelzy://app/r?c=HZ-…` opens that enquiry (owner: Today with the enquiry sheet; tenant: Holds). A code this account can't see gets "isn't in this account". `hostelzy://app/j?c=…` keeps the invite code for sign-up. The demo APK uses `hostelzy-demo://`.
- Other links open the app where it was. Test: `go_router deep links…`.
