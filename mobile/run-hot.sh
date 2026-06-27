#!/usr/bin/env bash
# Run Flutter on a device and auto hot-reload when lib/*.dart files change.
#
#   ./run-hot.sh
#   ./run-hot.sh -d <device-id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

STAMP=$(mktemp)
PIPE=$(mktemp -u)
mkfifo "$PIPE"
trap 'rm -f "$STAMP" "$PIPE"' EXIT INT TERM

echo "Using API_BASE_URL=$API_BASE_URL"
echo "Auto hot-reload: enabled (watches lib/*.dart)"
echo "(phone and this machine must be on the same network)"

touch "$STAMP"

(
  while true; do
    sleep 1
    if find "$SCRIPT_DIR/lib" -name '*.dart' -newer "$STAMP" -print -quit | grep -q .; then
      touch "$STAMP"
      printf 'r\n' > "$PIPE" 2>/dev/null || true
    fi
  done
) &
WATCHER_PID=$!
trap 'kill "$WATCHER_PID" 2>/dev/null; rm -f "$STAMP" "$PIPE"' EXIT INT TERM

flutter run \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  "$@" < "$PIPE"
