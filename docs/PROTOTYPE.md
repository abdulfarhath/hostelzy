# Clickable prototype (founder, 2026-10-04)

**Link:** https://claude.ai/artifact/EztxM6k1kud7ivGoG6K6iP. It's the real app compiled for the web, with sample data,
inside a phone frame. It has jump buttons for each role and flow, a light/dark toggle, and a notes box.

## New way of working (founder decision)
1. The founder clicks through the prototype and sends changes (screen → what → why).
2. The hub turns them into a spec, and Design updates the canvas.
3. **Build changes the code, then rebuilds and republishes the prototype** at the same link (same artifact URL). No APK.
4. The founder checks the prototype. **Only after the founder approves** does the change go to `main` and an APK.

## Rebuild and publish
- `tools/prototype.sh` builds `build/prototype/` (web build: `DATA=sample`, `PROTO=true`, no CDN, no service worker).
- Publish `build/prototype/index.html` to the same artifact URL, with every file under `app/` in `files`
  (`.frag` as `text/plain`, `.arb` as `application/json`). `PROTO=true` keeps the `?start=…&role=…` shortcuts in a release
  build, and only the prototype uses it.
- Known limits: no map tiles (artifact pages can't load other hosts), and no camera, push, location or Google sign-in. Use
  "Use on this phone only".
