# Brand: name and logo

Owned by the **Hostelzy · Brand** chat. Name first, then logo. Nothing is renamed in the app until
the founder picks a name and says so; then the Ideas chat records it in DECISIONS.md and Build
renames the app.

## What the founder wants (2026-10-02)
**Name**
- A list of possible names, each with **the story behind it**.
- **Simple to say** (Telugu, Hindi, English speakers) and simple to spell.
- **Says what the app is**: finding / holding a bed in a PG or hostel, and trust.
- Ideate and discuss first; the founder decides.

**Logo**
- Must use the **bed-arrangement idea from the app's bed picker / seat map** (rooms as squares,
  beds as small blocks like movie seats; F12 Room tab), so the logo itself shows "pick your bed".
- App look: Archivo font, red `#ec3013`, ink black, square corners, 2px rules; light + dark.
- Must work as a Play Store icon (small), on the login screen and on the A4 resident QR poster.

## Already found (Design chat, 2026-10-02)
Preliminary screen only: the official IP India search is blocked from the cloud environment, so
checks were web searches, app stores, company listings and .com/.app domain checks.
- **Cotkey** (KOT-kee): "cot" is what PG people call a bed; "key" = getting in, trust. Nothing found; .com/.app free.
- **Bedmila** (bed-MILL-aa): "Bed mila!" = "got a bed!". Nothing found; .com/.app free.
- **Cotwise** (KOT-wize): choose your PG wisely. Nothing found; .com/.app free.
- Riskier: Thehro (.com taken), Rehnaa (similar to Rahna Homes), Mancham (Hindi speakers won't get
  it), Holdbed (too descriptive). ~60 others rejected (Basera, Roomly, Nestly, Makaan, Thikana…).
- The Design chat also started 6 logo drafts (2 per name above).

## Before launch
A trademark lawyer runs the official IP India search and files in classes 9, 42, 43 and 36.

## Round 1 name list (Brand chat, 2026-10-02)
14 names with stories, ease of saying and quick checks: `names.md`.
Brand chat's top 3: **Cotkey, Bedpakka, Bedmila**. Waiting for the founder to pick 2–3.

## Founder decision (2026-10-02)
Keep the name **Hostelzy** for now (founder tired of searching). Brand chat warned: **Hostelz.com**
(hostel search site) is one letter away; a trademark lawyer must check before launch.
Ideas chat: please record this in DECISIONS.md.

## Logo
Round 1 concepts: `logo.md` and https://claude.ai/artifact/MQMKQkVhsePEJ755s1Vrq1

## Final logo (founder, 2026-10-02)
**B3-a2 "Room with AC"**. Spec, files and Build steps: `logo.md` (top). Assets: `assets/`.

## Brand pack (Brand chat, 2026-10-03)
- **Brand guide** (one page: logo, colours, type, tone of voice, do/don't):
  https://claude.ai/artifact/29kRWoLpWYYvW9AGuC2jSi · source `guide/brand-guide.html`
  (rebuild: `python3 docs/brand/tools/make_guide.py`).
- **Play Store listing pack**: `play-store.md` + `assets/play-store/` (feature graphic 1024×500,
  8 screenshots 1080×1920 from the real app screens, short + full description; Telugu left for a
  native speaker). ⚠️ Screenshots use sample data: retake with real hostels before the listing goes public.
- **For Build**: `app-assets.md`: new notification icon `ic_stat_hostelzy` (for FCM pushes too) and
  the Android 12+ splash on `#F3F2F2` / `#161514`. Files in `assets/notification/` and `assets/splash/`.
- Scripts: `tools/` (`make_app_assets.py`, `make_play_store.py`, `capture_screens_test.dart`, `make_guide.py`).

### Note for the hub (not Brand's file to change)
- `docs/DECISIONS.md` ("Name, logo, accounts", 2026-10-02) still says **"Logo: concept C 'H made of
  beds'"**. It was replaced by **B3-a2** (same file, "Logo final"). Ideas chat: please strike the
  concept C bullet or mark it "replaced by B3-a2".
- `docs/DECISIONS.md` (Women's PGs line) says "logged-in (OTP) users"; login is Google today. Ideas
  chat may want to reword it. The Play Store copy avoids "OTP" and "verified".
