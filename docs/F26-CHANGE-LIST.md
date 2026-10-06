# F26: what the founder asked vs what the prototype has (hub audit, 2026-10-06)

Source: the code diff `main` → `f26/integration` (prototype v4), checked line by line against `features/F26-founder-review-1.md`.
Tags: **Asked** = the founder's change · **Forced** = needed for an asked change · **Not asked** = Build's extra, being reverted.

## 1. Expectations vs prototype
| # | Founder asked | Prototype v4 | Gap |
|---|---|---|---|
| 1 | Map icon in the search bar | 📍 inside the search field opens the map near you | None |
| 2 | Near me / pick a place, sorted by price; simple filter row | One row: Near me · Price ↑ · Filters | "#1 near you" removed, extra "Then by price" line and "Lowest price" tags, location no longer sorts by distance, Filters renamed ("Who"), "Any" rent dropped, new "No food" chip. **Reverting** |
| 3 | Building map on the hostel page | Building view inline | None |
| 4 | Whole-week food menu, always open | 7-day table, no toggle | None |
| 5 | One-word verified badge | ✓ VERIFIED, navy | None |
| 6 | Remove the 4 tag boxes | Removed | None |
| 7 | Message + Call only after a hold | Locked before, WhatsApp + Call after | "Talking through Hostelzy keeps your deal and your ₹100 reward" line removed. **Reverting** |
| 8 | Floor filter, room layouts shown directly | All rooms' drawn layouts, floor chips jump | "See cheapest beds" list removed. **Reverting** |
| 9 | Hold result notification and steps | Sent → Owner reviewing → Kept / Declined | None |
| 10 | Remove Saved / Holds from Me | Removed | None |
| 11 | Log out in red | Red | None |
| 12 | Red "Edit this layout", publish needs a resident | Done | Try-mode wording rewritten. **Reverting** |
| 13 | No Food page; week table on Home | Done | "How was breakfast?" card added on Home. **Reverting** |
| 14 | My stay tab with Help inside | Done | None |
| 15 | No holds for residents | Replaced by your later call: residents can hold elsewhere | None |
| 16 | Red dot on hold result | Done | None |
| 17 | Find a bed = tenant app, Saved & Holds + My stay | Done | None |
| 18 | Owner Today grouped | Holds · Payments · Fixes tabs | 3 bottom cards folded in; "Confirm hold" → "Confirm". **Reverting** |
| 19 | Owner Beds: layouts only | Building view only | "Rooms and rates ›" link removed. **Reverting** |
| 20 | Rent: Call + WhatsApp, Paid green | Done | None |
| 21 | Unverified listings | Done | "N beds free now" header replaced. **Reverting** (both shown) |
| — | Layouts open to everyone | Done | None |
| — | AC / non-AC pricing untouched | Code identical to `main` | Founder saw a difference. **Build checking; screenshot needed** |
| — | Green for money saved kept | All 14 green spots identical to `main` | Only the ₹100 line (plain text) was lost, see #7 |

## 2. Everything that changed from the previous app
### Tenant · Explore
| Change | Tag |
|---|---|
| 📍 inside the search field; placeholder "Area, landmark or hostel" | Asked #1 |
| Chip row Men · Women · Co-living · AC · Under ₹8,000 · Hostelzy deals → Near me · Price ↑ · Filters | Asked #2 |
| Sort Price ↑ default; Distance · Rating · Best deals; "Recommended" gone | Asked #2 |
| One Featured hostel pinned on top | Asked (hub #2) |
| "#1 near you" label removed; "Then by price, lowest first" line; "Lowest price" / "Nearest" tags | Not asked |
| Location on no longer switches to Nearest; toast text changed | Not asked |
| Filters: "Budget" → "Rent" without "Any"; "For" → "Who"; chip order; new "No food" | Not asked |
| Filters count shown in the label instead of a red badge | Forced #2 |
| Header "N beds free now" → "N verified · M listed" | Not asked (both will show) |
| UNVERIFIED cards "Around ₹7,000–9,000 · expected"; verified first in each ₹2,000 band | Asked #21 |
### Tenant · Hostel page
| Change | Tag |
|---|---|
| ✓ VERIFIED navy + "Beds and prices checked by Hostelzy · date"; "Visited by Hostelzy" block gone | Asked #5 |
| Building view inline; "See the whole building ›" gone; 80+ beds "See all N rooms ›" | Asked #3 |
| Food "today" card → week table | Asked #4 |
| 4 tag boxes removed | Asked #6 |
| Owner number / "Ask on WhatsApp" → lock line + Message and Call after a hold | Asked #7 |
| "Talking through Hostelzy keeps your deal and your ₹100 reward." removed | Not asked |
| WhatsApp text now carries the HZ code | Asked #7 |
### Tenant · Pick a bed
| Change | Tag |
|---|---|
| Plan / Room / Building tabs gone; every room's layout in one scroll; floor chips jump | Asked #8 |
| "See cheapest beds ›" list removed | Not asked |
| Red "Edit this layout" → try mode; Publish → "Only residents can send a fix" | Asked #12 |
| Try-mode titles and banner rewritten | Not asked |
| "Sign in to see layouts" and women's-PG "after you hold" locks removed | Asked (open layouts) |
### Tenant · Holds, Saved, Me
| Change | Tag |
|---|---|
| Steps Sent → Owner reviewing → Kept / Declined; "Still waiting. Call the owner?" | Asked #9 |
| Red dot on Holds | Asked #16 |
| WhatsApp sheet "Ask X" → "Message X"; "keeps your Hostelzy price" line removed | Forced #7 |
| Me: Saved and Holds rows gone; Log out red | Asked #10, #11 |
| Settings "New free beds" note about verified alerts | Forced #21 |
### Resident
| Change | Tag |
|---|---|
| Tabs Home · Rent · My stay · Find a bed · Me (Food, Help gone; "Pay rent" now plain "Rent") | Asked #13, #14 |
| Home: week table replaces today's food | Asked #4 |
| Home: "How was breakfast?" card added | Not asked |
| My stay: bed, move, notice, refund, review, layout fix, Help as two sheets | Asked #14 |
| Find a bed = tenant app; residents can hold | Asked #17 |
| Meal reminders open Home | Forced #13 |
### Owner
| Change | Tag |
|---|---|
| Today: Holds · Payments · Fixes tabs, most urgent first, "Nothing needs you now" | Asked #18 |
| Today: "Still N free beds? / Rates right? / Layouts match?" cards folded into tabs | Not asked |
| Today: "Confirm hold" → "Confirm" | Not asked |
| Beds: building view only; Rooms list gone | Asked #19 |
| Beds: "Rooms and rates ›" link removed | Not asked |
| Rent: bell → Call + WhatsApp; Late light red; Due plain; Paid green (was already green) | Asked #20 |
| Manage: Enquiries page removed | Forced #7 |
| Reviews: rank counts verified hostels only | Forced #21 |
### Team console and web
| Change | Tag |
|---|---|
| Console: Listed and Claims pages | Asked #21 |
| Web enquiry link page now points to the app | Forced #7 |
