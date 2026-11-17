// Unit tests for the pure logic in src/qml/layout.js.
//   qmltestrunner -input tests/tst_layout.qml
import QtQuick
import QtTest
import "../src/qml/layout.js" as KeyLayout

TestCase {
    name: "Layout"

    function key(name, extra) {
        return Object.assign({ keyName: name, width: 65, height: 65, left: 15, top: 15 }, extra || {})
    }

    function test_grid_places_keys_by_column() {
        const map = KeyLayout.buildGrid({ "0": { keys: {
            "1": key("A"), "2": key("B", { keySpace: "keyboard-key wide" }), "3": key("C", { keyEmpty: ["keyboard-key-empty"] })
        } } })
        compare(map.keys.length, 3)
        compare(map.byId[1].x, 0)
        compare(map.byId[2].x, 80)
        compare(map.byId[2].w, 145)          // two columns wide
        compare(map.byId[3].x, 320)          // after the wide key and one blank cell
        compare(map.width, 385)
    }

    function test_grid_survives_missing_measurements() {
        const map = KeyLayout.buildGrid({ "0": { keys: { "1": { keyName: "A" } } } })
        verify(isFinite(map.width) && isFinite(map.height))
        verify(map.width > 0)
    }

    function test_grid_puts_light_bars_around_the_keys() {
        const map = KeyLayout.buildGrid({
            "0": { keys: { "1": { keyName: "", css: "keyboard-key wide100", onlyColor: true } } },
            "1": { keys: { "2": { keyName: "", css: "keyboard-key left-led-1", onlyColor: true }, "3": key("A"),
                           "4": { keyName: "", css: "keyboard-key right-led-1", onlyColor: true } } }
        })
        verify(map.byId[1].bar && map.byId[2].bar && map.byId[4].bar)
        compare(map.byId[1].y, 0)                           // along the top
        compare(map.byId[2].x, 0)                           // down the left
        compare(map.byId[4].x + map.byId[4].w, map.width)   // down the right
        verify(map.byId[3].x > map.byId[2].x + map.byId[2].w)
    }

    function test_pixel_layout_still_adds_gaps() {
        const map = KeyLayout.build({ "0": { keys: { "1": key("A"), "2": key("B") } } })
        compare(map.byId[1].x, 15)
        compare(map.byId[2].x, 15 + 65 + 15)
    }

    function test_readings_are_split_from_settings() {
        const device = { CpuTemp: 50, devices: { "1": { channelId: 1, name: "Fan", rpm: 900, temperatureString: "30 °C", profile: "Quiet" } } }
        const now = KeyLayout.takeReadings(device)
        compare(now["1"].rpm, 900)
        compare(device.devices["1"].rpm, undefined)
        compare(device.devices["1"].profile, "Quiet")
        compare(device.CpuTemp, undefined)
        // Two reads that differ only in readings leave identical settings.
        const again = { CpuTemp: 61, devices: { "1": { channelId: 1, name: "Fan", rpm: 1200, temperatureString: "35 °C", profile: "Quiet" } } }
        KeyLayout.takeReadings(again)
        compare(JSON.stringify(again), JSON.stringify(device))
    }

    function test_readings_tolerate_devices_without_parts() {
        compare(Object.keys(KeyLayout.takeReadings({ devices: { "0": "Display" } })).length, 0)
        compare(KeyLayout.parts({ devices: { "0": "Display" } }).length, 0)
        compare(KeyLayout.parts(null).length, 0)
    }

    function test_parts_are_ordered_and_skip_the_power_supply_itself() {
        const list = KeyLayout.parts({ devices: { "10": { channelId: 10 }, "2": { channelId: 2 }, "0": { channelId: 0, MainPSU: true } } })
        compare(list.map(p => p.channelId), [2, 10])
    }

    function test_reading_lines() {
        compare(KeyLayout.readingLines({ HasSpeed: true }, { rpm: 900, temperature: 30, temperatureString: "30 °C" }), ["900 RPM", "30 °C"])
        compare(KeyLayout.readingLines({ HasWatts: true, HasVolts: true, HasAmps: true }, { watts: 183.34, volts: 12.061, amps: 15.2 }),
                ["183.3 W", "12.06 V", "15.2 A"])
        compare(KeyLayout.readingLines({}, {}), [])
    }

    function test_part_names() {
        compare(KeyLayout.partName({ label: "Top", name: "QX120" }), "Top")
        compare(KeyLayout.partName({ label: "", name: "QX120" }), "QX120")
        compare(KeyLayout.partName({ channelId: 3 }), "Part 3")
    }

    function test_titles() {
        compare(KeyLayout.title("colorpulse"), "Color Pulse")
        compare(KeyLayout.title("static"), "Static Color")
    }

    function test_effect_colors_stay_in_range() {
        const modes = ["rainbow", "pastelrainbow", "watercolor", "wave", "colorpulse", "colorshift", "colorwarp", "circle",
                       "spinner", "rotator", "sequential", "marquee", "nebula", "flickering", "storm", "gradient"]
        const start = Qt.rgba(1, 0, 0, 1), end = Qt.rgba(0, 0, 1, 1)
        for (const mode of modes) {
            for (const t of [0, 0.7, 3.3, 60]) {
                const c = KeyLayout.effectColor(mode, 5, 20, t, start, end, 4)
                verify(c !== undefined && c !== null, mode + " gives a color")
                for (const part of [c.r, c.g, c.b])
                    verify(isFinite(part) && part >= 0 && part <= 1.0001, mode + " at " + t + " stays between 0 and 1")
            }
        }
    }

    function test_unlit_is_never_brighter_than_lit() {
        const ink = Qt.rgba(1, 1, 1, 1)
        let last = -1
        for (const level of [0, 0.01, 0.1, 0.5, 1]) {
            const c = KeyLayout.lightInk(Qt.rgba(level, level, level, 1), ink, 0.1, 1)
            const strength = c.a * (c.r + c.g + c.b)
            verify(strength >= last - 1e-6, "brighter light never draws dimmer (" + level + ")")
            last = strength
        }
    }
}
