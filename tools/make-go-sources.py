#!/usr/bin/env python3
"""Writes the Flatpak source list for OpenLinkHub's Go dependencies, so the
build needs no network (a Flathub requirement).

    tools/make-go-sources.py packaging/openlinkhub-modules.txt > packaging/openlinkhub-go-sources.json

The modules file is vendor/modules.txt from running `go mod vendor` in the
patched OpenLinkHub tree. Each module is fetched once from the Go module
proxy to record its checksum; the build unpacks them into vendor/.
"""
import hashlib, json, re, sys, urllib.request

def escaped(path):
    # The proxy spells an upper-case letter as "!" plus its lower-case form.
    return re.sub(r"[A-Z]", lambda m: "!" + m.group(0).lower(), path)

sources = []
for line in open(sys.argv[1]):
    found = re.match(r"# (\S+) (v\S+)$", line.strip())
    if not found:
        continue
    module, version = found.groups()
    url = f"https://proxy.golang.org/{escaped(module)}/@v/{escaped(version)}.zip"
    with urllib.request.urlopen(url) as reply:
        digest = hashlib.sha256(reply.read()).hexdigest()
    sources.append({
        "type": "archive",
        "url": url,
        "sha256": digest,
        "dest": "vendor/" + module,
        # Inside the zip everything sits under "<module>@<version>/".
        "strip-components": module.count("/") + 1,
    })
json.dump(sources, sys.stdout, indent=4)
print()
