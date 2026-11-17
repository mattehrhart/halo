# Contributing

Bug reports and device reports are the most useful thing you can send. Most screens have only been
checked with simulated devices, so reports from real hardware help a lot.

## Reporting a problem with a device

Include:

1. The device name as Halo shows it.
2. What you did and what happened.
3. The device data: `curl http://127.0.0.1:27003/api/devices/<serial>` (the serial is in
   `curl http://127.0.0.1:27003/api/`). Remove serial numbers if you prefer.

That file can be dropped into `tests/fakehub/data/` to reproduce the screen without the hardware.

## Changing code

- Build and run the tests as described in [docs/TESTING.md](docs/TESTING.md). Both suites must pass.
- When you add a screen or a section, add its route to `ROUTES` in `tests/smoke.py`.
- Check new screens at `--size 960x660` and at a large size.
- User-facing text: American spelling, short and plain. Controls apply immediately; no Apply buttons.
- Loading shows a skeleton, an empty list shows an empty state, and a refused change shows the
  reason OpenLinkHub gave.
- Do not add manufacturer images or logos. Devices are drawn (see [docs/DEVICES.md](docs/DEVICES.md)).

## Changing OpenLinkHub

Halo carries a small patch in `packaging/openlinkhub-halo.patch`. Keep it small and generic, since
the aim is to offer it upstream. After changing Go dependencies, regenerate the offline source list:

```sh
tools/make-go-sources.py packaging/openlinkhub-modules.txt > packaging/openlinkhub-go-sources.json
```
