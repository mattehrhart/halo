// The standard palette: twelve pure hues round the color wheel, then white,
// warm white and off, plus a button for any other color.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Flow {
    id: swatches

    property color value: "#00000000"
    signal chosen(color picked)

    readonly property var presets: [
        { color: "#ff0000", name: "Red" }, { color: "#ff8000", name: "Orange" },
        { color: "#ffff00", name: "Yellow" }, { color: "#80ff00", name: "Lime" },
        { color: "#00ff00", name: "Green" }, { color: "#00ff80", name: "Mint" },
        { color: "#00ffff", name: "Cyan" }, { color: "#0080ff", name: "Azure" },
        { color: "#0000ff", name: "Blue" }, { color: "#8000ff", name: "Violet" },
        { color: "#ff00ff", name: "Magenta" }, { color: "#ff0080", name: "Rose" },
        { color: "#ffffff", name: "White" }, { color: "#ffb060", name: "Warm white" },
        { color: "#000000", name: "Off" }
    ]

    spacing: Kirigami.Units.smallSpacing
    opacity: enabled ? 1 : 0.4

    Repeater {
        model: swatches.presets

        Rectangle {
            id: chip

            required property var modelData
            readonly property bool current: swatches.value.a > 0 && Qt.colorEqual(swatches.value, modelData.color)

            width: Kirigami.Units.gridUnit * 1.6
            height: width
            radius: width / 2
            color: modelData.color
            // A light and a dark ring, so every color shows on any theme.
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
            activeFocusOnTab: true
            scale: area.containsMouse || activeFocus ? 1.12 : 1

            Accessible.role: Accessible.Button
            Accessible.name: modelData.name
            Keys.onSpacePressed: swatches.pick(modelData.color)
            Keys.onReturnPressed: swatches.pick(modelData.color)

            Behavior on scale { NumberAnimation { duration: 80 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: chip.current || chip.activeFocus ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.22)
                visible: chip.current || chip.activeFocus || chip.modelData.color === "#000000"
            }
            // Off is a ring with a stroke through it.
            Rectangle {
                visible: chip.modelData.color === "#000000"
                anchors.centerIn: parent
                width: parent.width * 0.9
                height: 2
                rotation: -45
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: swatches.pick(chip.modelData.color)
            }
            QQC2.ToolTip.visible: area.containsMouse
            QQC2.ToolTip.delay: 600
            QQC2.ToolTip.text: modelData.name
        }
    }

    QQC2.Button {
        height: Kirigami.Units.gridUnit * 1.6
        text: "Custom…"
        icon.name: "color-picker"
        onClicked: {
            dialog.selectedColor = swatches.value.a > 0 ? swatches.value : "#ffffff"
            dialog.open()
        }
    }

    function pick(c) {
        value = c
        chosen(value)
    }

    ColorDialog {
        id: dialog

        title: "Choose a Color"
        onAccepted: swatches.pick(selectedColor)
    }
}
