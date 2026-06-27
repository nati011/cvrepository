#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p .local/pids logs

exec 201>"$ROOT/.local/run-all.lock"
if ! flock -n 201; then
  echo "run-all.sh is already running (see .local/run-all.lock). Stop it first or use: bash scripts/stop-dev.sh"
  exit 1
fi

stop_pid() {
  local f=$1
  if [[ -f "$f" ]]; then
    kill "$(cat "$f")" 2>/dev/null || true
    rm -f "$f"
  fi
}

cleanup() {
  stop_pid .local/pids/web.pid
  stop_pid .local/pids/worker.pid
  stop_pid .local/pids/api.pid
  stop_pid .local/pids/meili.pid
  stop_pid .local/pids/pg.pid
}
trap cleanup INT TERM

bash "$ROOT/scripts/ensure-backend.sh"

echo "==> Installing web deps (if needed)..."
if [[ ! -x web/node_modules/.bin/next ]]; then
  (cd web && npm install --no-audit --no-fund)
fi

if (echo >/dev/tcp/127.0.0.1/3000) >/dev/null 2>&1; then
  if curl -sf --max-time 2 "http://127.0.0.1:3000" >/dev/null 2>&1; then
    echo "Next.js already listening on http://localhost:3000 — skipping web start"
  else
    echo "Port 3000 is in use by a non-Next process; stop it or run: cd web && npm run dev" >&2
    exit 1
  fi
else
  echo "==> Starting Next.js..."
  (cd web && nohup npm run dev:web >"$ROOT/logs/web.log" 2>&1 & echo $! >"$ROOT/.local/pids/web.pid")

  for _ in $(seq 1 60); do
    if curl -sf --max-time 2 "http://127.0.0.1:3000" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

echo ""
echo "CV Repository is running:"
echo "  Web:  http://localhost:3000"
echo "  API:  http://localhost:8080/healthz"
echo "  Jobs: http://localhost:3000/campaigns"
echo ""

if command -v xdg-open >/dev/null; then
  xdg-open "http://localhost:3000" >/dev/null 2>&1 || true
fi

echo "Press Ctrl+C to stop all services."
while true; do
  sleep 30
  bash "$ROOT/scripts/restart-api-if-down.sh" || true
done
