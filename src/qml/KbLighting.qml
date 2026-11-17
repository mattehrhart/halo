import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property string mode: device.DeviceProfile.RGBProfile
    readonly property bool perKey: mode === "keyboard"
    readonly property int picked: page.selectedIds.length

    spacing: Kirigami.Units.largeSpacing

    // Brightness is done here, by dimming the colors that are sent: OpenLinkHub
    // cannot set this keyboard's own brightness, and its three-step setting
    // only affects moving effects. The level and the colors the user chose
    // are remembered per effect, so 0 % loses nothing.
    Settings {
        id: store

        category: "KeyboardBrightness"
        property string levels: "{}"
        property string bases: "{}"
    }
    readonly property string levelKey: page.serial + "/" + mode
    // Models whose brightness OpenLinkHub can set directly use that; the
    // rest are dimmed here, through the colors.
    readonly property bool ownSlider: device.DeviceProfile.BrightnessSlider !== undefined && device.DeviceProfile.BrightnessSlider !== null
    readonly property int level: {
        if (ownSlider)
            return 100
        const saved = JSON.parse(store.levels)[levelKey]
        return saved === undefined ? 100 : saved
    }
    readonly property var bases: JSON.parse(store.bases)[levelKey] || ({})
    // Effects with no colors of their own can only use OpenLinkHub's steps.
    readonly property bool stepped: !perKey && !KeyLayout.usesColors(mode)

    function rememberLevel(value) {
        const all = JSON.parse(store.levels)
        all[levelKey] = value
        store.levels = JSON.stringify(all)
    }

    function rememberBases(changes) {
        const all = JSON.parse(store.bases)
        all[levelKey] = Object.assign(all[levelKey] || {}, changes)
        store.bases = JSON.stringify(all)
    }

    // How much of a color to send for a brightness of 0 to 100: a straight
    // share, the same way OpenLinkHub dims the mouse.
    function gain(percent) {
        return Math.max(0, Math.min(100, percent)) / 100
    }

    function dim(base, to) {
        return base.map(v => Math.round(v * gain(to)))
    }

    // An earlier version dimmed along a different curve (30 % at the bottom).
    // Colors it sent are still on the keyboard until the slider next moves.
    function earlierDim(base, to) {
        return base.map(v => Math.round(v * (to <= 0 ? 0 : 0.3 + 0.7 * to / 100)))
    }

    function triple(c) {
        return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]
    }

    // The color the user chose for something, given what the device shows
    // now: the remembered one if it still matches, otherwise worked back
    // from the device (it was changed somewhere else).
    function baseOf(name, shown) {
        const saved = bases[name]
        const now = [shown.red, shown.green, shown.blue]
        if (saved) {
            const near = expect => Math.abs(expect[0] - now[0]) <= 1 && Math.abs(expect[1] - now[1]) <= 1 && Math.abs(expect[2] - now[2]) <= 1
            if (near(dim(saved, level)) || near(earlierDim(saved, level)))
                return saved
        }
        if (level === 0)
            return saved || [255, 255, 255]
        return now.map(v => Math.min(255, Math.round(v / gain(level))))
    }

    function wire(c) {
        return { red: c[0], green: c[1], blue: c[2], temperature: 0 }
    }

    function sendEffect(start, end, middle, speed, value, done, okText) {
        const profile = device.Rgb.profiles[mode]
        page.send("PUT", "/api/color/change", {
            profile: mode,
            startColor: wire(dim(start, value)),
            endColor: wire(dim(mode === "static" ? start : end, value)),
            middleColor: wire(dim(middle, value)),
            speed: speed,
            alternateColors: profile.alternateColors,
            rgbDirection: profile.rgbDirection
        }, done, okText)
    }

    function setLevel(value) {
        if (value === level)
            return
        const okText = "Brightness " + value + "%"
        if (stepped) {
            rememberLevel(value)
            // OpenLinkHub's steps: 1 low, 2 medium, 3 full, 4 dark.
            page.send("POST", "/api/brightness", { brightness: value === 0 ? 4 : value <= 40 ? 1 : value <= 80 ? 2 : 3 }, null,
                      "Brightness " + (value === 0 ? "off" : value <= 40 ? "low" : value <= 80 ? "medium" : "full"))
            return
        }
        if (perKey) {
            // Re-send every key at the new level, one request per distinct color.
            const chosen = {}
            const groups = {}
            for (const key of page.keymap.keys) {
                if (key.raw.noColor)
                    continue
                const base = baseOf(String(key.id), key.raw.color)
                chosen[String(key.id)] = base
                const next = dim(base, value)
                const name = next.join(",")
                if (!groups[name])
                    groups[name] = { color: next, keys: [] }
                groups[name].keys.push(key.id)
            }
            rememberBases(chosen)
            rememberLevel(value)
            page.sendEach("/api/keyboard/color", Object.keys(groups).map(name => ({
                keyId: groups[name].keys[0],
                keyOption: 3,
                keys: groups[name].keys,
                color: wire(groups[name].color)
            })), null, okText)
            return
        }
        const profile = device.Rgb.profiles[mode]
        const chosen = { start: baseOf("start", profile.start), end: baseOf("end", profile.end), middle: baseOf("middle", profile.middle) }
        rememberBases(chosen)
        rememberLevel(value)
        sendEffect(chosen.start, chosen.end, chosen.middle, profile.speed, value, function () {
            // Make sure OpenLinkHub's own step is not dimming the effect as well.
            if (root.device.DeviceProfile.Brightness !== 3)
                root.page.send("POST", "/api/brightness", { brightness: 3 })
        }, okText)
    }

    // Colors the selected keys, or every key when none are selected.
    function paint(c) {
        const ids = page.selectedIds
        const option = ids.length === 0 ? 2 : ids.length === 1 ? 0 : 3
        const chosen = {}
        const targets = ids.length > 0 ? ids : page.keymap.keys.map(k => k.id)
        for (const id of targets)
            chosen[String(id)] = triple(c)
        rememberBases(chosen)
        page.send("POST", "/api/keyboard/color", {
            keyId: ids.length > 0 ? ids[0] : 1,
            keyOption: option,
            keys: option === 3 ? ids : [],
            color: wire(dim(triple(c), level))
        }, null, ids.length === 0 ? "All keys colored" : ids.length === 1 ? "Key colored" : ids.length + " keys colored")
    }

    function saveEffect(first, second, speed) {
        const profile = device.Rgb.profiles[mode]
        const chosen = { start: triple(first), end: triple(second), middle: baseOf("middle", profile.middle) }
        rememberBases(chosen)
        sendEffect(chosen.start, chosen.end, chosen.middle, speed, level)
    }

    function shownKey(id) {
        const key = page.keymap.byId[id]
        if (!key)
            return Qt.rgba(0, 0, 0, 0)
        const base = baseOf(String(id), key.raw.color)
        return Qt.rgba(base[0] / 255, base[1] / 255, base[2] / 255, 1)
    }

    function shownColor(name) {
        const profile = device.Rgb && device.Rgb.profiles ? device.Rgb.profiles[mode] : null
        if (!profile)
            return Qt.rgba(1, 1, 1, 1)
        const base = baseOf(name, profile[name])
        return Qt.rgba(base[0] / 255, base[1] / 255, base[2] / 255, 1)
    }

    // For testing from the command line: --route keyboard/lighting/level=40
    Component.onCompleted: {
        if (page.startSelect.indexOf("level=") === 0)
            setLevel(Number(page.startSelect.slice(6)))
    }

    Panel {
        title: "Lighting Type"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 30
        Layout.fillWidth: false

        TypeTiles {
            id: modeTiles

            readonly property var modes: KeyLayout.orderedModes(root.device.RGBModes)

            Layout.fillWidth: true
            fallbackIcon: "color-management"
            types: modes.map((mode, index) => ({ id: index, text: KeyLayout.title(mode) }))
            current: modes.indexOf(root.mode)
            onPicked: id => {
                if (modes[id] !== root.mode && !root.page.busy)
                    root.page.send("POST", "/api/color", { channelId: 0, profile: modes[id] }, null, KeyLayout.title(modes[id]))
            }
        }
    }

    Panel {
        title: KeyLayout.title(root.mode)
        description: !root.perKey ? ""
            : root.picked === 0 ? "Applies to all keys."
            : root.picked === 1 ? "Applies to the selected key."
            : "Applies to " + root.picked + " selected keys."
        Layout.fillWidth: true

        ColorSwatches {
            Layout.fillWidth: true
            visible: root.perKey
            value: root.picked > 0 ? root.shownKey(root.page.selectedIds[0]) : "#00000000"
            onChosen: picked => root.paint(picked)
        }
        EffectSettings {
            Layout.fillWidth: true
            visible: !root.perKey
            page: root.page
            startColor: root.shownColor("start")
            endColor: root.shownColor("end")
            onChanged: (first, second, speed) => root.saveEffect(first, second, speed)
        }
        Kirigami.Separator { Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                text: "Brightness"
            }
            QQC2.Slider {
                id: slider

                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.ownSlider ? root.device.DeviceProfile.BrightnessSlider : root.level
                enabled: !root.page.busy && root.mode !== "off"
                Accessible.name: "Brightness"
                onPressedChanged: {
                    if (pressed)
                        return
                    if (root.ownSlider)
                        root.page.send("POST", "/api/brightness/gradual", { brightness: Math.round(value) }, null, "Brightness " + Math.round(value) + "%")
                    else
                        root.setLevel(root.stepped ? Math.round(value / 33.4) * 33 + (value > 83 ? 1 : 0) : Math.round(value))
                }
            }
            QQC2.Label {
                Layout.minimumWidth: percentSize.width
                horizontalAlignment: Text.AlignRight
                text: (root.stepped && !root.ownSlider ? ["Off", "Low", "Medium", "Full"][Math.round(slider.value / 33.4)] : Math.round(slider.value) + "%")

                TextMetrics {
                    id: percentSize
                    text: "Medium"
                }
            }
        }
    }
}
