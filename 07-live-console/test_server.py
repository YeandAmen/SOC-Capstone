import importlib.util
import time
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location("console_server", Path(__file__).with_name("server.py"))
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class SnapshotTests(unittest.TestCase):
    def test_real_event_shapes_create_detections_and_trace(self):
        now = time.time()
        stamp = lambda seconds: __import__("datetime").datetime.fromtimestamp(seconds, __import__("datetime").timezone.utc).isoformat()
        rows = {
            "ssh": [{"_time": stamp(now - i * 10), "host": "kali", "_raw": "Failed password for medusa from 192.168.64.1 port 50000 ssh2"} for i in range(10)],
            "account": [{"_time": stamp(now - 30), "host": "WIN-LAB", "EventCode": "4720", "TargetUserName": "capstone_admin", "_raw": "EventCode=4720"}],
            "powershell": [{"_time": stamp(now - 20), "host": "WIN-LAB", "EventID": "1", "User": "lab", "CommandLine": "powershell.exe DownloadString(...)"}],
        }
        result = server.build_snapshot(rows, 1)
        self.assertEqual(result["total"], 12)
        self.assertEqual(len(result["detections"]), 3)
        self.assertEqual(len(result["trace"]), 60)
        self.assertEqual(sum(bin.get("T1110", 0) for bin in result["trace"]), 10)
        self.assertEqual(result["hosts"], ["WIN-LAB", "kali"])

    def test_security_log_clear_is_critical(self):
        stamp = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()
        result = server.build_snapshot({"account": [{"_time": stamp, "host": "WIN-LAB", "EventCode": "1102", "_raw": "EventCode=1102"}]}, 24)
        self.assertEqual(result["detections"][0]["severity"], "critical")


if __name__ == "__main__":
    unittest.main()
