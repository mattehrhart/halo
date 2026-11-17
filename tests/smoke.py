#!/usr/bin/env python3
"""Opens every screen of Halo against the stand-in hub and fails if any of
them logs a QML error or draws nothing.

    tests/smoke.py <path to the halo binary> [--keep <folder for captures>]

Runs without a display (QT_QPA_PLATFORM=offscreen).
"""
import os
import pathlib
import re
import socket
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent

# device/section[/selection] for every kind of screen, at the smallest
# supported window and at a large one.
ROUTES = [
    "K70MAX/lighting", "K70MAX/assignments/50", "K70MAX/actuation", "K70MAX/performance", "K70MAX/device",
    "KB100/lighting", "KB95/lighting", "KB65/performance", "KB55/lighting",
    "SCIMITAR/assignments", "SCIMITAR/lighting", "SCIMITAR/dpi", "SCIMITAR/device",
    "MS65/lighting", "HS80/lighting", "HS80/device",
    "LSH1/parts", "LSH1/parts/curves", "LSH1/lighting", "LSH1/lcd", "LSH1/ports",
    "CXT1/parts", "CXT1/ports", "MB1/parts", "MEM1/parts", "MEM1/lighting", "PSU1/parts", "XEN1/widgets",
]
SIZES = ["960x660", "1920x1080"]

# Anything the QML engine prints when a binding, type or file is broken.
BAD = re.compile(r"(qrc:/|file:/).*:\d+|failed to load|is not a type|unavailable|ReferenceError|TypeError")
# Rendering chatter that the offscreen platform always prints.
NOISE = re.compile(r"graphics scene|QPen|propagateSizeHints|This plugin does not support")


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def wait_for(port):
    for _ in range(50):
        try:
            socket.create_connection(("127.0.0.1", port), timeout=0.2).close()
            return
        except OSError:
            time.sleep(0.1)
    raise SystemExit("the stand-in hub did not start")


def colors_in(png):
    """A rough count of distinct bytes, to tell a drawn page from a blank one."""
    data = png.read_bytes()
    return len(data), len(set(data[-4096:]))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    halo = sys.argv[1]
    keep = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == "--keep" else None
    out = keep or pathlib.Path(tempfile.mkdtemp(prefix="halo-smoke-"))
    out.mkdir(parents=True, exist_ok=True)

    port = free_port()
    hub = subprocess.Popen([sys.executable, str(HERE / "fakehub" / "server.py"), str(port)])
    failures = []
    try:
        wait_for(port)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        for size in SIZES:
            for route in ROUTES:
                shot = out / (route.replace("/", "-") + "-" + size + ".png")
                if shot.exists():
                    shot.unlink()
                run = subprocess.run(
                    [halo, "--hub", f"http://127.0.0.1:{port}", "--route", route, "--size", size,
                     "--grab", str(shot), "--grab-delay", "1500"],
                    env=env, capture_output=True, text=True, timeout=60)
                lines = [l for l in (run.stderr + run.stdout).splitlines() if BAD.search(l) and not NOISE.search(l)]
                problem = ""
                if lines:
                    problem = lines[0]
                elif not shot.exists():
                    problem = "no capture was written"
                elif colors_in(shot)[0] < 8000:
                    problem = "the capture looks blank"
                print(("FAIL " if problem else "ok   ") + f"{route} @ {size}" + (": " + problem if problem else ""))
                if problem:
                    failures.append(route)
    finally:
        hub.terminate()
    if failures:
        raise SystemExit(f"{len(failures)} screen(s) failed")
    print(f"{len(ROUTES) * len(SIZES)} screens opened cleanly")


if __name__ == "__main__":
    main()
