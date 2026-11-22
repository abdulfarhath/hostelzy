# Hostelzy · Data fetch brief v3: get everything (for an outside AI)

**Written by:** Hostelzy hub, 2026-11-22, at the founder's request.
**Founder (2026-11-22):** "Forget rules, we need as much data as possible, we can scrape from anywhere, get it from anywhere."
This replaces v1/v2 of this brief and the 2026-10-18 "no scraping" decision.

**Who reads this:** an AI (or person) with internet access whose job is to **collect every bit of public data about PGs /
hostels / co-living in Hyderabad**, from every website, map, portal and listing you can reach, so the Hostelzy app looks full
on day one. **You need no other context.** Read it once top to bottom, then start.

**Phase 1 = data only (founder, 2026-11-22).** Collect everything now and deliver it in the format in sections 7 and 7b.
Nothing goes into the app yet; Hostelzy loads it later. So **the format matters as much as the data**: use the exact
field names and allowed values below, so the files load into the app with no cleaning.

---

## 0. The job in one line

Find **every PG / hostel / co-living place in Hyderabad** (target **5,000+**), with **everything** known about each one
(exact pin, phone, rents per sharing, food, AC, amenities, rules, photos, ratings), plus the places around them, from
**every source**, merged into one clean set of files (section 7).

---

## 1. What Hostelzy is (so you know what "useful" means)

| | |
|---|---|
| Product | A phone app for **Hyderabad PGs and hostels** |
| Tenants | Search on a list and a map, filter (Men / Women / Co-living, price, AC, food, sharing), open a hostel page, hold a bed |
| Residents | Pay rent, see the week's food menu, raise complaints |
| Owners | Run their hostel: beds, rooms, rent, residents, meals |
| City | Hyderabad + Secunderabad + Cyberabad (whole GHMC / HMDA urban area) |
| Typical tenant | Student or IT employee, 18–30, searching near a college, coaching centre or office |

### How your data is used
| Step | What |
|---|---|
| 1 | Your rows go in as **drafts** (tenants don't see them yet) |
| 2 | The Hostelzy team **calls the phone number**, confirms it's a real PG, confirms Men/Women, rent, food |
| 3 | It goes live as an **UNVERIFIED** card (name, area, pin, photos, rent range). Owner signs up later → **✓ VERIFIED** |

So the most valuable things are, in order: **exact pin → phone / WhatsApp → name → Men/Women → rents → everything else.**

---

## 2. The only lines (they protect the data, not slow you down)

| # | Line | Why |
|---|---|---|
| 1 | **Never invent a value.** Unknown = `null`. | A made-up rent or phone is worse than none: the team wastes calls and tenants lose trust |
| 2 | **Every value says where it came from** (`source`, `url`, `seen_at`). | Merging, re-checking, removing a source later if needed |
| 3 | **Public pages only.** Don't log in with fake accounts, don't break CAPTCHAs or paywalls, don't use leaked databases. | Getting past a login or CAPTCHA is "unauthorised access" under Indian law (IT Act s.43/66); public pages are fine |
| 4 | **Go slow per site** (≈1 request / 2–3 s per domain, back off on 429/403, rotate nothing). | Not getting blocked halfway; not knocking a small site over |
| 5 | **Never put an API key, cookie or password in a delivered file.** | Leaks |

Everything else is open: Google Maps, every portal, every chain's site, social media public pages, classifieds, search results.

---

## 2b. Location must be exact (founder, 2026-11-22)

The map pin is what tenants walk or ride to. **Accurate `lat` / `lng` for every hostel is required.**

| Rule | Detail |
|---|---|
| Precision | At least **6 decimals** (`17.438123, 78.448710`). Never round. |
| Best pins, in order | 1 Google Maps business pin · 2 portal listing's own map pin (most portals embed lat/lng in the page JSON) · 3 OSM node / building centre · 4 geocoded full address (house no. + street) |
| Never a pin | Area centre, pincode centre, locality from geocoding only "Madhapur, Hyderabad". These get `location_quality = "area_only"` and are not shown as a pin |
| `location_quality` | `rooftop` (pin on a building outline, check against OSM `building=*` within 15 m) · `building` (business pin, no outline to check) · `street` · `area_only` |
| Many sources, one place | Keep every source's pin; pick the best by the order above as `lat`/`lng`; write the largest gap as `pin_gap_m`. Over **75 m** → "check pins" list in `REPORT.md` |
| Flags | Pin > 3 km from its area centre, outside the city box, or two different hostels within 5 m → flag in `REPORT.md`, don't drop, don't "fix" by guessing |

---

## 3. Sources: hit all of them

### A · Maps
| Source | What to take | How |
|---|---|---|
| **Google Maps** | Name, exact pin, address, phone, website, rating, review count, category, open/closed, photos, popular review keywords ("food", "clean", "girls") | Places API (New) if a key is given (cheapest: IDs-only grid, then Details); otherwise the Google Maps search results pages with a headless browser, grid search (section 5) |
| **OpenStreetMap** | Name, node/building pin, tags (`female=yes`, `phone`, `website`) | Overpass API / Geofabrik extract |
| Bing Maps, Apple Maps (web), MapmyIndia / Mappls, HERE WeGo | Same as Google; catches places Google lacks; second pin to cross-check | Public search pages / free APIs |

### B · PG and rental portals (richest for rent, sharing, food, amenities)
| Source | Typical data |
|---|---|
| **NoBroker** (PG section) | Rent per sharing, deposit, food, AC, amenities, rules, gender, photos, map pin |
| **MagicBricks** (PG/hostel) | Rent per sharing, gender, food, amenities, pin, sometimes owner name |
| **99acres** (PG) | Rent, sharing, gender, amenities, pin |
| **Housing.com** (PG) | Rent, sharing, gender, food, amenities, pin |
| **Justdial** | Name, phone (often masked), address, rating, category "PG / hostel / ladies hostel" |
| **Sulekha**, **Quikr**, **OLX** (rooms / PG) | Phone, rent, area, photos |
| **CommonFloor**, **Makaan**, **SquareYards**, **NestAway**, **Flatmates/Facebook-mirror sites** | Rent, sharing, area |
| **Google search** itself | `"PG in <area>" Hyderabad`, `"ladies hostel" <area>`, `site:instagram.com PG <area> Hyderabad` → find the long tail |

### C · Branded chains (each has a full public catalogue with exact rents)
Stanza Living · Zolo · Colive · Housr · Your-Space · Settl · Isthara · Hello World · Coho · Cove · Tribe · OYO Life /
any other you find. Take every Hyderabad property: name, pin, rent per sharing and per AC/non-AC, food, amenities, gender,
photos.

### D · Social and the hostel's own pages
| Source | What |
|---|---|
| Hostel's own website | Rent, food, menu, rules, WhatsApp, photos |
| **Instagram** public business profiles (`#hyderabadpg`, `#ameerpetpg`, `#ladieshostelhyderabad`…) | Name, WhatsApp/phone in bio, rent in posts, photos |
| **Facebook** public pages and public posts; **YouTube** room-tour videos (titles/descriptions give name, area, rent, phone) | Same |
| Telegram / WhatsApp public channel directories that are open without joining | PG ads with phone + rent |

### E · Around the hostel (for "Near metro", travel minutes, "Nearby")
| Data | Source |
|---|---|
| All Hyderabad Metro + MMTS stations, bus stations | OSM, HMRL / L&T Metro site |
| IT parks and big offices (Mindspace, DLF, Raheja, Waverock, Financial District…) | OSM, Google Maps, official sites |
| Colleges, coaching centres (Ameerpet, Ashok Nagar, Dilsukhnagar), hospitals | OSM, Google Maps, AICTE/UGC lists |
| Shops, ATM, gym, pharmacy, bus stops within 800 m | OSM |
| **Travel minutes** from each hostel: walk to nearest metro + ride to 12 hubs | Self-hosted OSRM / openrouteservice on OSM (no limits); Google Routes if a key is given |
| Area list with aliases and pincodes (target 80–120 areas) | OSM boundaries, India Post |

---

## 4. What to collect for each hostel (everything, every source)

| Group | Fields |
|---|---|
| **Identity** | `name`, `aliases` (other spellings across sources), `brand` (chain), `kind` (pg / hostel / coliving / working_women / student / backpacker) |
| **Location** | `lat`, `lng`, `location_quality`, `pin_gap_m`, `address`, `landmark` ("opp. Ameerpet metro"), `pincode`, `area` (from your `areas.json`) |
| **Contact** | `phones[]`, `whatsapp`, `email`, `website`, `instagram`, `facebook`, `owner_or_manager_name` (only if a listing names them) |
| **Who it's for** | `gender` (Men / Women / Co-living) + where it came from; `for` (students / working / both) |
| **Rent** | `rents[]` = `{sharing: 1-6, ac: true/false, rent_month, food_included}` per source; `deposit`; `maintenance`; `electricity` (included / extra / per unit); `notice_days`; `min_stay` |
| **Food** | `food` (yes/no), `meals` (breakfast/lunch/dinner), `veg_only`, `menu` text if published, meal times |
| **Rooms** | `sharing_types[]`, `ac_rooms`, `attached_bath`, `total_beds` (only if stated), `floors` |
| **Amenities** | WiFi, AC, geyser, washing machine, fridge, RO water, TV, power backup, lift, parking (bike/car), CCTV, biometric, warden, housekeeping, laundry, gym, study room, cupboard, mattress… as a list of the exact words seen, plus a normalised list |
| **Rules** | Gate closing time, visitors, guests, smoking/drinking, pets |
| **Media** | `photos[]` = `{url, source, label if any}` (all of them), `video_urls[]` (room tours) |
| **Social proof** | `ratings[]` = `{source, stars, count}`; `review_keywords[]` (top words/phrases from reviews, e.g. "good food", "strict timings"); `review_count_total` |
| **Freshness** | `listing_urls[]` (every page it appears on), `listed_on` / `updated_on` dates from portals, `business_status`, `first_seen`, `last_seen` |

Keep the **raw per-source values** too: the merged row picks the best, the raw rows keep everything (section 7).

**Keep:** PG, paying guest, hostel (students / working), co-living, ladies hostel, boys hostel, working women's hostel,
per-bed service apartments. **Mark, don't drop:** college campus hostels (`campus=true`), backpacker hostels
(`kind="backpacker"`). **Drop:** hotels, lodges, OYO rooms, resorts, per-night guest houses.

---

## 4b. Owners and social media (for the founder's marketing calls, founder 2026-11-22)

The founder will **call and WhatsApp every owner himself** to bring their hostel onto Hostelzy. For that he needs, per owner:
who to ask for, every number that reaches them, and where they are active online. This data is **never shown in the app**;
it is the founder's call list.

### Per owner (one owner can run many hostels)
| Field | What | Where to find it |
|---|---|---|
| `owner_key` | Your id, `own:0001` | — |
| `name` | Owner or manager name exactly as the listing / board / page shows it ("Ravi garu", "Mrs. Lakshmi") | Portal listings ("Posted by"), Justdial, own website "Contact", Instagram bio, YouTube video description, Google review replies signed with a name |
| `role` | `owner` / `manager` / `caretaker` / `chain_office` / `unknown` | Same |
| `phones[]` | `{number, type: mobile/landline, whatsapp: true/false/null, seen_on: [sources], seen_at}` | Google Maps, Justdial, portals, Instagram/Facebook "Call"/"WhatsApp" buttons, wa.me links, posters in photos (read the number off a board in a photo only if clearly legible), own website |
| `email` | Business email | Website, Facebook "About", Instagram contact button |
| `hostels[]` | Every `hostels.jsonl` key this owner runs | Same phone / same name+brand across listings |
| `hostel_count` | Number of hostels | Count of the above. **Owners with 3+ hostels go to the top of the list** |
| `languages` | Telugu / Hindi / English / Urdu, if a page shows it | Posts, videos |
| `best_channel` | `whatsapp` / `call` / `instagram_dm` / `email` | The channel where they're most active |

### Social presence (per hostel and per owner)
| Field | What |
|---|---|
| `instagram` | `{url, handle, followers, posts, last_post_date, posts_last_30d, has_whatsapp_link, bio_phone}` |
| `facebook` | `{url, followers_or_likes, last_post_date, phone_on_page}` |
| `youtube` | `{url, subscribers, videos, last_upload_date}` + room-tour video links |
| `google_business` | `{maps_url, rating, review_count, owner_replies_to_reviews: true/false, last_review_date, photos_count}` |
| `website` | `{url, has_booking_form, has_whatsapp_button}` |
| `portals[]` | Every portal it's listed on (`nobroker`, `magicbricks`, `housing`, `99acres`, `justdial`, `sulekha`, `olx`, `quikr`) with the listing URL and "posted / updated" date. **Listed on paid portals = already spends on marketing = warm lead** |
| `ads_seen` | Meta Ad Library (public, no login needed for India searches) entries for the page: `true/false` + count |
| `presence_score` | 0–5: one point each for Google profile with owner replies, Instagram active in last 30 days, Facebook active, on 2+ portals, own website. **Not a guess: computed only from the fields above** |

### Marketing priority (computed, not guessed)
`priority` = `A` if `hostel_count ≥ 3` or `presence_score ≥ 3` or listed on 2+ portals · `B` if it has a WhatsApp number ·
`C` the rest. The founder calls A first.

### Lines for this part
| Line | Why |
|---|---|
| Only numbers and pages the business published itself (listing, board, page, website) | Business contact the owner made public = fine to call; a relative's personal profile isn't |
| No personal profiles of family members, residents or staff | Privacy |
| Record `seen_on` + `seen_at` for every number | So a number can be traced and removed if the owner asks |
| `do_not_contact` field (empty now) | The founder fills it when someone says "don't call again"; it must never be re-added by a later fetch |

---

## 5. Method: don't miss any place

1. **Areas first.** Build `areas.json` (80–120 areas, section 6 list) with centre, radius, aliases, pincodes.
2. **Map grid.** Cover the box `lat 17.25–17.62, lng 78.20–78.70` with ~1 km cells (500 m in dense zones: Ameerpet, SR Nagar,
   Madhapur, Kondapur, Gachibowli, KPHB, Dilsukhnagar). Google Maps / Places returns max ~60–120 per search, so for every
   cell run all terms: `PG`, `paying guest`, `hostel`, `ladies hostel`, `boys hostel`, `mens PG`, `womens PG`, `co-living`,
   `working women hostel`, `PG accommodation`, `girls hostel`, `gents PG`. If a cell returns the maximum, split it in 4 and
   repeat.
3. **Portals by area.** For every portal in 3B, walk every area's PG list page to the last page; open each listing; take the
   embedded JSON (most of these sites ship the listing as JSON in the page, which is cleaner than the HTML).
4. **Chains.** Walk each chain's Hyderabad city page and every property page.
5. **Long tail.** Google search per area × term, Instagram hashtags, YouTube "PG in <area> Hyderabad", classifieds.
6. **Own websites.** For every row with a website, read its own pages for rent, food, rules, WhatsApp, menu.
7. **Merge** (section 7 checks): same phone → same place unless pins > 150 m apart; same normalised name within 150 m → same
   place; chain + property name → same place.
8. **Around + travel.** Landmarks, nearby counts, travel minutes for every merged hostel.
9. **Report** (section 7).

10. **Owners** (section 4b): group hostels by phone / name / brand into owners; visit each hostel's Instagram, Facebook,
    YouTube, Google profile and portal listings for names, numbers and activity; Meta Ad Library per page; compute
    `presence_score` and `priority`; write `owners_calllist.csv`.

Run order if time is short: **2 → 3 (NoBroker, MagicBricks, Housing, 99acres, Justdial) → 4 → 10 → 1 → 6 → 5 → 8.**

---

## 6. Areas to cover

| Zone | Areas |
|---|---|
| IT corridor West | Hitech City, Madhapur, Kondapur, Gachibowli, Financial District, Nanakramguda, Kokapet, Narsingi, Manikonda, Puppalaguda, Raidurg, Khajaguda, Botanical Garden, Kothaguda, Hafeezpet, Serilingampally, Lingampally, Chanda Nagar, Madinaguda, Miyapur, Gopanpally, Tellapur, Nallagandla |
| Coaching / central | Ameerpet, SR Nagar, Yousufguda, Punjagutta, Erragadda, Borabanda, Begumpet, Somajiguda, Khairatabad, Lakdikapul, Himayatnagar, Narayanaguda, Ashok Nagar, Chikkadpally, RTC X Roads, Musheerabad, Vidyanagar |
| North-West | Kukatpally, KPHB, JNTU, Moosapet, Balanagar, Nizampet, Bachupally, Pragathi Nagar, Kompally, Suchitra, Jeedimetla, Quthbullapur |
| North / Secunderabad | Secunderabad, Paradise, Bowenpally, Trimulgherry, Alwal, Malkajgiri, Tarnaka, Habsiguda, Nacharam, Uppal, Boduppal, ECIL, AS Rao Nagar, Sainikpuri |
| South / East | Dilsukhnagar, Kothapet, LB Nagar, Chaitanyapuri, Malakpet, Saroornagar, Vanasthalipuram, Hayathnagar, Nagole, Koti, Abids, Nampally, Mehdipatnam, Tolichowki, Attapur, Rajendranagar, Shamshabad |
| Others | Jubilee Hills, Banjara Hills, Film Nagar, Shaikpet, Madhura Nagar, Gandhi Nagar, Kavadiguda |

The app's current 32 areas use these spellings, keep them: Ameerpet · SR Nagar · Madhapur · Hitech City · Kondapur ·
Gachibowli · Nanakramguda · Manikonda · Jubilee Hills · Banjara Hills · Kukatpally · KPHB · Miyapur · Nizampet ·
Chanda Nagar · Lingampally · Begumpet · Secunderabad · Bowenpally · Alwal (+12 more in `tools/import/areas.json`).

---

## 7. What to hand back (exact files)

One folder **`data/fetch/<YYYY-MM-DD>/`** (or a zip). UTF-8. `.jsonl` = one JSON object per line.

| File | Content |
|---|---|
| `raw/<source>.jsonl` | Everything you took from each source, one listing per line, untouched values + `url` + `seen_at` (e.g. `raw/google_maps.jsonl`, `raw/nobroker.jsonl`, `raw/stanza.jsonl`) |
| `hostels.jsonl` | **Merged**: one line per real place, best value per field, `sources[]` listing every raw row it came from |
| `areas.json` | Areas (array) |
| `landmarks.json` | Metro, IT parks, colleges, coaching, hospitals, bus stations (array) |
| `travel.jsonl` | Per hostel: walk to nearest metro + minutes to 12 hubs + `method` |
| `nearby.jsonl` | Per hostel: counts + nearest within 800 m |
| `photos.csv` | `hostel_key, url, source, label` (links, not files) |
| `owners.jsonl` | One line per owner (section 4b): name, role, phones, email, hostels, social presence, priority |
| `owners_calllist.csv` | The founder's call sheet, sorted A → C then by `hostel_count`: `priority, owner_name, role, best_phone, whatsapp (Y/N), other_phones, hostel_names, areas, hostel_count, instagram, facebook, portals, presence_score, notes (empty), called_on (empty), outcome (empty), do_not_contact (empty)`. Opens in Excel / Google Sheets |
| `REPORT.md` | Counts per area and per source · how many have phone / rent / gender / exact pin · duplicates merged · dropped and why · "check pins" list · what you couldn't reach and why (blocked, login wall) · spot-check of 30 random rows against their pages |

### `hostels.jsonl`: one merged line
```json
{
  "key": "hz:000123",
  "name": "Sri Sai Ladies Hostel",
  "aliases": ["Sri Sai Womens PG", "Sai Ladies Hostel Ameerpet"],
  "brand": null,
  "kind": "pg",
  "gender": "Women", "gender_from": ["name", "nobroker"],
  "for": "both",
  "lat": 17.438123, "lng": 78.448710, "location_quality": "rooftop", "pin_from": "google_maps", "pin_gap_m": 12,
  "address": "Plot 12, Lane 3, Ameerpet, Hyderabad 500016", "landmark": "Behind Ameerpet Metro", "pincode": "500016",
  "area": "Ameerpet",
  "phones": ["+91 98xxxxxxxx"], "whatsapp": "+91 98xxxxxxxx", "email": null,
  "website": null, "instagram": "https://instagram.com/…", "facebook": null,
  "owner_or_manager_name": null,
  "rents": [
    { "sharing": 2, "ac": false, "rent_month": 7500, "food_included": true, "source": "nobroker", "seen_at": "2026-11-22" },
    { "sharing": 3, "ac": false, "rent_month": 6500, "food_included": true, "source": "nobroker", "seen_at": "2026-11-22" }
  ],
  "deposit": 5000, "maintenance": null, "electricity": "extra", "notice_days": 30, "min_stay": null,
  "food": true, "meals": ["breakfast", "dinner"], "veg_only": null, "menu": null,
  "sharing_types": [2, 3], "ac_rooms": false, "attached_bath": true, "total_beds": null,
  "only_ac": false,
  "amenities": ["wifi", "geyser", "washer", "ro"],
  "amenities_other": ["CCTV", "Power backup"],
  "amenities_raw": ["Wi-Fi", "Hot water", "Washing Machine", "RO", "CCTV", "Power Backup"],
  "rules": { "gate_close": "22:30", "visitors": "not allowed", "smoking": null },
  "photos_count": 14,
  "ratings": [{ "source": "google_maps", "stars": 4.1, "count": 230 }, { "source": "justdial", "stars": 4.3, "count": 51 }],
  "review_keywords": ["good food", "clean", "strict timings"],
  "business_status": "operational",
  "listing_urls": ["https://www.google.com/maps/place/…", "https://www.nobroker.in/…"],
  "sources": ["google_maps:ChIJ…", "nobroker:8a9f…", "justdial:…"],
  "first_seen": "2026-11-22", "last_seen": "2026-11-22"
}
```
Field rules: unknown = `null` (never `""`, `0` or a guess) · phones `+91 XXXXXXXXXX` (landlines `+91 40 XXXXXXXX`) ·
`area` must be a name in your `areas.json` · `gender` ∈ Men / Women / Co-living / null · rents in ₹ per month per bed.

### Checks before handing over
| Check | Pass when |
|---|---|
| Inside Hyderabad | Every pin inside the box in section 5 |
| Exact pins | 6 decimals + `location_quality` on every row; "check pins" list in `REPORT.md` |
| No duplicates | Merge rules in section 5 step 7 applied; `sources[]` lists every merged raw row |
| Nothing invented | 30 random rows spot-checked against their pages, result in `REPORT.md` |
| No secrets | No key, cookie or password anywhere in the folder |

---

## 7b. Exact values the Hostelzy app accepts (use these, nothing else)

Each field in `hostels.jsonl` lands in a real place in the Hostelzy database. Keep the raw words in the `*_raw` fields;
put the app's value in the main field.

| `hostels.jsonl` field | Goes into (Hostelzy) | Allowed values |
|---|---|---|
| `name` | `hostels.name` | Text, as written on the board/listing, no "PG in Ameerpet" SEO junk |
| `gender` | `hostels.gender` | Exactly `Men`, `Women`, `Co-living`, or `null` |
| `area` | `hostels.area` | Exactly a `name` from your `areas.json` |
| `address` | `hostels.address` | Full text |
| `lat`, `lng` | `hostels.lat`, `hostels.lng` | Decimal degrees, 6+ decimals |
| `food` | `hostels.food` | `true` / `false` / `null` |
| `ac_rooms` | `hostels.ac` | `true` if any AC room / `false` / `null` |
| `only_ac` | `hostels.only_ac` | `true` only if every room is AC |
| `rents[]` | `rate_cards` (one row per `ac` + `sharing`) | `sharing` integer **1–8** · `ac` `true`/`false` · `rent_month` integer ₹ per bed per month |
| min / max of `rents[]` | `hostels.rent_min`, `rent_max` | Integers ₹ |
| `deposit` | `hostels.terms.advance` | Integer ₹ |
| `maintenance` | `hostels.terms.maintenance` | Integer ₹ (one-time) |
| `notice_days` | `hostels.terms.noticeDays` | Integer days |
| `electricity` | `hostels.terms.electricityExtra` | `"extra"` → true, `"included"` → false, `null` |
| `amenities[]` | `amenities.kind` + `hostels.amenities` | Only these words: `wifi`, `fridge`, `washer` (washing machine), `ro` (RO / drinking water), `cooler`, `geyser` (hot water), `microwave`, `stove`, `iron`, `tv`, `drying` (drying area), `shoes` (shoe rack), `lift`, `dustbin`. Anything else (CCTV, power backup, parking, gym, housekeeping, biometric, warden…) → `amenities_other[]` as short plain words |
| `rules` | `hostels.rules` | `{ "gate_close": "HH:MM" 24 h, "visitors": "allowed" / "not allowed" / "day only", "smoking": "allowed" / "not allowed", "drinking": "allowed" / "not allowed" }`, any key `null` if unknown |
| `menu` | `menus` (one row per day) | `{ "Mon": {"breakfast": "...", "lunch": "...", "dinner": "..."}, … "Sun": {...} }` + `meal_times` `{ "breakfast": "07:30-09:30", … }` |
| `photos.csv` | `hostel_photos` (label) | `label` one of `Front`, `Room`, `1 sharing` … `6 sharing`, `Washroom`, `Kitchen`, `Dining`, `Common area`, `Other` |
| `phones[0]`, `whatsapp` | `hostel_leads` (team only) | `+91 XXXXXXXXXX` |
| `owner_or_manager_name` | `hostels.owner_name` (first name only) | Text |
| `sources[0]`, `google place id`, `last_seen` | `hostels.source`, `place_id`, `source_seen_at` | `source` one of `google_maps`, `osm`, `nobroker`, `magicbricks`, `99acres`, `housing`, `justdial`, `sulekha`, `olx`, `quikr`, `chain:<name>`, `website`, `instagram`, `facebook`, `youtube`, `other` |

`owners.jsonl` and `owners_calllist.csv` are **not** loaded into the app; they stay with the founder (later: the team console).

Everything else (ratings, review keywords, landmarks, nearby, travel minutes, listing URLs) is kept in the files exactly as in
section 7; the app gets new places for it later.

---

## 8. After you deliver (for the Hostelzy team, later, not for you)
| Step | Who | What |
|---|---|---|
| 1 | Build | Loader `tools/import/load-fetch.mjs`: `hostels.jsonl` → `hostels` drafts (`source` = first source), phones → `hostel_leads` (team only), rents/food/amenities → the team's call form as pre-filled values, `photos.csv` → console for the team to pick from |
| 2 | Build | Areas → the app's area list; landmarks + travel → replace the guessed per-area minutes (`hostelzy/lib/data/onboarding.dart` `areaSpot`) |
| 3 | Team | Console › Listed › **To call**: call, confirm, **List** → live UNVERIFIED card |
| 4 | Hub | Decide what shows publicly before the call: rating line, rent from portals, portal photos, Nearby row |
