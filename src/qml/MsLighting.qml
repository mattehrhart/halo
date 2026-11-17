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
    readonly property string zoneMode: KeyLayout.zoneMode(device)
    readonly property bool zones: zoneMode !== "" && mode === zoneMode
    readonly property bool hasBrightness: device.DeviceProfile.BrightnessSlider !== undefined && device.DeviceProfile.BrightnessSlider !== null
    readonly property var zoneIds: Object.keys(device.DeviceProfile.ZoneColors || {}).map(Number).sort((a, b) => a - b)

    spacing: Kirigami.Units.largeSpacing

    // Sends every zone's color, with one of them changed.
    function setZone(zone, picked) {
        const colors = {}
        for (const id of zoneIds) {
            const c = id === zone ? picked : KeyLayout.rgb(device.DeviceProfile.ZoneColors[String(id)].Color)
            colors[String(id)] = { red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255) }
        }
        page.send("POST", "/api/" + page.family + "/zoneColors", { colorZones: colors }, null,
                  device.DeviceProfile.ZoneColors[String(zone)].Name + " color changed")
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
        description: ""
        Layout.fillWidth: true

        GridLayout {
            visible: root.zones
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.zoneIds

                QQC2.Label {
                    required property int modelData

                    Layout.row: root.zoneIds.indexOf(modelData)
                    Layout.column: 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    text: root.device.DeviceProfile.ZoneColors[String(modelData)].Name
                }
            }
            Repeater {
                model: root.zoneIds

                ColorButton {
                    required property int modelData

                    Layout.row: root.zoneIds.indexOf(modelData)
                    Layout.column: 1
                    label: root.device.DeviceProfile.ZoneColors[String(modelData)].Name + " color"
                    value: KeyLayout.rgb(root.device.DeviceProfile.ZoneColors[String(modelData)].Color)
                    onChosen: picked => root.setZone(modelData, picked)
                }
            }
        }

        EffectSettings {
            id: effect

            Layout.fillWidth: true
            visible: !root.zones
            page: root.page
            startColor: profile ? KeyLayout.rgb(profile.start) : "#ffffff"
            endColor: profile ? KeyLayout.rgb(profile.end) : "#ffffff"
            onChanged: (first, second, speed) => {
                const part = c => ({ red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255), temperature: 0 })
                root.page.send("PUT", "/api/color/change", {
                    profile: root.mode,
                    startColor: part(first),
                    endColor: part(root.mode === "static" ? first : second),
                    middleColor: part(KeyLayout.rgb(effect.profile.middle)),
                    speed: speed,
                    alternateColors: effect.profile.alternateColors,
                    rgbDirection: effect.profile.rgbDirection
                }, null, "Effect updated")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.hasBrightness
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            visible: root.hasBrightness
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                text: "Brightness"
            }
            QQC2.Slider {
                id: level

                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.hasBrightness ? root.device.DeviceProfile.BrightnessSlider : 100
                enabled: !root.page.busy
                Accessible.name: "Brightness"
                onPressedChanged: {
                    if (!pressed && Math.round(value) !== root.device.DeviceProfile.BrightnessSlider)
                        root.page.send("POST", "/api/brightness/gradual", { brightness: Math.round(value) }, null,
                                       "Brightness " + Math.round(value) + "%")
                }
            }
            QQC2.Label {
                Layout.minimumWidth: percentSize.width
                horizontalAlignment: Text.AlignRight
                text: Math.round(level.value) + "%"

                TextMetrics {
                    id: percentSize
                    text: "100%"
                }
            }
        }
    }
}
