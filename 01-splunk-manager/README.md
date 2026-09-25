# 01 — Splunk Manager (macOS host)

## Role
This Mac is the **SIEM manager / indexer / search head**. Splunk Enterprise 10.2.6
is already installed at `/Applications/Splunk`. Splunk is NOT installed on any VM.

| Node | IP | Role |
|------|----|------|
| This Mac | <mac-ip> | Splunk Enterprise (indexer + search head + receiver) |
| Windows 11 VM | <windows-ip> | Victim endpoint → forwards logs to .1:9997 |
| Kali VM | <kali-ip> | Attacker **and** monitored Linux endpoint → forwards logs to .1:9997 |

## Run
```bash
export SPLUNK_ADMIN_PASSWORD='YourStrong!Pass'   # required
bash setup-splunk-macos.sh
```
Variables (all optional, defaults shown):
- `SPLUNK_ADMIN_PASSWORD` — **required**, the admin password to (re)set
- `SPLUNK_HOST_IP=<mac-ip>`
- `SPLUNK_INDEX=soc_capstone`
- `SPLUNK_RECEIVE_PORT=9997`
- `SPLUNK_WEB_PORT=8000`

## What the script does
1. On a fresh install only, writes `etc/system/local/user-seed.conf` to seed
   the admin password. Existing accounts are preserved. The seed file is
   removed after authentication is checked.
2. Starts Splunk non-interactively (`--accept-license`).
3. Enables the forwarder receiver on 9997.
4. Creates the `soc_capstone` index.
5. Adds macOS Application Firewall exceptions if the firewall is on.
6. Installs a user LaunchAgent for auto-start at login (the macOS equivalent of
   `enable boot-start`).
7. Restarts and verifies ports.

## Why a dedicated index instead of `main`
- **Evidence isolation** — capstone artifacts stay in one bucket; you can
  export/delete the whole dataset without touching operational data.
- **Retention/sizing** — per-index `frozenTimePeriodInSecs` can be tuned
  independently (e.g. keep `soc_capstone` longer).
- **Access control** — RBAC can restrict the SOC index to analysts only;
  `main` is readable by every role by default.
- **Cleaner searches** — `index=soc_capstone` is faster and less noisy than
  `index=*` and avoids known-field collisions from other apps writing to `main`.
- **Defensible posture** — "we route all lab telemetry to a dedicated index"
  reads as professional practice in the writeup.
