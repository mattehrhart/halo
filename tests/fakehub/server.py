#!/usr/bin/env python3
"""A stand-in for OpenLinkHub, so Halo's screens can be opened and tested
without any hardware.

    tests/fakehub/server.py [port]        (default 27103)
    halo --hub http://127.0.0.1:27103

It serves the device descriptions in data/ the way OpenLinkHub's API does.
Changes are accepted and ignored. Create a file named "slow" next to this
script to delay device reads by a few seconds (to see loading states). Set
HALO_FAKE_ONLY=K70MAX,SCIMITAR to list only some of the devices.
"""
import json
import os
import pathlib
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = pathlib.Path(__file__).parent
DATA = HERE / "data"

CURVE = {
    "0": [{"x": 0, "y": 70}, {"x": 40, "y": 70}, {"x": 60, "y": 75}, {"x": 80, "y": 90}, {"x": 200, "y": 100}],
    "1": [{"x": 0, "y": 30}, {"x": 40, "y": 40}, {"x": 60, "y": 50}, {"x": 80, "y": 75}, {"x": 200, "y": 100}],
}
CURVES = {name: {"sensor": 0, "Hidden": False, "points": CURVE} for name in ("Normal", "Performance", "Quiet")}
CURVES["aioCriticalTemperature"] = {"sensor": 2, "Hidden": True, "points": CURVE}

PERFORMANCE = [
    {"name": "Disable Win Key", "type": "checkbox", "value": False, "internal": "perf_winKey"},
    {"name": "Disable Shift + Tab", "type": "checkbox", "value": False, "internal": "perf_shiftTab"},
    {"name": "Disable Alt + Tab", "type": "checkbox", "value": False, "internal": "perf_altTab"},
    {"name": "Disable Alt + F4", "type": "checkbox", "value": False, "internal": "perf_altF4"},
]


def load(name):
    return json.loads((DATA / name).read_text())


def ok(data):
    return {"code": 200, "status": 1, "data": data}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, body):
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.rstrip("/")
        if path == "/api":
            everything = load("all.json")
            only = [name for name in os.environ.get("HALO_FAKE_ONLY", "").split(",") if name]
            if only:
                everything["device"] = {k: v for k, v in everything["device"].items() if k in only}
            return self.reply(everything)
        if path == "/api/batteryStats":
            return self.reply(load("battery.json"))
        if path.startswith("/api/devices/"):
            if (HERE / "slow").exists():
                time.sleep(4)
            serial = path.rsplit("/", 1)[1]
            if serial.isalnum() and (DATA / (serial + ".json")).exists():
                return self.reply(load(serial + ".json"))
            return self.reply({"code": 200, "status": 0, "message": "Non-existing device"})
        if path == "/api/temperatures":
            return self.reply(ok(CURVES))
        if path == "/api/lcd/images":
            return self.reply(ok([{"Name": "cat", "Frames": 24}, {"Name": "logo", "Frames": 1}]))
        if path.startswith("/api/keyboard/getPerformance"):
            return self.reply(ok(PERFORMANCE))
        if path.startswith("/api/keyboard/getFlashTap"):
            return self.reply(ok(load("K70MAX.json")["device"]["DeviceProfile"]["FlashTap"]))
        if path.startswith("/api/input/"):
            return self.reply(ok(load("SCIMITAR.json")["device"]["InputActions"]))
        self.reply(ok({}))

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0) or 0))
        if self.path.startswith("/api/keyboard/getKeys"):
            rows = load("K70MAX.json")["device"]["DeviceProfile"]["Keyboards"]["default"]["row"]
            keys = {i: k["keyName"] for r in rows.values() for i, k in r["keys"].items() if not k.get("onlyColor")}
            return self.reply(ok(keys))
        self.reply({"code": 200, "status": 1, "message": "ok"})

    do_PUT = do_POST
    do_DELETE = do_POST


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 27103
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
