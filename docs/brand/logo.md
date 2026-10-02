# Logo (Brand chat)

## ✅ FINAL LOGO: B3-a2 "Room with AC" (founder, 2026-10-02)

Founder in the Brand chat: "finalize B3-a2, put it into our application, take your own decisions".
Earlier rounds below are history only. **Concept C files were replaced**; `assets/` is now B3-a2 only.

### What it is
A top view of a real PG room: walls with a **window** (double line) and a **door gap**, an **AC**
on the wall with **dotted air**, a **fan**, a **bunk** and a grey bed, and **your bed in red**.
Story: "see the real room, pick your bed".

- Colours (from `Pal`): walls/AC/fan ink `#201E1D` (dark `#F0EEEE`), other beds grey `#605D5D`
  (dark `#9A9696`), **your bed red `#EC3013`** (dark `#FF563C`). Floor is transparent.
- Only your bed is red. Square corners. Don't rotate, outline, shadow or recolour it.
- **Two sizes of detail:** at 64 px and below the simple mark is used (AC = a bar, fan = a dot,
  no pillow or air dots), so it stays clear on small screens.
- Wordmark: **hostelzy**, lowercase, Archivo ExtraBold (800), −0.02em, same as the app header.
  In the lockup the room is 1.18× the height of the "h", gap 0.3×.
- Icon ground: **white**. Brand chat decision: a red tile would break "only your bed is red".

### Files in `docs/brand/assets/` (rebuild: `python3 docs/brand/make_logo.py`)
| File | What | For Build |
|---|---|---|
| `ic_launcher_foreground-{mdpi…xxxhdpi}.png` (108–432 px) | Room on transparent, 48dp inside 108dp (fits round masks) | `res/mipmap-*/ic_launcher_foreground.png` |
| `ic_launcher_monochrome-{mdpi…xxxhdpi}.png` | One-colour simple room | `res/mipmap-*/ic_launcher_monochrome.png` (Android 13 themed icons) |
| `ic_launcher_background.svg/.png` | Plain white | use a colour resource `#FFFFFF` instead |
| `ic_launcher-{mdpi…xxxhdpi}.png` (48–192) | Square white tile + room | `res/mipmap-*/ic_launcher.png` (Android 7 and older) |
| `ic_stat_hostelzy-{mdpi…xxxhdpi}.png` (24–96) | White simple room, transparent | `res/drawable-*/ic_stat_hostelzy.png` (push notifications, when Firebase lands) |
| `play-store-icon-512.png` | 512×512, full-bleed white (Play rounds it) | Play Console listing (F15) |
| `web-favicon.png`, `web-Icon-192/512.png`, `web-Icon-maskable-192/512.png` | Web build icons | `web/favicon.png`, `web/icons/Icon-*.png` (same names) |
| `mark-light.svg`, `mark-dark.svg`, `mark-mono.svg` (+ `-512.png`) | The room alone, transparent | In-app (with `flutter_svg`), splash, posters |
| `lockup-light/dark.svg` (+`@2x.png`), `lockup-on-light/on-dark` | Room + "hostelzy", text outlined | Website, QR poster, slides |
| `ic_launcher_foreground.svg`, `ic_launcher.svg`, `ic_stat_hostelzy.svg`, `*_monochrome.svg` | Vector sources | reference |

### Build steps (Build chat: please do these on a branch, then merge per standing approval)
1. Copy the PNGs above into `hostelzy/android/app/src/main/res/` (rename `-mdpi` etc. into the
   matching `mipmap-mdpi/…` folders; file name without the density suffix).
2. Add `res/mipmap-anydpi-v26/ic_launcher.xml` (and the same as `ic_launcher_round.xml`):
   ```xml
   <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
     <background android:drawable="@color/ic_launcher_background"/>
     <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
     <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
   </adaptive-icon>
   ```
   and `res/values/ic_launcher_background.xml` with `<color name="ic_launcher_background">#FFFFFF</color>`.
3. Replace `hostelzy/web/favicon.png` and `web/icons/Icon-*.png` with the `web-*` files.
4. In the app header (`screens_start.dart` start screen, `shell.dart` header) put the room mark
   (`mark-light.svg` / `mark-dark.svg` by theme, via `flutter_svg`, already a dependency) to the
   left of the live `hostelzy` text, mark height ≈ 1.2× the text's x-height. Keep the text as text.
5. App name stays **Hostelzy** (DECISIONS.md). No rename.


Name: **Hostelzy** (kept for now, founder 2026-10-02).

## Round 1 concepts (2026-10-02)
Canvas: https://claude.ai/artifact/MQMKQkVhsePEJ755s1Vrq1

All use the bed-picker idea: rooms as squares, beds as blocks, **your bed = red**.
App colours only: ink `#201E1D`, red `#EC3013` (dark: `#FF563C`), square corners.
Play icon = red tile, white blocks, your bed in ink.

| | Concept | What you see | Story |
|---|---|---|---|
| A | Pick your bed | 2×2 seats: 1 taken, 2 free (outlines), 1 red | The bed picker, as small as it gets |
| B | The room | Room square with a door gap, 3 beds inside, 1 red | A real room from the Room tab |
| C | H made of beds | 7 blocks make an "H", the middle one red | H for Hostelzy; the red bed is the H's crossbar |
| D | Beds near you | Map pin with a 2×2 bed grid, 1 red | Find a bed near you |
| E | Bed held | Like A, the red bed has a tick | Your bed is held |
| F | Your bed inside the h | Block "h" (the hostel) with a red bed under its roof | The hostel holds your bed |

Brand chat's picks: **C** (strongest letter + idea, clear at 32 px), then **A**, then **F**.

Each board shows: light, dark, Play icon at 112/64/48/32 px, and the wordmark lockup.
Waiting for the founder to pick 1–2 to refine.

---

# Concept C refined (2026-10-02) · NOT USED (history)

> **On hold:** the founder now prefers concept B "The room" (Ideas chat, 2026-10-02).
> Replaced by B3-a2. The C files were removed from `assets/` (see git history).

Picked by the Ideas chat on the founder's delegation (DECISIONS.md "Name, logo, accounts").
The founder can still change it.

## The mark
- 7 square blocks on a 3×3 grid make an **H**. The middle block is **your bed**.
- Grid: 100 units, blocks **28**, gaps **8** (bigger gaps than round 1, so it stays clear at 32 px).
- Colours (from `Pal` in `kit.dart`):

| Where | H blocks | Your bed (middle) | Ground |
|---|---|---|---|
| Light | ink `#201E1D` | red `#EC3013` | `#F3F2F2` |
| Dark | `#F0EEEE` | `#FF563C` | `#161514` |
| App icon | white `#FFFFFF` | ink `#201E1D` | red `#EC3013` |
| One colour (notification, themed icon) | white | white | transparent |

- Square corners always. Never rotate, outline, add shadows or change the block count.
- Wordmark: **hostelzy** in lowercase, Archivo ExtraBold (800), letter-spacing −0.02em, same as
  the app's header. In the lockup the mark is as tall as the "h", with a gap of ~⅓ of that.

## Files in `docs/brand/assets/` (made by `docs/brand/make_logo.py`)
Small PNGs are pixel-snapped so the blocks stay sharp.

| File | What it is | Where Build uses it |
|---|---|---|
| `ic_launcher_foreground.svg/.png` (432×432) | White H + ink bed on transparent; mark 46dp inside the 108dp canvas (fits the 66dp safe circle) | Adaptive icon foreground (`mipmap-anydpi-v26/ic_launcher.xml`) |
| `ic_launcher_background.svg/.png` (432×432) | Solid red `#EC3013` | Adaptive icon background (or a colour resource `#EC3013`) |
| `ic_launcher_monochrome.svg/.png` (432×432) | White H, same safe zone | Android 13+ themed icon (`<monochrome>`) |
| `ic_launcher-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}.png` (48–192) | Square red tile, legacy icon | `mipmap-*/ic_launcher.png` for Android < 8 |
| `play-store-icon-512.svg/.png` | 512×512 full-bleed red square (Play rounds it) | Play Console listing icon |
| `ic_stat_hostelzy-{mdpi…xxxhdpi}.png` (24–96) + `.svg` | White H on transparent | Notification small icon (`drawable-*/ic_stat_hostelzy.png`) |
| `mark.svg`, `mark-dark.svg`, `mark-mono.svg` (+ `-512.png`) | The mark alone, transparent | Login screen, splash, posters |
| `lockup.svg`, `lockup-dark.svg` (+ `@2x.png`) | Mark + wordmark, transparent; text is outlined (no font needed) | Login screen, website, A4 QR poster |
| `lockup-on-light.svg`, `lockup-on-dark.svg` (+ `@2x.png`) | Same, on the app's light / dark ground | Slides, social posts |

Canvas (final board at the bottom): https://claude.ai/artifact/MQMKQkVhsePEJ755s1Vrq1

---

# Round 2: concept B "The room", all options (2026-10-02)

Asked by the founder via the Ideas chat: "design all possible ways, I will be selecting one".
Canvas: https://claude.ai/artifact/7AQacMXpVCZUFpDn89ET4D
**No final files until the founder picks one code.**

Rules: walls ink, other beds grey (`#605D5D`, dark `#9A9696`), **only your bed is red**,
square corners, Play icon on a white tile. Every board: big light + dark, Play icon at
112/64/48/32 px, lockup with "hostelzy" (Archivo 800, lowercase like the app header).
At 48 px and below, pillow lines and the fan dot drop out on their own (too small to see).

| Code | What it is |
|---|---|
| **B1-a** | Clean room, door gap, 3 beds with pillow lines, your bed red |
| **B1-b** | Same, 2 beds |
| **B1-c** | Same as B1-a, no pillow lines |
| **B2-a** | Room + H: two tall beds on the side walls, your red bed across the middle = an H. Door gap. (Ideas chat pick) |
| **B2-b** | B2-a with the door drawn open (arc) |
| **B2-c** | B2-a with no pillow lines (pure H) |
| **B3-a** | Full room: window (double line on top wall), bunk, fan dot, 3 beds. Icon uses a simple version (window + 2 beds) |
| **B3-b** | B3-a with no fan dot |
| **B4-a** | Open door (arc) "welcome in", 3 beds |
| **B4-b** | Open door, 2 beds |

Also on the canvas:
- **Compare**: every Play icon at 48 px, on light and dark.
- **B2 splash storyboard** (about 0.9 s): walls draw → room ready → grey beds appear →
  your red bed drops in → "Bed mila!".

Brand chat view: **B2-a** or **B2-c** (the H gives the room a letter, reads at 32 px).
B1-b is the simplest. B3 is best kept for posters/splash, not the icon.

---

# Round 3: founder picked B3-a "Full room, fan on" (2026-10-02)

Founder: use B3-a, improve it, try dotted lines, fan, AC, washroom; show a few, founder decides.
Canvas page **"B3-a improved"**: https://claude.ai/artifact/7AQacMXpVCZUFpDn89ET4D

| Code | What's new on top of B3-a |
|---|---|
| **B3-a1** | Real fan (3 blades) + **dotted circle** = where the fan reaches (like F12's coverage layer) |
| **B3-a2** | **AC unit** on the top wall with **dotted air lines**, + fan |
| **B3-a3** | **Attached washroom** in the corner (partition, door, commode), + fan |
| **B3-a4** | **Dotted red path** from the door to your bed ("we take you to your bed"), + fan |
| **B3-a5** | **Everything**: window, AC + air, fan + dotted reach, washroom, dotted path |
| **B3-a6** | **Balanced**: window, fan, dotted path, 3 beds (no AC, no washroom) |

All keep: window (double line), bunk, your bed red, others grey, square corners.
Icon sizes (≤48 px) auto-simplify: fan becomes a dot, path becomes 3 red squares,
AC a bar, washroom just its walls.

Brand chat view: **B3-a6** or **B3-a4** for the app icon (the red path + red bed tells the story
at a glance); **B3-a5** for the splash screen and posters (the full room).
Still **no final files** until the founder picks a code.
