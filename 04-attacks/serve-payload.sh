#!/usr/bin/env bash
# 04-attacks / serve-payload.sh
# Starts a simple Python HTTP server hosting the benign payload, on Kali.
# The Windows Attk103 script downloads from here.
set -euo pipefail
cd "$(dirname "$0")/payload"
echo "[*] Serving benign payload on http://0.0.0.0:8000/  (Ctrl-C to stop)"
python3 -m http.server 8000
