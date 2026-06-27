#!/usr/bin/env bash
# Stop local dev stack started by run-all.sh / ensure-backend.sh.
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
stop_pid web
stop_pid worker
stop_pid api
stop_pid meili
stop_pid pg

pkill -f 'next dev --turbopack --hostname 0.0.0.0' 2>/dev/null || true
pkill -f 'scripts/worker-supervisor.sh' 2>/dev/null || true
pkill -f '.local/bin/api' 2>/dev/null || true
pkill -f '.local/bin/worker' 2>/dev/null || true
pkill -f '.local/bin/meilisearch' 2>/dev/null || true
pkill -f 'cmd/localpg' 2>/dev/null || true

echo "Done."
