# F17 · Make it real: remove every demo and fake behaviour

**Stage:** Design approved · 2026-10-02 (standing approval)

## Problem
The app was built from a clickable prototype. Today nothing talks to a server or another app
(`pubspec.yaml` has only `flutter` + `flutter_svg`). All data is seeded in `data.dart`, lives in
memory and is lost on restart, so every "sent", "paid", "told" and "verified" message is fake.
The founder found two examples: the demo number/OTP buttons on login, and "Pay advance" saying
the bed is "Yours" with no payment. Audit of `main` @ `bf3b730`, 2026-10-02.

## Rules from now on (all chats)
- **No fake success.** Never say "Paid", "Sent", "Told", "Verified" or "Yours" unless it really
  happened. Until the backend exists, say "Pending", "We'll check", or "Coming soon".
- **No demo controls in release builds.** Dev shortcuts only under `kDebugMode`.
- **No real-looking phone numbers** in sample data; use `+91 90000 0000x`.

## The list (what is fake → what the real version needs)
Group A = fix now (no keys needed). B = needs the backend (F13, founder's keys). C = needs a map key.

### 1. Login
| Now | Real | Group |
|---|---|---|
| "Fill a demo number" puts 9848012345 (`ui/screens_start.dart:122`) | Remove | A |
| "Paste code from SMS" fills 482913 (`screens_start.dart:181`) | Android SMS autofill of the real code | B |
| "Verify" accepts any 6 digits (`screens_start.dart:188`) | OTP checked by the server (MSG91 / Firebase) | B |
| "Resend in 0:24" never counts down (`:184`) | Real timer + resend | A (timer) / B (resend) |
| Anyone picks Owner; "Switch role" on Me (`screens_start.dart:216`, `screens_tenant.dart:683`) | Role from the account; owner only after onboarding | B |
| `myPhone` falls back to the demo number (`state.dart:514`) | Logged-in user's phone | B |
| Log out only clears a few fields (`screens_tenant.dart:684`) | Real sign-out | B |

### 2. Explore and map
| Now | Real | Group |
|---|---|---|
| Map is a drawn grid with 3 fake roads and a "map tiles" label (`screens_tenant.dart:356-528`) | Real map (Google Maps SDK, or flutter_map + MapTiler/OSM) | C |
| Pins and landmarks at fixed screen % (`data.dart:63-82`) | Latitude/longitude per hostel | A (data) + C |
| "6 min to Hitec City" hard-coded (`data.dart` `mins:`) | Distance from coordinates (straight-line now; travel time later) | A |
| "Directions" only toasts (`screens_tenant.dart:1732`) | Open Google Maps with the hostel's location | A |
| Photos are striped boxes "facade"/"bed" (`screens_tenant.dart:237`, `kit.dart:435`) | Real photos (founder takes them, F14) | B |
| Rank "#2 near Hitec City" is global (`state.dart:246`) | Rank within the area | A |

### 3. Hostel page, beds and holds
| Now | Real | Group |
|---|---|---|
| Bed states random from a seeded generator (`data.dart:168-229`) | Owner's real rooms and live bed state | B |
| Same window/door/AC drawing in every room (`screens_tenant.dart:1342`) | Real per-room layout (F12) | B |
| House rules invented; owner's Manage → Rules never used (`screens_tenant.dart:785`) | Show the owner's rules | A |
| "Hold placed. Srinivas has been told on WhatsApp." (`state.dart:804`) | "Hold placed. Tell Srinivas on WhatsApp →" (opens real WhatsApp); server lock later | A / B |
| Hold timer is local; at 0:00 the bed stays held forever (`screens_tenant.dart:1651`) | Expire the hold at 0:00 (local now, server later) | A / B |
| **"Demo: simulate the owner confirming"** button (`screens_tenant.dart:1749`) | Remove | A |
| "Did you join? Anjani 102-B" shows for everyone (`screens_tenant.dart:582`) | Only for the user's real ended holds | A |
| Move-in date always "5 Oct" (`:624`) | Pick a real date | A |
| Owner phone "Call" only toasts (`fairplay.dart:260`) | Open the phone dialler | A |
| "I've moved in" makes you a resident yourself (`rewards.dart:243`) | Owner confirms move-in (F06) | B |

### 4. Payments
| Now | Real | Group |
|---|---|---|
| **"Pay advance" books instantly: "Paid ₹X… Booked · Yours"** (`shell.dart:708`, `state.dart:812`) | Open UPI app to pay the **owner's** UPI ID with note HZ-xxxx → tenant enters UTR → status **"Payment sent · waiting for owner"** → owner taps "Received" → only then "Booked" | A (honest states + UPI link) / B (owner's UPI ID, sync) |
| Pay rent sets Paid + "Receipt sent on WhatsApp" (`screens_resident.dart:258`) | Same UPI → UTR → owner confirms flow; receipt after confirm | A / B |
| Rent ₹8,020 and line items, history, receipt number all hard-coded (`screens_resident.dart:80-305`) | From the owner's rate card + meter; server ledger | B |
| Refund "within 7 days" not tracked (`screens_resident.dart:740`) | Owner marks refund with UTR, tenant confirms | B |
| ₹100 credit "on the next Hostelzy invoice", no invoices exist (`rewards.dart:216`) | Owner billing (F10) | B |

### 5. WhatsApp and enquiries
| Now | Real | Group |
|---|---|---|
| **"Open WhatsApp" only toasts; WhatsApp never opens** (`shell.dart:780`) | `wa.me/91<phone>?text=…` (add `url_launcher`) | A |
| "Srinivas has been told on Hostelzy…" (`shell.dart:764`) | Say "Send this on WhatsApp so Srinivas knows you came from Hostelzy"; server notify later | A / B |
| Link `hostelzy.in/r/HZ-…` goes nowhere (`state.dart:544`) | Real domain + page (F15) | B |
| HZ codes from a local counter; every enquiry named "Rahul Varma" (`state.dart:386, 528`) | Server-issued codes; the user's name | B |
| Owner "Call"/"WhatsApp" fake (`screens_owner.dart:499`) | `tel:` and `wa.me` | A |
| "verified by OTP" labels | Only after real OTP | B |

### 6. Resident screens
| Now | Real | Group |
|---|---|---|
| "Morning, Rahul · Anjani · Room 204 · Bed B" for everyone (`screens_resident.dart:65`) | From the resident's stay; greeting by time | A (greeting) / B |
| Food: always Thursday; week fixed 28 Sep – 4 Oct (`state.dart:375`, `data.dart:401`) | Real today's date | A |
| Meal tags always Done/Next/Later (`:157`) | From the clock | A |
| Complaint "Sent. Srinivas has 72 hours" (`:661`) | "Saved. Srinivas will see it when you're online" + WhatsApp link; server later | A / B |
| Give notice / swap "sent to Srinivas" (`:749, 856`) | Same honest wording; server later | A / B |
| Confirm stay: fills 482113, any 6 digits work (`:988`) | Real code check | B |

### 7. Owner screens
| Now | Real | Group |
|---|---|---|
| Owner is always Srinivas / Anjani (`state.dart:418` and many `'anjani'`) | Owner's own hostels | B |
| Header date "Thu 1 Oct", rent month "October 2026" (`screens_owner.dart:106, 839`) | Real date | A |
| Seeded hold requests restart on each launch (`data.dart:357`) | Server | B |
| "Confirmed. Karthik gets a WhatsApp message" / "Reminder sent" / "has been updated" toasts | Open WhatsApp with the message, or say "Saved" | A |
| **Invite QR is a random pattern** (`screens_owner.dart:1391`) | Real QR (`qr_flutter`) of the invite link | A |
| "Print poster" says "Poster saved as a PDF" (`:1322`) | Make a real PDF (`pdf`/`printing`) or remove | A |
| Hold-requests tile does nothing (`:58`) | Wire it | A |
| Deals "help you rank higher" but deals aren't in the score (`deals.dart:224`) | Fix the wording | A |

### 8. Admin (founder)
| Now | Real | Group |
|---|---|---|
| Fair Play cases + strike buttons open for anyone via `?start=aCases` (`fairplay.dart:523`, `main.dart:21`) | Separate admin login (web console) | A (remove from app) / B |
| Fixed "47 h left", 6 seeded cases (`data.dart:688-713`) | Server deadlines and cases | B |
| Fair Play OTP accepts any 6 digits (`fairplay.dart:170`) | Real OTP | B |

### 9. Data
- **Today is fixed at 1 Oct 2026** (`data.dart:41`) → use the real date (Asia/Kolkata). **A**
- 6 sample hostels, 21 residents, enquiries, complaints, menu, reviews, cases, rewards: keep only as
  sample data until F13; **real-looking phone numbers → replace with obvious fake ones. A**
- Ratings, review counts, category averages, ranking factors are constants. **B**

### 10. Demo and developer tools (must not be in the Play Store app)
| Now | Real | Group |
|---|---|---|
| URL params `?start=…&role=owner` skip login (`main.dart:9-31`) | Debug builds only | A |
| `?page=overview` "all screens" canvas (`ui/overview.dart`) | Debug only | A |
| On screens ≥ 730 px: phone frame + jump list "Mobile prototype. Everything is clickable" (`shell.dart:37-219`) | Real full-screen layout on tablets/web | A |
| Fake status bar "9:41 · 5G" (`shell.dart:150`) | Remove | A |
| Demo state builder `_prep` (`state.dart:437`) and leftover design toggles | Debug only / remove | A |

### 11. Words that promise things we don't do yet
"Verified stay", "verified residents", "Trusted tenant" ticks, "Hostelzy checks this from real
stays", "Notifications go to WhatsApp", "We remind the owner and check in a week", "The owner never
sees your name", "Exit rules locked… Hostelzy steps in", "one review per stay; edit later".
→ Keep the promise only when the feature exists; otherwise soften or hide. **A** (wording) / **B**.

## Plan (Ideas chat decision)
1. **F17-A "Honest app" (Build now, no keys):** everything marked A. New packages allowed:
   `url_launcher`, `qr_flutter`, `share_plus`, `pdf`/`printing`. Payment becomes
   "UPI to owner → enter UTR → waiting for owner → owner confirms". Owner's UPI ID is a field in
   the owner's rate card (sample value clearly fake until F13).
2. **F17-C "Real map":** flutter_map with free OpenStreetMap-based tiles for now (no key, small
   traffic); move to a keyed provider (MapTiler or Google Maps) when the founder adds keys. Real
   coordinates for sample hostels in Hitec City, Madhapur, Kondapur, Ameerpet.
3. **Group B items go into F13 (backend)** when the founder adds Supabase/Firebase/MSG91 keys.
4. Design chat: mockups only for screens that change meaning (payment pending states, honest
   hold/enquiry sheets, map). Build F17 after F10, before the app icon and F12.

## Design
Canvas https://claude.ai/artifact/7deh6fqgzmxdytYgjnwuhz. Design approved under the founder's standing approval (CLAUDE.md, DECISIONS 2026-10-02). Only screens whose meaning changes. Sample UPI ID is clearly fake: `sample.owner@upi`; sample phone `+91 90000 00001`.

Payments: **pay the owner by UPI → enter UTR → owner confirms → only then Booked / Paid**. Shown as a 4-step bar on every payment screen.
1. **Tenant: pay the advance.** Sheet with the amount, "Pay to Srinivas · sample.owner@upi", UPI note HZ-4821. "Pay ₹3,000 by UPI" opens the UPI app with everything filled in; also "I've already paid · enter UTR". Note: Booked only after Srinivas confirms.
2. **Tenant: enter the UTR** (12 digits), with where to find it; "Send to Srinivas".
3. **Tenant: status** (tweak Waiting for owner / Booked / Not received).
   - Waiting: "Payment sent · waiting for Srinivas to confirm", the bed "not booked yet", Remind on WhatsApp, Fix the UTR.
   - Booked: "Booked. Bed 204-D is yours", show HZ-4821.
   - Not received: "Srinivas says the payment didn't arrive", Fix the UTR, WhatsApp, cancel.
4. **Owner: "Received ₹3,000?"** on Today, with the UTR and UPI note, and Yes, received / Not received. Also covers rent. Hint: tap yes only after seeing the money.
5. **Resident: pay rent** (tweak Due / Waiting for owner / Paid / Not received). Same steps. Amount from the rate card plus the electricity meter the owner enters; history shows "Confirmed by Srinivas".
6. **Owner: Manage → Rates** gets "Where tenants pay you": UPI ID, name shown in UPI, "Test with ₹1", and "Hostelzy never holds the money".

Honest wording:
7. **WhatsApp sheet.** "Send this on WhatsApp so Srinivas knows you came from Hostelzy" (neutral box, not green); "Send on WhatsApp" opens WhatsApp; "Nothing is sent until you press send in WhatsApp."
8. **Hold** (tweak Active / Expired at 0:00).
   - Active: timer and "Srinivas doesn't know yet", with "Tell Srinivas on WhatsApp".
   - Expired: "0:00 · Your hold has ended. Bed 204-D is free for everyone again", with Hold again / See other beds.

Real map, login, large screens:
9. **Real map** (OpenStreetMap-style tiles, with "© OpenStreetMap contributors" shown). Square red price pins (the selected one in ink), an ink "you are here" dot with a halo, search and "my location" buttons, and a bottom card with distance from you, Directions (opens Google Maps) and View hostel.
10. **Login without demo buttons** (tweak Phone number / Code). No "Fill a demo number", no "Paste code"; Send code / Verify stay disabled until the input is complete; real "Resend in 0:24"; "Android can fill it in for you"; consent line.
11. **Tablet / desktop full screen** (1280 × 800). Left nav rail, list in the middle, map on the right. No phone frame, jump list or fake status bar.
- Dark mode: boards "3 in dark mode" and "9 in dark mode". Every board has a Dark tweak.

## Build
Shipped in parts (Build chat).

**Part 1 · shipped 2026-10-02** (branch `feature/f17-honest-app`):
- **Login (board 10):** no demo number / code buttons in the Play Store build (they stay as "Debug: …" in debug builds only, `kDebugMode`); placeholder "10-digit number"; "by SMS"; Send code / Verify grey until the input is complete; a real "Resend in 0:30" countdown, then "Resend code"; "Change number"; Terms and Privacy line. The code itself is still not checked by a server (F13).
- **Release build has no demo tools:** `?start=…`, `?page=overview` and other URL shortcuts work only in debug builds. "Demo: simulate the owner confirming", the Fair Play "Paste code from SMS" and Confirm-stay "Paste code from WhatsApp" are debug-only too.
- **Real links** (`url_launcher`): WhatsApp opens `wa.me/91<number>?text=…` (tenant → owner, owner → tenant, rent reminder, founder's plan reminder, share invite link and referral code); Call opens the phone app (`tel:`); Directions opens Google Maps search for the hostel. In tests, `AppState.lastLink` records the link.
- **WhatsApp sheet (board 7):** "Ask Srinivas on WhatsApp", neutral box "Send this on WhatsApp so Srinivas knows you came from Hostelzy", Send on WhatsApp / Copy message, "Nothing is sent until you press send in WhatsApp." The dead link `hostelzy.in/r/…` is gone from the message.
- **Holds (board 8):** "Free hold · Srinivas doesn't know yet", Tell Srinivas on WhatsApp; the hold **expires at 0:00** (bed freed), with "Hold expired · 0:00", Hold again / See other beds.
- **Honest wording:** no "has been told", "gets a WhatsApp message", "Reminder sent", "Poster saved as a PDF" (now Copy link), complaint / notice / swap say "saved, tell Srinivas on WhatsApp too", no "Hostelzy steps in after 72 hours".
- Test: `honest app: links open WhatsApp, phone and maps; holds expire; login resend (F17)`.

**Part 2 · shipped 2026-10-02** (branch `feature/f17-payments`): payments are **UPI to the owner → UTR → owner confirms → only then Booked / Paid** (boards 1–6).
- `Payment` (advance or rent): due → waiting (UTR sent) → paid, or missing (owner says it didn't arrive). Every payment screen shows the 4-step bar.
- **Advance:** "Pay advance" puts the bed on hold for the tenant (status `paying`, bed shows On hold) and opens **Pay the advance** (amount, "Pay to Srinivas · sample.owner@upi", UPI note = HZ code). "Pay ₹3,000 by UPI" opens the UPI app with `upi://pay?pa=…&pn=…&am=…&tn=HZ-…&cu=INR`, then asks for the UTR; "I've already paid · enter UTR" goes straight there. The hold screen shows Waiting for Srinivas ("not booked yet", Remind on WhatsApp, Fix the UTR), Not received (Fix the UTR, WhatsApp, Cancel and pick another bed), and **Booked only after Srinivas confirms**.
- **Owner Today → Payments to check:** "Received ₹3,000?" with the UTR and UPI note, Yes, received / Not received (also for rent); one sample rent payment from Arjun is waiting.
- **Rent:** the same steps; "Pay Srinivas ₹8,020" with Pay by UPI / I've paid · enter UTR; waiting / not received / paid ("Srinivas confirmed on …", Share receipt on WhatsApp); history says "Confirmed by Srinivas". No more card / net banking or "Receipt sent on WhatsApp". The amount lines are still sample data (server ledger, F13).
- **Manage → Rates → Where tenants pay you:** UPI ID, name shown in UPI, Test with ₹1, "Hostelzy never holds the money"; the sample ID `sample.owner@upi` is flagged until the owner types theirs.
- Tests: the F04 booking, F09 move-in and rent tests now go through UTR + owner confirm; new test `payments: owner says not received; tenant fixes or cancels; owner UPI ID (F17)`.

**Part 3 · shipped 2026-10-02** (branch `feature/f17-map`):
- **Real map (board 9):** `flutter_map` with OpenStreetMap tiles and "© OpenStreetMap contributors" shown; square price pins (red, the selected one in ink, grey when filtered out), the searched landmark as an ink dot with a halo, the search bar, and a card with distance, rating, free beds, price, **Directions** (Google Maps directions to the hostel's coordinates) and View hostel. Hostels have real coordinates (Madhapur, Kondapur, Gachibowli, KPHB, Ameerpet); new hostels from Add hostel use their area. Android release manifest now has INTERNET.
- **Distances instead of made-up minutes:** Explore, the hostel page and the map show straight-line "1.6 km from Hitec City", and "Nearest" sorts by it. Travel time comes later.
- **Large screens (board 11):** the Play Store build on tablets / laptops shows the app column with the real map beside it for tenants (a brand panel for other roles). The phone frame, jump list, "Mobile prototype" text and the fake "9:41 · 5G" status bar are debug-only (`HostelzyShell.prototypeFrame`).
- **Follow-up (branch `feature/f17-map-config`):** tile provider in one file, `lib/map_config.dart` (URL, user agent, attribution). OSM's public tiles are for testing only, not heavy production traffic: switch to a keyed provider (MapTiler / Stadia / `google_maps_flutter`) when the founder adds a key. All landmarks are labelled on the map; a "my location" button says location comes with the permission (F15) and never fakes a spot. Android launch screen shows the room mark on white.
- **Not done from board 9/11:** real "my location" (needs the location permission, F15) and the desktop left nav rail (the app's own tabs are used).
- Test: `real map and the large-screen layout (F17)`.

**Group A cleanup · shipped 2026-10-02** (branch `feature/f17-cleanup`):
- All sample phone numbers are obvious fakes (`90000 000xx` for people, `90000 001xx` for owners).
- **Real date:** the Play Store build uses today's date in India; debug builds and tests keep 1 Oct 2026 so the sample data lines up. Rent month, complaint date, notice date and the add-booking date chips follow it.
- **Real QR codes** (`qr_flutter`): the resident invite QR encodes the invite link (the `hostelzy.in` page itself needs the domain, F15); the plan invoice QR is a real `upi://pay` code, marked "Sample QR, don't pay with it" until Hostelzy's UPI ID is set. "Print poster" was replaced by Copy link (no fake PDF).
- **"Did you join?"** asks about the tenant's own ended hold; the 102-B sample shows only in debug builds.
- **Hostel page house rules** for Anjani come from the owner's Manage → Rules (money terms always from the rate card).
- Booked holds no longer show a made-up "5 Oct"; the Hold requests tile responds; deals copy says "show in Best deals" (deals are not in the ranking score).
- Founder admin screens (cases, payments, layouts, add hostel, tracker) are reachable only through debug tools; a separate admin login comes with F13.
- Test: `honest leftovers: fake sample numbers, owner rules, real QR, joined prompt (F17)`.

**Still open:** owner screens that keep Anjani's sample data after switching hostels (needs per-hostel data, F13); group B (real OTP, sync, server HZ codes, ledger) waits for F13.

