# Hostelzy (Flutter)

The Hostelzy mobile app, built from the Claude Design handoff in
`../project/HostelzyApp.dc.html` (see `../chats/chat1.md` for the brief).
One app with three roles picked after OTP login: **tenant** (find and hold a
bed), **resident** (my stay) and **owner** (run the hostel). There is no
parent role.

## Run

```sh
flutter pub get
flutter run                 # Android / iOS
flutter run -d chrome       # web
flutter test                # flow tests
```

On a phone the app runs full screen. On a wide window (≥ 730 px) it shows the
design's prototype layout: the 410 × 864 phone frame with the screen list and
light/dark switch beside it. "Open all screens →" opens the overview canvas
with every screen as a live phone.

On the web, query parameters set the start state, the same props the design
exposes:

| Param | Values |
| --- | --- |
| `start` | `welcome` `phone` `otp` `role` `explore` `map` `holds` `me` `detail` `picker` `hold` `rHome` `rPay` `food` `help` `move` `rConfirm` `oToday` `oBeds` `oRent` `oMore` `oInvite` `oRates` |
| `role` | `tenant` `resident` `owner` |
| `theme` | `light` `dark` |
| `mode` | `plan` `list` `building` (bed picker) |
| `sheet` | `search` `hold` `wa` `add` `bed` `enq` `addR` |
| `moveTab` / `moreTab` | `vacate` `swap` / `residents` `complaints` `menu` `rules` |
| `bare` | `true`: phone frame only |
| `page` | `overview`: all screens |

Example: `/?start=picker&role=tenant&mode=list&theme=dark`.

## Code

- `lib/data.dart`: sample Hyderabad data and helpers (bed generation, `₹`
  formatting in Indian grouping, countdowns), ported 1:1 from the prototype.
- `lib/state.dart`: one `AppState` shared by all roles. A tenant's free hold
  shows in the owner's inbox, menu edits reach the resident's Food tab, rent
  payments update the owner's rent list.
- `lib/ui/kit.dart`: design tokens (light and dark `Pal`) and CSS-fidelity
  primitives:
  - `T` / `CssLine`: text with CSS line boxes (exact `font-size × line-height`,
    Blink's baseline placement, CSS letter-spacing).
  - `_Balanced`: `text-wrap: balance`, ported from Blink.
  - `CssRow`: flex shrink.
  - hatch and dashed painters, and the icons.
- `lib/ui/common.dart`: shared pieces (buttons, segmented controls, chips,
  bed boxes, inputs).
- `lib/ui/screens_*.dart`: start, tenant, resident and owner screens.
- `lib/ui/shell.dart`: frame, tab bar, bottom sheets and toast.
- `lib/ui/overview.dart`: the all-screens page.

Fonts (Archivo 400/500/600/800, JetBrains Mono 400) are bundled in
`assets/fonts`. Photos and the map are placeholders, as in the design.
WhatsApp, Maps and payments are simulated with toasts, as in the prototype.
