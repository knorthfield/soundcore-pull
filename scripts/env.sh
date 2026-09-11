#!/bin/bash
# Shared settings for the build scripts.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -f "$ROOT/Local.xcconfig" ]; then
  printf '// Team-specific settings. Not committed.\n// DEVELOPMENT_TEAM = XXXXXXXXXX\n' > "$ROOT/Local.xcconfig"
fi
APP_PATH="$ROOT/build/Build/Products/Debug/SoundcorePull.app"
