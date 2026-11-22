# Hostelzy · Data collection plan (v5)

| | |
|---|---|
| Written by | Hostelzy hub (Claude), 2026-11-22, for the founder |
| Founder's rule | **Get all the data. Collect first; how it's used (app, calls) is decided later.** No legal review in this plan |
| v5 changes | Reviewer AI's fixes applied (keys, merge rules, pins, search terms, areas, API order, gender, rent window); all legal sections removed |
| Repo | github.com/abdulfarhath/hostelzy · this file `docs/DATA-FETCH-BRIEF.md` · schema facts checked by the hub against `supabase/migrations/` on 2026-11-22 |

| You are… | Read |
|---|---|
| The data-collecting AI | Part 1 for context, all of Part 2 |
| A reviewer AI | Everything; open decisions are in section 8 |

---

## 0. Summary
1. **Hostelzy** = phone app for PGs / hostels in Hyderabad: tenants find and hold beds, residents manage their stay, owners run the hostel.
2. **Now: collect everything** about every PG / hostel / co-living place in Hyderabad, plus the owners' contacts and social media, into fixed-format files.
3. **Later:** Build loads the files into the app; the founder decides what is shown and who is called.

---

# Part 1 · The app (context)

## 1. Hostelzy
| | |
|---|---|
| City | Hyderabad + Secunderabad + Cyberabad. Launch zone: **Madhapur · Hitech City · Kondapur · Gachibowli** |
| Users | Tenant · Resident · Owner (+ manager) · Hostelzy team (web console) |
| Tenant | Student or IT employee, 18–30, searching near a college, coaching centre or office |
| Tech | Flutter app (`hostelzy/`), Supabase Postgres (`supabase/`), console + web pages (`app/`). Map: `flutter_map` + OpenStreetMap tiles today, Google Maps planned at launch |
| State | Features F02–F31 merged, Android build apk-109 |
| Money | Tenants pay Hostelzy ₹0. Owners pay ₹499 / ₹999 / ₹1,499 a month by bed count. Move-in = ₹3,000 advance + first month, straight to the owner |

## 2. Listing tiers
| Tier | Tenants see | How it gets there |
|---|---|---|
| **draft** | Nothing | Imports and collected data land here |
| **listed** (UNVERIFIED, grey) | Name, Men/Women/Co-living, area, pin, photos, rent range (only within 60 days of a human confirming it, else "Rent on request") | Team calls, presses **List** |
| **live** (✓ VERIFIED, navy) | Everything: rooms, beds, a price per room type, menu, reviews, holds | Owner signs up; rooms, prices, linked owner, 8 photos, team visit |

## 3. Where data goes in the database
| Table · column | Values |
|---|---|
| `hostels.name` | text, required |
| `hostels.gender` | `Men` / `Women` / `Co-living` (= mixed-gender building), required today (see D3) |
| `hostels.area` | text, required, one of the app's areas |
| `hostels.address`, `lat`, `lng` | text, doubles |
| `hostels.owner_name` | first name shown to tenants |
| `hostels.food`, `ac`, `only_ac` | bool |
| `hostels.amenities` | text[] · `hostels.tags` text[] (card chips) |
| `hostels.terms` | `{"advance": ₹, "maintenance": ₹ (exit, kept from the advance), "noticeDays": int, "dueOnJoining": bool, "electricityExtra": bool}` |
| `hostels.rules` | `[{"k": "Gate closes", "v": "10:30 pm"}, …]` |
| `hostels.rent_min`, `rent_max`, `rent_confirmed_at` | ₹, ₹, timestamp |
| `hostels.status` | `draft` / `listed` / `live` / `paused` |
| `hostels.source` | only `team`, `resident`, `partner`, `places`, `osm`, `web` today (see D2) |
| `hostels.place_id` (unique), `source_seen_at`, `source_photos` | Google id or `osm:n123`; timestamp; Google photo names |
| `rate_cards (hostel, ac, share) → rent` | one price per AC/non-AC × sharing; no food column (see D4) |
| `menus` | `day` 0–6 (**0 = Monday**), `breakfast`, `lunch`, `dinner`, `*_time` |
| `amenities.kind` (per floor) | `fridge`, `washer`, `ro`, `cooler`, `geyser`, `microwave`, `stove`, `iron`, `tv`, `wifi`, `drying`, `shoes`, `lift`, `dustbin`, `other` |
| `hostel_photos` | files in Hostelzy's own bucket, `label` |
| `hostel_leads` (team only) | `owner_phone`, `owner_whatsapp`, `stage`, `next_step`: one phone + one WhatsApp per hostel (see D10) |
| `reviews` | verified residents only; collected reviews are kept in files |

Already built (F28): `tools/import/places.mjs` (Places API, 4 terms per area), `tools/import/osm.mjs`, `tools/import/areas.json`
(32 areas), monthly workflow, console › Listed › **To call**, owner web form `app/list/`.

---

# Part 2 · The collection brief

## 4. The job
Every PG / hostel / co-living place in Hyderabad (several thousand), everything about it, from every source; every owner's
contacts and online presence. Deliver the files in section 7.

### 4.1 Data-quality lines (the only lines)
| # | Line |
|---|---|
| 1 | **Never invent a sourced value.** Unknown = `null` (never `""`, `0`, or a guess) |
| 2 | **Every sourced value keeps `source`, `url`, `seen_at`** (ISO 8601 with offset, `2026-11-22T14:05:00+05:30`) |
| 3 | **Derived fields** (computed from sourced data, no URL needed): `gender` from name words, `area`, `location_quality`, `pin_gap_m`, `topics`, `sentiment`, `reviewer_type` (default `unknown`), `presence_score`, `priority`, `best_channel`, photo `label` (default `Other`). Mark them in `REPORT.md` |
| 4 | **Stable keys** (section 7.2): the same place gets the same key on every future fetch |
| 5 | No API keys, cookies or passwords inside delivered files |

### 4.2 Exact location
| Rule | Detail |
|---|---|
| Precision | ≥ 6 decimals, never rounded |
| Best pin, in order | 1 Google business pin · 2 OSM node / building-outline centre · 3 geocoded address with house number · 4 portal pin (portals usually blur PG locations: `street` unless the page JSON has an exact lat/lng) |
| `location_quality` | `rooftop` (on an OSM building outline within 15 m) · `building` · `street` · `area_only` (area / pincode centre: never used as a pin) |
| `pin_from` | `google_maps`, `osm`, `geocoded`, `<portal name>` |
| Conflicts | Keep all pins in raw; `pin_gap_m` = largest gap; > 75 m → `check_pins.csv` |
| Flags | > 3 km from its area centre · outside the box · two different hostels within 5 m → `check_pins.csv` |
| City box | **lat 17.20–17.65, lng 78.15–78.75** |

### 4.3 What counts
| Keep | Mark and keep | Drop |
|---|---|---|
| PG, paying guest, hostel, co-living, ladies / gents / boys / girls / working women's / working men's hostel, bachelors rooms, per-bed service apartments | Campus hostels (`campus: true`), backpacker hostels (`kind: "backpacker"`), closed places (`business_status`) | Hotels, lodges, OYO rooms, resorts, per-night guest houses (unless the name also says PG / hostel) |

`gender: "Co-living"` means a mixed-gender building. Never infer it from a brand or from `kind: "coliving"` (a Stanza women's building is `kind: coliving, gender: Women`).

## 5. Sources (use all)
| Group | Sources | Gives |
|---|---|---|
| Google | **Places API (New)** (key from the founder) for ids, pins, phones, ratings, photo names · **Google Maps web pages** for every review, every photo, owner replies, "people also search" neighbours | The backbone: pins and phones |
| OSM | Geofabrik Telangana extract (offline) for tagged places, buildings, landmarks, nearby; Overpass for small checks | Pins, building outlines |
| PG portals | NoBroker · MagicBricks · 99acres · Housing.com · Justdial · Sulekha (phones often visible) · Quikr / OLX / NestAway / CommonFloor / Makaan / SquareYards (**timebox 1 h each**, little PG stock) | Rent per sharing, deposit, food, amenities, rules, gender, owner names, Justdial/Sulekha reviews and phones |
| Chains | Stanza Living · Zolo · Colive · Settl · Isthara · Hello World · Tribe · (Housr, Your-Space, Coho, Cove: check Hyderabad presence first) | Exact rents per type, photos, addresses |
| Instagram | **Graph API Business Discovery** from Hostelzy's own business account (followers, media count, recent posts with dates and captions) + browsing while signed in to Hostelzy's own account (hashtags `#hyderabadpg`, `#ameerpetpg`, `#ladieshostelhyderabad`, `#pgingachibowli`…) | Handles, bio phones / WhatsApp, rent posts, activity |
| Facebook | Pages and posts, signed in to Hostelzy's own account | Page phone, activity |
| YouTube | **Data API v3** search "PG in <area> Hyderabad", room tours | Name, area, rent, phone in descriptions, channel stats |
| Telegram | Public channel previews `t.me/s/<channel>` | PG ads with phone + rent |
| Web search | `"PG in <area>" Hyderabad`, `"ladies hostel" <area>`, `site:instagram.com PG <area> Hyderabad`, `site:sulekha.com …` | The long tail, own websites |
| Own websites | Every website found | Rent, food, menu, rules, WhatsApp, photos |
| Meta Ad Library (web) | Spot-check owners' pages | Whether they run ads |
| Around | OSM extract, HMRL / L&T Metro station list, AICTE / UGC college lists, India Post pincodes | Landmarks, areas |
| Travel time | Self-hosted **OSRM** on the Telangana extract (`foot`, `car`) | Minutes to metro and hubs |

**Where phones come from (expect):** Google Places (Details Enterprise) first, then Sulekha / Justdial, Instagram bios,
own websites, YouTube descriptions, Telegram ads, photos of boards. Big portals (NoBroker, MagicBricks, 99acres, Housing)
mostly hide phones behind lead forms.

When a site blocks you, move to the next source and note it in `REPORT.md`.

## 6. Method
| Step | What |
|---|---|
| 0 | **Seed:** take the app's 32 areas + the names in 6.1 as the area list; take the export of existing `places` / `osm` drafts (`place_id`s, from the founder) so known places aren't paid for twice |
| 1 | **Google grid (API):** ~1 km cells over the box, 500 m in dense zones (Ameerpet, SR Nagar, Madhapur, Kondapur, Gachibowli, KPHB, Dilsukhnagar, Ashok Nagar). Every term in 6.2 per cell with **Text Search Essentials (IDs only)**; a cell that returns 60 → split in 4. Plus a **Nearby Search** sweep with `includedTypes: ["hostel"]` |
| 2 | **Place Details Pro** for every unique id (`displayName, location, primaryType, types, businessStatus, formattedAddress`) → filter PG-like by name / type |
| 3 | **Place Details Enterprise + Atmosphere** for PG-likes only (`nationalPhoneNumber, internationalPhoneNumber, websiteUri, googleMapsUri, rating, userRatingCount, reviews, photos`). Spread over two calendar months if free monthly caps help (founder's spend cap: D1) |
| 4 | **Google Maps pages** for every PG-like: all reviews (scroll to the end), owner replies, all photos |
| 5 | **OSM:** tagged places (`tourism=hostel`, `amenity=dormitory`, `building=dormitory`, `amenity=student_accommodation`) + name regex `nwr["name"~"hostel|paying guest|\\bPG\\b|co-?liv",i]` inside the box |
| 6 | **Portals:** every area's PG list to the last page; each listing; prefer the JSON in the page |
| 7 | **Chains:** every Hyderabad property page |
| 8 | **Social + long tail:** Instagram, Facebook, YouTube, Telegram, web search, own websites |
| 9 | **Rent + reviews** from every page opened (section 7.3) |
| 10 | **Owners:** group by phone / name / brand; social presence; priority (section 7.3) |
| 11 | **Areas** refined (80–140), **landmarks**, **nearby**, **travel** |
| 12 | **Merge, check, report** (section 7.4) |

**Merge rules:** same `place_id` = same place · same phone = same place unless pins > 150 m apart · same normalised name **and**
(same phone, or same house number, or pins < 30 m apart) = same place · anything weaker → `possible_duplicates.csv`.

### 6.1 Areas
| Zone | Areas |
|---|---|
| IT corridor West | Hitech City, Madhapur, Kondapur, Gachibowli, Financial District, Nanakramguda, Kokapet, Narsingi, Gandipet, Manikonda, Puppalaguda, Raidurg, Khajaguda, Botanical Garden, Kothaguda, Hafeezpet, Serilingampally, Lingampally, Chanda Nagar, Madinaguda, Miyapur, Gopanpally, Tellapur, Nallagandla, Beeramguda, Ameenpur, Patancheru, BHEL / RC Puram |
| Coaching / central | Ameerpet, SR Nagar, Yousufguda, Punjagutta, Erragadda, Borabanda, Sanath Nagar, Begumpet, Somajiguda, Khairatabad, Lakdikapul, Masab Tank, Himayatnagar, Narayanaguda, Ashok Nagar, Chikkadpally, RTC X Roads, Musheerabad, Vidyanagar, Nallakunta, Amberpet, Kachiguda |
| North-West | Kukatpally, KPHB, JNTU, Moosapet, Balanagar, Nizampet, Bachupally, Pragathi Nagar, Kompally, Suchitra, Jeedimetla, Quthbullapur, Medchal |
| North / Secunderabad | Secunderabad, Paradise, Marredpally, Bowenpally, Trimulgherry, Alwal, Malkajgiri, Moula Ali, Tarnaka, Habsiguda, Nacharam, Uppal, Ramanthapur, Boduppal, Pocharam, ECIL, AS Rao Nagar, Sainikpuri |
| South / East | Dilsukhnagar, Kothapet, LB Nagar, Chaitanyapuri, Malakpet, Saroornagar, Vanasthalipuram, Hayathnagar, Nagole, Koti, Abids, Nampally, Mehdipatnam, Tolichowki, Attapur, Hydershakote, Bandlaguda Jagir, Rajendranagar, Shamshabad |
| Others | Jubilee Hills, Banjara Hills, Film Nagar, Shaikpet, Srinagar Colony, Madhura Nagar, Gandhi Nagar, Kavadiguda |

Keep the app's 32 spellings exactly (Ameerpet · SR Nagar · Madhapur · Hitech City · Kondapur · Gachibowli · Nanakramguda ·
Manikonda · Jubilee Hills · Banjara Hills · Kukatpally · KPHB · Miyapur · Nizampet · Chanda Nagar · Lingampally · Begumpet ·
Secunderabad · Bowenpally · Alwal + 12 in `tools/import/areas.json`).

### 6.2 Search terms (every cell, every source)
PG · paying guest · PG accommodation · hostel · hostel for ladies · ladies hostel · ladies PG · girls hostel · girls PG ·
womens hostel · womens PG · working women hostel · boys hostel · boys PG · gents hostel · gents PG · mens hostel · mens PG ·
working mens hostel · bachelors room · executive PG · luxury PG · co-living · coliving

## 7. Deliverables
One folder `data/fetch/<YYYY-MM-DD>/` (or zip). UTF-8. `.jsonl` = one JSON object per line.

### 7.1 Files
| File | Content |
|---|---|
| `raw/<source>.jsonl` | Every listing as seen, untouched, + `url`, `seen_at` |
| `hostels.jsonl` | One per real place, merged (7.2) |
| `rents.jsonl` · `rent_by_area.csv` | Every price seen · min / median / max per area × sharing × AC × food (count ≥ 3, last 180 days) |
| `reviews.jsonl` | Every review (7.3) |
| `owners.jsonl` · `owners_calllist.csv` | Owners (7.3) |
| `photos.csv` | `hostel_key, url, source, label, seen_at` (links) |
| `areas.json` | `name, aliases[], lat, lng, radius_m, pincodes[], zone, osm_id, polygon` |
| `landmarks.json` | Metro, MMTS, bus stations, IT parks, colleges, coaching clusters, hospitals: `id, group, name, aliases[], lat, lng, area, lines[], source, osm_id, seen_at` |
| `travel.jsonl` | Per hostel: `walk_to_metro {landmark_id, metres, minutes}`, `ride_to {hub: minutes}`, `method`. Hubs: Hitech City · Gachibowli (DLF / Wipro Circle) · Financial District · Kondapur · Ameerpet · KPHB · JNTU · Secunderabad · Begumpet · Banjara Hills · Koti · Dilsukhnagar · LB Nagar · Uppal · Pocharam |
| `nearby.jsonl` | Per hostel, within 800 m walk: supermarket, pharmacy, hospital/clinic, ATM, gym, bus stop, restaurant, laundry, police `{count, nearest_name, nearest_m}` |
| `check_pins.csv` · `possible_duplicates.csv` | For the team |
| `REPORT.md` | Counts per area and source · % with phone / rent / gender / exact pin · merges · drops · per-domain request counts and blocks · API spend per SKU · 30-row spot check · derived fields list |

### 7.2 `hostels.jsonl`
**Key** (stable across fetches): `g:<place_id>` → else `osm:<n|w><id>` → else `ph:<sha1(normalised primary phone)>` →
else `nm:<sha1(normalised name + lat,lng rounded to 4 decimals)>`.

```json
{
  "key": "g:ChIJ…",
  "name": "Sri Sai Ladies Hostel", "aliases": ["Sri Sai Womens PG"],
  "brand": null, "kind": "pg", "campus": false,
  "gender": "Women", "gender_from": ["name", "nobroker"], "for": "both",
  "lat": 17.438123, "lng": 78.448710, "location_quality": "rooftop", "pin_from": "google_maps", "pin_gap_m": 12,
  "address": "Plot 12, Lane 3, Ameerpet, Hyderabad 500016", "landmark": "Behind Ameerpet Metro", "pincode": "500016",
  "area": "Ameerpet", "launch_zone": false,
  "phones": [{ "number": "+91 98xxxxxxxx", "whatsapp": true, "seen_on": ["google_maps", "instagram"] }],
  "email": null, "website": null, "instagram": "https://instagram.com/…", "facebook": null, "youtube": null,
  "owner_key": "ph:3f2a…", "owner_first_name": null,
  "food": true, "meals": ["breakfast", "dinner"], "veg_only": null,
  "ac": false, "only_ac": false, "sharing_types": [2, 3], "attached_bath": true, "total_beds": null,
  "rent_min": 6500, "rent_max": 7500,
  "rents_latest": [
    { "share": 2, "ac": false, "food": true, "rent": 7500, "source": "nobroker", "seen_at": "2026-11-22T14:05:00+05:30" }
  ],
  "terms": { "advance": 5000, "maintenance": null, "noticeDays": 30, "dueOnJoining": null, "electricityExtra": true },
  "rules": [{ "k": "Gate closes", "v": "10:30 pm" }, { "k": "Non-veg", "v": "Not allowed" }],
  "amenities": ["wifi", "geyser", "washer", "ro"], "amenities_other": ["CCTV", "Power backup"],
  "amenities_raw": ["Wi-Fi", "Hot water", "Washing Machine", "RO", "CCTV", "Power Backup"],
  "menu": { "Mon": { "breakfast": "Idli, chutney", "lunch": null, "dinner": "Chapati, dal" } },
  "meal_times": { "breakfast": "7:30 – 9:30", "lunch": null, "dinner": "8:00 – 10:00" },
  "photos_count": 14,
  "ratings": [{ "source": "google_maps", "stars": 4.1, "count": 230 }],
  "review_count_total": 281, "top_praise": [{ "topic": "food", "count": 41 }], "top_complaints": [{ "topic": "timings", "count": 12 }],
  "business_status": "operational", "place_id": "ChIJ…", "osm_id": null,
  "sources": ["google_maps:ChIJ…", "nobroker:8a9f…"], "listing_urls": ["…"],
  "first_seen": "2026-11-22T14:05:00+05:30", "last_seen": "2026-11-22T14:05:00+05:30"
}
```

| Field | Allowed values |
|---|---|
| `kind` | `pg`, `hostel`, `coliving`, `working_women`, `student`, `backpacker`, `unknown` |
| `gender` | `Men`, `Women`, `Co-living` (mixed building), `null` |
| `for` | `students`, `working`, `both`, `null` |
| `area` | a name in `areas.json` · `launch_zone`: area ∈ Madhapur, Hitech City, Kondapur, Gachibowli |
| `location_quality` / `pin_from` | section 4.2 |
| phones | `+91 XXXXXXXXXX`; landline `+91 40 XXXXXXXX` |
| `food`, `ac`, `only_ac`, `attached_bath`, `veg_only` | `true` / `false` / `null` |
| `rents_latest[]` | latest price per (`share` 1–8, `ac`, `food`); `rent` ₹ per bed per month |
| `rent_min`, `rent_max` | over monthly prices seen in the **last 180 days**; else `null` |
| `terms` keys | `advance`, `maintenance` (exit), `noticeDays`, `dueOnJoining`, `electricityExtra` |
| `rules[].k` | `Gate closes`, `Visitors`, `Opposite gender entry`, `Guests overnight`, `Quiet hours`, `Smoking`, `Drinking`, `Non-veg`, `Cooking`, `Lock-in`, `Pets`; `v` short text as written |
| `amenities` | `wifi`, `fridge`, `washer`, `ro`, `cooler`, `geyser`, `microwave`, `stove`, `iron`, `tv`, `drying`, `shoes`, `lift`, `dustbin`; the rest in `amenities_other` |
| `menu` | `Mon`…`Sun` × `breakfast` / `lunch` / `dinner` |
| photo `label` | `Front`, `Room`, `1 sharing`…`6 sharing`, `Washroom`, `Kitchen`, `Dining`, `Common area`, `Other` |
| `business_status` | `operational`, `closed_temporarily`, `closed_permanently`, `null` |

### 7.3 Rent, reviews, owners
**`rents.jsonl`:** `hostel_key, share, ac, food, rent, rent_raw, period (month/day/week as written), deposit, offer, source, url, seen_at, listed_on`.

**`reviews.jsonl`:** `hostel_key, source, review_id (source's id or hash of text+date), stars, text, lang, date / date_raw, reviewer_name, reviewer_type, owner_reply {text, date}, photos[], topics[], sentiment, url, seen_at`.
`topics`: `food`, `cleanliness`, `water`, `wifi`, `safety`, `owner_behaviour`, `rent_hike`, `deposit_refund`, `timings`, `noise`, `location`, `ac`, `washroom`, `bugs`.

**`owners.jsonl`:**
| Field | Content |
|---|---|
| `owner_key` | `ph:<sha1(primary phone)>`, or `chain:<name>` · stable across fetches |
| `name`, `role` | as shown · `owner` / `manager` / `caretaker` / `chain_office` / `unknown` |
| `phones[]` | `{number, type, whatsapp, seen_on[], seen_at}` |
| `email`, `languages` | |
| `hostels[]`, `hostel_count`, `areas[]`, `launch_zone` | |
| `instagram` | `{url, handle, followers, posts, last_post_date, posts_last_30d, bio_phone, has_whatsapp_link}` |
| `facebook` | `{url, followers_or_likes, last_post_date, phone_on_page}` |
| `youtube` | `{url, subscribers, videos, last_upload_date}` |
| `google_business` | `{maps_url, rating, review_count, owner_replies_to_reviews, last_review_date, photos_count}` |
| `website`, `portals[]`, `ads_seen` | |
| `presence_score` | 0–5 from the fields above (Google replies · Instagram post ≤ 30 days · Facebook post ≤ 30 days · 2+ portals · own website) |
| `priority` | `A` = 3+ hostels or score ≥ 3 or 2+ portals · `B` = has WhatsApp · `C` = rest |
| `best_channel`, `do_not_contact` (`false`, set by the founder, kept across fetches) | |

**`owners_calllist.csv`** sorted **launch zone first**, then priority, then `hostel_count`:
`launch_zone, priority, owner_name, role, best_phone, whatsapp_yn, other_phones, hostel_names, areas, hostel_count, gender, latest_rent_seen, rent_seen_at, google_rating, instagram, facebook, portals, presence_score, notes, called_on, outcome, do_not_contact`.

### 7.4 Checks
| Check | Pass when |
|---|---|
| Inside the box | every pin |
| Pins | 6 decimals + `location_quality` everywhere; `check_pins.csv` written |
| Keys | deterministic per 7.2; re-running on the same input gives the same keys |
| Duplicates | merge rules applied; every raw row in exactly one `sources[]` |
| Values | every field in 7.2 uses only allowed values (validate with a script) |
| Spot check | 30 random hostels against their pages, in `REPORT.md` |

---

# Part 3 · Open decisions (for the founder / reviewer)

| # | Question | Hub recommends |
|---|---|---|
| D1 | Google Places spend cap (founder's money) | Reviewer suggested ~₹15,000; near zero if run over two months under the free caps. **Founder sets it** |
| D2 | `hostels.source` needs a value for collected rows | Migration: add `scrape`, plus `source_detail` and `source_url` |
| D3 | Many places won't state Men/Women | Migration: `gender` nullable while `status = 'draft'`; console **List** stays disabled until "For" is set |
| D4 | Portals give with-food and without-food prices | Migration: add `food` to the `rate_cards` key (`hostel, ac, share, food`) |
| D5 | Amenities are hostel-level, not per floor | Use `hostels.amenities`; floors stay for verified hostels |
| D6 | Show Google / portal ratings on listed cards? | Founder decides at load time |
| D7 | Show collected rents before a call? 60-day re-confirm ≈ 33 calls a day for 2,000 listed hostels | Founder decides: keep 60 days, go to 120 days, or show "Rent as of <month>" |
| D8 | Photos on listed cards | Founder decides: placeholder · Google photos live with attribution (`source_photos` exists) · collected photos copied in · owner sends one on the call |
| D9 | Owner call list home | CSV now; console › To call in phase 2 |
| D10 | Several phones per owner | New team-only `owner_contacts` table (owner-level `do_not_contact`) |
| D11 | Travel minutes | Replace the app's guessed per-area minutes (`hostelzy/lib/data/onboarding.dart` `areaSpot`) with `travel.jsonl`; small spec first |
| D12 | After the team call confirms a place | Flip `source` to `team`, set `rent_confirmed_at` |

| Assumption | Status |
|---|---|
| Several thousand PGs, most with a phone on some source | Plausible; phones mainly from Google Places + Sulekha/Justdial + Instagram |
| Places API: Text Search ≤ 60 results (20 × 3 pages); IDs-only SKU exists; billing by field mask | Confirmed by the reviewer |
| Schema in section 3 | Checked by the hub against the migrations on 2026-11-22 |
