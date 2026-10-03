# Google Play listing pack (Brand chat, 2026-10-03)

For the founder / Build when the Play Console listing is filled in (F15). App name stays
**Hostelzy**, logo **B3-a2** (`logo.md`). Every line below describes something the app does today
(`docs/BOARD.md`, F01–F24). Nothing says "verified by OTP": sign-in is with Google and the phone
number shows as "not verified" (DECISIONS.md, Plan B).

Files: `docs/brand/assets/play-store/`. Rebuild: copy `docs/brand/tools/capture_screens_test.dart`
into `hostelzy/test/`, run it with `flutter test`, delete the copy, then
`python3 docs/brand/tools/make_play_store.py`.

## Store listing fields

| Field | Value |
|---|---|
| App name (30 max) | `Hostelzy: PGs in Hyderabad` (26) |
| Short description (80 max) | `Find a PG or hostel in Hyderabad. See the room, pick your bed, hold it free.` (75) |
| App icon | `docs/brand/assets/play-store-icon-512.png` (512 × 512) |
| Feature graphic | `assets/play-store/feature-graphic-1024x500.png` |
| Phone screenshots | `assets/play-store/screenshot-1…8-*.png` (1080 × 1920, 9:16) in the order below |
| Category | House & Home |
| Contact | WhatsApp +91 90597 90014 (DECISIONS.md), privacy policy `https://farhath.me/hostelzy/app/privacy/` |
| Tags | PG, hostel, rooms, Hyderabad |

### Full description (English, 4000 max)

```
Looking for a PG or hostel in Hyderabad? Hostelzy shows you the real room before you go.

SEE THE ROOM, PICK YOUR BED
• Every room is drawn: where the window, fan, AC, door and washroom are.
• Pick your own bed, like a seat at the movies.
• Not sure? Compare two beds side by side: under the fan, near the window, near the door.

KNOW THE RENT BEFORE YOU GO
• Rent for 2, 3 and 4 sharing, AC and non-AC, in one table.
• Hostelzy prices: some owners give a lower rent or advance to people who come through the app.
• The advance (₹3,000) is paid straight to the owner by UPI. Hostelzy never holds your money.

HOLD A BED FOR FREE
• Hold any free bed for 1 hour while you go and see it. It costs nothing.
• Ask the owner on WhatsApp with your Hostelzy code.

REVIEWS FROM PEOPLE WHO STAYED
• Only residents whose stay the owner confirmed can write a review.
• Hostels are ranked with the reasons shown in plain words.

LIVING IN A HOSTEL?
• Pay rent by UPI, see today's food menu, raise a complaint, message the owner.
• Reminders for water, meals and rent, right on your phone.
• Fix your room's layout if something has moved.
• Stay Rewards: ₹100 off your next Hostelzy stay.

RUN YOUR HOSTEL (OWNERS)
• Today: confirm holds, check rent received, answer enquiries.
• Beds, rent list, residents, rooms and rates, food menu, house rules, photos.
• Fair Play rules keep deals honest for owners and tenants.

Areas: Madhapur, Hitec City, Kondapur, Gachibowli, KPHB, Ameerpet, SR Nagar and more.
Languages: English, Telugu, Hindi.
```

### Telugu and Hindi listings
**For a native speaker.** Don't machine-translate the store text.
- `te-IN` short description: `[TE: Find a PG or hostel in Hyderabad. See the room, pick your bed, hold it free.]`
- `te-IN` full description: `[TE: translate the English text above, same sections]`
- Screenshot captions: `[TE: …]` for each line in the table below. The images are made with English
  captions only. When the Telugu lines arrive, add them to `SHOTS` in `make_play_store.py` with a
  Telugu font (Archivo has no Telugu letters: use Noto Sans Telugu Bold).
- Hindi (`hi-IN`): same, if the founder wants a Hindi listing.

## The 8 screenshots

Each frame: app ground `#F3F2F2`, a small red block (the "your bed" block from the logo), a caption
in Archivo ExtraBold (line 1 ink, line 2 grey), and the **real app screen** under a 2px-style ink
rule, square corners.

| # | File | Screen (real app) | Caption | Telugu |
|---|---|---|---|---|
| 1 | `screenshot-1-explore.png` | Explore (tenant) | **Find a PG bed** / near your office or college | `[TE]` |
| 2 | `screenshot-2-picker.png` | Pick a bed (room cards) | **See every room.** / Pick your own bed. | `[TE]` |
| 3 | `screenshot-3-compare.png` | Compare beds | **Fan, AC, window?** / Compare two beds first. | `[TE]` |
| 4 | `screenshot-4-detail.png` | Hostel page, rent table | **Clear rent, before** / you go: AC and non-AC | `[TE]` |
| 5 | `screenshot-5-reviews.png` | Reviews | **Reviews from people** / who really stayed | `[TE]` |
| 6 | `screenshot-6-rHome.png` | Resident home | **Living there? Rent,** / food and complaints | `[TE]` |
| 7 | `screenshot-7-reminders.png` | Reminders | **Reminders for water,** / meals and rent | `[TE]` |
| 8 | `screenshot-8-oToday.png` | Owner Today | **Owners: holds, rent and** / enquiries in one place | `[TE]` |

Feature graphic: lockup, "See the room. / **Pick your bed.**", "PGs and hostels in Hyderabad",
and the full room large on the right. No screenshots or prices in it.

## ⚠️ Before publishing (honest listing)
- These screenshots are taken from the app's **sample data** (sample hostels such as "Anjani
  Residency", sample residents, sample prices) and show "No photos yet" where real photos will be.
  **Retake them with real live hostels (owner's OK) and real photos before the listing goes
  public**, or Play could see them as misleading. Same script: point the states in
  `capture_screens_test.dart` at the real hostel.
- The fake status bar (9:41, 5G) is the app's design frame; fine for Play.
- Don't add claims the app doesn't do yet (e.g. "verified", "instant booking", "OTP").
