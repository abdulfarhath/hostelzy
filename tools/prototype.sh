#!/usr/bin/env bash
# Builds the clickable web prototype: the real app, sample data, dev shortcuts on (PROTO=true).
# Output: build/prototype/app/ ready to publish behind docs/prototype/index.html (see docs/PROTOTYPE.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; export PATH="$HOME/flutter/bin:$PATH"
cd "$ROOT/hostelzy"
flutter build web --release --dart-define=DATA=sample --dart-define=PROTO=true --no-web-resources-cdn --pwa-strategy=none
OUT="$ROOT/build/prototype"; rm -rf "$OUT"; mkdir -p "$OUT/app"; cp -r build/web/. "$OUT/app/"
cd "$OUT/app"
# Artifacts serve only web file types and no service workers; the JS build only needs canvaskit.
find . -name '*.symbols' -delete
rm -rf flutter_service_worker.js .last_build_id assets/NOTICES assets/AssetManifest.bin canvaskit/skwasm* canvaskit/wimp* canvaskit/webparagraph
sed -i 's#<base href="/">#<base href="./">#' index.html
cp "$ROOT/docs/prototype/index.html" "$OUT/index.html"
echo "Prototype in $OUT ($(du -sh "$OUT" | cut -f1)). Publish index.html with every file under app/ (.frag as text/plain, .arb as application/json)."
