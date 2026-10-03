#!/bin/bash
# Cloud sessions: install Flutter (the CI version) once and fetch packages, so
# `flutter analyze`, `flutter test` and tools/check.sh work straight away.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION=3.47.5   # keep in step with .github/workflows/android-apk.yml
FLUTTER_DIR="$HOME/flutter"

if ! "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | grep -q "Flutter $FLUTTER_VERSION"; then
  rm -rf "$FLUTTER_DIR"
  curl -sSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf /tmp/flutter.tar.xz -C "$HOME"
  rm -f /tmp/flutter.tar.xz
fi
git config --global --add safe.directory "$FLUTTER_DIR" >/dev/null 2>&1 || true

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --disable-analytics >/dev/null 2>&1 || true
cd "$CLAUDE_PROJECT_DIR/hostelzy"
flutter pub get
