// A small colour well that opens the system colour picker.
import QtQuick
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Rectangle {
    id: well

    property color value: "#ffffff"
    property string label: "Colour"
    signal chosen(color picked)

    implicitWidth: Kirigami.Units.gridUnit * 2
    implicitHeight: Kirigami.Units.gridUnit * 1.6
    radius: Kirigami.Units.cornerRadius
    color: value
    border.width: area.containsMouse || activeFocus ? 2 : 1
    border.color: area.containsMouse || activeFocus ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onSpacePressed: open()
    Keys.onReturnPressed: open()

    function open() {
        dialog.selectedColor = well.value
        dialog.open()
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: well.open()
    }

    ColorDialog {
        id: dialog

        title: well.label
        onAccepted: {
            well.value = selectedColor
            well.chosen(well.value)
        }
    }
}
