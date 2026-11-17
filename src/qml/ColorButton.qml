// A color well. Clicking it opens the standard palette in a small popup.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: well

    property color value: "#ffffff"
    property string label: "Color"
    signal chosen(color picked)

    implicitWidth: Kirigami.Units.gridUnit * 2.6
    implicitHeight: Kirigami.Units.gridUnit * 1.6
    radius: Kirigami.Units.cornerRadius
    color: value
    opacity: enabled ? 1 : 0.4
    // A dark and a light edge, so white on a light theme still reads as a well.
    border.width: area.containsMouse || activeFocus ? 2 : 1
    border.color: area.containsMouse || activeFocus ? Kirigami.Theme.highlightColor : Qt.rgba(0, 0, 0, 0.45)
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onSpacePressed: palette.open()
    Keys.onReturnPressed: palette.open()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2)
        visible: !area.containsMouse && !well.activeFocus
    }
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: palette.open()
    }

    QQC2.Popup {
        id: palette

        y: well.height + Kirigami.Units.smallSpacing
        width: Kirigami.Units.gridUnit * 17
        padding: Kirigami.Units.largeSpacing
        modal: false
        focus: true

        contentItem: ColorSwatches {
            value: well.value
            onChosen: picked => {
                palette.close()
                well.value = picked
                well.chosen(picked)
            }
        }
    }
}
