#!/bin/bash
# Generate the Xcode project and build the app.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
xcodegen generate --quiet
xcodebuild -project SoundcorePull.xcodeproj -scheme SoundcorePull -destination 'platform=macOS' \
  -derivedDataPath build build "$@" | grep -E "error:|warning:|BUILD" || true
