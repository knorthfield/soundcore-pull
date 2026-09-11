#!/bin/bash
# Run the unit tests.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
xcodegen generate --quiet
xcodebuild -project SoundcorePull.xcodeproj -scheme SoundcorePull -destination 'platform=macOS' \
  -derivedDataPath build test | grep -E "error:|Test Case|Executed|TEST" || true
