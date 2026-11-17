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
            x += k.left
            keys.push({
                id: id,
                row: r,
                x: x,
                y: rowY + k.top,
                w: k.width,
                h: k.height,
                name: k.keyName,
                label: label(k.keyName),
                raw: k
            })
            x += k.width
            width = Math.max(width, x)
            height = Math.max(height, rowY + k.top + k.height)
            rowTop = k.top
            rowHeight = Math.min(rowHeight, k.height)
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
const SPINS = ["circle", "circleshift", "spinner", "rotator"]

// The colour a key shows for the device's current effect. Animated effects
// are imitated here, so they give the right impression but not exact timing.
function keyColor(key, device, phase) {
    if (!device || key.raw.noColor)
        return Qt.rgba(0, 0, 0, 1)
    const mode = device.DeviceProfile.RGBProfile
    if (mode === "off" || device.DeviceProfile.RgbOff)
        return Qt.rgba(0, 0, 0, 1)
    if (mode === "keyboard")
        return rgb(key.raw.color)
    const profile = device.Rgb && device.Rgb.profiles ? device.Rgb.profiles[mode] : null
    const start = profile ? rgb(profile.start) : Qt.rgba(1, 1, 1, 1)
    const end = profile ? rgb(profile.end) : start
    if (mode === "static")
        return start
    if (RAINBOWS.indexOf(mode) >= 0) {
        const pastel = mode.indexOf("pastel") >= 0 || mode === "watercolor"
        return Qt.hsva((key.cx * 0.8 + key.cy * 0.2 + phase) % 1, pastel ? 0.45 : 1, 1, 1)
    }
    if (SPINS.indexOf(mode) >= 0) {
        const angle = Math.atan2(key.cy - 0.5, key.cx - 0.5) / (2 * Math.PI) + 0.5
        return mix(start, end, 0.5 + 0.5 * Math.sin(2 * Math.PI * (angle + phase)))
    }
    if (mode === "cpu-temperature" || mode === "gpu-temperature") {
        const temp = mode === "cpu-temperature" ? device.CpuTemp : device.GpuTemp
        return Qt.hsva(Math.max(0, 0.33 - Math.max(0, temp - 35) / 150), 1, 1, 1)
    }
    if (mode === "colorpulse" || mode === "colorshift" || mode === "flickering" || mode === "storm")
        return mix(start, end, 0.5 + 0.5 * Math.sin(2 * Math.PI * phase))
    // wave, gradient, marquee, sequential and anything newer
    return mix(start, end, 0.5 + 0.5 * Math.sin(2 * Math.PI * (key.cx + phase)))
}

// Effects in the order to list them: the plain choices first.
function orderedModes(modes) {
    const first = ["keyboard", "mouse", "static", "off"]
    const list = (modes || []).slice()
    list.sort((a, b) => {
        const ia = first.indexOf(a), ib = first.indexOf(b)
        if (ia >= 0 || ib >= 0)
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
        return title(a).localeCompare(title(b))
    })
    return list
}

function hex(c) {
    const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
    return "#" + h(c.r) + h(c.g) + h(c.b)
}

function title(mode) {
    const special = {
        "keyboard": "Per-key colours",
        "mouse": "Zone colours",
        "off": "Lights off",
        "static": "Static colour",
        "colorpulse": "Colour pulse",
        "colorshift": "Colour shift",
        "colorwarp": "Colour warp",
        "circleshift": "Circle shift",
        "pastelrainbow": "Pastel rainbow",
        "cpu-temperature": "CPU temperature",
        "gpu-temperature": "GPU temperature"
    }
    if (special.hasOwnProperty(mode))
        return special[mode]
    return mode.charAt(0).toUpperCase() + mode.slice(1)
}
