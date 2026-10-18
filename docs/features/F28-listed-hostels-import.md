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
- Part 1: the pin key `pin-<id>` (test hook only). `priceBand` kept in place (no removals). decided.
- Build lists extras here; the hub decides within the day. Kept out on purpose: OCR of rent from photos, scraping of any
site, auto-rent from portals, tenants adding reviews for a hostel they added, college ambassadors (28-91, later).

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
