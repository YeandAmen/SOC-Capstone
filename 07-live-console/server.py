#!/usr/bin/env python3
"""Local, read-only bridge from Splunk search to the capstone console."""

import base64
import json
import os
import re
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SPLUNK_URL = os.environ.get("SPLUNK_URL", "https://127.0.0.1:8089").rstrip("/")
SPLUNK_USER = os.environ.get("SPLUNK_USER", "admin")
SPLUNK_PASSWORD = os.environ.get("SPLUNK_PASSWORD", "")
INDEX = os.environ.get("SPLUNK_INDEX", "soc_capstone")
PORT = int(os.environ.get("CONSOLE_PORT", "8765"))
HOST = os.environ.get("CONSOLE_HOST", "127.0.0.1")
TLS_VERIFY = os.environ.get("SPLUNK_TLS_VERIFY", "0") == "1"

SEARCHES = {
    "ssh": 'sourcetype=linux_secure ("Failed password" OR "Accepted password")',
    "account": 'sourcetype=WinEventLog:Security (EventCode=4720 OR EventCode=4732 OR EventCode=1102)',
    "powershell": 'sourcetype=XmlWinEventLog:Microsoft-Windows-Sysmon/Operational EventID=1 (DownloadString OR DownloadFile OR Invoke-WebRequest OR Net.WebClient OR EncodedCommand)',
}
MAX_PER_SEARCH = 250
_cache = {}
_cache_lock = threading.Lock()


def splunk_search(query, earliest):
    search = f"search index={INDEX} earliest=-{earliest}h {query} | head {MAX_PER_SEARCH} | table _time host sourcetype EventCode EventID src Source_Network_Address User Account_Name TargetUserName CommandLine _raw"
    body = urllib.parse.urlencode({"search": search, "output_mode": "json", "preview": "false"}).encode()
    request = urllib.request.Request(
        f"{SPLUNK_URL}/services/search/jobs/export",
        data=body,
        headers={
            "Authorization": "Basic " + base64.b64encode(f"{SPLUNK_USER}:{SPLUNK_PASSWORD}".encode()).decode(),
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    context = None if TLS_VERIFY else ssl._create_unverified_context()
    with urllib.request.urlopen(request, timeout=25, context=context) as response:
        return [item["result"] for line in response for item in [json.loads(line)] if "result" in item]


def parse_time(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (ValueError, AttributeError):
        return 0


def classify(kind, row):
    raw = row.get("_raw", "") or ""
    code = str(row.get("EventCode") or row.get("EventID") or "")
    if kind == "ssh":
        failed = "Failed password" in raw
        match = re.search(r"from ([0-9a-fA-F:.]+)", raw)
        return ("SSH failure" if failed else "SSH success", "T1110", "high" if failed else "medium", match.group(1) if match else (row.get("src") or "unknown"))
    if kind == "account":
        labels = {"4720": ("Local account created", "T1136.001", "high"), "4732": ("Administrator group changed", "T1136.001", "high"), "1102": ("Security log cleared", "T1070.001", "critical")}
        for candidate, label in labels.items():
            if code == candidate or re.search(r"EventCode\s*=\s*" + candidate, raw):
                return (*label, row.get("TargetUserName") or row.get("Account_Name") or "")
        return None
    return ("PowerShell download command", "T1059.001", "high", row.get("User") or "")


def build_snapshot(rows_by_kind, hours):
    events = []
    for kind, rows in rows_by_kind.items():
        for row in rows:
            classified = classify(kind, row)
            if not classified:
                continue
            label, technique, severity, actor = classified
            timestamp = parse_time(row.get("_time"))
            if not timestamp:
                continue
            events.append({
                "time": timestamp,
                "host": row.get("host") or "unknown",
                "label": label,
                "technique": technique,
                "severity": severity,
                "actor": actor,
                "detail": (row.get("CommandLine") or row.get("_raw") or "")[:340],
            })
    events.sort(key=lambda event: event["time"], reverse=True)
    now = time.time()
    window_start = now - hours * 3600
    bins = [Counter() for _ in range(60)]
    for event in events:
        index = int((event["time"] - window_start) / (hours * 3600) * 60)
        if 0 <= index < 60:
            bins[index][event["technique"]] += 1
    ssh_failures = [event for event in events if event["label"] == "SSH failure"]
    burst = any(sum(1 for other in ssh_failures if 0 <= event["time"] - other["time"] <= 300 and event["actor"] == other["actor"]) >= 10 for event in ssh_failures)
    detections = []
    if burst:
        detections.append({"title": "SSH failure burst", "technique": "T1110", "severity": "high", "reason": "10+ failures from one source within five minutes"})
    for technique, title in (("T1136.001", "Account change"), ("T1059.001", "PowerShell download"), ("T1070.001", "Security log cleared")):
        matching = [event for event in events if event["technique"] == technique]
        if matching:
            detections.append({"title": title, "technique": technique, "severity": "critical" if technique == "T1070.001" else "high", "reason": f"{len(matching)} matching event(s) in selected window"})
    return {
        "updated_at": now,
        "hours": hours,
        "events": events[:100],
        "trace": [dict(item) for item in bins],
        "detections": detections,
        "counts": dict(Counter(event["technique"] for event in events)),
        "hosts": sorted({event["host"] for event in events}),
        "total": len(events),
        "limited": any(len(rows) == MAX_PER_SEARCH for rows in rows_by_kind.values()),
    }


def snapshot(hours):
    with _cache_lock:
        cached = _cache.get(hours)
        if cached and time.time() - cached[0] < 10:
            return cached[1]
    rows = {kind: splunk_search(query, hours) for kind, query in SEARCHES.items()}
    result = build_snapshot(rows, hours)
    with _cache_lock:
        _cache[hours] = (time.time(), result)
    return result


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = urllib.parse.urlparse(self.path)
        if route.path == "/api/events":
            if not SPLUNK_PASSWORD:
                return self.send_json({"error": "Set SPLUNK_PASSWORD before starting the console."}, 503)
            try:
                hours = int(urllib.parse.parse_qs(route.query).get("hours", [24])[0])
                if hours not in (1, 6, 24, 72):
                    return self.send_json({"error": "hours must be 1, 6, 24 or 72"}, 400)
                return self.send_json(snapshot(hours))
            except (urllib.error.URLError, TimeoutError, ValueError) as exc:
                return self.send_json({"error": f"Splunk search failed: {exc}"}, 502)
        if route.path in ("/", "/index.html"):
            return self.send_file(ROOT / "index.html", "text/html; charset=utf-8")
        if route.path == "/app.css":
            return self.send_file(ROOT / "app.css", "text/css; charset=utf-8")
        if route.path == "/stats.css":
            return self.send_file(ROOT / "stats.css", "text/css; charset=utf-8")
        if route.path == "/app.js":
            return self.send_file(ROOT / "app.js", "text/javascript; charset=utf-8")
        self.send_error(404)

    def send_json(self, value, status=200):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path, mime):
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", INDEX):
        raise SystemExit("SPLUNK_INDEX contains unsupported characters")
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"SOC console: http://{HOST}:{PORT} (Splunk: {SPLUNK_URL}, index: {INDEX})", flush=True)
    server.serve_forever()
