# Live trace console

The console runs on the Mac at `http://127.0.0.1:8765`. It calls Splunk's local
management API on port 8089 from the server process. The browser never receives
the Splunk password. The server binds to loopback by default.

Start Splunk and the console:

```bash
bash 07-live-console/start-macos.sh
```

The launcher prompts for the Splunk admin password. You can instead supply
`SPLUNK_PASSWORD` from a secret manager. `SPLUNK_URL`, `SPLUNK_USER`,
`SPLUNK_INDEX`, `CONSOLE_HOST`, and `CONSOLE_PORT` are optional overrides.
Set `SPLUNK_TLS_VERIFY=1` after installing a trusted certificate for Splunk's
management endpoint.

The trace is a 60-bin count of real matching events for the selected time
window. It is not a request latency chart. Detections are transparent rules:
10 or more SSH failures from one source within five minutes, or the presence
of account creation/admin group changes, a PowerShell download command, or a
Security log clear event. Results refresh every 15 seconds and are cached by
the server for 10 seconds. Each event class is capped at 250 results; the UI
flags a capped result set. The app does not fabricate events or scores.

The console reads `linux_secure`, `WinEventLog:Security`, and Sysmon Operational
events from `soc_capstone`. It has no external JavaScript or Python runtime
dependencies. On a fresh machine, the console will show a disconnected state
until Splunk, its index, and forwarders are configured.
