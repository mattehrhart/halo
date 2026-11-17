# Testing

No hardware is needed for any of this.

## Run the tests

Inside the KDE SDK (so Qt and Kirigami match the Flatpak):

```sh
flatpak run --command=sh --devel --share=network --filesystem="$PWD" org.kde.Sdk//6.11 -c '
  cmake -B build -G Ninja && cmake --build build &&
  ctest --test-dir build --output-on-failure'
```

| Test | What it checks |
|---|---|
| `layout` (`tests/tst_layout.qml`) | The logic in `layout.js`: key layouts, light bars, readings, effect colors staying in range, preview brightness never going backwards |
| `screens` (`tests/smoke.py`) | Opens every screen for every kind of device at 960x660 and 1920x1080 against the stand-in hub; fails on any QML error or blank capture |
| `appstreamtest` | The store metadata file is valid |

`tests/smoke.py build/bin/halo --keep shots/` keeps the captures so you can look at them.

CI runs the same tests and builds the Flatpak on every push (`.github/workflows/ci.yml`).

## The stand-in hub

`tests/fakehub/server.py` answers like OpenLinkHub from the files in `tests/fakehub/data/`:

```sh
tests/fakehub/server.py 27103 &
build/bin/halo --hub http://127.0.0.1:27103
build/bin/halo --hub http://127.0.0.1:27103 --route LSH1/parts --size 960x660
```

- Changes are accepted and ignored, so controls can be clicked freely.
- `touch tests/fakehub/slow` delays device reads by four seconds, to see loading skeletons.
- `HALO_FAKE_ONLY=K70MAX,SCIMITAR` lists only those devices.

The K70 MAX and Scimitar files are real device data (serial numbers replaced). The others are
synthetic: real key layouts from OpenLinkHub's database, and hub, memory and power-supply data
written from OpenLinkHub's source. They prove the screens open, not that the hardware behaves.

## What the tests do not cover

- Anything on real hardware other than the author's K70 MAX and Scimitar Elite.
- Clicking: the smoke test opens screens but does not press controls.
- The tray, autostart and notifications.
- The patched OpenLinkHub calls. Check those against a running service:

```sh
curl -X POST -d '{"deviceId":"<serial>","dpiStage":2}' http://127.0.0.1:27003/api/mouse/dpiStage
curl http://127.0.0.1:27003/api/lcd/images
```
