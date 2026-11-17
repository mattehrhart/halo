# How Halo is put together

```
 Halo (Qt 6 / QML / Kirigami)  ──HTTP──▶  OpenLinkHub (Go)  ──USB/HID──▶  devices
        this repository                    bundled, patched
```

Halo never touches a device. Everything goes through OpenLinkHub's REST API on
`http://127.0.0.1:27003`.

## The service

- If something already answers on port 27003, Halo uses it.
- Otherwise `HubService` (in `src/main.cpp`) copies the bundled OpenLinkHub from
  `/app/lib/openlinkhub` to Halo's data folder and runs it from there, because OpenLinkHub keeps its
  settings beside its program. The copy is refreshed when the bundled program changes; saved
  profiles are never overwritten.
- The service lives as long as Halo does. With "Keep Running in Tray" and "Start at Login" it is up
  for the whole session.
- Devices are only reachable after a udev rule tags them for the logged-in user. A Flatpak cannot
  install that, so the setup page (`HomePage.qml`) writes the rule file and shows the one command
  that installs it.

## The patch

`packaging/openlinkhub-halo.patch` adds two calls to OpenLinkHub 0.9.4:

| Call | Why |
|---|---|
| `POST /api/mouse/dpiStage {deviceId, dpiStage}` | Upstream can only change the active DPI stage from the mouse's own button |
| `GET /api/lcd/images` | Upstream lists uploaded LCD images only inside its web page |

Halo works against an unpatched OpenLinkHub too; those two features then report an error or hide.

## No push channel

OpenLinkHub cannot announce changes. To show what happens on the device (a DPI button press, a
profile key), an open device page re-reads its device and compares the answer with the last one:
every 250 ms for mice and headsets, 500 ms for keyboards, 1 s for hubs and coolers. A read takes
about a millisecond locally. Nothing is redrawn unless the answer changed.

For devices made of parts, measurements (RPM, temperature, watts) are split from settings
(`takeReadings` in `layout.js`), so a fan speed changing does not rebuild every control.

## Source layout

| Path | What |
|---|---|
| `src/main.cpp` | `HubService` (bundled service, permissions, image upload), `Shell` (tray, autostart, notifications, single instance), `DeviceImages` (diagram lookup), command line |
| `src/qml/Main.qml` | Window, routing to a device page, lights off, battery alerts |
| `src/qml/Hub.qml` | Singleton: the device list and every HTTP call |
| `src/qml/KeyboardPage.qml`, `Kb*.qml` | Keyboard page and its sections |
| `src/qml/MousePage.qml`, `Ms*.qml` | Page for every other device; mouse and headset sections |
| `src/qml/Sys*.qml`, `FanCurves.qml` | Sections for hubs, coolers, memory, power supplies, screens |
| `src/qml/KeyboardView.qml`, `MouseView.qml`, `OutlineView.qml`, `DeviceGlyph.qml` | Device drawings |
| `src/qml/layout.js` | Pure logic: key layouts, effect colors, readings, names |
| `src/devices/` | Device diagrams and traced outlines |
| `tests/` | Unit tests, screen smoke test, stand-in hub |
| `tools/` | Generators for diagrams, outlines and the offline Go source list |

A device page is one shape everywhere: device tabs on top, a section list beside the device
drawing (or live readings), and a row of cards below for the chosen section. Sections appear only
when the device's data has something for them.

## Lighting previews

`effectColor` in `layout.js` follows OpenLinkHub's own formulas (`src/rgb/*.go` upstream): effects
run per light in LED order, not by position. Previews are not synchronized to the device clock, and
random effects are approximations.

Keyboards that have no brightness control in OpenLinkHub are dimmed by Halo: it scales the colors it
sends and remembers the undimmed ones per effect.

## Command line

| Option | Use |
|---|---|
| `--hub <url>` | Talk to another OpenLinkHub (for example the stand-in hub) |
| `--minimized` | Start in the tray |
| `--route <device>/<section>[/<selection>]` | Open a page; device is a kind (`keyboard`, `mouse`) or a serial |
| `--size WxH` | Window size |
| `--grab <file.png>` `--grab-delay <ms>` | Save a capture and exit (used by the tests) |
| `--separate` | Run beside a Halo that is already open, without a tray icon (for testing) |
