// A row of preset colours plus a button for the system colour picker.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Flow {
    id: swatches

    property color value: "#ff6400"
    signal chosen(color picked)

    readonly property var presets: [
        "#ff0000", "#ff6400", "#ffd000", "#00ff00", "#00ffc8", "#00b4ff",
        "#0040ff", "#8000ff", "#ff00c8", "#ffffff"
    ]

    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: swatches.presets

        Rectangle {
            id: chip

            required property string modelData
            readonly property bool current: Qt.colorEqual(swatches.value, modelData)

            width: Kirigami.Units.gridUnit * 1.6
            height: width
            radius: Kirigami.Units.cornerRadius
            color: modelData
            border.width: current ? 3 : 1
            border.color: current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

            Accessible.role: Accessible.Button
            Accessible.name: "Colour " + modelData

            TapHandler {
                onTapped: {
                    swatches.value = chip.modelData
                    swatches.chosen(swatches.value)
                }
            }
        }
    }

    QQC2.Button {
        height: Kirigami.Units.gridUnit * 1.6
        text: "Custom…"
        icon.name: "color-picker"
        onClicked: {
            dialog.selectedColor = swatches.value
            dialog.open()
        }
    }

    ColorDialog {
        id: dialog

        title: "Choose a colour"
        onAccepted: {
            swatches.value = selectedColor
            swatches.chosen(swatches.value)
        }
    }
}
