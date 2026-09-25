# 03 — Linux Endpoint (Kali)

## Role
Kali is BOTH the attacker box AND a monitored Linux endpoint (per your choice),
so it runs a Universal Forwarder that ships `auth.log` + `syslog` to the Mac.
This lets the SOC see attacker-side artifacts (e.g. the SSH brute force's own
`Failed password` lines on the target, plus `useradd` if a Linux account is
created) — the same logs a real IR team would pull off a compromised box.

## Run (on Kali, as root)
```bash
sudo SPLUNK_HOST_IP=192.168.64.1 bash setup-uf-kali.sh
```
Env vars (optional): `SPLUNK_HOST_IP`, `SPLUNK_RECEIVE_PORT=9997`, `SPLUNK_INDEX=soc_capstone`.

## What it collects
| File | Sourcetype | Why |
|------|-----------|-----|
| `/var/log/auth.log` | `linux_secure` | SSH `Failed password` (Attk101), `sudo`/`su`, `useradd` (Attk102) |
| `/var/log/syslog` | `syslog` | General system timeline / cron / service activity |

## Verify on Kali
```bash
/opt/splunkforwarder/bin/splunk status
nc -zv 192.168.64.1 9997
tail -f /opt/splunkforwarder/var/log/splunk/metrics.log | grep tcpout
```
Then on the Mac, in Splunk:
```splunk
index=soc_capstone sourcetype=linux_secure | stats count by host
```
