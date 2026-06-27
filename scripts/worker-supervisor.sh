#!/usr/bin/env bash
# Restart the Go worker when it exits (PDF extraction / pipeline jobs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CVREPO_USE_PDFTOTEXT=1

while true; do
  .local/bin/worker
  echo "$(date -Iseconds) worker exited, restarting in 2s..." >>logs/worker.log
  sleep 2
done
