# How devices are drawn

Halo contains no manufacturer images. Each device is drawn one of three ways, best first.

## 1. Hand-made diagram

`src/devices/<slug>.json`, for example `k70-max.json` and `scimitar-elite.json`. A diagram has the
case outline, details, where each light is, and (for mice) the shape of every button so it can be
clicked. `tools/make-device-diagrams.py <folder of reference pictures>` writes them; the reference
pictures are used only to measure proportions and are not part of this repository.

The slug is the product name in lower case with dashes. Add the file to `qt_add_resources` in
`CMakeLists.txt`.

## 2. Keyboard layout from OpenLinkHub

Any keyboard without a diagram is laid out from OpenLinkHub's own layout data by `buildGrid` in
`layout.js`: a grid of equal columns, wider keys from `keySpace` (`wide`, `wide3`…), blank cells
from `keyEmpty`, and light bars along the top and sides. This follows the CSS OpenLinkHub's web
page uses, so a keyboard looks the same in both.

## 3. Traced outline

`src/devices/outlines.json` holds a simple silhouette for about 230 products, made by
`tools/make-outlines.py`. `DeviceImages::outline` picks the closest name. Lights are shown as a row
of labeled dots under the outline, because an outline does not know where the lights are.

Devices made of parts (hubs, coolers, memory, power supplies) show live readings instead of a
drawing.

## Adding support for a device

Usually nothing is needed: sections appear from the device's data. If a screen is wrong:

1. Save the device data (`curl http://127.0.0.1:27003/api/devices/<serial>`) into
   `tests/fakehub/data/<NAME>.json` and add it to `all.json` there.
2. Open it: `halo --hub http://127.0.0.1:27103 --route <NAME>/lighting`.
3. Fix the section, and add the route to `tests/smoke.py`.
