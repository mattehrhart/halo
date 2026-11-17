# Changelog

Each release has a section here. CI publishes that section as the GitHub release notes.

## 0.3.0 - 2026-11-17

First public release.

### Devices
- Keyboards: lighting effects with a preview, per-key colors, key assignments, actuation points, polling rate, game mode.
- Mice: button assignments, zone lighting, DPI stages, sleep and polling settings.
- Headsets: lighting and device settings.
- Hubs, coolers, memory and power supplies: fan speeds, temperatures, power draw, fan curves, lighting, LCD settings, LED port setup.

### App
- Tray icon with profiles and battery level.
- Start at login and start minimized.
- Low-battery alerts.
- One switch to turn all lights off.
- Setup page on first run.

### Included
- OpenLinkHub 0.9.4, with a patch that adds two API calls: set the active DPI stage, and list LCD images.

### Tested hardware
- K70 MAX keyboard and Scimitar Elite Wireless mouse.
- Other devices are checked with simulated devices only.

### Install
```sh
flatpak install --user halo.flatpak
flatpak run io.github.mattehrhart.Halo
```
