# F22 · Redesign every screen (F21 style)

**Stage:** Designing · founder, 2026-10-02 ("I really like the after… do every screen, your own
decisions, never take my approval").

## Rules (from the approved F21 demo)
- **One job per screen**, one clear red primary action, everything else secondary or in a sheet.
- **Photo first** wherever a hostel/room appears.
- **Plain words**: Booking code, UPI reference, "Your price is fixed", "Came from the app".
- **Real numbers in one line** (rent · move-in cost · what's extra).
- Lists over sideways scrolls; vertical rows with icon + one-line status.
- States everywhere: skeleton, empty (what to do next), offline + Retry, inline error + Retry, Undo.
- Accessibility: 48dp targets, body ≥ 14px, no info in 10–11px caps, text scaling to 2.0.
- Telugu-ready copy (short labels, no idioms).
- Keep brand: Archivo, #ec3013, 2px rules, square corners, green only for savings, light + dark.

## Order (Design area by area; Build follows each area in parallel)
1. Tenant: Explore, Map, Search/filters, Hostel page, Picker, Hold/Book, Saved, Holds, Me, Settings
2. Resident: Home, Rent/Pay, Food, Help, Move/Swap, Notice, Reviews, Rewards, Reminders
3. Owner: Today, Beds, Rent, Manage + every Manage page, Invite, Layouts/Rooms/Photos, Plan/Invoices,
   Fair Play, Team
4. Onboarding + Hostelzy team in app + team console website + web pages
5. Leftovers: permission, gate, delete account, F19/F20 screens

## Design
Update the **All screens** canvas in place, area by area (tag "Redesigned"). Tell Build after each area.

## Build
One PR per area; flow tests per area; keep server behaviour unchanged.
