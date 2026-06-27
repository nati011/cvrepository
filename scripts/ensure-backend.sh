#!/usr/bin/env bash
# Start local Postgres, Meilisearch, API, and worker when they are not already running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p .local/bin .local/data .local/pids logs data/cvs

exec 200>"$ROOT/.local/ensure-backend.lock"
if ! flock -n 200; then
  if curl -sf --max-time 2 "http://127.0.0.1:8080/healthz" >/dev/null 2>&1; then
    echo "ensure-backend already running elsewhere — API is up, skipping"
    exit 0
  fi
  echo "ensure-backend already running elsewhere — waiting for lock..."
  flock 200
fi

wait_url() {
  local url=$1
  local name=$2
  for _ in $(seq 1 60); do
    if curl -sf --max-time 2 "$url" >/dev/null 2>&1; then
      echo "$name is up"
      return 0
    fi
    sleep 1
  done
  echo "timeout waiting for $name ($url)" >&2
  return 1
}

wait_port() {
  local port=$1
  local name=$2
  for _ in $(seq 1 60); do
    if (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1; then
      echo "$name is up on port $port"
      return 0
    fi
    sleep 1
  done
  echo "timeout waiting for $name on port $port" >&2
  return 1
}

pid_alive() {
  local f=$1
  [[ -f "$f" ]] && kill -0 "$(cat "$f")" 2>/dev/null
}

record_pid() {
  local pid_file=$1
  local pattern=$2
  local pid
  pid="$(pgrep -n -f "$pattern" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    echo "$pid" >"$pid_file"
  fi
}

start_if_needed() {
  local name=$1
  local pid_file=$2
  if pid_alive "$pid_file"; then
    echo "$name already running (pid $(cat "$pid_file"))"
    return 0
  fi
  rm -f "$pid_file"
  return 1
}

worker_supervisor_running() {
  if ! pid_alive .local/pids/worker.pid; then
    return 1
  fi
  local pid
  pid="$(cat .local/pids/worker.pid)"
  if ps -p "$pid" -o args= 2>/dev/null | grep -q 'worker-supervisor\.sh'; then
    return 0
  fi
  echo "Stale worker pid file (pid $pid is not worker-supervisor) — clearing"
  rm -f .local/pids/worker.pid
  return 1
}

api_healthy() {
  curl -sf --max-time 2 "http://127.0.0.1:8080/healthz" >/dev/null 2>&1
}

api_port_open() {
  (echo >/dev/tcp/127.0.0.1/8080) >/dev/null 2>&1
}

stop_api_pid() {
  local pid_file=.local/pids/api.pid
  if pid_alive "$pid_file"; then
    local pid
    pid="$(cat "$pid_file")"
    echo "Stopping API (pid $pid)..."
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.25
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

start_api() {
  if [[ ! -x .local/bin/api ]]; then
    echo "==> Building Go binaries..."
    go build -o .local/bin/api ./cmd/api
    go build -o .local/bin/worker ./cmd/worker
  fi
  echo "==> Starting Go API..."
  nohup .local/bin/api >>logs/api.log 2>&1 &
  echo $! >.local/pids/api.pid
}

ensure_api() {
  if api_healthy; then
    echo "API already up"
    record_pid .local/pids/api.pid '.local/bin/api'
    return 0
  fi

  if api_port_open; then
    echo "Port 8080 is open but health check failed — waiting for API..."
    wait_url "http://127.0.0.1:8080/healthz" "API"
    record_pid .local/pids/api.pid '.local/bin/api'
    return 0
  fi

  if pid_alive .local/pids/api.pid; then
    echo "Stale API process (not listening) — stopping pid $(cat .local/pids/api.pid)"
    stop_api_pid
  else
    rm -f .local/pids/api.pid
  fi

  start_api
  wait_url "http://127.0.0.1:8080/healthz" "API"
  record_pid .local/pids/api.pid '.local/bin/api'
}

export CVREPO_USE_PDFTOTEXT=1

if ! (echo >/dev/tcp/127.0.0.1/5433) >/dev/null 2>&1; then
  if ! start_if_needed "Postgres" .local/pids/pg.pid; then
    echo "==> Starting embedded Postgres..."
    go run ./cmd/localpg >logs/localpg.log 2>&1 &
    echo $! >.local/pids/pg.pid
    wait_port 5433 "Postgres"
  fi
else
  echo "Postgres already listening on port 5433"
  record_pid .local/pids/pg.pid 'cmd/localpg'
fi

if ! curl -sf --max-time 2 "http://127.0.0.1:7700/health" >/dev/null 2>&1; then
  if ! start_if_needed "Meilisearch" .local/pids/meili.pid; then
    echo "==> Starting Meilisearch..."
    if [[ ! -x .local/bin/meilisearch ]]; then
      curl -fsSL -o .local/bin/meilisearch.tmp \
        "https://github.com/meilisearch/meilisearch/releases/download/v1.11.3/meilisearch-linux-amd64"
      chmod +x .local/bin/meilisearch.tmp
      mv .local/bin/meilisearch.tmp .local/bin/meilisearch
    fi
    MEILI_MASTER_KEY=dev_master_key .local/bin/meilisearch \
      --http-addr 127.0.0.1:7700 \
      --env development \
      --db-path .local/data/meili >logs/meili.log 2>&1 &
    echo $! >.local/pids/meili.pid
    wait_url "http://127.0.0.1:7700/health" "Meilisearch"
  fi
else
  echo "Meilisearch already up"
  record_pid .local/pids/meili.pid '.local/bin/meilisearch'
fi

ensure_api

if ! worker_supervisor_running; then
  if [[ ! -x .local/bin/worker ]]; then
    go build -o .local/bin/worker ./cmd/worker
  fi
  echo "==> Starting Go worker supervisor..."
  nohup bash "$ROOT/scripts/worker-supervisor.sh" >>logs/worker.log 2>&1 &
  echo $! >.local/pids/worker.pid
fi
