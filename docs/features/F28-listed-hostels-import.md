# F28 · Verified filter + listed-hostel import (ideating, 2026-10-18)

**Founder (2026-10-18):** "a filter of verified and unverified hostels. Scrape all the data from the internet and put the
actual details of all the hostels; verified hostels have the detailed information rather than the dummy information
scraped from the internet. Can we scrape from Google Maps or any other platform? Ideate on this."

## What exists already (F26 #21, on main since apk-104)
- `hostels.status = 'listed'` = UNVERIFIED tier: name, gender, area, pin, photos, `rent_min`–`rent_max`. No rooms, beds,
  holds or owner contact. Tenants see the UNVERIFIED badge, "Tell me when verified", "Are you the owner? Claim this hostel".
- Console › Listed: the team lists a hostel by hand (`list_hostel` RPC); Explore header counts "N verified · M listed".
- Missing: a **Verified only** filter, and a **bulk way to get hostels in**.

## Ideas

### A. The filter (small, 1 screen touched)
Filters sheet (H1) gets one more switch under Food included: **Verified only** (off by default). Chip row stays as is.
Explore list shows the UNVERIFIED cards after the verified ones when the switch is off. Hostel count line unchanged.

### B. Where listed hostels come from (the big question)
| Source | What we get | Legal / cost | Verdict |
|---|---|---|---|
| **Google Places API** (Text Search "PG hostel in Kukatpally", Nearby Search) | Name, pin, address, phone, rating, 1–10 photos, opening hours. No rent | Allowed. Needs a card on Google Cloud (founder's card issue). Free monthly tier per SKU, then paid. **Rule:** only `place_id` may be stored for ever; other fields max 30 days → we store place_id + pin + our own typed name/photo, refresh the rest | ✅ Best legal source for *finding* hostels |
| **Scraping Google Maps pages** | Same as above | Breaks Google's Terms; account/IP bans; data can't be kept | ❌ No |
| **Justdial / Sulekha / NoBroker / Housing / 99acres / MagicBricks pages** | Names, phones, sometimes rent (often stale or bait) | Their terms forbid scraping; rent is the least reliable field | ❌ Not as a pipeline. ✅ OK as a *human* reading list while calling owners |
| **OpenStreetMap (Overpass)** | Pins for `tourism=hostel` / `amenity=dormitory` | Free, open licence (credit OSM) | 🟡 Thin for Hyderabad PGs; use as a supplement |
| **Owners themselves** ("Claim this hostel", WhatsApp list, partners) | Real rent, real photos | Free, and it is the verification path anyway | ✅ The only source for rent and beds |

**Honesty rule applies:** a listed hostel never shows a rent we did not confirm with a person. Scraped/API data gives
name, pin, phone, photo; rent range comes from a call or stays "Rent on request".

### C. The pipeline I'd build (if the founder says yes)
1. `tools/import-places.ts` (team-only script, run by the hub/Build, not in the app): for each of ~25 Hyderabad areas run
   Places Text Search for "PG" / "hostel" / "paying guest", dedupe by `place_id`, write `hostels` rows as `status='draft'`
   with `source='google_places'`, `place_id`, pin, phone, up to 3 photo URLs. Nothing public yet.
2. Console › Listed gets an **Import queue**: team opens each draft, calls the number (script on screen), fills
   rent_min/rent_max and gender, taps **List** → `listed`. Rows without a call stay draft (invisible).
3. Owner claim → verification → `live` as today.
4. Refresh job (pg_cron, weekly) re-fetches Places fields for listed rows, honours the 30-day rule, drops closed ones.

Volume: Hyderabad has thousands of PGs on Google Maps (I'll confirm with one Places query per area before promising a number).
At 3 min per call, 20 hostels a day per person.

### D. Not in this spec (ideas kept)
Auto-rent from scraped portals · tenants adding hostels · reviews imported from Google (not allowed to store).

## Questions for the founder (yes / no)
| # | Question | My pick |
|---|---|---|
| 1 | Use Google Places API (needs your card on Google Cloud; free tier likely enough for one city) | Yes |
| 2 | Rent on listed hostels only after a phone call; otherwise "Rent on request" | Yes |
| 3 | Verified-only filter as a switch in Filters (not a chip in the row) | Yes |
| 4 | Who calls owners: you + 1 partner at ₹20 per listed hostel? (money → Finance) | Ask Finance |

## Design · Build
Not started. Screens touched if approved: H1 Filters (+1 switch), S8 Explore (order of listed cards), console Listed (+Import queue, T-id new).
