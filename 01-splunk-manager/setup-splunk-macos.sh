#!/usr/bin/env bash
# Splunk Enterprise manager setup for the SOC Playground (macOS host).
# Manager = this Mac (<mac-ip>). Splunk 10.2.6 already installed at
# /Applications/Splunk. This script is idempotent: it (re)sets the admin
# password on first install, starts Splunk, enables the receiver, creates a dedicated
# index, opens the macOS app firewall, and installs a launchd auto-start.
#
# Usage:
#   export SPLUNK_ADMIN_PASSWORD='ChangeMe!123'
#   bash setup-splunk-macos.sh
set -euo pipefail

SPLUNK_HOME="${SPLUNK_HOME:-/Applications/Splunk}"
SPLUNK_BIN="$SPLUNK_HOME/bin/splunk"
INDEX_NAME="${SPLUNK_INDEX:-soc_capstone}"
RECEIVE_PORT="${SPLUNK_RECEIVE_PORT:-9997}"
WEB_PORT="${SPLUNK_WEB_PORT:-8000}"
MGMT_PORT="${SPLUNK_MGMT_PORT:-8089}"
MAC_IP="${SPLUNK_HOST_IP:-<mac-ip>}"

log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[X] %s\n' "$*" >&2; exit 1; }

[ -n "${SPLUNK_ADMIN_PASSWORD:-}" ] || die "Set SPLUNK_ADMIN_PASSWORD env var first (the admin password to set)."
[ -x "$SPLUNK_BIN" ] || die "splunk binary not found at $SPLUNK_BIN"
log "Splunk home : $SPLUNK_HOME"
log "Splunk ver  : $("$SPLUNK_BIN" version 2>/dev/null | head -1)"
log "Manager IP  : $MAC_IP"
log "Index       : $INDEX_NAME"
log "Receive port: $RECEIVE_PORT"

# -----------------------------------------------------------------------------
# 1. (Re)set the admin password using the documented user-seed.conf method.
#    user-seed.conf is consumed by splunkd at startup and (re)seeds the admin
#    account. This is the supported recovery path for a forgotten admin login
#    (the same mechanism the official Splunk Docker image uses for
#    SPLUNK_PASSWORD). We delete the seed file after auth is verified so no
#    plaintext password lingers on disk.
# -----------------------------------------------------------------------------
SEED="$SPLUNK_HOME/etc/system/local/user-seed.conf"
PASSWD="$SPLUNK_HOME/etc/passwd"
umask 077
if [ ! -f "$PASSWD" ]; then
  log "Writing user-seed.conf for first start..."
  cat > "$SEED" <<EOF
[user_info]
USERNAME = admin
PASSWORD = $SPLUNK_ADMIN_PASSWORD
EOF
  chmod 600 "$SEED"
else
  log "Existing Splunk users found; using the supplied password without resetting them."
fi

# -----------------------------------------------------------------------------
# 2. Start Splunk (accept license + non-interactive).
# -----------------------------------------------------------------------------
log "Starting Splunk (first start after install may take a minute)..."
"$SPLUNK_BIN" start --accept-license --answer-yes --no-prompt >/tmp/splunk-start.log 2>&1 || {
  warn "splunk start returned non-zero; tail of log:"; tail -n 30 /tmp/splunk-start.log >&2
  die "splunk start failed"
}

log "Waiting for web ($WEB_PORT) and mgmt ($MGMT_PORT) ports..."
for i in $(seq 1 90); do
  if nc -z 127.0.0.1 "$WEB_PORT" >/dev/null 2>&1 && nc -z 127.0.0.1 "$MGMT_PORT" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
nc -z 127.0.0.1 "$WEB_PORT" >/dev/null 2>&1 || die "web port $WEB_PORT never came up"

# -----------------------------------------------------------------------------
# 3. Verify admin auth via the REST API, then remove the plaintext seed.
# -----------------------------------------------------------------------------
log "Verifying admin credentials via REST..."
auth_code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$SPLUNK_ADMIN_PASSWORD" "https://127.0.0.1:$MGMT_PORT/services/server/info" || true)
if [ "$auth_code" = 200 ]; then
  log "Admin auth OK. Removing user-seed.conf (no plaintext password left on disk)."
  rm -f "$SEED"
else
  rm -f "$SEED"
  die "Admin auth failed (HTTP $auth_code). Check the supplied password."
fi

# -----------------------------------------------------------------------------
# 4. Enable the forwarder receiving port (9997) and create the dedicated index.
#    Creating an index requires a restart; we restart once at the end.
# -----------------------------------------------------------------------------
log "Enabling receiver port $RECEIVE_PORT..."
"$SPLUNK_BIN" enable listen "$RECEIVE_PORT" -auth "admin:$SPLUNK_ADMIN_PASSWORD" >/dev/null 2>&1 \
  || warn "enable listen returned non-zero (may already be enabled)"

log "Creating dedicated index '$INDEX_NAME' (idempotent)..."
"$SPLUNK_BIN" add index "$INDEX_NAME" -auth "admin:$SPLUNK_ADMIN_PASSWORD" >/dev/null 2>&1 \
  || warn "add index returned non-zero (may already exist)"

# -----------------------------------------------------------------------------
# 5. macOS Application Firewall exceptions (best effort). Only needed if the
#    app firewall is enabled; if it is off, incoming from the UTM NAT works.
# -----------------------------------------------------------------------------
if [ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]; then
  fw_state=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | awk '{print $3}' | tr -d '.') || true
  if [ "$fw_state" = "on" ]; then
    log "App firewall is ON; adding Splunk exceptions..."
    for b in splunkd splunkweb; do
      p="$SPLUNK_HOME/bin/$b"
      [ -x "$p" ] && { sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$p" >/dev/null 2>&1 || true; \
                        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$p" >/dev/null 2>&1 || true; }
    done
  else
    log "App firewall is OFF; no exceptions needed."
  fi
fi

# -----------------------------------------------------------------------------
# 6. macOS "boot-start" equivalent: a user LaunchAgent that starts Splunk at
#    login (runs as the current user, matching the install owner). This is the
#    supported macOS pattern; Splunk's Linux `enable boot-start` (init/systemd)
#    does not apply on macOS.
# -----------------------------------------------------------------------------
PLIST="$HOME/Library/LaunchAgents/com.splunk.startup.plist"
log "Installing launchd auto-start -> $PLIST"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.splunk.startup</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SPLUNK_BIN</string>
    <string>start</string>
    <string>--no-prompt</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/splunk-launchd.log</string>
  <key>StandardErrorPath</key><string>/tmp/splunk-launchd.err</string>
</dict>
</plist>
EOF
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST" 2>/dev/null || warn "launchctl load failed (Splunk still starts via the manual start above)"

# -----------------------------------------------------------------------------
# 7. Restart once so the new index becomes available.
# -----------------------------------------------------------------------------
log "Restarting Splunk so the new index takes effect..."
"$SPLUNK_BIN" restart --no-prompt >/tmp/splunk-restart.log 2>&1 || warn "restart returned non-zero (see /tmp/splunk-restart.log)"
sleep 6

# -----------------------------------------------------------------------------
# 8. Final verification + summary.
# -----------------------------------------------------------------------------
log "Final checks:"
"$SPLUNK_BIN" status 2>&1 | sed 's/^/    /'
for p in "$WEB_PORT" "$RECEIVE_PORT" "$MGMT_PORT"; do
  nc -z 127.0.0.1 "$p" >/dev/null 2>&1 && log "port $p OPEN" || warn "port $p CLOSED"
done

cat <<EOF

Splunk manager is ready
------------------------------------------------------------
 Web UI .... http://$MAC_IP:$WEB_PORT   (admin / <SPLUNK_ADMIN_PASSWORD>)
 REST ...... https://$MAC_IP:$MGMT_PORT
 Receive ... $MAC_IP:$RECEIVE_PORT  (point all Universal Forwarders here)
 Index ..... $INDEX_NAME
------------------------------------------------------------
 From each VM, confirm reachability:
    nc -zv $MAC_IP $RECEIVE_PORT
EOF
