# Logo (Brand chat)

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

# Final: concept C "H made of beds" (2026-10-02)

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
