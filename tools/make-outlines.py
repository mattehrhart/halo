#!/usr/bin/env python3
"""Traces an outline of every device in a folder of reference pictures.

Halo draws each device as a simple outline. Two models have hand-finished
diagrams (make-device-diagrams.py); every other one gets what this makes: the
traced silhouette of each view of the device, with no artwork copied.

Reads a folder laid out like iCUE's device pictures (first argument) and
writes src/devices/outlines.json: for each device its name and, per view, the
size and the outline as a closed line of points.
"""
import csv
import json
import math
import pathlib
import sys

from PIL import Image, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "src/devices/outlines.json"
RAYS = 120
HEIGHT = 400  # every view is scaled to this height


def trace(picture):
    """The device's outer edge in one picture, or None if nothing is there."""
    gray = picture.convert("L").filter(ImageFilter.GaussianBlur(3))
    solid = gray.point(lambda v: 255 if v > 24 else 0)
    box = solid.getbbox()
    if not box or (box[2] - box[0]) < 40 or (box[3] - box[1]) < 40:
        return None
    solid = solid.crop(box)
    scale = HEIGHT / solid.height
    solid = solid.resize((max(1, round(solid.width * scale)), HEIGHT))
    pixels = solid.load()
    cx, cy = solid.width / 2, solid.height / 2
    reach = math.hypot(solid.width, solid.height)
    radii = []
    for i in range(RAYS):
        angle = 2 * math.pi * i / RAYS
        ux, uy = math.cos(angle), math.sin(angle)
        last, r = 0.0, 0.0
        while r < reach:
            x, y = int(cx + ux * r), int(cy + uy * r)
            if not (0 <= x < solid.width and 0 <= y < solid.height):
                break
            if pixels[x, y]:
                last = r
            r += 1.5
        radii.append(last)
    points = []
    for i in range(RAYS):
        r = sum(radii[(i + k) % RAYS] for k in (-2, -1, 0, 1, 2)) / 5
        angle = 2 * math.pi * i / RAYS
        points.append([round(cx + math.cos(angle) * r), round(cy + math.sin(angle) * r)])
    return {"width": solid.width, "height": HEIGHT, "outline": points}


def views(folder):
    """A device's body pictures: one color variant, in name order."""
    body = folder / "body"
    if not body.is_dir():
        return []
    pictures = sorted(p for p in body.iterdir() if p.suffix.lower() in (".jpg", ".png"))
    if not pictures:
        variants = sorted(p for p in body.iterdir() if p.is_dir())
        if variants:
            pictures = sorted(p for p in variants[0].iterdir() if p.suffix.lower() in (".jpg", ".png"))
    return pictures


def main():
    source = pathlib.Path(sys.argv[1])
    names = {}
    with open(source / "index.csv", newline="") as handle:
        for row in csv.DictReader(handle):
            names[row["folder"]] = row["device name"]
    devices = {}
    for folder in sorted(p for p in source.iterdir() if p.is_dir()):
        pictures = views(folder)
        # Keyboards come in one picture per language; one is enough.
        keyboard = any(p.stem in ("na", "uk", "de") for p in pictures)
        if keyboard:
            pictures = [p for p in pictures if p.stem == "na"] or pictures[:1]
        traced = []
        for picture in pictures[:3]:
            try:
                view = trace(Image.open(picture))
            except Exception:
                view = None
            if view:
                traced.append(view)
        if traced:
            devices[folder.name] = {"name": names.get(folder.name, folder.name), "keyboard": keyboard, "views": traced}
    OUT.write_text(json.dumps(devices, separators=(",", ":")) + "\n")
    print(f"wrote {len(devices)} devices, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
