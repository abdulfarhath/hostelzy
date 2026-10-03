# Real app screenshots for Design

Rendered from the app itself (main, 2026-10-03) with real fonts and the demo build's sample data,
in a 390 × 844 phone frame. Each file has a 1× (390 × 844) and an `@3x` version.

| File | Screen |
|---|---|
| `map-light`, `map-dark` | Map tab (`map`): search bar, "Use my location" pin button, price pins, landmarks, selected hostel card |
| `map-use-my-location-light`, `-dark` | Map with the "Use your location?" sheet (`loc`) |
| `map-area-picker-light`, `-dark` | Area picker (`where`): Near me, landmarks, areas (with "Coming soon") |

**Map tiles are not in these images.** The capture machine can't reach tile.openstreetmap.org
(blocked by its network), so the map shows its plain ground colour under the pins. On a phone the
same screen has OpenStreetMap tiles under everything shown here; nothing else differs.

Re-capture or add screens: `docs/design/tools/capture_design_test.dart` (instructions at its top).
