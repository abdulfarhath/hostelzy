# Hostelzy (Flutter)

The Hostelzy app for Hyderabad PGs and hostels, built from the Claude Design handoff in
`../project/HostelzyApp.dc.html`. One app, three roles picked after Google sign-in:
**tenant** (find and hold a bed), **resident** (my stay) and **owner** (run the hostel, with managers),
plus the Hostelzy **team mode**. How the code is organised, the data flow and how to add a screen or
migration: `../docs/ARCHITECTURE.md`. Every screen and sheet: `../docs/SCREENS.md`.

## Run and check

```sh
flutter pub get
flutter run                              # demo data (DATA=sample, the default)
flutter run --dart-define=DATA=supabase  # live data from Supabase
flutter analyze && flutter test          # or ../tools/check.sh for everything CI runs
```

Cloud sessions get Flutter 3.47.5 from `../.claude/hooks/session-start.sh`.

On a wide window (≥ 730 px) debug builds show the design's 410 × 864 phone frame with the screen
list and a light/dark switch; "Open all screens →" opens the overview of every screen.

## Debug start states (debug builds only)

Release builds always start at Welcome. In debug, query parameters set the start state:

| Param | Values |
| --- | --- |
| `start` | any key in `AppState.screens` (`lib/state.dart`), e.g. `explore` `detail` `picker` `rHome` `oToday` `oMeter` `aAdd` |
| `role` | `tenant` `resident` `owner` |
| `theme` | `light` `dark` `system` |
| `mode` | `plan` `room` `list` (bed picker) |
| `sheet` | the keys listed in `lib/main.dart` (`search` `hold` `wa` `add` `bed` `enq` `perks`…) |
| `moveTab` / `moreTab` | `vacate` `swap` / Manage tabs (`residents` `complaints` `deals` `rates` `menu` `rules`…) |
| `bare` | `true`: phone only, no frame |
| `page` | `overview`: all screens |

Example: `/?start=picker&role=tenant&mode=list&theme=dark`.

## Code at a glance

- `lib/state.dart`: `AppState` core (screen, back stack, sheet, toast, persistence); every area's state
  is a `part` in `lib/features/<area>/<area>.dart` (fields mixin + `<Area>Actions` extension).
- `lib/features/<area>/`: that area's state, screens (`*_screen(s).dart`) and sheets (`*_sheets.dart`).
- `lib/features/listings/`: `HostelRepo` interface (`repo.dart`) with `SupabaseRepo` and `SampleRepo`,
  row parsing (`rows.dart`), realtime (`live.dart`), load/apply (`sync.dart`), offline cache.
- `lib/data.dart` → `lib/data/`: models, sample data and helpers by domain (`format.dart`: ₹ in Indian
  grouping, dates, countdowns).
- `lib/ui/kit.dart`: design tokens (`Pal` light/dark) and CSS-faithful primitives (`T`, `CssLine`,
  `CssRow`, text balancing, icons). `lib/ui/common.dart`: `Cta`, `OutlineCta`, `Seg`, chips, fields.
  `lib/ui/shell.dart`: frame, tab bar, screen and sheet maps, toast.

## Design fidelity

Match the design exactly: Archivo (bundled in `assets/fonts`), `#ec3013` red for actions, green
`#1f7a3d` / `#dcefe0` only for savings and Hostelzy deals, 2px rules, square corners, light and dark.
Use `T`/`CssLine` for text, `Pal` tokens for colour, and `Cta`, `Seg` and the other kit pieces; no
hard-coded colours. Every screen must fit at 390 × 844 and at 2× text size.
