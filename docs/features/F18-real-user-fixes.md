# F18 · Real-user bug fixes (from the founder's phone test, apk-29)

**Stage:** Building · 2026-10-02 · no design needed (follow existing screens; F17 rules apply)

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

## Needs the backend (F13 part 2; keep honest "once online" wording until then)
Owner confirms holds/payments from their phone (D1, D2), server HZ codes, shared notice/complaints
(E4), real codes for confirm-stay/Fair Play/delete (E2, F13, H7 — delete must re-auth with Google
and delete the Firebase user + server data), notifications (H6), real admin accounts (G1),
`DATA=supabase` release once real hostels exist (C6).

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

