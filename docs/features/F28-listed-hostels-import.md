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
| 28-50 | **Owner self-serve** web page **W9 `app/list/`** | "List your PG on Hostelzy, free": hostel name, your name, phone, area, rent from–to, For, Food, 1–3 photos → RPC `self_list_request` (anon, max 3 per phone per day) → draft with `source = 'web'` → To call. Page says "We'll call you within 2 days to confirm" (honest; no "Listed!"). **W10 `app/list/poster.html`**: printable A4/A5 poster with the QR to W8, red headline "Get tenants from Hostelzy. Free listing.", for tea stalls, gates, Xerox shops |
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
| **W9** `app/list/` (new web page) | List your PG | + sent state (variant) |
| **W10** `app/list/poster.html` (new web page) | Poster with QR | A4 and A5 |

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
- SCREENS: +2 screens (S92, S93), +2 web pages (W9, W10; W8 is already app/delete-account). Changed H1, S8, S9, S79, T20, S22, C14, C15.
- **28-60 built early (Build 1, 2026-10-18):** `tools/outreach/send.mjs` (whatsapp-web.js 1.34.7 pinned, QR login with
  `LocalAuth`, ≤ 25/hour with random 60–180 s gaps, ≤ 150/day, `sent.json` never-twice record incl. numbers not on
  WhatsApp, stops on the first reply from a messaged number, "STOP" marks the number final, `--dry` prints without sending),
  the pure rules in `tools/outreach/lib.mjs` (tested by `supabase/functions/tests/outreach.test.ts`: message word for
  word, CSV parsing, limits, gaps, never twice, STOP), `tools/outreach/README.md` (limits, the ban risk in plain words,
  separate SIM, how to run). The CSV comes from C14 › To call › Export CSV (wave 3); until then any CSV with
  name, phone, area, id columns works. Not in the app; not counted.

## Build · Part 1 (wave 1, branch `feature/w1-filter-wall-contacts`, PR #W1, 2026-10-18)
- **H1 switch** `features/explore/explore_sheets.dart` (`SearchSheet`): **Verified only** under Food included (key
  `verifiedToggle`), the same switch as Food included; field `fVerified` (`features/reviews/reviews.dart`), counted in
  `filterCount` and reset by `clearFilters` (`features/session/guest.dart`); "Show N hostels" follows it.
- **S8 order** `features/explore/explore_screen.dart`: `filtered()` drops listed hostels when the switch is on;
  `listingTierStep` → `tierCompare(…, byPrice: false)`: every verified hostel first, then the UNVERIFIED ones, each tier in the
  picked sort (the F26 #21 ₹2,000-band interleave under Price ↑ is gone; `priceBand` / `byPrice` stay in
  `features/listings/tiers.dart`, Explore no longer uses them). The header's `tierLine` is unchanged.
- **S9 pins** `features/map/map_screen.dart`: the pins already come from `filtered()`, so the switch applies; each pin got a
  key `pin-<id>` for the test.
- **Tests** `hostelzy/test/f28_verified_filter_test.dart` (3): the switch (position, default, count, hidden cards, header,
  Clear all); verified first then listed in every sort (price order inside the verified tier, nearest, rating); the pins.
  Updated: `f26_holds_listings_test` (#21: the band asserts → tier first), `f26_tenant_test` (#2: the pinned candidate is the
  last verified hostel, the listed one is last now). No SQL.

## Not in the spec
- Console (integration, hub's ask): C2 **Payouts due** sits above the owner invoices; **Paid** takes a 12-digit UTR ("Enter the 12-digit UTR."); C14 Partners shows each partner's hostels under their row (Checked ✓ → "Checked. ₹20 due."). decided.
- Part 1: the pin key `pin-<id>` (test hook only). `priceBand` kept in place (no removals). decided.
- Build lists extras here; the hub decides within the day. Kept out on purpose: OCR of rent from photos, scraping of any
site, auto-rent from portals, tenants adding reviews for a hostel they added, college ambassadors (28-91, later).

**Part 4, decided by Build 4 (2026-10-18, wave 4):**
| # | What Build 4 did | Why |
|---|---|---|
| 1 | The demo's listed sample hostel (Sri Balaji) counts as **confirmed today**, so the demo APK shows a range; the "Rent on request" state is covered by the flow test | Sample data only; no second sample hostel was added |
| 2 | ~~Card "Rent on request · not confirmed lately"; page with a sentence~~ → **hub (F31 Rule A):** the card says only **"Rent on request"**; the page says "Rent on request" plus the button **Ask on WhatsApp** (the existing Ask Hostelzy number), no sentence | Hub decision, 2026-10-18 |
| 3 | A stale listed hostel still answers the **Budget filter** by its old range (unchanged), and under Price ↑ it sorts after every priced card (fresh listed ones included), then by its old range among the stale ones | The number is kept back from the tenant, not thrown away |
| 4 | The app **reads the server's view `listed_rent_visible`** (Build 3) when it exists: a listed hostel the view hides the rent of is treated as never confirmed (the server's clock decides); before the view exists the app applies the same 60-day rule to `rent_confirmed_at` itself | Hub, 2026-10-18 |

## Design
**Design approved** (Design, 2026-10-18). Canvas v25 on branch `design/f26-merge` (`docs/design/v25/`, hub publishes). Note: the hub later assigned these boards to Design 2 (`design/f28-boards`); the set below already exists, see `docs/design/main-canvas/README.md` § v25.
- **[S92]** addHostel light + dark: name, gate photo (1–3), pin (drag to fix, area from the pin), For, "What do you pay? · ₹/month", Sharing 1/2/3/4+, Food included, Owner's name + phone (required), I live here / I'm a Hostelzy partner, Add. [variant] partner: rent from–to + partner code.
- **[S93]** myAdd light + dark: the card as tenants see it (UNVERIFIED, "Around ₹7,000/mo · expected, not confirmed"), the 5 steps Added ✓ → Owner asked → Owner agreed → Verified → ₹200 paid, Send to your owner (red), the honest line. Variants: Owner asked (Ask again · from 21 Oct), Owner agreed (UPI id + Save), Verified (₹200 on the 5th), Paid (green chip), Still waiting (60 days: "Still waiting. You can ask again."), Queued (monthly cap: "₹200 queued for 5 Dec").
- H1 Filters: **Verified only** switch under Food included. S8: [variant] end of the list "Can't find your PG? Add it"; verified cards already sort before listed ones. T4 exploreEmpty: "Can't find your PG? Add it ›". S79 Me: **Add a hostel** row first (Rule B), [variant] "Your hostel · Sri Balaji Men's PG · Owner asked". T20: "Your stay isn't on Hostelzy yet" + **Add my hostel**. [variant of S22] Rewards: "₹200 · Sri Balaji Men's PG verified · paid by UPI on the 5th", "₹20 · Lakshmi Ladies Hostel listed (partner) · after the team check".
- **Web:** `app/list/` form + sent state, A4 poster "Get tenants from Hostelzy. Free listing." with the QR. **Ids on the canvas: W9 = app/list/, W10 = poster**, because W8 is already `app/delete-account/` there (Design numbered the two web states W3/W5 on 2026-10-03). Hub to settle: change the spec's W8/W9, or realign web ids to the SCREENS table.
- **Console:** C14 Listed gets the segments Listed · To call · To refresh · Partners; [variants] To call (drafts with phone, the 6-line call script, rent from–to, For, Food, List / Not a PG · Closed / Call later, Export CSV, OSM credit), To refresh (past 50 days, Rent confirmed today / Closed, Export CSV), Partners (add partner with code, list, listed count, ₹ due). [variant of C15] Claims: "added by Ravi (resident) · owner phone matches ✓ / ✗".
Rule A (F31) applied: no helper lines. Not drawn: S9 map pins with the switch (screenshot boards).


## Id fix (hub, 2026-10-18 15:50)
W8 was already `app/delete-account/` in SCREENS §5. The owner self-serve page is **W9** and the poster **W10** everywhere (spec, boards, SCREENS).

## Hub decisions on Build 3's "Not in the spec" (2026-10-18 15:55)
| # | Item | Decision |
|---|---|---|
| 1 | `removed_at`, `call_after`, `source_photos` columns | ✅ Keep |
| 2 | Owner phone moved to `hostel_leads` by trigger; `hostel_owner_phone(h)` | ✅ Keep; Build 2 dedupes through it |
| 3 | `list_draft` needs no photo | ✅ Keep; the card shows the Places photo or the neutral placeholder; `list_hostel` (F26) unchanged |
| 4 | Private `self-list` bucket for web photos | ✅ Keep (3 files, ≤ 5 MB, images only; team copies into hostel photos when listing) |
| 5 | Web dedupe by name + area; Indian mobile check | ✅ Keep |
| 6 | Gender from the name, hotels/lodges skipped, nearest area | ✅ Keep as a hint; the call confirms |
| 7 | A gone Google place keeps a listed/live row | ✅ Keep |
| 8 | Partner RPC names | ✅ Build 2 defines exactly `new_partner(p_name, p_phone, p_upi)` and `partners_due()` |
| 9 | Drafts and removed rows hidden from Listed | ✅ Keep |
| 10 | F31 Rule A applied | ✅ |
| 11 | TLS **without** certificate verification for the DB connection | ❌ Change: verify the certificate by default (Node's CA store + Supabase's CA; the pooler presents a public cert). `PGSSL_NO_VERIFY=1` is an explicit opt-out for local tests only, and the script prints one line when it is on |

## Hub decisions on Build 4's Part 4 extras (2026-10-18 20:45)
| # | Decision |
|---|---|
| 1 | ✅ Demo's listed sample counts as confirmed today |
| 2 | ❌ Change (F31 Rule A): card says **"Rent on request"** only; hostel page says **"Rent on request"** + the button **"Ask on WhatsApp"**, no sentence |
| 3 | ✅ Stale rent still answers the Budget filter; sorts after priced cards |
| 4 | ✅ App reads `listed_rent_visible`, falls back to the 60-day rule |

## Hub decisions on Build 2's wave 2 extras (2026-10-18 20:50)
F28 #1–4, #6–9 accepted as built (partner_code, owner_asked_at, `reward_payouts` + `payouts_due()` + `mark_payout_paid()`,
`check_partner_hostel(h)` (integrator wires it to the C14 Partners "checked" tick and lists `payouts_due()` in console
Payments), adder photos, adder-only owner phone, S22 row, Rule A, no Realtime for these tables).
#5 accepted with one copy change (Rule A): the partner line in S93 reads **"₹20 when checked"**.

## Build (wave 3 · Build 3, 2026-10-18, branch `feature/w3-import`, not merged: the original Build chat integrates waves 0→4)
Merged to `main` (#155, 2026-10-18), with waves 2–5 on `integration/w2-5`.

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
11. ~~TLS without certificate verification~~ → **hub: verify by default.** Done: Node's CA store, optional `tools/import/supabase-ca.pem` for a direct host, `PGSSL_NO_VERIFY=1` the only opt-out (local tests, prints one line). Items 1–10 accepted by the hub (2026-10-18).

## Build (wave 2 · Build 2, 2026-10-18, branch `feature/w2-add-join`, not merged: the original Build chat integrates waves 0→4)
Part 2 in the app and its SQL (28-30, 28-31, 28-40). Console pieces (C14 Partners segment, C15 line) are Build 3's; they call
the RPC names below. Handover: `docs/handover/w2-build.md`.

| Piece | Where | State |
|---|---|---|
| **S92** `addHostel` | `hostelzy/lib/features/add_hostel/add_hostel_screens.dart` (`AddPgScreen`), state `add_hostel.dart` | Built. Name · gate photos 1–3 (camera / gallery, `cameraPick`) · pin on the team's map (aPin in `pinFor = 'add'` mode, area read off the pin) · For · "What do you pay? ₹ a month" (partner: from–to) · Sharing 1/2/3/4+ · Food · Owner's name + phone · "I live here" / "I'm a Hostelzy partner" + code (remembered on the phone, `partnerCode` in the snapshot) · **Add**. Dedupe box "Already on Hostelzy: X. Ask your owner to verify it instead." with **Share the link with your owner**. Rule A (F31): no helper lines |
| **S93** `myAdd` | same files (`MyAddScreen`) | Built. The listed card (photo · name + UNVERIFIED / ✓ VERIFIED · gender · area · rent range), 5 steps **Added ✓ → Owner asked → Owner agreed → Verified → ₹200 paid** (states only), **Send to your owner** (WhatsApp from the adder's phone: "Your PG X is on Hostelzy. Agree to get it verified (free): `app/r/?h=<id>&claim=1`"), **Ask again** after 3 days ("Sent 18 Oct · ask again in N days" before), UPI id box after the owner agrees (`set_adder_upi`), the honest line "Paid only when the owner agrees and Hostelzy verifies the hostel." Variants: Still waiting (60 days) · Queued (cap, `pay_month`) · Paid · Removed · empty ("No hostel added yet" + Add a hostel) |
| Entry points | `explore_screen.dart` (`AddItRow` after the cards and in the empty state), `me_screen.dart` (**Add a hostel** · `₹200 when verified`, or **Your hostel** · `<name> · owner asked`), `resident_screens.dart` T20 (**Add my hostel** / **Your hostel on Hostelzy**) | Built. Guests get "Sign in to add a hostel" (`afterSignIn = 'add'`) |
| Claim link | `router.dart` (`/r?h=<id>&claim=1` → `openClaimLink`), `app/r/index.html` (opens the app) | Built: the UNVERIFIED page (T32) with H47 Claim pre-opened; submitting = owner agreed |
| S22 variant | `rewards_screens.dart` (`addReward` row) | Built: "₹200 · <hostel> verified · Paid by UPI on the 5th" / "Queued for <Month> · monthly cap" / "Paid 5 Nov by UPI" (from `my_added_hostel()`) |
| SQL | `supabase/migrations/20261018100000_f28_add_hostels.sql`, test `supabase/tests/f28_add_hostels_test.sql` | Built, rerun-safe (twice on one DB). `hostels.source/added_by/place_id/source_seen_at/rent_confirmed_at/owner_phone_hint` (+ `partner_code`, `owner_asked_at`), `partners`, `new_partner(p_name, p_phone, p_upi) → code`, `partners_due()`, `add_hostel(p) → {duplicate, hostel_id, name}` (dedupe: `hostel_owner_phone(h)` = typed phone, or same normalised name within 150 m; one in-progress per resident), `my_added_hostel()`, `asked_owner(h)`, `set_adder_upi(upi)`, `is_adder(h)` + photo policies (adder: ≤ 3 gate photos), reward kinds `hostel_added` ₹200 (trigger on `hostels.status → live`, push to the adder) / `hostel_listed` ₹20 (`check_partner_hostel(h)`, team), `reward_ledger.pay_month` with the ₹2,000 cap (`reward_cap_month`), `reward_payouts` + `payouts_due()` / `mark_payout_paid(ledger_id, utr)` (console › Payments), `profiles.payout_upi`. `hostel_owner_phone(h)` is a stub with Build 3's body (theirs runs after and wins) |
| Demo | `add_hostel.dart` (`myAdd` seed), `demoPartnerCode` | "Sri Balaji Men's PG" shows as added by you at **Owner asked**; partner code `HZ-PART-1` works; dedupe runs against the sample hostels |
| Tests | `hostelzy/test/w2_add_join_test.dart` (F28 group, 4 flows) | Green |
| Checks | `tools/check.sh` | See `docs/handover/w2-build.md` §6 |

### Not in the spec (wave 2, F28, for the hub)
1. **`hostels.partner_code`** (which partner listed it) and **`hostels.owner_asked_at`** ("Owner asked" step and the 3-day "Ask again"), two columns the spec's list doesn't name. The owner's phone itself is **not** on `hostels` (`owner_phone_hint` stays `''`): it goes straight to the team-only `hostel_leads.owner_phone`, in line with Build 3's trigger.
2. **Payout record**: `reward_payouts` + `payouts_due()` + `mark_payout_paid()` so "₹200 paid" (step 5) and the console's payouts list are real, not a promise. The ledger stays append-only.
3. **`check_partner_hostel(h)`** (team): the C14 "checked" tick that grants the ₹20. Build 3's Partners segment can call it; until then the team runs it in SQL.
4. The adder's own gate photos go to `hostel_photos` through two new policies (adder of a listed hostel, ≤ 3); `add_hostel` makes the row `listed` without a photo (the photos follow a moment later), unlike `list_hostel` which needs one first.
5. S93 for a **partner** reuses the same 5 steps; its reward line reads "₹20 when checked" (hub copy). The Me row / S93 show the **latest** hostel only (partners with many listed see the newest).
6. `my_added_hostel()` returns the owner's phone **to the adder only** (they typed it), so "Send to your owner" works after a reinstall. Nobody else ever gets it.
7. The reward row in S22 comes from the same `my_added_hostel()` call (no change to the `Rewards` record / live rows).
8. **Rule A (F31, hub message)** applied to S92 and S93: no helper lines; step subtitles are dates/states; toasts ≤ 6 words. The spec's honest line in S93 is kept as the one state sentence.
9. `join_requests` / `add_hostel` are **not** in the Realtime publication (the F26 RLS test pins the publication's table list); S93 and Today reload when opened and after each action.

## Build · Part 4, app side (wave 4, Build 4, 2026-10-18)
Branch `feature/w4-drive-fresh`, not merged (`docs/handover/w4-build.md`). Console "To refresh" is Build 3's.
| Piece | Where | State |
|---|---|---|
| `hostels.rent_confirmed_at` (`add column if not exists`, same as wave 2/3) | `supabase/migrations/20261018140000_f29_drive.sql` (+ a row in its SQL test) | Done |
| `Hostel.rentConfirmedAt` from the row; `rentFresh` (60 days), `rentLine`, `rentFreshCompare`; `SupabaseRepo.listings()` overlays the view `listed_rent_visible` (`rent_visible = false` → stale) | `hostelzy/lib/data/hostels.dart`, `features/listings/rows.dart`, `features/listings/tiers.dart`, `supabase_repo.dart` | Done |
| Explore card and T32 page say **"Rent on request"** after 60 days; the card sorts after every priced one (first sort step) | `features/explore/unverified_screen.dart`, `explore_screen.dart` | Done |
| Tests | `hostelzy/test/w4_drive_test.dart` (28-90 unit + flow) | Green |
