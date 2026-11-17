// A gently pulsing block that stands where content is still being read.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: block

    implicitHeight: Kirigami.Units.gridUnit
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.09)

    SequentialAnimation on opacity {
        running: block.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.45; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.45; to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
}
