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
| `start` | `welcome` `phone` `otp` `role` `explore` `map` `holds` `me` `detail` `picker` `hold` `rHome` `rPay` `food` `help` `move` `rConfirm` `oToday` `oBeds` `oRent` `oMore` `oInvite` `rReview` `rExit` `reviews` `oReviews` `oRank` `oRules` `oCase` `oStrike` `aCases` `rewards` `moveIn` |
| `role` | `tenant` `resident` `owner` |
| `theme` | `light` `dark` |
| `mode` | `plan` `list` `building` (bed picker) |
| `sheet` | `search` `hold` `wa` `add` `bed` `enq` `addR` `rank` `joined` `report` `trusted` |
| `moveTab` / `moreTab` | `vacate` `swap` / `residents` `complaints` `deals` `rates` `menu` `rules` |
| `bare` | `true`: phone frame only |
| `page` | `overview`: all screens |

Example: `/?start=picker&role=tenant&mode=list&theme=dark`.

## Code

- `lib/data.dart`: barrel that re-exports the models, sample Hyderabad data
  and helpers in `lib/data/` (one file per domain: `hostels`, `format` (`₹` in
  Indian grouping, dates, countdowns), `residents`, `holds`, `house`, `deals`,
  `reviews`, `plan`, `layouts`, `onboarding`, `geo`, `amenities`).
- `lib/state.dart`: one `AppState` shared by all roles (core: navigation,
  sheets, persistence). Each area's state is a `part` in
  `lib/features/<area>/<area>.dart` (data mixin + `<Area>Actions` extension).
  A tenant's free hold shows in the owner's inbox, menu edits reach the
  resident's Food tab, rent payments update the owner's rent list.
- `lib/features/<area>/`: each feature folder owns its state part and its
  screens and sheets (`*_screen(s).dart`, `*_sheets.dart`), e.g.
  `explore/` (Explore, hostel page, filters), `holds/` (holds, bed picker),
  `owner/` (Today, Beds, Rent, Manage, Invite), `residents/`, `session/`
  (start, sign-in, Me, settings), `layouts/`, `onboarding/`, `team/`.
- `lib/features/listings/repo.dart`: the `HostelRepo` interface; it re-exports
  `sample_repo.dart` (`SampleRepo`), `supabase_repo.dart` (`SupabaseRepo`) and
  `rows.dart` (row parsing).
- `lib/ui/kit.dart`: design tokens (light and dark `Pal`) and CSS-fidelity
  primitives:
  - `T` / `CssLine`: text with CSS line boxes (exact `font-size × line-height`,
    Blink's baseline placement, CSS letter-spacing).
  - `_Balanced`: `text-wrap: balance`, ported from Blink.
  - `CssRow`: flex shrink.
  - hatch and dashed painters, and the icons.
- `lib/ui/common.dart`: shared pieces (buttons, segmented controls, chips,
  bed boxes, inputs).
- `lib/ui/shell.dart`: frame, tab bar, the screen and sheet maps, and toast.
  Screen and sheet bodies live in their feature folders.
- `lib/ui/overview.dart`: the all-screens page.

Fonts (Archivo 400/500/600/800, JetBrains Mono 400) are bundled in
`assets/fonts`. Photos and the map are placeholders, as in the design.
WhatsApp, Maps and payments are simulated with toasts, as in the prototype.
