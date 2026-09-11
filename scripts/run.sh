#!/bin/bash
# Build, then launch the app.
set -euo pipefail
source "$(dirname "$0")/env.sh"
"$ROOT/scripts/build.sh"
open "$APP_PATH"
