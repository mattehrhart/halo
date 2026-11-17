// A drawn keyboard: metal frame, key caps, and each key lit in its colour.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Item {
    id: view

    property var keymap: ({ keys: [], byId: ({}), width: 1, height: 1 })
    property var device: null
    // id -> true for every selected key
    property var selected: ({})
    // "" or "actuation": what small print to show on each key cap
    property string badge: ""
    signal keyTapped(int id, bool extend)

    // Frame margin around the keys, in the same units as the key sizes.
    readonly property real pad: 42
    readonly property real unit: Math.min(width / (keymap.width + 2 * pad), height / (keymap.height + 2 * pad))
    readonly property string mode: device ? device.DeviceProfile.RGBProfile : "off"
    readonly property bool animated: ["keyboard", "static", "off", "cpu-temperature", "gpu-temperature"].indexOf(mode) < 0
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 7000
        loops: Animation.Infinite
        running: view.visible && view.animated
    }

    function lit(key) {
        return KeyLayout.keyColor(key, view.device, view.phase)
    }

    Item {
        id: frame

        anchors.centerIn: parent
        width: (view.keymap.width + 2 * view.pad) * view.unit
        height: (view.keymap.height + 2 * view.pad) * view.unit

        // Soft shadow under the keyboard.
        Rectangle {
            anchors.fill: plate
            anchors.topMargin: 10 * view.unit
            anchors.bottomMargin: -14 * view.unit
            radius: plate.radius
            color: "#000000"
            opacity: 0.28
        }

        // Brushed-metal top plate.
        Rectangle {
            id: plate

            anchors.fill: parent
            radius: 20 * view.unit
            border.width: 1
            border.color: "#0d0e10"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#4a4d53" }
                GradientStop { position: 0.06; color: "#35383d" }
                GradientStop { position: 0.9; color: "#26282c" }
                GradientStop { position: 1.0; color: "#1b1c1f" }
            }
        }
        Rectangle {
            anchors.left: plate.left
            anchors.right: plate.right
            anchors.top: plate.top
            anchors.margins: 3 * view.unit
            height: Math.max(1, 2 * view.unit)
            radius: height
            color: "#ffffff"
            opacity: 0.13
        }

        // Light spilling from under the caps: every key's colour, blurred once.
        Item {
            id: glow

            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: 40
                brightness: 0.05
            }

            Repeater {
                model: view.keymap.keys

                Rectangle {
                    required property var modelData
                    readonly property color tint: view.lit(modelData)

                    x: (view.pad + modelData.x - 5) * view.unit
                    y: (view.pad + modelData.y - 5) * view.unit
                    width: (modelData.w + 10) * view.unit
                    height: (modelData.h + 10) * view.unit
                    radius: 10 * view.unit
                    color: tint
                    visible: tint.r + tint.g + tint.b > 0.02
                    opacity: 0.85
                }
            }
        }

        Repeater {
            model: view.keymap.keys

            Item {
                id: cap

                required property var modelData
                readonly property bool isBar: modelData.name === "Logo"
                readonly property bool isRoller: modelData.name === "WH +" || modelData.name === "WH -"
                readonly property bool picked: view.selected[modelData.id] === true
                readonly property color tint: view.lit(modelData)
                readonly property bool dark: tint.r + tint.g + tint.b < 0.06
                readonly property string caption: {
                    if (view.badge === "actuation" && KeyLayout.adjustable(modelData.raw))
                        return (modelData.raw.actuationPoint / 10).toFixed(1)
                    return ""
                }

                x: (view.pad + modelData.x) * view.unit
                y: (view.pad + modelData.y) * view.unit
                width: modelData.w * view.unit
                height: modelData.h * view.unit

                Accessible.role: Accessible.Button
                Accessible.name: KeyLayout.spokenName(modelData.name)

                // Light bar: a lit strip with no cap.
                Rectangle {
                    visible: cap.isBar
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: Math.max(3, 9 * view.unit)
                    radius: height / 2
                    color: cap.dark ? "#1a1b1e" : cap.tint
                }

                // Key base, then the sculpted top face.
                Rectangle {
                    visible: !cap.isBar
                    anchors.fill: parent
                    radius: 8 * view.unit
                    color: "#08090a"
                }
                Rectangle {
                    id: face

                    visible: !cap.isBar
                    anchors.fill: parent
                    anchors.leftMargin: 6 * view.unit
                    anchors.rightMargin: 6 * view.unit
                    anchors.topMargin: 3 * view.unit
                    anchors.bottomMargin: 9 * view.unit
                    radius: 6 * view.unit
                    gradient: Gradient {
                        orientation: cap.isRoller ? Gradient.Horizontal : Gradient.Vertical
                        GradientStop { position: 0.0; color: cap.isRoller ? "#55585d" : hover.containsMouse ? "#3c3f45" : "#303237" }
                        GradientStop { position: 0.5; color: cap.isRoller ? "#9a9da2" : hover.containsMouse ? "#2f3136" : "#25272b" }
                        GradientStop { position: 1.0; color: cap.isRoller ? "#4a4d52" : hover.containsMouse ? "#292b2f" : "#1d1f22" }
                    }
                }
                Text {
                    visible: !cap.isBar
                    anchors.centerIn: face
                    width: face.width - 4 * view.unit
                    horizontalAlignment: Text.AlignHCenter
                    text: cap.modelData.label
                    color: cap.isRoller ? "#17181a" : cap.dark ? "#5c6066" : cap.tint
                    font.pixelSize: Math.max(6, (cap.modelData.label.length > 2 ? 16 : 20) * view.unit)
                    minimumPixelSize: 5
                    fontSizeMode: Text.HorizontalFit
                    font.weight: Font.DemiBold
                    style: cap.dark || cap.isRoller ? Text.Normal : Text.Raised
                    styleColor: Qt.rgba(cap.tint.r, cap.tint.g, cap.tint.b, 0.35)
                }
                Text {
                    visible: cap.caption !== ""
                    anchors.right: face.right
                    anchors.bottom: face.bottom
                    anchors.margins: 3 * view.unit
                    text: cap.caption
                    color: "#e8eaed"
                    font.pixelSize: Math.max(6, 12 * view.unit)
                }

                // Selection ring in the desktop's highlight colour.
                Rectangle {
                    visible: cap.picked
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 9 * view.unit
                    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.22)
                    border.width: Math.max(2, 3 * view.unit)
                    border.color: Kirigami.Theme.highlightColor
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const extend = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.ShiftModifier) !== 0
                        view.keyTapped(cap.modelData.id, extend)
                    }
                }
            }
        }
    }
}
