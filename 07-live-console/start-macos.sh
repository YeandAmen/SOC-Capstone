#!/usr/bin/env bash
set -euo pipefail

SPLUNK_HOME="${SPLUNK_HOME:-/Applications/Splunk}"
if ! nc -z 127.0.0.1 8089 >/dev/null 2>&1; then
  "$SPLUNK_HOME/bin/splunk" start --no-prompt
fi
exec python3 "$(dirname "$0")/server.py"
