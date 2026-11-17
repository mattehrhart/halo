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
    readonly property bool zones: mode === "mouse"
    readonly property var zoneIds: Object.keys(device.DeviceProfile.ZoneColors || {}).map(Number).sort((a, b) => a - b)

    spacing: Kirigami.Units.gridUnit

    function saveZones() {
        const colors = {}
        for (let i = 0; i < wells.count; i++) {
            const c = wells.itemAt(i).tint
            colors[String(wells.itemAt(i).modelData)] = {
                red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255)
            }
        }
        page.send("POST", "/api/mouse/zoneColors", { colorZones: colors })
    }

    Panel {
        title: "Lighting Type"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.fillWidth: false

        Repeater {
            model: KeyLayout.orderedModes(root.device.RGBModes)

            QQC2.ItemDelegate {
                required property string modelData

                Layout.fillWidth: true
                text: KeyLayout.title(modelData)
                highlighted: root.mode === modelData
                onClicked: {
                    if (root.mode !== modelData)
                        root.page.send("POST", "/api/color", { channelId: 0, profile: modelData })
                }
            }
        }
    }

    Panel {
        title: root.zones ? "Zone Colours" : KeyLayout.title(root.mode)
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            visible: !root.zones
            wrapMode: Text.WordWrap
            text: root.mode === "off" ? "The mouse's lights are off."
                : "This effect lights the whole mouse. To give each zone its own colour, choose Zone colours."
        }
        QQC2.Button {
            visible: !root.zones
            text: "Switch to Zone colours"
            icon.name: "color-management"
            onClicked: root.page.send("POST", "/api/color", { channelId: 0, profile: "mouse" })
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            visible: root.zones

            Repeater {
                id: wells

                model: root.zoneIds

                ColorButton {
                    required property int modelData
                    property color tint: KeyLayout.rgb(root.device.DeviceProfile.ZoneColors[String(modelData)].Color)

                    Kirigami.FormData.label: root.device.DeviceProfile.ZoneColors[String(modelData)].Name + ":"
                    label: root.device.DeviceProfile.ZoneColors[String(modelData)].Name + " colour"
                    value: tint
                    onChosen: picked => tint = picked
                }
            }
        }
        QQC2.Button {
            visible: root.zones
            text: "Apply"
            icon.name: "dialog-ok-apply"
            enabled: !root.page.busy
            onClicked: root.saveZones()
        }
    }

    Panel {
        title: "Brightness"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.fillWidth: false

        RowLayout {
            Layout.fillWidth: true

            QQC2.Slider {
                id: level

                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
                value: root.device.DeviceProfile.BrightnessSlider
                Accessible.name: "Brightness"
                onPressedChanged: {
                    if (!pressed && Math.round(value) !== root.device.DeviceProfile.BrightnessSlider)
                        root.page.send("POST", "/api/brightness/gradual", { brightness: Math.round(value) })
                }
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                horizontalAlignment: Text.AlignRight
                text: Math.round(level.value) + " %"
            }
        }
    }
}
