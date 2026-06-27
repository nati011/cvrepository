#!/usr/bin/env bash
# Capture mobile app screenshots on a connected Android device via adb.
set -euo pipefail

DEVICE="${DEVICE:-R9ZL10GEREL}"
PKG=com.example.cv_exec_feed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/../docs/screenshots"

# Bottom nav centers (720×1600, nav bar y≈1390–1510) from UIAutomator dump.
TAB_FEED=(72 1450)
TAB_JOBS=(216 1450)
TAB_CAMPAIGNS=(360 1450)
TAB_LISTS=(504 1450)
TAB_CHAT=(648 1450)
BTN_PROFILE=(64 117)
BTN_NOTIFICATIONS=(668 117)

mkdir -p "$OUT"

tap() {
  adb -s "$DEVICE" shell input tap "$1" "$2"
  sleep 2
}

capture() {
  adb -s "$DEVICE" exec-out screencap -p > "$OUT/$1.png"
  echo "Captured $1"
}

tap_desc_contains() {
  local needle="$1"
  adb -s "$DEVICE" shell uiautomator dump /sdcard/ui.xml >/dev/null
  local line
  line="$(adb -s "$DEVICE" shell cat /sdcard/ui.xml | tr '>' '>\n' | grep "$needle" | head -1 || true)"
  if [ -z "$line" ]; then
    echo "Could not find element containing: $needle" >&2
    return 1
  fi
  local bounds
  bounds="$(echo "$line" | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p')"
  read -r x1 y1 x2 y2 <<<"$bounds"
  tap $(( (x1 + x2) / 2 )) $(( (y1 + y2) / 2 ))
}

adb -s "$DEVICE" shell am force-stop "$PKG"
adb -s "$DEVICE" shell am start -n "$PKG/.MainActivity"
sleep 6

tap "${TAB_FEED[@]}"
capture "01_feed"

tap "${TAB_JOBS[@]}"
capture "02_jobs"

tap "${TAB_CAMPAIGNS[@]}"
capture "03_campaigns"

tap "${TAB_LISTS[@]}"
capture "04_lists"

tap "${TAB_CHAT[@]}"
capture "05_chat"

tap "${TAB_FEED[@]}"
tap "${BTN_PROFILE[@]}"
capture "06_profile"

tap_desc_contains "View leaderboard" || tap 360 827
capture "08_leaderboard"

adb -s "$DEVICE" shell input keyevent KEYCODE_BACK
sleep 1
adb -s "$DEVICE" shell input keyevent KEYCODE_BACK
sleep 1

tap "${BTN_NOTIFICATIONS[@]}"
capture "07_notifications"

echo "Done — screenshots in $OUT"
