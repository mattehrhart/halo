#!/usr/bin/env python3
"""Prints the CHANGELOG.md section for one version, for the GitHub release.

    tools/release-notes.py 0.3.0

Exits with an error if the version has no section, so a release cannot be
published without notes.
"""
import pathlib
import re
import sys

version = sys.argv[1].lstrip("v")
text = (pathlib.Path(__file__).resolve().parent.parent / "CHANGELOG.md").read_text()
found = re.search(rf"^## {re.escape(version)}\b[^\n]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
if not found or not found.group(1).strip():
    raise SystemExit(f"CHANGELOG.md has no notes for {version}")
print(found.group(1).strip())
