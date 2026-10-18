# F28 · Every Hyderabad hostel in: Verified filter, tenants and partners add hostels, Places import, owner link

**Stage:** Ideas (founder, 2026-10-18) → **Spec final (hub, 2026-10-18, under the founder's delegation)** → Design → Build
(28-10 wave 1 · 28-30/31/40 wave 2 · 28-20/21/50/60/80 wave 3 · 28-90 wave 4).

**Founder (2026-10-18):** a Verified / Unverified filter; get the details of every hostel into the app, with verified hostels
showing the real detailed information and the rest as unverified; tenants add their own PG (owner's phone required, paid
~₹200 only when the owner agrees and the hostel gets verified); partners add hostels; owner self-serve link; the founder
messages owners on WhatsApp himself; OpenStreetMap as a supplement; keep rents fresh. No scraping of Google Maps or portals.
Dropped: GHMC. Later: college ambassadors.

## What exists (F26 #21)
`hostels.status = 'listed'` = UNVERIFIED tier (name, gender, area, pin, photos, `rent_min`–`rent_max`; no beds, holds or
contact), console › Listed (C14) and › Claims (C15), `list_hostel` RPC, `claim_requests`, `verify_waitlist` ("Tell me when
verified"), Explore header "N verified · M listed", `area_counts()`.

## Part 1 · Verified-only filter (28-10, wave 1)
| Where | Change |
|---|---|
| H1 Filters sheet | New switch at the bottom, under Food included: **Verified only** (off by default). Count in the "n" of the filter row like the others |
| S8 Explore | Order: verified cards first (today's sort), UNVERIFIED cards after them, in the same sort. With the switch on, UNVERIFIED cards are hidden and the header still says "N verified · M listed" |
| S9 Map | Same switch applies to pins |

## Part 2 · Anyone adds a hostel (28-30, 28-31, 28-40, wave 2)
| Step | Who | What |
|---|---|---|
| 1 | Tenant / resident / partner (signed in) | **S92 `addHostel`** "Add a hostel": hostel name · gate photo (camera/gallery, 1–3) · pin (GPS, drag to fix; area from the pin) · For: Men / Women / Co-living · Rent: "What do you pay?" ₹/month (one number; partners enter a range) · Sharing: 1/2/3/4+ · Food included yes/no · **Owner's name + phone (required)** · "I live here" (default) or "I'm a Hostelzy partner" (needs a partner code) · **Add** |
| 2 | App | Dedupe: same phone or same name within 150 m of an existing hostel → "Already on Hostelzy: <name>. Ask your owner to verify it instead" with the share button; no new row. Else the hostel is created as `listed` (UNVERIFIED) with `source = 'resident'` or `'partner'`, `added_by`, the rent as `rent_min = rent_max = paid rent` (partners: range) and `rent_confirmed_at = now()` |
| 3 | Adder | **S93 `myAdd`** "Your hostel on Hostelzy": the card as tenants see it, the 5 steps **Added ✓ → Owner asked → Owner agreed → Verified → ₹200 paid**, big button **Send to your owner** (WhatsApp from the tenant's phone: "Your PG <name> is on Hostelzy. Agree to get it verified (free): <claim link>"), "Ask again" after 3 days, and the honest line "Paid only when the owner agrees and Hostelzy verifies the hostel" |
| 4 | Owner | Claim link `app/r/?h=<id>&claim=1` → the UNVERIFIED page (T32) with the existing **Claim this hostel** sheet H47 pre-opened; submitting = **owner agreed** (step 3 ticks) |
| 5 | Team | Console › Claims (C15): the claim shows "added by Ravi (resident) · owner phone matches ✓/✗". Team verifies as today (visit, checklist) → `live` |
| 6 | App | On `live`: `reward_ledger` entry **₹200 `hostel_added`** for the adder (resident path) or **₹20 `hostel_listed`** for the partner at step 2 (partner path, once the team ticks "checked" on the row in C14). Rewards (S22) shows it as "₹200 · <hostel> verified · paid by UPI on the 5th"; console › Payments (C2) lists payouts due with the adder's UPI id (asked once in S93 after the owner agrees) |

Rules (hub decisions, money ones marked ₹ for the founder to change later):
- ₹ **₹200** per hostel added by a resident, paid once, when the hostel goes `live`; **₹20** per partner-listed hostel after the team check.
- ₹ Monthly cap for these two together: **₹2,000** (10 hostels). Beyond the cap the reward is queued for next month and S93 says so honestly.
- One resident can have one hostel "in progress" at a time; a partner any number. No reward for duplicates or for a hostel the team removes.
- Owner never answers: after 60 days the card stays UNVERIFIED, the steps stop at "Owner asked", no payout (S93 says "Still waiting. You can ask again").
- Owner's phone is never shown to anyone but the team (contact rule of F26 #7 stands).
- Entry points: Explore "Can't find your PG? **Add it**" row at the end of the list and in the empty state (T? exploreEmpty); Me (S79) row **Add a hostel** (or **Your hostel** → S93 when one exists); resident My stay empty state T20 "Your stay isn't on Hostelzy yet" → **Add my hostel**.
- Partners: table `partners` (code, name, phone, upi, active); the team makes codes in the console (C14 gets a **Partners** segment: add partner, list, listed count, ₹ due). A partner code is typed once in S92 and remembered on the device.

## Part 3 · Finding hostels at scale (28-20, 28-21, 28-50, 28-60, 28-80, wave 3)
| # | Piece | What |
|---|---|---|
| 28-20 | **Places import** `tools/import/places.mjs` | For each area in `tools/import/areas.json` (~25 Hyderabad areas with a centre and radius) run Places API (New) Text Search for "PG hostel", "paying guest", "hostel for men", "hostel for women"; dedupe by `place_id` and by name+150 m against `hostels`; insert `hostels` rows as **`status = 'draft'`, `source = 'places'`**, `place_id`, name, pin, area, phone, up to 3 photo URLs, `source_seen_at`. Needs `GOOGLE_PLACES_KEY` (GitHub secret, founder one-time; without it the workflow prints "No key yet" and exits 0). Stores only what Google allows long-term (place_id for ever; the rest is refreshed every 30 days by the same job and dropped if the place is gone) |
| 28-80 | **OSM import** `tools/import/osm.mjs` | Overpass query for `tourism=hostel`, `amenity=dormitory`, `building=dormitory` in Hyderabad; same draft rows with `source = 'osm'`; credit line "Map data © OpenStreetMap contributors" in the console footer |
| | Workflow `.github/workflows/import-hostels.yml` | `workflow_dispatch` + monthly; runs both scripts with `SUPABASE_DB_URL` (same secret as the SQL autorun). Never prints keys |
| 28-21 | **Console › Listed › To call** segment (C14) | Drafts from Places/OSM/web: name, area, phone (tap to call), the call script (6 lines: who we are, free listing, rent range, men/women, food, "want to be verified?"), fields rent range + For + Food, buttons **List** (→ `listed`, `rent_confirmed_at = now()`), **Not a PG / Closed** (→ removed), **Call later**. **Export CSV** (name, phone, area, id) for the founder's WhatsApp run |
| 28-50 | **Owner self-serve** web page **W8 `app/list/`** | "List your PG on Hostelzy, free": hostel name, your name, phone, area, rent from–to, For, Food, 1–3 photos → RPC `self_list_request` (anon, max 3 per phone per day) → draft with `source = 'web'` → To call. Page says "We'll call you within 2 days to confirm" (honest; no "Listed!"). **W9 `app/list/poster.html`**: printable A4/A5 poster with the QR to W8, red headline "Get tenants from Hostelzy. Free listing.", for tea stalls, gates, Xerox shops |
| 28-60 | **WhatsApp sender** `tools/outreach/send.mjs` (founder runs it) | Reads the CSV from C14, sends one personalised message per number through `whatsapp-web.js` from a **separate SIM**: QR login, warm-up note, ≤ 25 messages/hour with random 60–180 s gaps, ≤ 150/day, skips numbers already messaged (local `sent.json`), stops on any reply (the founder answers by hand), text: "Hi, this is <founder> from Hostelzy, a free app where tenants find PGs in Hyderabad. <Hostel> is listed as unverified. Reply 1 to add your rent and get verified, 2 to remove it. – Hostelzy" with "Reply STOP to never hear from us". README with the limits and the ban risk in plain words. Not in the app; not counted |

## Part 4 · Keep it honest over time (28-90, wave 4)
| Piece | What |
|---|---|
| `rent_confirmed_at` | Set when a human confirmed the rent (List button, Add a hostel, owner claim with rent, console "Rent confirmed today") |
| App | A listed hostel shows its rent range only when `rent_confirmed_at` is within **60 days**; else **"Rent on request"** and the card sorts after priced ones |
| Console | C14 segment **To refresh**: listed hostels past 50 days, Export CSV (the founder's monthly "Still running? Rent same?" WhatsApp run), per row **Rent confirmed today** / **Closed** |
| pg_cron | Nightly: nothing to compute; the 60-day rule is a view. Weekly: drafts from Places older than 30 days are re-fetched by the import workflow (above) |

## Screens
| Id | Screen | Notes |
|---|---|---|
| H1 `search` (changed) | Verified only switch | — |
| S8 `explore`, S9 `map` (changed) | Order and filter | Explore end-of-list row "Can't find your PG? Add it" |
| **S92** `addHostel` (new) | Add a hostel | light + dark; partner variant (range + code) |
| **S93** `myAdd` (new) | Your hostel on Hostelzy | 5 steps; variants: Owner asked / Owner agreed / Verified / Paid / Still waiting (60 days) / Queued (cap) |
| S79 `me` (changed) | Add a hostel / Your hostel row | — |
| T20 (S89 empty) (changed) | Add my hostel button | — |
| S22 `rewards` (variant) | ₹200 / ₹20 rows | — |
| C14 `#listed` (changed) | Segments: Listed · To call · To refresh · Partners; Export CSV | console view, variants |
| C15 `#claims` (variant) | "added by Ravi (resident)" line | — |
| **W8** `app/list/` (new web page) | List your PG | + sent state (variant) |
| **W9** `app/list/poster.html` (new web page) | Poster with QR | A4 and A5 |

## Server
Migration `f28_add_hostels.sql` (rerun-safe): `hostels.source` (team|resident|partner|places|osm|web), `added_by`,
`place_id`, `source_seen_at`, `rent_confirmed_at`, `owner_phone_hint` (team-only column, RLS), `partners`,
`self_list_requests` (anon RPC with rate limit), `add_hostel(...)` RPC (signed in; dedupe; one in-progress per resident),
`my_added_hostel()`, `set_adder_upi(upi)`, reward kinds `hostel_added` (₹200) / `hostel_listed` (₹20) with the ₹2,000
monthly cap in `reward_ledger` (queued rows carry `pay_month`), console RPCs `list_draft(id, rent_min, rent_max, gender,
food)`, `draft_not_pg(id)`, `rent_confirmed(id)`, `new_partner(...)`, view `listed_rent_visible`. Bundles regenerated;
ships with the SQL autorun. FOUNDER-TODO one-time: `GOOGLE_PLACES_KEY` secret (needs the card) — the app works without it.

## Build notes
- Wave 1: Part 1. Wave 2: Part 2 (S92, S93, entry points, rewards, C14 Partners, C15 line). Wave 3: Part 3. Wave 4: Part 4.
- Demo (sample data): one hostel "added by you" at step "Owner asked", one partner code `HZ-PART-1`.
- SCREENS: +2 screens (S92, S93), +2 web pages (W8, W9). Changed H1, S8, S9, S79, T20, S22, C14, C15.

## Not in the spec
Build lists extras here; the hub decides within the day. Kept out on purpose: OCR of rent from photos, scraping of any
site, auto-rent from portals, tenants adding reviews for a hostel they added, college ambassadors (28-91, later).

## Design
Boards S92 (+ partner variant), S93 (+ 5 state variants), W8 (+ sent), W9, H1 with the switch, S8 with the end row,
S79 row, T20 button, S22 variant, C14 segments (To call, To refresh, Partners), C15 variant. Light + dark for S92, S93.

## Build (wave 3 · Build 3, 2026-10-18, branch `feature/w3-import`, not merged: the original Build chat integrates waves 0→4)
Items 28-20, 28-21, 28-50, 28-80, the whole console side of F28 (C14 segments, C15 line) and the Part 4 console segment. Handover: `docs/handover/w3-build.md`.

| Piece | Where | State |
|---|---|---|
| 28-20 Places import | `tools/import/places.mjs` (+ `lib.mjs`, `areas.json` 32 areas, `package.json`, `test.mjs`) | Built. Text Search (New) for the 4 terms per area, drafts `status='draft', source='places'`, dedupe by `place_id` and by name within 150 m, refresh after 30 days, gone → dropped. "No key yet" exit 0 |
| 28-80 OSM import | `tools/import/osm.mjs` | Built. Overpass `tourism=hostel`, `amenity=dormitory`, `building=dormitory` in the Hyderabad box; `source='osm'`, `place_id='osm:n…'`; credit line in the console footer |
| Workflow | `.github/workflows/import-hostels.yml` | Built. `workflow_dispatch` + monthly (1st, 08:47 IST); plain message and exit 0 without `SUPABASE_DB_URL` / `GOOGLE_PLACES_KEY` |
| 28-21 C14 segments | `app/console/console.js` (`listed`), `logic.js`, `console.css` | Built: **Listed · To call · To refresh · Partners**. To call: call script (6 lines), rent + For + Food, List / Not a PG / Closed / Call later, owner's web photos, Export CSV `name,phone,area,id`. To refresh: > 50 days, Export CSV, Rent confirmed today / Closed. Partners: add partner → `new_partner`, list from `partners_due()` (Build 2's SQL; honest message until it exists) |
| C15 line | `app/console/console.js` (`claims`) | Built: "added by Ravi (resident) · owner phone matches ✓/✗" from `claim_adders()` |
| 28-50 W9 | `app/list/index.html` (+ `mark.svg`) | Built: form → photos to the private `self-list` bucket → `self_list_request` → "We'll call you within 2 days" (sent state). No "Listed!" |
| 28-50 W10 | `app/list/poster.html` | Built: A4 / A5 toggle, print, QR to W9, red headline "Get tenants from Hostelzy. Free listing.", Archivo, brand mark |
| SQL | `supabase/migrations/20261018120000_f28_import.sql`, test `supabase/tests/f28_import_test.sql` | Built, rerun-safe: the 6 `hostels` columns (`add column if not exists`, same as Build 2), `self_list_requests`, `self_list_request()` (anon, 3 per phone a day), `list_draft`, `draft_not_pg`, `rent_confirmed`, `call_later`, `call_list()`, `claim_adders()`, `hostel_owner_phone()`, view `listed_rent_visible` (60 days) |
| Checks | `tools/check.sh` | Green on the branch (analyze, Flutter tests, SQL incl. F28, 25 function tests incl. `import.test.ts`); `tools/import/test.mjs` 3/3 against the local DB. SQL bundle **not** regenerated (integrator) |

### Not in the spec (wave 3, for the hub)
1. **`hostels.removed_at`**: "Not a PG / Closed" needs a mark; the row stays (status `draft`) so the import never re-adds the same `place_id`. **`hostels.call_after`**: "Call later" puts the row last for 3 days. **`hostels.source_photos`**: Google photo *names* (the media URL needs the key), up to 3, team-only in meaning.
2. **The owner's phone stays team-only by a trigger**, not column RLS (Postgres has none): `owner_phone_hint` stays on a row only while it is a draft (invisible to the public); on `listed`/`live` the trigger moves it to `hostel_leads.owner_phone` and blanks the column. `hostel_owner_phone(h)` (definer-only) reads either. **Build 2's `add_hostel` phone dedupe must use `hostel_owner_phone()` or check `hostel_leads` too.**
3. `list_draft` needs **no photo** (Places/OSM drafts have none in our bucket); the team adds one later in Listed. `list_hostel` (F26) still needs one.
4. Web-form photos go to a new private bucket **`self-list`** (anon may upload `web/<uuid>/n.jpg`, team reads via signed URLs); they are not copied into `hostel_photos`.
5. Web-form dedupe = same name + same area (no pin on the web); a duplicate request points at the existing hostel, no second row. Phone must be an Indian mobile (6–9 start).
6. Import gender from the name (women/ladies/girls → Women, co-living → Co-living, else Men); the call confirms. Hotels/lodges/resorts skipped unless the name says PG/hostel. Area = nearest `areas.json` centre.
7. A gone Google place that is already `listed`/`live` keeps its row (a human confirmed it) and loses only the Google fields; only drafts are deleted.
8. Partners segment calls Build 2's `new_partner(p_name, p_phone, p_upi)` → code and `partners_due()` → `(code, name, phone, upi, active, listed, due)`; the integrator aligns the names.
9. The Listed segment no longer shows import/web drafts (they live in To call) nor removed rows.
10. **F31 Rule A applied** (hub message, 2026-10-18): no helper sentences in C14/C15, W9, W10; the F26 Listed aside's two grey lines and the Claims "says they own it" sentence went too (see `docs/handover/w3-build.md` §7).
11. The import connects with `SUPABASE_DB_URL` over TLS without certificate verification (`rejectUnauthorized: false`), like `psql sslmode=require`.
