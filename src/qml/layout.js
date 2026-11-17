// Turns OpenLinkHub's row/key description of a keyboard into absolute
// positions. In that data each key's "left" is the gap from the key before
// it and "top" is the gap above the row, as in the web page it was made for.
.pragma library

const NAMES = {
    "<---": "Backspace",
    "----------": "",
    "WH +": "Vol +",
    "WH -": "Vol −",
    "PF": "Profile",
    "BTS": "Light",
    "LOCK": "Lock",
    "MUTE": "Mute",
    "STOP": "■",
    "PREV": "⏮",
    "PLAY": "⏯",
    "NEXT": "⏭",
    "CAPS": "Caps",
    "Logo": ""
}

function label(name) {
    return NAMES.hasOwnProperty(name) ? NAMES[name] : name
}

// A name for lists and messages, where a blank key cap would be unhelpful.
function spokenName(name) {
    if (name === "----------")
        return "Space"
    if (name === "Logo")
        return "Light bar"
    const text = label(name)
    return text === "" ? name : text
}

function build(rows) {
    const keys = []
    let rowY = 0
    let width = 0
    let height = 0
    const rowIds = Object.keys(rows || {}).map(Number).sort((a, b) => a - b)
    for (const r of rowIds) {
        const row = rows[String(r)]
        const ids = Object.keys(row.keys).map(Number).sort((a, b) => a - b)
        let x = 0
        let rowTop = 0
        let rowHeight = Infinity
        for (const id of ids) {
            const k = row.keys[String(id)]
            // OpenLinkHub leaves out any measurement that is zero.
            const left = k.left || 0, top = k.top || 0, w = k.width || 0, h = k.height || 0
            x += left
            keys.push({
                id: id,
                row: r,
                x: x,
                y: rowY + top,
                w: w,
                h: h,
                name: k.keyName,
                label: label(k.keyName),
                raw: k
            })
            x += w
            width = Math.max(width, x)
            height = Math.max(height, rowY + top + h)
            rowTop = top
            rowHeight = Math.min(rowHeight, h)
        }
        if (ids.length > 0)
            rowY += rowTop + rowHeight
    }
    const byId = {}
    for (const key of keys) {
        key.cx = (key.x + key.w / 2) / Math.max(1, width)
        key.cy = (key.y + key.h / 2) / Math.max(1, height)
        byId[key.id] = key
    }
    return { keys: keys, byId: byId, width: width, height: height }
}

// The same data read the way OpenLinkHub's own page lays it out: a grid of
// equal columns where a key takes one column unless its class says wider,
// with blank cells before it. Used for every model Halo has no diagram for.
// Light bars around the edge are not in the grid; they are spread along the
// top and sides.
function buildGrid(rows) {
    const KEY = 65, GAP = 15, PITCH = KEY + GAP
    const keys = []
    const bars = { top: [], left: [], right: [] }
    let y = 0
    let width = 0
    const rowIds = Object.keys(rows || {}).map(Number).sort((a, b) => a - b)
    for (const r of rowIds) {
        const row = rows[String(r)]
        const ids = Object.keys(row.keys).map(Number).sort((a, b) => a - b)
        const placed = []
        let column = 0
        let rowHeight = 0
        for (const id of ids) {
            const k = row.keys[String(id)]
            const kind = (k.keySpace || "keyboard-key") + " " + (k.css || "")
            const entry = { id: id, row: r, name: k.keyName, label: k.onlyColor ? "" : label(k.keyName), raw: k }
            if (/-led-|wide100|height\d/.test(kind)) {
                entry.bar = true
                bars[/wide100/.test(kind) ? "top" : /right/.test(kind) ? "right" : "left"].push(entry)
                continue
            }
            column += (k.keyEmpty || []).length + (Array.isArray(k.spacing) ? k.spacing.length : (k.spacing || 0))
            const wide = /wide(\d*)/.exec(kind)
            const span = wide ? (wide[1] === "" ? 2 : Number(wide[1])) : 1
            const half = /half/.test(kind)
            entry.x = column * PITCH
            entry.w = span * PITCH - GAP
            entry.h = /125/.test(kind) ? 2 * KEY + GAP : half ? 30 : KEY
            entry.dy = /top-?32/.test(kind) ? 35 : 0
            // A row of half-height color-only cells is a light strip.
            if (k.onlyColor && half)
                entry.bar = true
            column += span
            if (/keyboard-key empty/.test(kind))
                continue
            // A key pushed down makes its whole row taller; a double-height key does not.
            rowHeight = Math.max(rowHeight, entry.dy + Math.min(entry.h, KEY))
            placed.push(entry)
        }
        if (placed.length === 0)
            continue
        if (row.top)
            y += GAP
        for (const entry of placed) {
            entry.y = y + entry.dy
            keys.push(entry)
            width = Math.max(width, entry.x + entry.w)
        }
        y += rowHeight + GAP
    }
    let height = Math.max(0, y - GAP)
    for (const key of keys)
        height = Math.max(height, key.y + key.h)

    // Light bars: a strip above the keys and one down each side.
    const BAR = 12, AWAY = 14
    const inset = bars.left.length > 0 ? BAR + AWAY : 0
    const drop = bars.top.length > 0 ? BAR + AWAY : 0
    for (const key of keys) {
        key.x += inset
        key.y += drop
    }
    width += inset + (bars.right.length > 0 ? BAR + AWAY : 0)
    height += drop
    bars.top.forEach(function (entry, i) {
        const each = width / bars.top.length
        entry.x = i * each + 2; entry.y = 0; entry.w = each - 4; entry.h = BAR
        keys.push(entry)
    })
    for (const side of ["left", "right"]) {
        bars[side].forEach(function (entry, i) {
            const each = (height - drop) / bars[side].length
            entry.x = side === "left" ? 0 : width - BAR
            entry.y = drop + i * each + 2; entry.w = BAR; entry.h = each - 4
            keys.push(entry)
        })
    }

    const byId = {}
    for (const key of keys) {
        key.cx = (key.x + key.w / 2) / Math.max(1, width)
        key.cy = (key.y + key.h / 2) / Math.max(1, height)
        byId[key.id] = key
    }
    return { keys: keys, byId: byId, width: width, height: height }
}

// Whether a key has a magnetic switch whose press distance can be set.
function adjustable(raw) {
    return !raw.noActuation && !raw.onlyColor && raw.actuationPoint > 0
}

function rgb(c) {
    if (!c)
        return Qt.rgba(0, 0, 0, 1)
    return Qt.rgba(c.red / 255, c.green / 255, c.blue / 255, 1)
}

function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
}

const RAINBOWS = ["rainbow", "pastelrainbow", "spiralrainbow", "pastelspiralrainbow", "rainbowwave", "colorwarp", "watercolor", "nebula"]

const PASTELS = [[244,253,255],[255,218,247],[255,140,230],[254,96,219],[255,17,206],[254,28,206],[255,106,225],[255,184,241],
                 [255,230,248],[255,255,203],[255,255,155],[255,255,80],[255,255,33],[216,250,52],[161,244,119],[105,237,185],
                 [14,208,250],[37,210,255],[114,227,255],[159,235,253]]

function frac(v) {
    return v - Math.floor(v)
}

function scaled(c, k) {
    return Qt.rgba(c.r * k, c.g * k, c.b * k, 1)
}

// A repeatable "random" color for a numbered cycle, for effects that pick
// a new random color each time round.
function cycleColor(n) {
    return Qt.hsva(frac(Math.sin(n * 12.9898 + 4.1) * 43758.5453), 1, 1, 1)
}

// What one light shows for an effect, following OpenLinkHub's own effect
// code (src/rgb/*.go): light number `i` of `n`, `t` seconds after the
// effect started, its two colors, and its speed setting (1 is fastest).
// The start time is not known, so the preview runs the same pattern at the
// same pace as the device, not in step with it.
function effectColor(mode, i, n, t, start, end, speed) {
    const pace = Math.max(1, speed)
    const progress = frac(t / pace)
    const along = i / n
    switch (mode) {
    case "rainbow": {
        // Five bands: red, yellow, green, cyan, blue, back to red.
        const stops = [[1,0,0],[1,1,0],[0,1,0],[0,1,1],[0,0,1],[1,0,0]]
        const pos = frac(along + t / pace) * 5
        const a = stops[Math.floor(pos)], b = stops[Math.floor(pos) + 1], f = frac(pos)
        return Qt.rgba(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 1)
    }
    case "pastelrainbow": {
        const pos = frac(along + t / pace) * PASTELS.length
        const a = PASTELS[Math.floor(pos)], b = PASTELS[(Math.floor(pos) + 1) % PASTELS.length], f = frac(pos)
        return Qt.rgba((a[0] + (b[0] - a[0]) * f) / 255, (a[1] + (b[1] - a[1]) * f) / 255, (a[2] + (b[2] - a[2]) * f) / 255, 1)
    }
    case "watercolor":
        return Qt.hsva(frac(along + t / pace * 4), 0.4, 1, 1)
    case "wave": {
        const level = 0.5 * (1 + Math.sin(2 * Math.PI * (t * 10 / pace + i) / pace))
        return scaled(mix(start, end, level), level)
    }
    case "colorpulse":
        return mix(start, end, progress)
    case "colorshift":
        return Math.floor(t / pace) % 2 === 0 ? mix(start, end, progress) : mix(end, start, progress)
    case "colorwarp": {
        const cycle = Math.floor(t / pace)
        return mix(cycleColor(cycle), cycleColor(cycle + 1), progress)
    }
    case "circle":
    case "circleshift": {
        // A soft point of light travelling along the lights.
        let distance = Math.abs(progress - along)
        if (distance > 0.5)
            distance = 1 - distance
        return scaled(mix(start, end, along), Math.max(0, Math.cos(distance * Math.PI * 6)))
    }
    case "spinner": {
        const lit = Math.floor(progress * n)
        return i === lit ? mix(start, end, Math.min(1, lit / 40)) : Qt.rgba(0, 0, 0, 1)
    }
    case "rotator": {
        // The first color, brightening and dimming in a band that moves along.
        const hue = (t * 500 / pace + i * 5) % 360
        const level = hue < 120 ? 0 : hue < 180 ? (hue - 120) / 60 : hue < 300 ? 1 : (360 - hue) / 60
        return scaled(start, level)
    }
    case "sequential": {
        // Fills light by light with one color, then with the other.
        const even = Math.floor(t / pace) % 2 === 0
        return i <= Math.floor(progress * n) ? (even ? start : end) : (even ? end : start)
    }
    case "marquee": {
        // Pairs of lights on and off, stepping along, between the two colors.
        const shift = progress < 0.5 ? progress * 2 : (1 - progress) * 2
        return (i + Math.floor(progress * 4)) % 4 < 2 ? mix(start, end, shift) : Qt.rgba(0, 0, 0, 1)
    }
    case "nebula": {
        const w = (Math.sin((along + frac(t / (pace * 5))) * Math.PI * 2) + 1) * 0.5
        const hue = w < 0.45 ? 220 + 80 * w / 0.45 : w < 0.75 ? 300 - 120 * (w - 0.45) / 0.3 : 180 + 40 * (w - 0.75) / 0.25
        const value = w < 0.45 ? 0.4 + 0.5 * w : w < 0.75 ? 0.6 : 0.5
        return Qt.hsva(hue / 360, 0.9, value * 0.6, 1)
    }
    case "flickering":
        // A steady blend from the first color to the second along the lights.
        return mix(start, end, along)
    case "storm":
        return start
    case "gradient":
        return Math.floor(t / 5) % 2 === 0 ? mix(start, end, frac(t / 5)) : mix(end, start, frac(t / 5))
    }
    return mix(start, end, 0.5 + 0.5 * Math.sin(2 * Math.PI * (along + progress)))
}

// How a light of a given strength looks, as a color for the screen.
// A light at half power looks far brighter than half-gray on a monitor, so
// the signal is put through the screen's own curve; `share` is any extra
// dimming the device applies (0 to 1).
function onScreen(c, share) {
    const curve = v => Math.pow(Math.max(0, Math.min(1, v * share)), 1 / 2.2)
    return Qt.rgba(curve(c.r), curve(c.g), curve(c.b), 1)
}

// The color to draw part of a diagram in, for a light of color `tint`.
// Unlit, it is the outline ink at `low` opacity; as the light comes up it
// takes the light's hue and rises steadily to `high` opacity. Nothing drawn
// for a lit key is ever fainter than the same thing drawn unlit.
function lightInk(tint, ink, low, high) {
    const strength = Math.max(tint.r, tint.g, tint.b)
    if (strength <= 0.001)
        return Qt.rgba(ink.r, ink.g, ink.b, low)
    const hue = Math.min(1, strength * 2.5)
    return Qt.rgba(ink.r + (tint.r / strength - ink.r) * hue,
                   ink.g + (tint.g / strength - ink.g) * hue,
                   ink.b + (tint.b / strength - ink.b) * hue,
                   low + (high - low) * strength)
}

// The extra dimming a device applies on top of the colors it is sent.
function dimming(device, animated) {
    const profile = device.DeviceProfile
    // Mice: OpenLinkHub's brightness slider, 0 to 100.
    if (profile.BrightnessSlider !== undefined && profile.BrightnessSlider !== null)
        return profile.BrightnessSlider / 100
    // Keyboards: moving effects use OpenLinkHub's steps (low, medium, full, dark).
    if (animated && profile.Brightness > 0) {
        const step = [1, 0.3, 0.6, 1, 0][profile.Brightness]
        return step === undefined ? 1 : step
    }
    return 1
}

// The color a key shows for the device's current effect, `clock` seconds
// into it, as it looks at the device's brightness.
function keyColor(key, device, clock) {
    if (!device || key.raw.noColor)
        return Qt.rgba(0, 0, 0, 1)
    const mode = device.DeviceProfile.RGBProfile
    if (mode === "off" || device.DeviceProfile.RgbOff)
        return Qt.rgba(0, 0, 0, 1)
    if (mode === "keyboard")
        return onScreen(rgb(key.raw.color), dimming(device, false))
    const profile = device.Rgb && device.Rgb.profiles ? device.Rgb.profiles[mode] : null
    const start = profile ? rgb(profile.start) : Qt.rgba(1, 1, 1, 1)
    const end = profile ? rgb(profile.end) : start
    if (mode === "static")
        return onScreen(start, dimming(device, false))
    if (mode === "cpu-temperature" || mode === "gpu-temperature") {
        const temp = mode === "cpu-temperature" ? device.CpuTemp : device.GpuTemp
        return onScreen(Qt.hsva(Math.max(0, 0.33 - Math.max(0, temp - 35) / 150), 1, 1, 1), dimming(device, true))
    }
    const count = Math.max(1, device.LEDChannels || 1)
    const light = key.light !== undefined ? key.light
        : key.raw.packetIndex && key.raw.packetIndex.length > 0 ? key.raw.packetIndex[0] % count : 0
    return onScreen(effectColor(mode, light, count, clock, start, end, profile ? profile.speed : 4), dimming(device, true))
}

// The lighting mode in which each zone has its own color, by device kind.
const ZONE_MODES = ["mouse", "headset", "mousepad", "stand", "controller"]

// Effects in the order to list them: the plain choices first.
function orderedModes(modes) {
    const first = ["keyboard"].concat(ZONE_MODES, ["static", "off"])
    const list = (modes || []).slice()
    list.sort((a, b) => {
        const ia = first.indexOf(a), ib = first.indexOf(b)
        if (ia >= 0 || ib >= 0)
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
        return title(a).localeCompare(title(b))
    })
    return list
}


function zoneMode(device) {
    const modes = device && device.RGBModes ? device.RGBModes : []
    return ZONE_MODES.find(m => modes.indexOf(m) >= 0) || ""
}

const FIXED = ["keyboard", "off", "cpu-temperature", "gpu-temperature", "liquid-temperature"].concat(ZONE_MODES)

// Whether an effect has a first/second color the user can set.
function usesColors(mode) {
    return FIXED.indexOf(mode) < 0 && RAINBOWS.indexOf(mode) < 0
}

// Whether an effect moves, and so has a speed.
function usesSpeed(mode) {
    return FIXED.indexOf(mode) < 0 && mode !== "static" && mode !== "storm"
}

// "1000 Hz / 1 msec" -> "1000 Hz (1 ms)"
function rate(text) {
    const parts = String(text).split("/")
    if (parts.length !== 2)
        return String(text)
    return parts[0].trim() + " (" + parts[1].trim().replace("msec", "ms") + ")"
}

// "Win Key" -> "Win key": sentence case for checkbox and switch labels.
function sentence(text) {
    return text.split(" ").map((word, index) => index === 0 || word.length <= 1 || /^(Win|Alt|Tab|Shift|Ctrl|F[0-9]+)$/.test(word) ? word : word.toLowerCase()).join(" ")
}

function hex(c) {
    const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
    return "#" + h(c.r) + h(c.g) + h(c.b)
}

function title(mode) {
    const special = {
        "keyboard": "Per-Key Colors",
        "mouse": "Zone Colors",
        "headset": "Zone Colors",
        "mousepad": "Zone Colors",
        "stand": "Zone Colors",
        "controller": "Zone Colors",
        "off": "Lights Off",
        "static": "Static Color",
        "colorpulse": "Color Pulse",
        "colorshift": "Color Shift",
        "colorwarp": "Color Warp",
        "circleshift": "Circle Shift",
        "pastelrainbow": "Pastel Rainbow",
        "cpu-temperature": "CPU Temperature",
        "gpu-temperature": "GPU Temperature"
    }
    if (special.hasOwnProperty(mode))
        return special[mode]
    return mode.charAt(0).toUpperCase() + mode.slice(1)
}

// --- Devices made of parts (hubs, coolers, memory, power supplies) ---

// Fields that change by themselves many times a minute. They are kept apart
// from the settings so a new fan speed does not rebuild the whole page.
const READINGS = ["rpm", "vrmRpm", "gpuRpm", "temperature", "temperatureString", "gpuTemperature", "gpuTemperatureString",
                  "vrmTemperature", "vrmTemperatureString", "psuTemperature", "psuTemperatureString",
                  "volts", "amps", "watts", "powerOut", "powerOutString"]

// Splits a device as read from OpenLinkHub into its settings (returned in
// place) and its readings by part number.
function takeReadings(device) {
    const out = {}
    delete device.CpuTemp
    delete device.GpuTemp
    delete device.InputVoltage
    const parts = device.devices
    if (!parts || typeof parts !== "object")
        return out
    for (const id of Object.keys(parts)) {
        const part = parts[id]
        if (!part || typeof part !== "object")
            continue
        const now = {}
        for (const field of READINGS) {
            if (part[field] !== undefined) {
                now[field] = part[field]
                delete part[field]
            }
        }
        out[id] = now
    }
    return out
}

// The parts in port order.
function parts(device) {
    if (!device || !device.devices || typeof device.devices !== "object")
        return []
    return Object.keys(device.devices).map(Number).sort((a, b) => a - b)
        .map(id => device.devices[String(id)]).filter(p => p && typeof p === "object" && p.MainPSU !== true)
}

function partName(part) {
    return part.label && part.label !== "" ? part.label : (part.name || "Part " + part.channelId)
}

// A short description of what a part is.
function partKind(part) {
    if (part.sku)
        return [part.sku, part.size ? part.size + " GB" : "", part.speed ? part.speed + " MHz" : ""].filter(t => t !== "").join("  ·  ")
    if (part.IsTemperatureProbe)
        return "Temperature probe"
    if (part.name && part.name !== partName(part))
        return part.name
    return part.description || ""
}

function amount(value, digits, unit) {
    return typeof value === "number" && isFinite(value) ? value.toFixed(digits) + " " + unit : ""
}

// What a part is measuring right now, most important first.
function readingLines(part, now) {
    const lines = []
    if (part.HasSpeed === true || now.rpm > 0)
        lines.push((now.rpm || 0) + " RPM")
    if (now.temperatureString && now.temperature !== 0)
        lines.push(now.temperatureString)
    else if (typeof now.temperature === "number" && now.temperature > 0)
        lines.push(now.temperature.toFixed(1) + " °C")
    if (part.HasWatts === true || part.IsPSU === true)
        lines.push(amount(now.watts, 1, "W") || now.powerOutString || "")
    if (part.HasVolts === true)
        lines.push(amount(now.volts, 2, "V"))
    if (part.HasAmps === true)
        lines.push(amount(now.amps, 1, "A"))
    return lines.filter(line => line !== "")
}
