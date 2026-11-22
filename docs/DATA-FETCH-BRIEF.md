# Hostelzy · Data collection plan (v4, self-contained)

| | |
|---|---|
| Written by | Hostelzy hub (Claude), 2026-11-22, for the founder |
| Status | **Draft for review.** The founder will have another AI check it, then come back with corrections |
| Repo | github.com/abdulfarhath/hostelzy · this file is `docs/DATA-FETCH-BRIEF.md` |
| Facts checked against | The repo's `main` on 2026-11-22: `supabase/migrations/*.sql`, `hostelzy/lib/**`, `tools/import/*`, `docs/DECISIONS.md` |

**How to read this file**

| You are… | Read |
|---|---|
| **A reviewer AI** (checking the plan, helping the founder decide) | Everything. Section **8 lists the open decisions and risks**; section **9 tells you what to check** |
| **The data-collecting AI** | Part 1 for context, then all of Part 2. You need no other file |
| The founder | Section 0, then section 8 |

---

## 0. Summary in 6 lines

1. **Hostelzy** is a phone app for PGs and hostels in Hyderabad: tenants find and hold beds, residents manage their stay, owners run the hostel.
2. The app needs **real hostels in it on day one**. Today it has only the hostels the team added by hand.
3. **Phase 1 (now): collect data only.** Every PG / hostel in Hyderabad, from every public source, into files with a fixed format. Nothing is loaded into the app yet.
4. Data per hostel: exact pin, name, Men/Women, phones, rents per room type, food, amenities, rules, photos (links), ratings, **reviews**. Plus **owner contacts and social media** for the founder's sales calls.
5. **Phase 2 (later):** Build writes a loader. Hostels enter the app as drafts. The team phones each one, then lists it as an UNVERIFIED card.
6. Founder's instruction (2026-11-22): "as much data as possible, scrape from anywhere." Kept on purpose: nothing invented, every value has a source, public pages only, exact pins.

---

# Part 1 · The app (context)

## 1. What Hostelzy is

| | |
|---|---|
| City | Hyderabad (+ Secunderabad, Cyberabad). Started dense around Madhapur / Hitech City / Kondapur / Gachibowli |
| Users | **Tenant** (looking for a bed) · **Resident** (lives in a Hostelzy hostel) · **Owner** (+ **manager**) · **Hostelzy team** (console) |
| Typical tenant | Student or IT employee, 18–30, searching near a college, coaching centre or office |
| Sign-in | Google sign-in; the user types their phone (shown as "Not verified"). No SMS OTP yet |
| Guests | Can browse the list, map, prices and filters; after 3 hostel pages, they must sign in (F30) |
| Tech | Flutter app (`hostelzy/`), Supabase Postgres + Edge Functions (`supabase/`), team console and public web pages (`app/`, served at farhath.me/hostelzy/app/) |
| Size | 166 app screens/sheets/states, 15 console views, 10 web pages (`docs/SCREENS.md`) |
| Build state | Features F02–F31 specced and merged to `main`; latest Android build **apk-109**. Founder is testing |

### How money works (founder's numbers; only the founder changes them)
| Item | Rule |
|---|---|
| Tenants pay Hostelzy | ₹0 |
| Moving in | ₹3,000 advance + first month's rent, paid **straight to the owner**. Hostelzy never holds money |
| Leaving | Owner keeps ₹1,000–1,500 exit maintenance from the advance. 30-day notice. Electricity usually extra |
| Owners pay Hostelzy | Plan ₹499 / ₹999 / ₹1,499 a month (≤30 / 31–80 / 80+ beds), 30-day free trial, by UPI |
| Holds | Tenant holds a bed free for 1 hour (2 h for members) |
| Rewards | ₹100 next-stay credit; ₹200 to a resident whose added hostel goes live; ₹20 to a partner per listed hostel; ₹2,000/month cap |

## 2. The two listing tiers (key to this plan)

| Tier | Badge | What tenants see | How a hostel gets there |
|---|---|---|---|
| **draft** | — (hidden) | Nothing | Imports, web form, tenant adds. **Collected data lands here** |
| **listed** = UNVERIFIED | Grey outline "UNVERIFIED" | Name, Men/Women/Co-living, area, map pin, photos, rent range. **Rent only if a human confirmed it in the last 60 days**, else "Rent on request". No beds, no holds, no owner contact. "Tell me when verified" button | Team calls the place and presses **List** in the console |
| **live** = ✓ VERIFIED | Navy "✓ VERIFIED" | Everything: room layouts, beds, a price for every room type, food menu, reviews, deals, holds | Owner signs up; checklist: rooms, a price for every room type, linked owner, **8 photos**, team visit |

Order in search: verified first, then listed. A "Verified only" switch hides listed ones.

## 3. Rules the app lives by (from `docs/DECISIONS.md`)

| Rule | Meaning for this plan |
|---|---|
| **Honest** | No fake numbers, no sample data in the real app, no "Verified/Paid" unless true. Collected data must be real and sourced |
| **Owner phone is private** | Shown to a tenant only with a live hold or a stay. In the database it lives in `hostel_leads` (team-only), never on the public `hostels` row |
| **Reviews in the app** | Only from verified residents of that hostel (F08). Ratings from Google etc. are **not** shown today |
| **No explanations** (F31) | Plain labels; no helper text. Not relevant to data, relevant to anything shown later |
| **Scraping** | 2026-10-18: "no scraping of Google Maps or portals". **Replaced 2026-11-22 by the founder:** "scrape from anywhere" |

## 4. Where the data goes in the database (checked against the migrations)

### `hostels` (one row per hostel)
| Column | Type / allowed values | Notes |
|---|---|---|
| `name` | text, required | |
| `gender` | **required**, exactly `Men` / `Women` / `Co-living` | Can't be empty: the loader must pick one (see 8·D3) |
| `area` | text, **required** | One of the app's area names |
| `address` | text | |
| `lat`, `lng` | double | Map pin |
| `owner_name` | text | **First name** shown to tenants on verified pages |
| `food` | bool | Food included |
| `ac` | bool | Has AC rooms · `only_ac` bool: every room is AC |
| `amenities` | text[] | Hostel-level list |
| `tags` | text[] | Short card chips on verified hostels ("3 meals a day", "CCTV in corridors") |
| `terms` | jsonb `{"advance": int ₹, "maintenance": int ₹ (exit, kept from the advance), "noticeDays": int, "dueOnJoining": bool, "electricityExtra": bool}` | |
| `rules` | jsonb list `[{"k": "Gate closes", "v": "10:30 pm"}, {"k": "Visitors", "v": "Common area only, till 8 pm"}, {"k": "Quiet hours", "v": "11 pm – 6 am"}]` | Label / value pairs; labels in plain English |
| `rent_min`, `rent_max` | int ₹ | The listed card's rent range |
| `rent_confirmed_at` | timestamp | Rent shows publicly only within 60 days of this |
| `status` | `draft` / `listed` / `live` / `paused` | |
| `source` | **only** `team`, `resident`, `partner`, `places`, `osm`, `web` | A new value (e.g. `scrape`) needs a migration (see 8·D2) |
| `place_id` | text, **unique** | Google place id, or `osm:n123` / `osm:w123` |
| `source_seen_at` | timestamp | When the import last saw it |
| `source_photos` | text[] | Google photo names (not files) |
| `removed_at`, `call_after` | timestamp | "Not a PG / Closed", "Call later" in the console |

### Other tables
| Table | Holds | Allowed values |
|---|---|---|
| `rate_cards` | One price per `(hostel, ac, share)` | `ac` bool · `share` int · `rent` int ₹. **No "with/without food" column**: food is hostel-level (see 8·D4) |
| `rooms` | Verified hostels only: number, floor, `share` 1–8, `ac`, `bath` `Attached`/`Shared`, rent | Not filled from collected data |
| `menus` | One row per weekday: `day` 0–6 (**0 = Monday**), `breakfast`, `lunch`, `dinner` text, `*_time` text | |
| `amenities` | Per-floor items for the building view: `kind` ∈ `fridge`, `washer`, `ro`, `cooler`, `geyser`, `microwave`, `stove`, `iron`, `tv`, `wifi`, `drying`, `shoes`, `lift`, `dustbin`, `other` (name ≤ 40 chars) | Needs a floor number; collected data usually has none (see 8·D5) |
| `hostel_photos` | Files in **our own storage bucket**, with `label` ("Front", "3 sharing", "Washroom") | Portal/Google photos can't go here without copying them (see 8·R3) |
| `hostel_leads` | Team-only: `owner_phone`, `owner_whatsapp`, `stage` (`lead`/`visited`/`signed_up`/`data_complete`), `next_step` | **One phone + one WhatsApp per hostel** |
| `reviews` | Verified residents' reviews only | Collected reviews do **not** go here |

### What already exists for imports (F28, built and merged)
| Piece | What it does |
|---|---|
| `tools/import/places.mjs` | Google Places API (New) Text Search per area for 4 terms → drafts with `source='places'`, dedupe by `place_id` and same name within 150 m, refresh after 30 days |
| `tools/import/osm.mjs` | OpenStreetMap Overpass (`tourism=hostel`, `amenity=dormitory`, `building=dormitory`) → drafts with `source='osm'` |
| `tools/import/areas.json` | **32 areas** with centre and radius (the app's area names) |
| `.github/workflows/import-hostels.yml` | Runs both monthly; needs a `GOOGLE_PLACES_KEY` secret (founder, not added yet) |
| Console › Listed › **To call** | Every draft with a phone: call script, rent from–to, For, Food, **List** / Not a PG / Call later, Export CSV |
| Web page `app/list/` | Owners list their own PG (draft `source='web'`) |

---

# Part 2 · The collection brief (for the data-collecting AI)

## 5. The job

Find **every PG / hostel / co-living place in Hyderabad** (expect several thousand), with everything public about it, plus
its **owner's public contacts and social media**, from every source you can reach. Deliver the files in section 7.

### 5.1 Lines you must keep
| # | Line | Why |
|---|---|---|
| 1 | **Never invent a value.** Unknown = `null` (never `""`, `0` or a guess) | A fake phone wastes a call; a fake rent misleads a tenant |
| 2 | **Every value keeps its source**: `source`, `url`, `seen_at` | Checking, merging, removing a source later |
| 3 | **Public pages only.** No fake accounts, no logging in, no breaking CAPTCHAs or paywalls, no leaked databases | Getting past a login or CAPTCHA can be "unauthorised access" under India's IT Act (s.43 / s.66) |
| 4 | **Slow per site**: about 1 request every 2–3 s per domain; back off on 429 / 403 | Not getting blocked; not knocking small sites over |
| 5 | **No secrets** (API keys, cookies, passwords) in any delivered file | Leaks |
| 6 | **No private individuals**: no reviewer names, no residents, no owners' family profiles | Privacy (India's DPDP Act 2023) |

### 5.2 Exact location (required)
| Rule | Detail |
|---|---|
| Precision | At least **6 decimals** (≈ 10 cm). Never round |
| Best pin, in order | 1 Google Maps business pin · 2 a portal listing's own map pin (often in the page's JSON) · 3 OSM node / building-outline centre · 4 a geocoded full address with house number |
| Never a pin | Centre of an area / pincode / street, or geocoding only "Madhapur, Hyderabad" → `location_quality = "area_only"` |
| `location_quality` | `rooftop` (on a building outline: check against OSM `building=*` within 15 m) · `building` (business pin, no outline to check) · `street` · `area_only` |
| Many sources | Keep every pin in the raw files; choose the best by the order above; `pin_gap_m` = the largest gap between sources. Over 75 m → "check pins" list |
| Flags (don't drop, don't "fix") | More than 3 km from its area centre · outside the city box · two different hostels within 5 m |

City box: `lat 17.25–17.62, lng 78.20–78.70`.

### 5.3 What counts as a hostel
| Keep | Mark, keep | Drop |
|---|---|---|
| PG / paying guest, hostel (students / working), co-living, ladies / boys / working women's hostel, per-bed service apartments | College campus hostels (`campus: true`), backpacker hostels (`kind: "backpacker"`) | Hotels, lodges, OYO rooms, resorts, per-night guest houses (unless the name also says PG / hostel) |

## 6. Sources and method

### 6.1 Sources (use all)
| Group | Sources | Best for |
|---|---|---|
| Maps | **Google Maps** (Places API (New) if a key is given; else the public search results in a headless browser) · OpenStreetMap (Overpass / Geofabrik) · Bing Maps · Apple Maps web · Mappls (MapmyIndia) | Pin, name, phone, rating, photos |
| PG portals | **NoBroker** · **MagicBricks** · **99acres** · **Housing.com** · **Justdial** · Sulekha · Quikr · OLX · CommonFloor · Makaan · SquareYards · NestAway | Rent per sharing, deposit, food, amenities, rules, gender, pin |
| Chains | Stanza Living · Zolo · Colive · Housr · Your-Space · Settl · Isthara · Hello World · Coho · Cove · Tribe · any other with Hyderabad properties | Exact rents per room type, photos |
| Social / own | Hostel's own website · Instagram business profiles (`#hyderabadpg`, `#ameerpetpg`, `#ladieshostelhyderabad`…) · Facebook public pages · YouTube room tours · public Telegram channels (readable without joining) · Meta Ad Library | WhatsApp, owner name, rent posts, activity |
| Search | Google / Bing: `"PG in <area>" Hyderabad`, `"ladies hostel" <area>`, `site:instagram.com PG <area> Hyderabad` | The long tail |
| Around | OSM (metro, MMTS, bus stations, colleges, hospitals, shops) · HMRL / L&T Metro site · AICTE / UGC lists · India Post pincodes | Landmarks, travel time, areas |
| Travel time | Self-hosted **OSRM** or **openrouteservice** on OSM data (`foot` and `driving-car`, no traffic) | Minutes to metro and hubs |

### 6.2 Method (in order; if time is short: 2 → 3 → 4 → 7 → 8 → 1 → 5 → 6 → 9)
1. **Areas**: build `areas.json` (80–120 areas, section 6.3), keeping the app's 32 names exactly.
2. **Map grid**: ~1 km cells over the city box (500 m in dense zones: Ameerpet, SR Nagar, Madhapur, Kondapur, Gachibowli, KPHB, Dilsukhnagar). Per cell, every term: `PG`, `paying guest`, `hostel`, `ladies hostel`, `girls hostel`, `boys hostel`, `gents PG`, `mens PG`, `womens PG`, `co-living`, `working women hostel`, `PG accommodation`. A search returns about 60 places at most: if a cell hits that, split it in 4 and repeat. With the Places API: grid with the cheapest IDs-only field mask first, then Place Details only for likely PGs.
3. **Portals**: for each portal, every area's PG list to the last page; open each listing; prefer the JSON in the page over the HTML.
4. **Chains**: every Hyderabad property page.
5. **Long tail**: search queries, Instagram hashtags, YouTube, classifieds.
6. **Own websites**: for every hostel with a website, its own pages (rent, food, menu, rules, WhatsApp).
7. **Rent and reviews**: on every page you open, take every price and every review ("all reviews", to the last page).
8. **Owners**: group hostels by phone / name / brand; visit their Instagram, Facebook, YouTube, Google profile, portal listings; Meta Ad Library; compute `presence_score` and `priority`.
9. **Around + travel**: landmarks, nearby counts, travel minutes per hostel.
10. **Merge, check, report** (section 7.4).

**Merge rules:** same `place_id` = same place · same phone = same place unless pins are > 150 m apart (one owner, many buildings) ·
same normalised name (lower case, no spaces/punctuation, "PG"/"hostel"/"ladies" kept) within 150 m = same place · chain + property name = same place.

### 6.3 Areas to cover
| Zone | Areas |
|---|---|
| IT corridor West | Hitech City, Madhapur, Kondapur, Gachibowli, Financial District, Nanakramguda, Kokapet, Narsingi, Manikonda, Puppalaguda, Raidurg, Khajaguda, Botanical Garden, Kothaguda, Hafeezpet, Serilingampally, Lingampally, Chanda Nagar, Madinaguda, Miyapur, Gopanpally, Tellapur, Nallagandla |
| Coaching / central | Ameerpet, SR Nagar, Yousufguda, Punjagutta, Erragadda, Borabanda, Begumpet, Somajiguda, Khairatabad, Lakdikapul, Himayatnagar, Narayanaguda, Ashok Nagar, Chikkadpally, RTC X Roads, Musheerabad, Vidyanagar |
| North-West | Kukatpally, KPHB, JNTU, Moosapet, Balanagar, Nizampet, Bachupally, Pragathi Nagar, Kompally, Suchitra, Jeedimetla, Quthbullapur |
| North / Secunderabad | Secunderabad, Paradise, Bowenpally, Trimulgherry, Alwal, Malkajgiri, Tarnaka, Habsiguda, Nacharam, Uppal, Boduppal, ECIL, AS Rao Nagar, Sainikpuri |
| South / East | Dilsukhnagar, Kothapet, LB Nagar, Chaitanyapuri, Malakpet, Saroornagar, Vanasthalipuram, Hayathnagar, Nagole, Koti, Abids, Nampally, Mehdipatnam, Tolichowki, Attapur, Rajendranagar, Shamshabad |
| Others | Jubilee Hills, Banjara Hills, Film Nagar, Shaikpet, Madhura Nagar, Gandhi Nagar, Kavadiguda |

The app's current spellings (keep exactly): Ameerpet · SR Nagar · Madhapur · Hitech City · Kondapur · Gachibowli ·
Nanakramguda · Manikonda · Jubilee Hills · Banjara Hills · Kukatpally · KPHB · Miyapur · Nizampet · Chanda Nagar ·
Lingampally · Begumpet · Secunderabad · Bowenpally · Alwal, plus 12 more in `tools/import/areas.json`.

## 7. What to deliver

One folder `data/fetch/<YYYY-MM-DD>/` (or a zip of it). UTF-8. `.jsonl` = one JSON object per line.

### 7.1 Files
| File | One line / row per | Section |
|---|---|---|
| `raw/<source>.jsonl` | Listing as seen on that source, untouched values + `url` + `seen_at` | 6.1 |
| `hostels.jsonl` | Real place, merged, best value per field, `sources[]` | 7.2 |
| `rents.jsonl` | Price seen (every source, every date) | 7.3 |
| `rent_by_area.csv` | `area, sharing, ac, food_included, count, min, median, max` (only where count ≥ 3) | 7.3 |
| `reviews.jsonl` | Public review | 7.3 |
| `owners.jsonl` | Owner (one owner can run many hostels) | 7.3 |
| `owners_calllist.csv` | Owner, sorted for the founder's calls | 7.3 |
| `photos.csv` | `hostel_key, url, source, label` (links only, no files) | 7.2 |
| `areas.json` | Area: `name, aliases[], lat, lng, radius_m, pincodes[], zone, osm_id, polygon` | 6.3 |
| `landmarks.json` | Metro, MMTS, bus station, IT park, college, coaching cluster, hospital: `id, group, name, aliases[], lat, lng, area, lines[], source, osm_id, seen_at` | 6.1 |
| `travel.jsonl` | Hostel: `walk_to_metro {landmark_id, metres, minutes}`, `ride_to {landmark_id: minutes}` for 12 hubs (Hitech City, Financial District, Mindspace, Kondapur, Ameerpet, KPHB, JNTU, Secunderabad, Begumpet, Banjara Hills, Koti, Uppal), `method` | 6.1 |
| `nearby.jsonl` | Hostel: `{kind: {count, nearest_name, nearest_m}}` within 800 m walk for supermarket, pharmacy, hospital/clinic, ATM, gym, bus stop, restaurant, laundry, police | 6.1 |
| `REPORT.md` | Counts per area and source · how many have phone / rent / gender / exact pin · merges · drops and why · "check pins" list · sites not reached and why · 30-row spot check · money spent (if an API was used) | 7.4 |
| `ATTRIBUTION.md` | "© OpenStreetMap contributors (ODbL)", Google, and each source used | — |

### 7.2 `hostels.jsonl` (values already in the app's format)
```json
{
  "key": "hz:000123",
  "name": "Sri Sai Ladies Hostel",
  "aliases": ["Sri Sai Womens PG"],
  "brand": null,
  "kind": "pg",
  "campus": false,
  "gender": "Women",
  "gender_from": ["name", "nobroker"],
  "for": "both",
  "lat": 17.438123, "lng": 78.448710,
  "location_quality": "rooftop", "pin_from": "google_maps", "pin_gap_m": 12,
  "address": "Plot 12, Lane 3, Ameerpet, Hyderabad 500016",
  "landmark": "Behind Ameerpet Metro",
  "pincode": "500016",
  "area": "Ameerpet",
  "phones": ["+91 98xxxxxxxx"], "whatsapp": "+91 98xxxxxxxx", "email": null,
  "website": null, "instagram": "https://instagram.com/…", "facebook": null,
  "owner_key": "own:0042",
  "owner_first_name": null,
  "food": true, "meals": ["breakfast", "dinner"], "veg_only": null,
  "ac": false, "only_ac": false,
  "sharing_types": [2, 3], "attached_bath": true, "total_beds": null,
  "rent_min": 6500, "rent_max": 7500,
  "rents_latest": [
    { "share": 2, "ac": false, "food_included": true, "rent": 7500, "source": "nobroker", "seen_at": "2026-11-22" },
    { "share": 3, "ac": false, "food_included": true, "rent": 6500, "source": "nobroker", "seen_at": "2026-11-22" }
  ],
  "terms": { "advance": 5000, "maintenance": null, "noticeDays": 30, "dueOnJoining": null, "electricityExtra": true },
  "rules": [ { "k": "Gate closes", "v": "10:30 pm" }, { "k": "Visitors", "v": "Not allowed" } ],
  "amenities": ["wifi", "geyser", "washer", "ro"],
  "amenities_other": ["CCTV", "Power backup"],
  "amenities_raw": ["Wi-Fi", "Hot water", "Washing Machine", "RO", "CCTV", "Power Backup"],
  "menu": { "Mon": { "breakfast": "Idli, chutney", "lunch": null, "dinner": "Chapati, dal" } },
  "meal_times": { "breakfast": "7:30 – 9:30", "lunch": null, "dinner": "8:00 – 10:00" },
  "photos_count": 14,
  "ratings": [ { "source": "google_maps", "stars": 4.1, "count": 230 } ],
  "review_count_total": 281,
  "top_praise": [ { "topic": "food", "count": 41 } ],
  "top_complaints": [ { "topic": "timings", "count": 12 } ],
  "business_status": "operational",
  "place_id": "ChIJ…",
  "osm_id": null,
  "sources": ["google_maps:ChIJ…", "nobroker:8a9f…"],
  "listing_urls": ["https://www.google.com/maps/place/…", "https://www.nobroker.in/…"],
  "first_seen": "2026-11-22", "last_seen": "2026-11-22"
}
```

**Allowed values**
| Field | Values | Lands in (phase 2) |
|---|---|---|
| `kind` | `pg`, `hostel`, `coliving`, `working_women`, `student`, `backpacker`, `unknown` | — |
| `gender` | `Men`, `Women`, `Co-living`, `null` · `gender_from`: `name`, `osm_tag`, `<source name>` | `hostels.gender` |
| `for` | `students`, `working`, `both`, `null` | — |
| `area` | A `name` from your `areas.json` | `hostels.area` |
| `phones`, `whatsapp` | `+91 XXXXXXXXXX`; landlines `+91 40 XXXXXXXX` | `hostel_leads` (team only) |
| `owner_first_name` | First name only, only if a listing shows it | `hostels.owner_name` |
| `food`, `ac`, `only_ac`, `attached_bath`, `veg_only` | `true`, `false`, `null` | `hostels.food / ac / only_ac` |
| `rents_latest[].share` | Integer 1–8 (single = 1); dormitory with an unknown size: keep in `rents.jsonl` only | `rate_cards.share` |
| `rents_latest[].rent`, `rent_min`, `rent_max` | Integer ₹ per bed per month | `rate_cards.rent`, `hostels.rent_min/max` |
| `terms` | Keys exactly `advance`, `maintenance` (exit maintenance), `noticeDays`, `dueOnJoining`, `electricityExtra`; ints / bools / `null` | `hostels.terms` |
| `rules` | List of `{"k", "v"}`; `k` one of `Gate closes`, `Visitors`, `Quiet hours`, `Smoking`, `Drinking`, `Guests overnight`, `Pets`; `v` short text as written | `hostels.rules` |
| `amenities` | Only: `wifi`, `fridge`, `washer`, `ro`, `cooler`, `geyser`, `microwave`, `stove`, `iron`, `tv`, `drying`, `shoes`, `lift`, `dustbin` | `hostels.amenities` |
| `amenities_other` | Short plain words (CCTV, Power backup, Parking, Gym, Housekeeping, Biometric, Warden, Laundry, Study room) | `hostels.tags` candidates |
| `menu` | Keys `Mon`…`Sun`; meals `breakfast`, `lunch`, `dinner` | `menus` (Mon = day 0) |
| `meal_times` | `"7:30 – 9:30"` style | `menus.*_time` |
| `photos.csv label` | `Front`, `Room`, `1 sharing`…`6 sharing`, `Washroom`, `Kitchen`, `Dining`, `Common area`, `Other` | `hostel_photos.label` (after the team picks and owns a photo) |
| `place_id` / `osm_id` | Google place id / `n123` or `w123` | `hostels.place_id` (`osm:n123`) |
| `business_status` | `operational`, `closed_temporarily`, `closed_permanently`, `null` | — |

### 7.3 Rent, reviews, owners

**`rents.jsonl`** (every price seen):
`hostel_key, share (1–8 or null), ac, food_included, rent (₹/bed/month or null), rent_raw (exactly as written), period ("month" / "day" / "week" as written), deposit, offer, source, url, seen_at, listed_on (the portal's own posted/updated date)`.
Don't convert day/week prices to monthly; keep `period`.

**`reviews.jsonl`** (every public review):
`hostel_key, source, stars (1–5 or null), text (full), lang, date (ISO) or date_raw ("3 months ago"), reviewer_type (resident / ex_resident / parent / visitor / unknown; no names), owner_reply {text, date}, topics[], sentiment (positive / mixed / negative), url, seen_at`.
`topics` only from words the review actually uses: `food`, `cleanliness`, `water`, `wifi`, `safety`, `owner_behaviour`,
`rent_hike`, `deposit_refund`, `timings`, `noise`, `location`, `ac`, `washroom`, `bugs`.

**`owners.jsonl`** (one per owner):
| Field | Content |
|---|---|
| `owner_key` | `own:0001` |
| `name`, `role` | As a listing / page / board shows it · `owner` / `manager` / `caretaker` / `chain_office` / `unknown` |
| `phones[]` | `{number, type: mobile/landline, whatsapp: true/false/null, seen_on[], seen_at}` (only numbers the business published itself: listings, boards in photos if clearly legible, pages, wa.me links) |
| `email` | Business email |
| `hostels[]`, `hostel_count` | Keys from `hostels.jsonl` |
| `languages` | If visible |
| `instagram` | `{url, handle, followers, posts, last_post_date, posts_last_30d, has_whatsapp_link, bio_phone}` |
| `facebook` | `{url, followers_or_likes, last_post_date, phone_on_page}` |
| `youtube` | `{url, subscribers, videos, last_upload_date}` |
| `google_business` | `{maps_url, rating, review_count, owner_replies_to_reviews, last_review_date, photos_count}` |
| `website` | `{url, has_booking_form, has_whatsapp_button}` |
| `portals[]` | `{portal, url, listed_on}` |
| `ads_seen` | Meta Ad Library: `{active: true/false, count}` |
| `presence_score` | 0–5: +1 each for Google profile with owner replies · Instagram post in the last 30 days · Facebook post in the last 30 days · listed on 2+ portals · own website |
| `priority` | `A` = `hostel_count ≥ 3` or `presence_score ≥ 3` or on 2+ portals · `B` = has a WhatsApp number · `C` = the rest |
| `best_channel` | `whatsapp` / `call` / `instagram_dm` / `email` |
| `do_not_contact` | `false` (the founder sets it; never reset by a later fetch) |

**`owners_calllist.csv`** (sorted A → C, then `hostel_count` high → low):
`priority, owner_name, role, best_phone, whatsapp_yn, other_phones, hostel_names, areas, hostel_count, instagram, facebook, portals, presence_score, notes, called_on, outcome, do_not_contact` (last 4 empty).

### 7.4 Checks before delivery
| Check | Pass when |
|---|---|
| Inside the city | Every pin inside the box |
| Exact pins | Every row: 6-decimal pin + `location_quality`; "check pins" list in `REPORT.md` |
| No duplicates | Merge rules applied; every raw row appears in exactly one `sources[]` |
| App values | Every field in 7.2 uses only its allowed values (validate with a script, report the count of fixes) |
| Nothing invented | 30 random hostels checked against their source pages; result in `REPORT.md` |
| No secrets | No key, cookie or password in the folder |
| No private people | No reviewer names; owner data only from business pages |

---

# Part 3 · For the reviewer

## 8. Open decisions, gaps and risks (the hub's recommendation in each row)

### Decisions needed (D)
| # | Question | Hub recommends |
|---|---|---|
| D1 | Spend cap if the Google Places API is used (paid per request) | Founder sets a number; a key is optional (scraping the public pages is the fallback) |
| D2 | `hostels.source` allows only `team/resident/partner/places/osm/web`. Scraped portal rows need a value | Add `scrape` by migration in phase 2; keep the detailed source in a new `source_detail` column |
| D3 | `hostels.gender` can't be empty, but many places won't say | Loader writes the hint if known, else `Co-living` **and** keeps it a draft until the call confirms (today's import defaults to `Men`: change it, `Men` is a guess) |
| D4 | `rate_cards` has no "with / without food" column; portals often list both | Phase 2: store the with-food price when food is included (matches `hostels.food`); keep the other in the files |
| D5 | The app's `amenities` table needs a floor; collected amenities are hostel-level | Use `hostels.amenities` (hostel-level list) only; floors stay for verified hostels |
| D6 | Show Google / portal **ratings** on UNVERIFIED cards? | Not now. Today only verified-resident reviews are shown (F08); revisit after launch |
| D7 | Show **portal rents** publicly before a call? | No: the 60-day human-confirmed rule stays. Rents pre-fill the team's call form |
| D8 | Use **portal / Google photos** in the app? | No copying into our bucket. Team uses them as reference; real photos come from the owner or the team |
| D9 | Where the owner call list lives | Phase 1: the CSV with the founder. Phase 2: the console's To call segment |
| D10 | `hostel_leads` holds one phone + one WhatsApp per hostel; owners have several | Phase 2: add an `owner_contacts` table (team-only) or keep extras in the CSV |
| D11 | Travel minutes: the app today uses rough per-area guesses (`hostelzy/lib/data/onboarding.dart` `areaSpot`) | Replace with `travel.jsonl` after a small spec |

### Risks (R)
| # | Risk | Mitigation in this plan |
|---|---|---|
| R1 | Sites' terms of service forbid scraping: blocks, IP bans, legal notices (Google Maps, NoBroker, MagicBricks, Justdial…) | Slow rate, public pages only, stop a site on a block and report it; data stays internal (not republished as is) |
| R2 | Unauthorised access (IT Act s.43 / s.66) | No logins, no CAPTCHA breaking (line 3) |
| R3 | Copyright in photos and review text (Copyright Act 1957) | Photos as links only, not shown in the app (D8); reviews not shown in the app (D6) |
| R4 | Personal data (DPDP Act 2023): owner phones are often personal mobiles | Only numbers the business published itself, `seen_on` kept, `do_not_contact` honoured for ever. **Have a lawyer confirm** the "made public by the person" exemption before bulk outreach |
| R5 | Marketing rules (TRAI telemarketing rules, WhatsApp Business policy) | Founder calls / WhatsApps one to one from the separate SIM; no bulk SMS / robocalls; WhatsApp bans numbers that message hundreds of strangers a day (rule of thumb: start at ~20–30 new chats a day) |
| R6 | Stale data (closed PGs, old rents) | `seen_at` / `listed_on` on everything; team call before listing; monthly refresh exists for Google |
| R7 | Wrong pins | Section 5.2 rules; "check pins" list; team fixes pins after the call |
| R8 | Google Places data may be stored only 30 days (except `place_id`) under Google's API terms | Only matters if the API is used; the existing monthly refresh handles it |

### Things the hub may have got wrong (check these)
| # | Assumption |
|---|---|
| A1 | Several thousand PGs exist in Hyderabad and most have a phone on at least one source |
| A2 | Places API (New) returns about 60 results per search and has a cheap IDs-only tier; check current Google docs and prices |
| A3 | Meta Ad Library pages for Indian advertisers are viewable without logging in |
| A4 | The 12 travel hubs and 80–120 areas are the right set for Hyderabad tenants |
| A5 | Priority A/B/C thresholds (3+ hostels, score ≥ 3, 2+ portals) are a sensible first cut |

## 9. What the reviewer should check
1. Does section 4 match the database? (Repo `supabase/migrations/`; the hub checked on 2026-11-22.)
2. Does every field in 7.2 have a home, or is it listed in section 8 as a gap?
3. Do any of the lines in 5.1 contradict the founder's "scrape from anywhere"? (They're kept as the legal minimum; say if you disagree.)
4. Are D1–D11 recommended sensibly? Flag any that need the founder.
5. Is the method in 6.2 complete for Hyderabad (sources missed, terms missed)?
6. Return: a list of corrections as `section · what's wrong · what it should say`.

## 10. Glossary
| Word | Meaning |
|---|---|
| PG | Paying guest: a shared-room hostel, rent per bed per month |
| Sharing | Beds per room (2 sharing = 2 beds in a room) |
| Advance | One-time deposit paid at move-in (₹3,000 norm) |
| Exit maintenance | Part of the advance the owner keeps when the tenant leaves |
| Listed / UNVERIFIED | A public card from collected data, confirmed by a team call, without owner sign-up |
| Live / ✓ VERIFIED | Owner signed up and the team visited |
| Hub | The Claude chat the founder talks to; it plans and decides product details |
| Build | The Claude chat that writes the code |
| Console | The Hostelzy team's web tool (`app/console/`) |
