#!/usr/bin/env bash
# Wipe local dev data and restart from empty (Postgres, Meilisearch, CV files, mobile app state).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

stop_pid() {
  local name=$1
  local f=".local/pids/${name}.pid"
  if [[ -f "$f" ]]; then
    local pid
    pid="$(cat "$f")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "Stopping $name (pid $pid)..."
      kill "$pid" 2>/dev/null || true
      for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$f"
  fi
}

echo "==> Stopping local services..."
stop_pid worker
stop_pid api
stop_pid web
stop_pid meili
stop_pid pg
pkill -f '.local/bin/api' 2>/dev/null || true
pkill -f '.local/bin/worker' 2>/dev/null || true
pkill -f 'cmd/localpg' 2>/dev/null || true
rm -f .local/pids/*.pid

echo "==> Clearing embedded Postgres data..."
rm -rf .local/pg/data .local/pg/runtime

echo "==> Clearing Meilisearch index..."
rm -rf .local/data/meili
mkdir -p .local/data/meili

echo "==> Clearing CV file storage..."
rm -rf data/cvs
mkdir -p data/cvs

echo "==> Clearing Flutter app data on connected device/emulator..."
if command -v adb >/dev/null 2>&1; then
  if adb get-state >/dev/null 2>&1; then
    adb shell pm clear com.example.cv_exec_feed >/dev/null 2>&1 \
      && echo "Cleared com.example.cv_exec_feed (SharedPreferences + local cache)" \
      || echo "Note: Flutter app not installed on device — skip mobile clear"
  else
    echo "No adb device — skip mobile clear"
  fi
else
  echo "adb not found — skip mobile clear"
fi

echo ""
echo "Done. Database, search index, CV files, and mobile app state are empty."
echo "Start fresh with:  ./scripts/run-all.sh"
echo "Note: campaigns/jobs are wiped too — recreate a campaign after uploading CVs so the feed can rank candidates."
