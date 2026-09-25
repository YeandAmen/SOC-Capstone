#!/usr/bin/env bash
set -euo pipefail

SPLUNK_HOME="${SPLUNK_HOME:-/Applications/Splunk}"
if ! nc -z 127.0.0.1 8089 >/dev/null 2>&1; then
  "$SPLUNK_HOME/bin/splunk" start --no-prompt
fi
if [ -z "${SPLUNK_PASSWORD:-}" ]; then
  printf 'Splunk admin password (used only by this local process): ' >&2
  trap 'stty echo' EXIT
  stty -echo
  read -r SPLUNK_PASSWORD
  stty echo
  trap - EXIT
  printf '\n' >&2
  export SPLUNK_PASSWORD
fi
exec python3 "$(dirname "$0")/server.py"
