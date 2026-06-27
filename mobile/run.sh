#!/usr/bin/env bash
# Run the Flutter app on a connected device, wiring the API base URL from env.sh.
#
#   ./run.sh                # auto-detect device + host IP
#   API_HOST=192.168.1.50 ./run.sh
#   ./run.sh -d <device-id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

echo "Using API_BASE_URL=$API_BASE_URL"
echo "(phone and this machine must be on the same network)"

exec flutter run \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "$@"
