#!/usr/bin/env bash
# Lightweight API restart — only when port 8080 is not serving healthz.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if curl -sf --max-time 2 "http://127.0.0.1:8080/healthz" >/dev/null 2>&1; then
  exit 0
fi

echo "$(date -Iseconds) API health check failed — ensuring backend..."
bash "$ROOT/scripts/ensure-backend.sh"
