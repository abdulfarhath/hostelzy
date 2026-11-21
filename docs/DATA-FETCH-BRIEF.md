# Hostelzy · Data fetch brief (for an outside AI)

**Written by:** Hostelzy hub, 2026-11-21, at the founder's request.
**Who reads this:** an AI (or person) with internet access whose job is to **collect as much real, public data as possible
about PGs / hostels in Hyderabad**, so the Hostelzy app looks full on day one.
**You do not need any other context.** Everything you need is in this file. Read it top to bottom once before you start.

---

## 0. The job in one line

Find **every PG / hostel / co-living place in Hyderabad** (target: 3,000+), plus the **places around them** (metro, IT parks,
colleges, shops), and hand back clean files in the exact formats in section 6. Nothing invented, every row has a source.

---

## 1. What Hostelzy is (so you know what "useful" means)

| | |
|---|---|
| Product | A phone app (Flutter + Supabase) for **Hyderabad PGs and hostels** |
| Tenants | Search hostels on a list and a map, filter (Men / Women / Co-living, price, AC, food), open a hostel page, hold a bed |
| Residents | Pay rent, see the week's food menu, raise complaints |
| Owners | Run their hostel: beds, rooms, rent, residents, meals |
| City | Hyderabad + Secunderabad + Cyberabad (the whole GHMC / HMDA urban area) |
| Typical user | Student or IT employee, 18–30, looking near their college, coaching centre or office |

### Two kinds of listing in the app
| Tier | Badge | What it shows | Where the data comes from |
|---|---|---|---|
| **✓ VERIFIED** | Navy | Rooms, beds, exact rent per room type, food menu, owner contact, 8 photos | The owner + a Hostelzy team visit. **Not your job.** |
| **UNVERIFIED** (listed) | Grey outline | Name, Men/Women/Co-living, area, map pin, photos, rent range (only if a human confirmed it in the last 60 days, else "Rent on request") | **Your data** → the team phones each place → it becomes a listed card |

Your data first lands as a **draft** (not visible to tenants). The Hostelzy team calls the place, confirms it is a real PG,
confirms Men/Women and rent, and then lists it. So: **more rows with a phone number = more hostels the team can list.**

---

## 2. Hard rules (break one and the data is thrown away)

| # | Rule |
|---|---|
| 1 | **Real data only.** Never invent, estimate, average or "fill in" a value. Unknown = leave the field `null`. |
| 2 | **Every row has a source**: `source` + `source_url` (or `place_id`) + `fetched_at` (ISO date-time, UTC). |
| 3 | **Official APIs and open data only.** Allowed: Google **Places API (New)** with an API key, **OpenStreetMap** (Overpass API, Geofabrik extracts, Nominatim within its usage policy), **openrouteservice / self-hosted OSRM** for travel times, government open data (data.gov.in, Telangana Open Data, HMRL / L&T Metro published station lists), a hostel's **own** website or own Instagram page. |
| 4 | **Forbidden (founder decision):** scraping Google Maps web pages, scraping listing portals (NoBroker, MagicBricks, 99acres, Housing.com, Justdial, Sulekha, Stanza/Zolo/Colive sites' search pages, OLX, Facebook groups), bought or leaked phone lists, personal social profiles. GHMC licence lists are dropped too. |
| 5 | **Google terms.** Google content (name, address, phone, rating, photos…) may be stored **up to 30 days** and then must be refreshed or deleted; only `place_id` may be kept for ever. So every Google row carries `fetched_at`, and photos are delivered as **photo names + author attributions**, never downloaded image files. |
| 6 | **OpenStreetMap is ODbL.** Fine to store for ever; keep `osm_id` and the credit line "© OpenStreetMap contributors". |
| 7 | **No private people.** No personal names of tenants, no reviewers' names, no Aadhaar/ID anything. An owner's name only if the business itself publishes it (e.g. "Contact: Ravi" on its own website). |
| 8 | **No secrets in files.** Never write an API key into any delivered file or log. |
| 9 | **Spend cap.** Google Places costs money per request. Stay under the budget the founder gives you (default **US$ 100 total** unless told otherwise) and report what you spent. Use the cheap-first method in section 5. |

---

## 3. What to fetch, in priority order

"App shows it today" tells you how much it matters right now. **P1 = must have.**

### P1 · Hostels (the main thing)
One row per physical PG / hostel / co-living building.

| Field | Why the app needs it | App shows it today | Source |
|---|---|---|---|
| `name` | Card title | ✅ | Places `displayName` / OSM `name` |
| `lat`, `lng` | Map pin, distance sort, "Near me" | ✅ | Places `location` / OSM |
| `address` | Hostel page, team call | ✅ (page) | Places `formattedAddress` / OSM `addr:*` |
| `area` | Area filter, card subtitle ("Madhapur") | ✅ | Nearest area from **your** `areas.json` (section 3·P2) |
| `pincode` | Area matching | — | Address / OSM `addr:postcode` |
| `gender_hint` | Men / Women / Co-living filter | ✅ (after the call) | Name words: ladies, women, girls, womens, working women → `Women`; boys, gents, men, mens → `Men`; co-living, coliving, unisex → `Co-living`; else `null`. Also OSM `female=yes` / `male=yes`. **Never guess beyond the name/tags.** |
| `phone` | **Team calls the place to list it** (most important after the pin) | Team only (never public) | Places `nationalPhoneNumber` / OSM `phone`, `contact:phone` / own website |
| `whatsapp` | Team messages the owner | Team only | Own website / own Instagram only |
| `website`, `instagram` | Team call, later photos | — | Places `websiteUri` / OSM `website` |
| `google_maps_uri` | Team opens it | — | Places `googleMapsUri` |
| `business_status` | Drop closed places | — | Places `businessStatus` (keep only `OPERATIONAL`, mark the others) |
| `photos` | Card + page photos | ✅ | Places `photos[].name` + `authorAttributions` (up to 10). Not the image bytes. |
| `rating`, `rating_count` | Possible "Google ★ 4.1 · 230" line (**not shown yet, needs a hub decision**) | — | Places `rating`, `userRatingCount` |
| `food_hint`, `ac_hint`, `wifi_hint`, `sharing_hint` | Pre-fill the team's call form | Team only | Only if the hostel's **own** website / own Instagram bio states it. With `source_url`. |
| `rent_hint_min`, `rent_hint_max` | Pre-fill the team's call (the team confirms before anything shows) | Team only, never public | Only the hostel's **own** website / own post. With `source_url` and the date seen. |
| `types` | Filter out hotels | — | Places `types`, `primaryType` |
| `brand` | Group chains (Zolo, Stanza, Colive, Housr, Your-Space…) | — | Name / OSM `brand` |
| `source`, `place_id` / `osm_id`, `source_url`, `fetched_at` | Dedupe, refresh, honesty | — | Always |

**Keep:** PG, paying guest, hostel (students / working), co-living, ladies hostel, boys hostel, working women's hostel,
service apartments rented per bed. **Drop:** hotels, lodges, OYO rooms, resorts, guest houses rented per night,
student hostels inside a college campus that outsiders cannot join (mark `campus=true` instead of dropping if unsure),
travellers' backpacker hostels (Zostel etc.: keep but mark `kind="backpacker"`).

### P2 · Areas (the area list the app filters by)
The app has 32 areas today (list in section 7). Make it **complete for Hyderabad (target 80–120)**.

| Field | Why | Source |
|---|---|---|
| `name` | Area chip / filter, plain local spelling ("SR Nagar", "KPHB", "Hitech City") | OSM `place=suburb/neighbourhood/quarter`, admin boundaries |
| `lat`, `lng`, `radius_m` | Search circle for the import, nearest-area match | Centre of the OSM polygon; radius covering it |
| `polygon` (GeoJSON, optional) | Exact matching later | OSM boundary if it exists |
| `aliases` | "Hitec City" = "HITEC City" = "Hi-Tech City"; "Kukatpally Housing Board" = "KPHB" | OSM `alt_name`, common spellings |
| `pincodes` | Address → area | India Post open data |

### P3 · Landmarks (what tenants search near)
Tenants search "PG near Mindspace", "near Ameerpet metro", "near JNTU". The app today shows travel minutes to only 4 places,
and those minutes are **rough per-area guesses** in the code. Real landmarks + real times replace them.

| Group | Examples | Target count | Source |
|---|---|---|---|
| `metro` | All Hyderabad Metro stations (Red, Blue, Green lines) | all (~57) | OSM `railway=station` + `station=subway`/network "Hyderabad Metro", HMRL list |
| `mmts` / `rail` | MMTS stations, Secunderabad, Nampally, Kacheguda, Lingampally | all | OSM |
| `it_park` | Mindspace, DLF Cyber City, Raheja, Waverock, Phoenix, Financial District, Hitec City, Q City, Salarpuria Sattva Knowledge City, Cyber Towers, Cyber Gateway, Divyasree, RMZ Nexity, Kokapet SEZs | 60+ | OSM `landuse=commercial`/`office=*` named parks, official sites |
| `college` | JNTU, OU, UoH (HCU), IIIT-H, ISB, NIFT, Vasavi, CBIT, CVR, VNR VJIET, MGIT, Gokaraju, St. Mary's, Villa Marie, Nizam College, Koti Women's College… | 150+ | OSM `amenity=university/college`, AICTE / UGC lists |
| `coaching` | Ameerpet coaching cluster, Ashok Nagar / Chikkadpally (exam coaching), Dilsukhnagar | 30+ clusters | OSM `amenity=school` + name contains "academy/institute/coaching", own websites |
| `hospital` | Big hospitals (also a big source of nurse / staff tenants) | 50+ | OSM `amenity=hospital` |
| `bus_hub` | MGBS, JBS, Dilsukhnagar, Kukatpally, Lingampally bus stations | 20+ | OSM `amenity=bus_station` |

Fields: `id`, `group`, `name`, `aliases`, `lat`, `lng`, `area`, `source`, `osm_id`/`source_url`, `fetched_at`.

### P4 · Travel times (replace the guessed minutes)
For **every hostel** in P1: minutes to the **nearest metro station (walking)** and to the **top hubs (two-wheeler / car)**.

| Field | Method |
|---|---|
| `walk_to_metro`: station id + metres + minutes | OSRM / openrouteservice `foot` profile on OSM data |
| `ride_to` : `{landmark_id: minutes}` for the 12 hubs: Hitec City, Gachibowli (Financial District), Madhapur (Mindspace), Kondapur, Ameerpet, Kukatpally/KPHB, JNTU, Secunderabad, Begumpet, Banjara Hills, Koti/Abids, Uppal | OSRM / openrouteservice `driving-car` profile, no traffic (state this in `method`) |

**Do not** use Google Routes / Distance Matrix for this (its results can't be stored). Self-host OSRM with the Geofabrik
`southern-zone` (or Telangana) extract, or use openrouteservice within its free quota. Write the profile and date in `method`.

### P5 · Around each hostel (for a future "Nearby" row)
Counts and the nearest one within **800 m walking**, from OSM only:
`supermarket`, `pharmacy`, `hospital`/`clinic`, `atm`, `gym`, `bus_stop`, `restaurant`/`fast_food`, `laundry`, `police`.
Fields per hostel: `{kind: {count, nearest_name, nearest_m}}`. Not shown in the app yet (would need a new feature spec);
fetch it only after P1–P4 are done.

### Not wanted (don't spend time on it)
| Don't fetch | Why |
|---|---|
| Google review texts, reviewer names | App shows only reviews from verified residents |
| Rents from portals or from Google reviews | Forbidden source / not reliable; rents come from the owner or the team's call |
| Food menus, room counts, bed counts | Only the owner gives these (verified tier) |
| Downloaded Google photos | Google terms; deliver photo names only |
| Anything invented to "make it look full" | The founder's first rule: honest app, no fake numbers |

---

## 4. Area coverage (where to look)
Cover all of these zones; the PG density is highest in the first two rows.

| Zone | Areas (non-exhaustive) |
|---|---|
| IT corridor West | Hitech City, Madhapur, Kondapur, Gachibowli, Financial District, Nanakramguda, Kokapet, Narsingi, Manikonda, Puppalaguda, Raidurg, Khajaguda, Botanical Garden, Kothaguda, Hafeezpet, Serilingampally, Lingampally, Chanda Nagar, Madinaguda, Miyapur, Gopanpally, Tellapur, Nallagandla |
| Coaching / central | Ameerpet, SR Nagar, Yousufguda, Punjagutta, Erragadda, Borabanda, Begumpet, Somajiguda, Khairatabad, Lakdikapul, Himayatnagar, Narayanaguda, Ashok Nagar, Chikkadpally, RTC X Roads, Musheerabad, Vidyanagar |
| North-West | Kukatpally, KPHB, JNTU, Moosapet, Balanagar, Nizampet, Bachupally, Pragathi Nagar, Kompally, Suchitra, Jeedimetla, Quthbullapur |
| North / Secunderabad | Secunderabad, Paradise, Bowenpally, Trimulgherry, Alwal, Malkajgiri, Tarnaka, Habsiguda, Nacharam, Uppal, Boduppal, ECIL, AS Rao Nagar, Sainikpuri |
| South / East | Dilsukhnagar, Kothapet, LB Nagar, Chaitanyapuri, Malakpet, Saroornagar, Vanasthalipuram, Hayathnagar, Nagole, Koti, Abids, Nampally, Mehdipatnam, Tolichowki, Attapur, Rajendranagar, Shamshabad |
| Others | Jubilee Hills, Banjara Hills, Film Nagar, Shaikpet, Madhura Nagar, Gandhi Nagar, Kavadiguda |

---

## 5. How to fetch hostels without missing any (and without a big bill)

**Google Text Search returns at most 60 results per query (3 pages × 20).** One query per area misses most PGs in dense
areas like Ameerpet. So:

1. **Grid.** Cover the city bounding box `lat 17.25–17.62, lng 78.20–78.70` with a grid of ~1 km cells (dense zones:
   500 m cells). Use `locationRestriction` (rectangle) per cell, not a bias.
2. **Search terms** (run each per cell): `PG`, `paying guest`, `hostel`, `ladies hostel`, `boys hostel`, `mens PG`,
   `womens PG`, `co-living`, `working women hostel`, `PG accommodation`. If a cell returns the full 60 for a term,
   split that cell into 4 and repeat.
3. **Cheap first:** run the grid with an **IDs-only field mask** (`places.id`, `places.displayName` if allowed in that
   tier, `nextPageToken`): the cheapest Places SKU. Collect unique `place_id`s.
4. **Filter** obvious non-PGs by name (hotel, lodge, resort, OYO, inn, guest house, banquet) **unless** the name also says
   PG / hostel.
5. **Then Place Details** once per remaining id with the field mask:
   `id,displayName,formattedAddress,addressComponents,location,nationalPhoneNumber,internationalPhoneNumber,websiteUri,googleMapsUri,businessStatus,types,primaryType,rating,userRatingCount,photos`.
6. **OSM pass** (free): Overpass for `tourism=hostel`, `amenity=dormitory`, `building=dormitory`, `amenity=student_accommodation`,
   and any node/way whose `name` matches `(?i)\b(pg|paying guest|hostel|co-?living)\b` inside the box.
7. **Own websites** (only for rows that have a `websiteUri`): read the hostel's own pages for rent, food, AC, WiFi,
   sharing, WhatsApp. One request per site, respect `robots.txt`, no crawling beyond the site's own pages.
8. **Dedupe** (section 6·checks) and **report** counts and cost.

Check Google's current price list before step 3 and step 5 and stop at the budget. Log every request count per SKU.

---

## 6. What to hand back (exact files)

Put everything in one folder **`data/fetch/<YYYY-MM-DD>/`** (or a zip of it). UTF-8, one JSON object per line for `.jsonl`.

| File | Content |
|---|---|
| `hostels.jsonl` | P1, one hostel per line |
| `areas.json` | P2, a JSON array |
| `landmarks.json` | P3, a JSON array |
| `travel.jsonl` | P4, one line per hostel `{ "hostel_key", "walk_to_metro": {...}, "ride_to": {...}, "method" }` |
| `nearby.jsonl` | P5 (optional) |
| `REPORT.md` | Counts per area and per source, how many have a phone, duplicates merged, places dropped and why, requests and money spent per Google SKU, what you could not do |
| `ATTRIBUTION.md` | "© OpenStreetMap contributors (ODbL)", Google Places attribution note, any open-data licences used |

### `hostels.jsonl`: one line looks like this
```json
{
  "key": "g:ChIJN1t_tDeuEmsRUsoyG83frY4",
  "source": "google_places",
  "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
  "osm_id": null,
  "source_url": "https://maps.google.com/?cid=…",
  "fetched_at": "2026-11-22T10:15:00Z",
  "name": "Sri Sai Ladies Hostel",
  "kind": "pg",
  "brand": null,
  "gender_hint": "Women",
  "gender_hint_from": "name",
  "lat": 17.43812,
  "lng": 78.44871,
  "address": "Plot 12, Lane 3, Ameerpet, Hyderabad, Telangana 500016",
  "pincode": "500016",
  "area": "Ameerpet",
  "area_distance_m": 420,
  "phone": "+91 98xxxxxxxx",
  "whatsapp": null,
  "website": null,
  "instagram": null,
  "google_maps_uri": "https://maps.google.com/?cid=…",
  "business_status": "OPERATIONAL",
  "types": ["lodging", "point_of_interest"],
  "rating": 4.1,
  "rating_count": 230,
  "photos": [
    { "name": "places/ChIJ…/photos/AUc7…", "width": 4032, "height": 3024,
      "attribution": [{ "displayName": "…", "uri": "…" }] }
  ],
  "hints": {
    "food": null, "ac": null, "wifi": null, "sharing": null,
    "rent_min": null, "rent_max": null,
    "source_url": null, "seen_at": null
  },
  "campus": false,
  "also_seen_in": ["osm:n123456789"]
}
```
Rules for the fields:
- `key` = `g:<place_id>` for Google rows, `osm:n<id>` / `osm:w<id>` for OSM-only rows. Unique in the file.
- `kind` ∈ `pg`, `hostel`, `coliving`, `working_women`, `student`, `backpacker`, `unknown`.
- `gender_hint` ∈ `Men`, `Women`, `Co-living`, `null`; `gender_hint_from` ∈ `name`, `osm_tag`, `own_website`, `null`.
- Phone in E.164-ish `+91 XXXXXXXXXX`; landlines keep the 040 code (`+91 40 XXXXXXXX`).
- `area` must be a `name` from your `areas.json`.
- Unknown = `null`. Never `""`, never `0`, never a guess.

### `areas.json` item
```json
{ "name": "Ameerpet", "aliases": ["Ameerpeta"], "lat": 17.4375, "lng": 78.4483, "radius_m": 1500,
  "pincodes": ["500016", "500038"], "zone": "Coaching / central", "osm_id": "r1234567", "polygon": null }
```

### `landmarks.json` item
```json
{ "id": "metro-ameerpet", "group": "metro", "name": "Ameerpet Metro", "aliases": ["Ameerpet Interchange"],
  "lat": 17.4374, "lng": 78.4482, "area": "Ameerpet", "lines": ["Red", "Blue"],
  "source": "osm", "osm_id": "n987654321", "fetched_at": "2026-11-22T10:15:00Z" }
```

### `travel.jsonl` line
```json
{ "hostel_key": "g:ChIJ…",
  "walk_to_metro": { "landmark_id": "metro-ameerpet", "metres": 650, "minutes": 9 },
  "ride_to": { "hitec-city": 24, "gachibowli": 33, "ameerpet": 3, "jntu": 15 },
  "method": "OSRM 5.x, Geofabrik southern-zone 2026-11-20, profiles foot + car, no traffic" }
```

### Checks before you hand it over
| Check | Pass when |
|---|---|
| Inside Hyderabad | Every `lat`/`lng` inside the box in section 5 |
| Duplicates | No two rows with the same `place_id`; Google + OSM rows of the same place merged when names match (case/space/punctuation-insensitive) within **150 m**, or same phone; merged ids go to `also_seen_in` |
| Same phone, many rows | Allowed (chains, one owner with 3 buildings) only if pins are > 150 m apart; otherwise merge |
| Closed | `business_status` ≠ `OPERATIONAL` → kept but listed separately in `REPORT.md` |
| No invented values | Spot-check 30 random rows against their source; write the result in `REPORT.md` |
| No key in files | `grep -ri "AIza" data/fetch/` returns nothing |

---

## 7. Today's area list in the app (keep these names exactly, add the rest)
Ameerpet · SR Nagar · Madhapur · Hitech City · Kondapur · Gachibowli · Nanakramguda · Manikonda · Jubilee Hills ·
Banjara Hills · Kukatpally · KPHB · Miyapur · Nizampet · Chanda Nagar · Lingampally · Begumpet · Secunderabad ·
Bowenpally · Alwal and ~12 more in `tools/import/areas.json` in the Hostelzy repo (name, lat, lng, radius in metres).
If you can't see that file, start from section 4 and keep these spellings.

---

## 8. What happens after you deliver (for the Hostelzy team, not for you)
| Step | Who | What |
|---|---|---|
| 1 | Build | Small loader `tools/import/load-fetch.mjs`: reads `data/fetch/<date>/`, writes `hostels` rows as `status='draft'`, `source='places'`/`'osm'`, `place_id`, `source_photos`, `source_seen_at = fetched_at`; dedupes against existing hostels (same rules as `places.mjs`); phones go to `hostel_leads` (never the public row) |
| 2 | Build | `areas.json` merged into `tools/import/areas.json` and the app's area list; landmarks + travel replace the guessed per-area minutes (`hostelzy/lib/data/onboarding.dart` `areaSpot`) — needs a small spec first |
| 3 | Existing monthly job | `import-hostels.yml` refreshes Google fields within 30 days (Google terms), drops gone places |
| 4 | Team | Console › Listed › **To call** shows every draft with a phone; call, confirm, **List** → UNVERIFIED card goes live |
| 5 | Hub | Decide whether the app shows "Google ★ 4.1 · 230" on UNVERIFIED cards (with attribution) and the "Nearby" row. Until then those fields are stored, not shown |

**Founder's part:** a Google Cloud project with **Places API (New)** enabled, billing on, a budget alert at the cap you
choose, and the key given to whoever runs the fetch (never pasted into the repo).
