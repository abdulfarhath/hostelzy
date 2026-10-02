# F24 · Close every gap (app = canvas = everything we discussed)

**Stage:** Spec ready · founder, 2026-10-02 ("never miss a single screen or feature; canvas and app the
same"). Source: three audits (canvas vs app, every founder message, every doc/decision). ~170 items
checked; these are the ones missing or partial. Chats decide details; no approval needed (only items
marked 👤 need the founder).

## Wave A — make real hostels possible (blocks "20 hostels this month")
1. **Owner phone on the server**: add `owner_phone` (and owner WhatsApp) to hostels; used for "owner's
   number after a hold", enquiry WhatsApp, resident Message owner / Remind / notice / swap / Something
   wrong, owner→resident Message. Resident phone visible to staff for "Message resident".
2. **Onboard a real hostel end to end** (app team mode + console): hostel, floors, rooms, beds, rate
   card, terms, map pin, food, tags, photos, residents, **link the owner account** (owner role, not just
   managers). Go live only when the checklist is complete; go-live creates the plan row with the 30-day
   trial (`trial_ends`).
3. **Owner room/floor edits saved to the server** (add/remove rooms & floors, uneven floors).
4. **Food menu** per hostel in `menus` (owner Save, starts empty), resident Food + Home today, food
   rating saved, tenant "Food menu ›" peek, meal reminders use the menu's real times. *(Build already on it.)*
5. **Notice / swap / move-out** via `move_requests`; owner confirms; "Mark as leaving" saved; refund
   tracked (owner marks refund + UPI reference, tenant confirms).
6. Real values instead of fake ones: owner reply speed (from enquiry/hold reply times), ranking factors,
   availability "N free · confirmed X days ago" (server confirmations), "Visited by Hostelzy" (server
   field), house rules (no invented rules when empty).

## Wave B — owner & tenant features promised but partial
7. Item **Working / Not working** saved; tenants see it; raises a complaint; "AC under repair".
8. **Hold for a walk-in** saved on the server.
9. **"Still N free beds?" nudge** every 3 days (Today card + push); confirm saved; **confirm layouts
   every 3 months** saved.
10. **Fan / AC layer toggle** back on the room layout (rings only when the layer is on) — DECISIONS F12.
11. **Room shapes** L / T / U / custom beyond rectangles, and **"Request a shape — done in 48 h"** tracked
    (owner request → team queue in console → team draws → Send to owner → owner sees it).
12. **Deal headline = 6-month saving** with upfront part + "With Hostelzy vs Walk in" (DECISIONS F03),
    inside the single F21 price table.
13. "Your price is fixed" perks stored on the server (owner sees them).
14. "Did you join?" (Yes / Not yet / Still deciding) saved → Fair Play signal.
15. "Checked by N residents" on the hostel page too.
16. Trusted tenant perks: first look at new free beds, lower-advance deals; Members' 2-hour hold
    countdown uses the tenant's level from the server.
17. Owner-only areas (plan, deals, rates, Fair Play) enforced by role in app + RLS (managers can't).
18. Fair Play: rules acceptance saved; "Joined before Hostelzy" import path; strikes expire (30 days for
    strike 2) and strike 3 hides the hostel on the server; case photo proof back; all 6 signals on the
    server; tenant reports visible to the team in the console; "3 fixes in 6 months = 1 warning" counted;
    correct strike labels.
19. AC room must have an AC unit — also when changing rates (not only when publishing).
20. Featured spot for 80+ bed hostels in ranking (DECISIONS F10).
21. Deals pause for tenants when the owner's plan is 15+ days late (tenants can read "deals paused"),
    5-day-late reminder as push/WhatsApp, rent-due / invoice / availability pushes.
22. Notification switches honoured by the server; "New free beds" alerts.
23. Edit your name in Settings; name never pre-filled (empty field, Google name only as a hint).
24. Confirm your stay opens after joining with a code; camera explainer before first photo.
25. Electricity by meter: owner enters the meter reading/units → resident rent shows it.
26. Laundry day: owner sets it → resident reminder.
27. "Tell me when it's ready" (layout coming soon) as a real notify-me.
28. Remove false "verified by OTP" wording everywhere (poster, Trusted sheet, aAdd 5) until OTP exists.
29. In-app team tracker and team members from the server (no sample leads/"Founder 9000000100").

## Wave C — platform
30. Offline list cache + drafts; https App Links for r/ and j/ (when the domain exists).
31. Staging + production Supabase projects; Play AAB build in CI (upload key 👤).

## Canvas must add / fix (Design)
Owner Enquiries list; layer toggle on Room; shape picker + shape request flow; console layout queue,
Rewards page with Reverse, tenant reports; manager invite + join; "Still N free beds?" card on Today;
confirm-layouts card; electricity meter (owner) + meter line (resident); laundry day setting; refund
tracking (owner + tenant); deal headline (6-month saving); "Checked by N" on hostel page; Trusted perks;
case photo; remove "Publish for approval"/"Hostelzy admin" from oEditor; remove OTP wording; picker
opens on room plan (layout-first); owner block on hostel page (number after a hold).
Rule: every new screen in the app gets a board; same count both ways (CLAUDE.md).

## Needs the founder 👤
SMS OTP (card for Firebase Blaze) · map key or MapTiler · Play upload key · Telugu/Hindi native check ·
demo key step · SQL runs · **monthly cap on Hostelzy-funded rewards (₹ amount)**.
