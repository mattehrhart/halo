#!/usr/bin/env python3
"""Makes Halo's device diagrams: simple outlines of each device, drawn by Halo.

A diagram is a small JSON file in src/devices/ that says how big the device
is, what its silhouette is, and where its keys or buttons are. Halo draws it
with plain shapes and lights the legends itself, so no vendor artwork ships.

This script is a drawing aid, run once per device by a developer. It reads a
reference picture of the device (first argument: a folder laid out like
iCUE's device pictures) only to trace the silhouette and take proportions;
nothing from the picture is copied into the diagram.
"""
import json
import math
import pathlib
import sys

from PIL import Image, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "src/devices"


def device_box(picture, pad=12, floor=22):
    box = picture.convert("L").filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > floor else 0).getbbox()
    return (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)


def silhouette(picture, dx=0, dy=0, rays=240, floor=26, smooth=4):
    """Traces a device's outer edge as a smooth closed line.

    Rays are cast outward from the middle of the shape; the last solid point
    on each ray is on the edge. The radii are then averaged with their
    neighbors, which rounds off the small bumps a traced edge would have.
    """
    solid = picture.convert("L").filter(ImageFilter.GaussianBlur(2)).point(lambda v: 255 if v > floor else 0)
    pixels = solid.load()
    box = solid.getbbox()
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    reach = math.hypot(solid.width, solid.height)
    radii = []
    for i in range(rays):
        angle = 2 * math.pi * i / rays
        ux, uy = math.cos(angle), math.sin(angle)
        last = 0.0
        r = 0.0
        while r < reach:
            x, y = int(cx + ux * r), int(cy + uy * r)
            if not (0 <= x < solid.width and 0 <= y < solid.height):
                break
            if pixels[x, y]:
                last = r
            r += 1.5
        radii.append(last)
    points = []
    for i in range(rays):
        r = sum(radii[(i + k) % rays] for k in range(-smooth, smooth + 1)) / (2 * smooth + 1)
        angle = 2 * math.pi * i / rays
        points.append([round(cx + math.cos(angle) * r + dx, 1), round(cy + math.sin(angle) * r + dy, 1)])
    return points


def grid(corners, columns, rows, gap):
    """Even cells inside a four-cornered area (top-left, top-right, bottom-right,
    bottom-left), each pulled in by `gap`. Returns cells[column][row]."""
    tl, tr, br, bl = corners

    def at(u, v):
        top = (tl[0] + (tr[0] - tl[0]) * u, tl[1] + (tr[1] - tl[1]) * u)
        bottom = (bl[0] + (br[0] - bl[0]) * u, bl[1] + (br[1] - bl[1]) * u)
        return (top[0] + (bottom[0] - top[0]) * v, top[1] + (bottom[1] - top[1]) * v)

    cells = []
    for c in range(columns):
        column = []
        for r in range(rows):
            quad = [at(c / columns, r / rows), at((c + 1) / columns, r / rows),
                    at((c + 1) / columns, (r + 1) / rows), at(c / columns, (r + 1) / rows)]
            mx = sum(p[0] for p in quad) / 4
            my = sum(p[1] for p in quad) / 4
            column.append([[round(x + (mx - x) * gap, 1), round(y + (my - y) * gap, 1)] for x, y in quad])
        cells.append(column)
    return cells


def pulled_in(points, amount):
    """A shape shrunk toward its middle, leaving an even margin around it."""
    mx = sum(p[0] for p in points) / len(points)
    my = sum(p[1] for p in points) / len(points)
    return [[round(x + (mx - x) * amount, 1), round(y + (my - y) * amount, 1)] for x, y in points]


def main_buttons(outline, channel, seams):
    """The two main buttons of a mouse seen from above, cut from its outline.

    `channel` is the (left, right) edge of the gap that holds the wheel, and
    `seams` the line each button ends at, from the channel out to the edge.
    Each button is the part of the outline beside the channel and above its
    seam, so the buttons follow the mouse's edge exactly.
    """
    (lx0, ly0), (lx1, ly1) = seams[0]
    (rx0, ry0), (rx1, ry1) = seams[1]
    left = [p for p in outline if p[0] <= channel[0] and p[1] <= ly0 + (lx0 - p[0]) * (ly1 - ly0) / (lx0 - lx1)]
    right = [p for p in outline if p[0] >= channel[1] and p[1] <= ry0 + (p[0] - rx0) * (ry1 - ry0) / (rx1 - rx0)]
    # Order each along the edge, starting from the channel.
    left.sort(key=lambda p: -p[0])
    right.sort(key=lambda p: p[0])
    # Each seam runs from the channel to where it meets the edge, which is
    # the last edge point kept.
    left_shape = [[channel[0], left[0][1]]] + left + [[lx0, ly0]]
    right_shape = [[channel[1], right[0][1]]] + right + [[rx0, ry0]]
    return pulled_in(left_shape, 0.045), pulled_in(right_shape, 0.045)


def grown(corners, by):
    """A four-cornered area pushed outward from its middle by `by` units."""
    mx = sum(p[0] for p in corners) / 4
    my = sum(p[1] for p in corners) / 4
    out = []
    for x, y in corners:
        d = math.hypot(x - mx, y - my)
        out.append([round(x + (x - mx) / d * by, 1), round(y + (y - my) / d * by, 1)])
    return out


def k70_max(source):
    full = Image.open(source / "k70-max/body/na.jpg")
    box = device_box(full)
    dx, dy = box[0], box[1]
    width, height = box[2] - box[0], box[3] - box[1]
    place = lambda x, y, w, h: [x - dx, y - dy, w, h]
    return {
        "kind": "keyboard",
        "width": width,
        "height": height,
        # The case, then the raised bar along the top with its glossy panel.
        "body": [12, 12, width - 24, height - 24, 16],
        "parts": [
            {"box": [12, 12, width - 24, 150], "radius": 16},
            {"box": place(1150, 168, 680, 104), "radius": 8, "solid": True},
        ],
        # Where layout point (0, rowOffset) is, and diagram units per layout unit.
        "origin": [382 - dx, 348 - dy],
        "scale": [1.2345, 1.161],
        "rowOffset": 90,
        "rowShift": {"1": -10},
        # Controls that are not on the key grid.
        "overrides": {
            "PF": place(386, 194, 94, 51), "BTS": place(480, 194, 94, 51), "LOCK": place(574, 194, 94, 51),
            "Logo": place(1440, 207, 100, 26), "MUTE": place(2286, 194, 88, 51),
            "WH -": place(2379, 194, 98, 51), "WH +": place(2477, 194, 98, 51),
        },
        # What to print on controls whose name is not a legend.
        "symbols": {"PF": "Profile", "BTS": "Light", "LOCK": "Lock", "MUTE": "Mute", "WH -": "", "WH +": "", "Logo": ""},
        "roller": place(2379, 194, 196, 51),
    }


# The thumb pad: twelve buttons in four columns of three, numbered down each
# column from 3-2-1 on the left to 12-11-10 on the right. It is drawn square
# to the page: a diagram, not a perspective view.
PAD = [[575, 305], [1085, 305], [1085, 650], [575, 650]]
THUMB = {}
for column, numbers in enumerate([[3, 2, 1], [6, 5, 4], [9, 8, 7], [12, 11, 10]]):
    for row, number in enumerate(numbers):
        THUMB[number] = grid(PAD, 4, 3, 0.09)[column][row]


def scimitar_elite(source):
    folder = source / "scimitar-elite-rgb-wireless/body/black"
    side_full = Image.open(folder / "body_2.jpg")
    top_full = Image.open(folder / "body_1.jpg")
    side = side_full.crop(device_box(side_full, pad=14))
    top = top_full.crop(device_box(top_full, pad=14)).rotate(-90, expand=True)
    height, side_height, gap = 900, 620, 60
    side = side.resize((round(side.width * side_height / side.height), side_height), Image.LANCZOS)
    top = top.resize((round(top.width * height / top.height), height), Image.LANCZOS)
    side_line = silhouette(side, 0, (height - side_height) // 2)
    top_line = silhouette(top, side.width + gap, 0)
    left_button, right_button = main_buttons(top_line, (1886, 1966), ([(1886, 355), (1672, 446)], [(1966, 357), (2141, 429)]))
    return {
        "kind": "mouse",
        "width": side.width + gap + top.width,
        "height": height,
        # Two views: the thumb side, then the top.
        "outlines": [side_line, top_line],
        # The panel the thumb buttons sit in.
        "details": [grown(PAD, 40) + [grown(PAD, 40)[0]]],
        "shapes": {
            **{f"Side Button {number}": cell for number, cell in THUMB.items()},
            "Left Button": left_button,
            "Right Button": right_button,
            "Middle Button": [[1898, 96], [1954, 96], [1954, 262], [1898, 262]],
            "DPI Button": [[1898, 350], [1954, 350], [1954, 414], [1898, 414]],
            "Profile Switch": [[1898, 424], [1954, 424], [1954, 488], [1898, 488]],
        },
        # What each button shows when lit, and which lighting zone lights it.
        "labels": {f"Side Button {n}": {"text": str(n), "zone": 0} for n in range(1, 13)},
        # Other lights: [x, y, width, height] and the zone that colors each.
        "lights": [
            {"box": [1898, 306, 56, 16], "zone": 1},
            {"box": [1878, 704, 96, 50], "zone": 1},
        ],
    }


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: make-device-diagrams.py <reference pictures folder>")
    source = pathlib.Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for slug, diagram in {"k70-max": k70_max(source), "scimitar-elite": scimitar_elite(source)}.items():
        (OUT / f"{slug}.json").write_text(json.dumps(diagram, separators=(",", ":")) + "\n")
        print(f"wrote {slug}: {diagram['width']}x{diagram['height']}")


if __name__ == "__main__":
    main()
