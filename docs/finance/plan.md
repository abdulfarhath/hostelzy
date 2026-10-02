# Hostelzy money & growth plan (v1)

Owned by the **Hostelzy · Finance & Growth** chat. Written 2026-10-02.
Reads with: `docs/DECISIONS.md` (prices, rewards), `docs/marketing/README.md` (what to post, where).
This file does **not** change any amount in DECISIONS. Items marked **PROPOSED** wait for the founder's yes.

Rates used: $1 ≈ ₹95 (Sept 2026). Foreign tools add 18% GST + ~3.5% card fee, so $25 ≈ ₹2,900.

---

## 0. Open questions for the founder (answer in the Finance chat)

| # | Question | My default if you don't answer |
|---|---|---|
| Q1 | Is the ₹30,000 **after** your personal costs, or do personal costs come out of it? | Plan below spends ₹25,000 max and leaves ₹5,000 for you. |
| Q2 | Rewards cap **₹5,000/month** (see §6)? | PROPOSED, not live until you say yes. |
| Q3 | Founding-20 offer: Marketing README says "3 months free, then ₹299 for life". DECISIONS says 30-day trial, ₹499/₹999/₹1,499. Which one? | DECISIONS wins. See §4 for why. |
| Q4 | Marketing's guarantee "No enquiry in 30 days → you never pay"? It's open-ended. Safer: "No enquiry during your 30-day trial → your next month is free too" (costs at most one month, ~₹750 per hostel). | Not promised to anyone until you say yes. |

---

## 1. Monthly budget

### The split (from Month 2, steady state)

| Bucket | Cap / month | Expected spend | Notes |
|---|---|---|---|
| Tech | ₹5,000 | ~₹3,000 | Unused part goes to the reserve |
| Rewards (Hostelzy-paid) | ₹5,000 **PROPOSED** | ₹0–5,000 | Hard cap, §6 |
| Sales commissions (partner / ambassadors) | ₹6,000 | grows with paid owners | Only paid when an owner pays, §3 |
| Print: QR posters, stickers, standees | ₹3,000 | ₹2,000–3,000 | Only on hostels that joined |
| Travel + tea for owner visits | ₹2,500 | ₹2,500 | Metro/petrol, chai with owners |
| Instagram boosts (test only) | ₹2,000 | ₹0–2,000 | Only boost a reel that already did well for free |
| Buffer (marketing) | ₹1,500 | — | Moves to reserve if unused |
| **Total Hostelzy** | **₹25,000** | | |
| You (personal) | ₹5,000 | | Q1 may change this |

**Reserve rule:** all unused money goes to a "Hostelzy reserve" until it holds **₹30,000** (one month of runway). Don't spend the reserve on ads.

### Tech: real tools and costs

| Tool | Plan | Cost | When |
|---|---|---|---|
| Supabase (database, Mumbai) | Free | ₹0 | Now, while only owners use it |
| Supabase | **Pro $25/mo** (includes $10 compute = 1 Micro server) | **~₹2,900/mo** | From tenant launch (Month 2). Free plan has no backups and pauses idle projects. |
| Firebase (Google login, push, crash reports) | Spark (free) | ₹0 | Now. Blaze not needed (and your card failed on it). |
| Google Play Console | One time $25 | **~₹2,400 once** | Month 1. Needs an international card. New personal accounts must run a **closed test with 12 testers for 14 days** before going public, so start in week 1. |
| Domain | farhath.me (already yours) | ₹0 | Now |
| `.in` domain (e.g. hostelzy.in) | Optional | ~₹600–900/yr ≈ ₹75/mo | Only after the app name is final (Brand chat) |
| Map | OpenStreetMap tiles (now) | ₹0 | Testing only; OSM forbids heavy app traffic |
| Map at launch | Google Maps SDK for Android | ₹0 for map display (unlimited); search/geocoding free up to 10,000 calls/mo | Needs a Google billing account (card). Set a ₹500 budget alert. |
| WhatsApp Business **app** | Free | ₹0 | Use the app, **not** the paid WhatsApp API |
| GitHub Actions (APK builds) | Free tier | ₹0 | Check minutes if the repo is private |
| Google Sheets / Drive | Free | ₹0 | Money tracker, invoices folder |
| **Tech total** | | **~₹2,900/mo + ₹2,400 once** | Well under ₹5,000 |

---

## 2. First 90 days

| | Month 1 (Oct) | Month 2 (Nov) | Month 3 (Dec) |
|---|---|---|---|
| **Focus** | Owners: 20 founding hostels | Tenants: launch in 2 areas | Convert + repeat |
| **Areas** | Ameerpet, SR Nagar first; then Madhapur, Hitec City, Kondapur, Gachibowli | Same | Add 1 area only if 70%+ of Month-1 owners stayed |
| Hostels live (on trial or paid) | **20** | 30 | 45 |
| Beds listed | ~800 (20 × ~40) | ~1,200 | ~1,800 |
| Tenants signed up | 300 waitlist | 1,000 | 2,500 |
| Holds | 20 (first tests) | 150 | 400 |
| Paid owners | 0 (all on 30-day trial) | **10** (half of Month 1 convert) | **25** |
| Owner revenue | ₹0 | ~₹7,500 | ~₹19,000 |
| Rewards spent | ₹0 | ₹1,000 | ₹3,000–5,000 |
| Tech | ₹2,400 (Play) | ₹2,900 | ₹2,900 |

These are **targets, not promises**. If Month 2 paid owners < 6, stop adding areas and find out why (call every owner who didn't pay).

### Month 1 week by week (owners)

| Week | Do | Done when |
|---|---|---|
| 1 | Play Console account + start closed test (12 testers). Open a separate bank account (§5). Make the money sheet. List 60 hostels in Ameerpet/SR Nagar to visit. | Account paid, sheet exists |
| 2 | Visit 15 hostels a week (3 a day, after work). Onboard on the spot with the Add hostel tool. | 5 hostels live |
| 3 | Same, plus Madhapur/Hitec City. Put QR posters in every joined hostel. | 12 live |
| 4 | Kondapur/Gachibowli. Ask each owner for one owner friend. | 20 live |

Content for posts, reels and posters: Marketing chat (`docs/marketing/`).

---

## 3. Getting marketing done for free or cheap (honest)

**Is free marketing realistic?** Free in money, **not** free in time. The cheapest channel is you visiting
owners in person; expect 10–15 hours a week. Paid ads before you have hostels in an area are wasted.

| Option | Money | Your effort | Expected result | Verdict |
|---|---|---|---|---|
| You visit owners in person | ₹2,500/mo travel | High | 20 hostels in a month is doable | **Do first** |
| Owners as the channel (QR posters in joined PGs) | ₹100–150 per PG | Low | Every resident sees it daily; best tenant source | **Do** |
| Commission-only sales partner | ₹200 per paid owner | Medium (training) | 5–15 paid owners/mo if they're good | **Do** (ad below) |
| College interns / campus ambassadors, paid per result | ₹20 per hold, ₹200 per paid owner | Medium | Tenants mostly; some owners | **Do** in Month 2 |
| WhatsApp groups (coaching, IT new joiners, college) | ₹0 | Low | Good for tenants; don't spam, get admin OK | **Do** |
| Instagram reels | ₹0 (₹2k boost max) | Medium | Slow start, builds trust | **Do** (Marketing chat) |
| Google Business Profile | ₹0 | Low | People searching "PG near Ameerpet" | **Do** once |
| Local Facebook / Telegram groups, r/hyderabad | ₹0 | Low | Small but free | **Do** |
| College placement cells / hostels offices | ₹0 | Medium | Batch of students moving to Hyderabad | Month 2–3 |
| Co-founder for equity | ₹0 cash, gives up 10–40% | High (finding one) | Biggest help if right person; slow | Look, don't rush (see below) |
| Paid Google/Meta ads | ₹5k+ | Low | Expensive per tenant in Hyderabad | **Not yet** |

**Co-founder:** only someone who has sold to small businesses before. Written founders' agreement,
4-year vesting with a 1-year cliff (they earn shares over time, nothing if they leave in year 1).

### One-page ad: commission-based sales partner / intern

> **Hostelzy is looking for a sales partner in Hyderabad (part-time, commission only)**
>
> Hostelzy is a new app that helps people find PGs and hostels in Ameerpet, SR Nagar, Madhapur,
> Hitec City, Kondapur and Gachibowli. Owners list beds; tenants hold a bed and move in.
>
> **What you do**
> - Visit PG/hostel owners, show the app, help them list their hostel (free 30-day trial).
> - Put up Hostelzy QR posters in hostels that joined (with the owner's OK).
> - Tell students and new joiners about the app.
>
> **What you earn**
> - **₹200** for every owner who pays their first month (paid after we confirm the UPI payment).
> - **₹20** for every tenant hold made with your code (paid monthly, see rules).
> - **₹1,000 bonus** in any month you bring 5 paying owners.
> - Paid by UPI on the 5th of every month. No joining fee. No salary.
>
> **Good fit:** college students, freshers, anyone who knows the area and speaks Telugu/Hindi/English.
> 18+ only.
>
> **Rules:** no fake listings, no fake reviews, no listing a hostel without the owner's OK, no
> pressure or false promises. Breaking these ends the partnership and unpaid commissions.
>
> **Apply:** WhatsApp +91 90597 90014 with your name, college/area and one line on why.

**Pay rules that stop gaming**
- ₹200 only after the owner's first UTR is confirmed. If the owner leaves in month 1 because of a false promise, it's taken back.
- ₹20 per hold only from a **new phone number**, not the partner's own phone/UPI/contacts list, and not if the hold was cancelled within 10 minutes. Max 100 holds per partner per month (₹2,000).
- Commissions capped at **₹6,000/month total** in Month 2–3. Raise it only when paid-owner revenue covers it.

**Legal / ethical basics**
- A short **written agreement** for every partner (WhatsApp-signed PDF is fine): commission-only,
  independent, how and when paid, the rules above, either side can stop anytime.
- When they post about Hostelzy on social media they must say they work with Hostelzy (ASCI rule).
- No fake reviews, listings or numbers, ever (same as `docs/marketing/README.md` ground rules).
- Keep every payout in the money sheet with the UPI reference. When yearly payouts to one person
  get big, ask a CA about TDS.

---

## 4. Unit economics

**Revenue per hostel per month** (assumed mix in our areas):

| Plan | Price | Share of hostels | Weighted |
|---|---|---|---|
| Up to 30 beds | ₹499 | 60% | ₹299 |
| 31–80 beds | ₹999 | 30% | ₹300 |
| 80+ beds | ₹1,499 | 10% | ₹150 |
| **Average** | | | **≈ ₹750** |

Next-stay ₹100 discounts are credited on the owner's invoice, so they lower this a little (counted in the rewards cap).

**Cost to get one customer**

| | Cost | Made of |
|---|---|---|
| One paying owner | **≈ ₹450** | ₹200 commission + ₹150 posters/stickers + ₹100 travel |
| One tenant hold | **≈ ₹20–50** | ₹20 commission (if via partner) + share of posters |
| One tenant who moves in via referral | ₹200 | ₹100 + ₹100 referral (Hostelzy-paid) |

**Payback:** an owner at ₹750/mo pays back their ₹450 cost in under 1 month.

**Break-even (number of paid hostels at ₹750)**

| Covers | Monthly cost | Paid hostels needed |
|---|---|---|
| Tech only | ₹3,000 | **4** |
| Tech + marketing (full ₹25k) | ₹25,000 | **34** |
| Everything incl. the ₹5k for you (₹30k) | ₹30,000 | **40** |

**When does your ₹30k stop being needed?** At **~40 paid hostels**. On the targets above that's
Month 4–5 (Feb 2027) if conversion holds at 50%+. Realistic range: Month 4 to Month 8.

**Why the "₹299 for life" founding offer hurts (Q3):** 20 hostels × ₹299 = ₹6,000/mo forever,
and 3 free months means no revenue until Month 4. Break-even would need ~100 hostels instead of
~40. Better founding perks that cost no cash: "Founding hostel" badge, a featured spot for 3
months, first say on new features. Price stays as in DECISIONS.

---

## 5. Bills & money admin

### Steps (one at a time)
1. Open a **separate savings account** only for Hostelzy (any bank with free UPI; no company needed, DECISIONS says no company/GST at start).
2. Link the Hostelzy UPI ID `9059790014@axl` to that new account (in the UPI app → bank accounts → change primary). Owners' payments then land there.
3. Pay every Hostelzy bill (Supabase, Play, posters, commissions) **from that account only**.
4. Move your monthly ₹25,000 into it on the 1st. Nothing personal goes in or out.
5. Make the Google Sheet below. Update it every Sunday (10 minutes).
6. Save every invoice the app makes (owner plan, F10) as PDF in a Drive folder `Hostelzy/Invoices/2026-10/`. Match each UTR to the bank statement once a month.

### Google Sheet layout ("Hostelzy money")

**Tab 1 · Money in**
| Date | Hostel | Plan | Amount | UTR | Invoice no. | Checked in bank? |
|---|---|---|---|---|---|---|

**Tab 2 · Money out**
| Date | What | Bucket (Tech / Rewards / Commission / Print / Travel / Ads) | Amount | Paid to | UPI ref / bill | Receipt saved? |
|---|---|---|---|---|---|---|

**Tab 3 · Rewards**
| Date | Tenant (masked phone) | Type (referral / next-stay) | Amount | Month total | Under cap? |
|---|---|---|---|---|---|

**Tab 4 · Partners**
| Month | Partner | Paid owners | Holds | Owed | Paid on | UPI ref |
|---|---|---|---|---|---|---|

**Tab 5 · Monthly summary** (formulas)
| Month | In | Out | Profit/loss | Paid hostels | Tech | Rewards | Commission | Reserve balance |
|---|---|---|---|---|---|---|---|---|

### Tax notes (just so you know)
- **GST:** registration is needed once service income passes **₹20 lakh a year** (≈ ₹1.67 lakh/month,
  ≈ 220 paid hostels). Not soon. Talk to a **CA** when revenue reaches ~₹1 lakh/month.
- Income tax: Hostelzy income goes in your own ITR as business income. A CA can do this for ~₹2–5k/yr.

---

## 6. Rewards rules that can't drain money (PROPOSED)

| Rule | Detail |
|---|---|
| **Monthly cap** | **₹5,000/month** total for Hostelzy-paid rewards (referral payouts + next-stay credits) = 25 referrals (₹100 + ₹100) or 50 next-stay discounts |
| First come, first served | Rewards are counted in the order they are earned |
| Cap hit → pause | New rewards that month go on a **waitlist** and are paid first next month. The app says so plainly: "This month's rewards are used up. Yours is #3 for November." Never silently drop a reward someone was promised. |
| Raise the cap | Only when paid-owner revenue ≥ 4× the cap (₹20k revenue → ₹5k cap; ₹40k → ₹10k) |
| Fraud: same phone | One reward per phone number, ever, per type |
| Fraud: same UPI | Referrer and friend can't share a UPI ID; one UPI ID gets max 5 referral payouts a year |
| Fraud: self-referral | Same device / same name+phone pattern → hold for review |
| Fraud: fake move-in | Referral pays only after the friend's **first month** and the owner confirmed the resident (F06) |
| Founder check | Any single person earning > ₹500 in a month → founder looks before paying |

**What Build needs if the founder says yes:** a monthly cap setting, a waitlist state for rewards,
and the plain-words message above. (Finance doesn't write code; the Ideas chat records it and
specs it.)
