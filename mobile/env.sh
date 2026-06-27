#!/usr/bin/env bash
# Source before running Flutter commands: source env.sh
export JAVA_HOME="$HOME/development/jdk17"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$HOME/development/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# API endpoint the phone uses to reach the backend on this machine.
# Auto-detect the host's LAN IP; override by exporting API_HOST / API_PORT before sourcing.
export API_PORT="${API_PORT:-8080}"
if [ -z "${API_HOST:-}" ]; then
  API_HOST="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
  if [ -z "${API_HOST:-}" ]; then
    API_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
fi
export API_HOST
export API_BASE_URL="${API_BASE_URL:-http://${API_HOST}:${API_PORT}}"
