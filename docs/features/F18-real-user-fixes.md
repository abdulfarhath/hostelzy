# F18 · Real-user bug fixes (from the founder's phone test, apk-29)

**Stage:** Spec ready · 2026-10-02 · no design needed (follow existing screens; F17 rules apply)

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
_Not started._
