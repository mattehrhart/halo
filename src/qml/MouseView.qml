// A drawn top-down mouse with a twelve-button thumb pad. Buttons are
// matched to OpenLinkHub's button list by name, so tapping one selects it.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Item {
    id: view

    property var device: null
    // The selected button's index in device.KeyAssignment, or "".
    property string selected: ""
    signal buttonTapped(string index)

    readonly property real unit: Math.min(width / 520, height / 420)
    readonly property string mode: device ? device.DeviceProfile.RGBProfile : "off"
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 7000
        loops: Animation.Infinite
        running: view.visible && ["mouse", "static", "off"].indexOf(view.mode) < 0
    }

    function indexOf(name) {
        if (!device || !device.KeyAssignment)
            return ""
        for (const index in device.KeyAssignment) {
            if (device.KeyAssignment[index].name === name)
                return index
        }
        return ""
    }

    // Colour of lighting zone 0 (thumb pad) or 1 (palm).
    function zone(number) {
        if (!device || mode === "off" || device.DeviceProfile.RgbOff)
            return Qt.rgba(0, 0, 0, 1)
        if (mode === "mouse") {
            const z = device.DeviceProfile.ZoneColors[String(number)]
            return z ? KeyLayout.rgb(z.Color) : Qt.rgba(0, 0, 0, 1)
        }
        return KeyLayout.keyColor({ raw: {}, cx: number * 0.5, cy: 0.5 }, device, phase)
    }

    component Hit: MouseArea {
        property string name: ""
        readonly property string index: view.indexOf(name)

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: index !== ""
        onClicked: view.buttonTapped(index)
        Accessible.role: Accessible.Button
        Accessible.name: name

        Rectangle {
            anchors.fill: parent
            radius: 8 * view.unit
            visible: view.selected === parent.index && parent.index !== ""
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.25)
            border.width: Math.max(2, 3 * view.unit)
            border.color: Kirigami.Theme.highlightColor
        }
    }

    Item {
        id: frame

        anchors.centerIn: parent
        width: 520 * view.unit
        height: 420 * view.unit

        // Glow from both lighting zones.
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 48
            }

            Rectangle {
                x: 28 * view.unit
                y: 118 * view.unit
                width: 190 * view.unit
                height: 200 * view.unit
                radius: 30 * view.unit
                color: view.zone(0)
                opacity: 0.7
            }
            Rectangle {
                x: 285 * view.unit
                y: 285 * view.unit
                width: 90 * view.unit
                height: 70 * view.unit
                radius: 35 * view.unit
                color: view.zone(1)
                opacity: 0.8
            }
        }

        // Thumb pad, sticking out of the left side.
        Rectangle {
            id: pad

            x: 40 * view.unit
            y: 130 * view.unit
            width: 190 * view.unit
            height: 176 * view.unit
            radius: 22 * view.unit
            border.width: 1
            border.color: "#0d0e10"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3a3d42" }
                GradientStop { position: 1.0; color: "#232528" }
            }

            Grid {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -14 * view.unit
                columns: 3
                spacing: 6 * view.unit

                Repeater {
                    model: 12

                    Rectangle {
                        id: thumb

                        required property int index
                        readonly property color tint: view.zone(0)
                        readonly property bool dark: tint.r + tint.g + tint.b < 0.06

                        width: 40 * view.unit
                        height: 34 * view.unit
                        radius: 7 * view.unit
                        color: thumbHit.containsMouse ? "#2c2e33" : "#17181b"
                        border.width: 1
                        border.color: "#08090a"

                        Text {
                            anchors.centerIn: parent
                            text: thumb.index + 1
                            color: thumb.dark ? "#5c6066" : thumb.tint
                            font.pixelSize: Math.max(6, 16 * view.unit)
                            font.weight: Font.DemiBold
                        }
                        Hit {
                            id: thumbHit
                            anchors.fill: parent
                            name: "Side Button " + (thumb.index + 1)
                        }
                    }
                }
            }
        }

        // Body.
        Rectangle {
            id: body

            x: 200 * view.unit
            y: 20 * view.unit
            width: 250 * view.unit
            height: 380 * view.unit
            radius: 118 * view.unit
            border.width: 1
            border.color: "#0d0e10"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#45484e" }
                GradientStop { position: 0.45; color: "#2b2d31" }
                GradientStop { position: 1.0; color: "#1c1d20" }
            }
        }
        // Seam between the two main buttons.
        Rectangle {
            x: body.x + body.width / 2 - 1
            y: body.y + 8 * view.unit
            width: 2
            height: 150 * view.unit
            color: "#0d0e10"
        }
        Hit {
            x: body.x + 8 * view.unit
            y: body.y + 12 * view.unit
            width: body.width / 2 - 26 * view.unit
            height: 150 * view.unit
            name: "Left Button"
        }
        Hit {
            x: body.x + body.width / 2 + 18 * view.unit
            y: body.y + 12 * view.unit
            width: body.width / 2 - 26 * view.unit
            height: 150 * view.unit
            name: "Right Button"
        }
        // Wheel.
        Rectangle {
            id: wheel

            x: body.x + body.width / 2 - 13 * view.unit
            y: body.y + 48 * view.unit
            width: 26 * view.unit
            height: 62 * view.unit
            radius: 13 * view.unit
            border.width: 1
            border.color: "#08090a"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1a1b1e" }
                GradientStop { position: 0.5; color: "#55585d" }
                GradientStop { position: 1.0; color: "#1a1b1e" }
            }
            Hit {
                anchors.fill: parent
                name: "Middle Button"
            }
        }
        // The two small buttons behind the wheel.
        Repeater {
            model: ["DPI Button", "Profile Switch"]

            Rectangle {
                id: small

                required property string modelData
                required property int index

                x: body.x + body.width / 2 - 15 * view.unit
                y: body.y + (124 + index * 34) * view.unit
                width: 30 * view.unit
                height: 26 * view.unit
                radius: 8 * view.unit
                color: smallHit.containsMouse ? "#2c2e33" : "#17181b"
                border.width: 1
                border.color: "#08090a"

                Hit {
                    id: smallHit
                    anchors.fill: parent
                    name: small.modelData
                }
            }
        }
        // Palm light.
        Rectangle {
            readonly property color tint: view.zone(1)

            x: body.x + body.width / 2 - 26 * view.unit
            y: body.y + 286 * view.unit
            width: 52 * view.unit
            height: 30 * view.unit
            radius: 15 * view.unit
            color: tint.r + tint.g + tint.b < 0.06 ? "#1a1b1e" : tint
        }
    }
}
