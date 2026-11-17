// The shape of a device page while the device is still being read:
// "view" stands in for the picture, "panels" for the cards below it.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string part: "view"

    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Loading"

    Skeleton {
        visible: root.part === "view"
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, Kirigami.Units.gridUnit * 44)
        height: Math.min(parent.height * 0.7, Kirigami.Units.gridUnit * 16)
        radius: Kirigami.Units.gridUnit
    }

    RowLayout {
        visible: root.part === "panels"
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: 2

            Rectangle {
                required property int index

                Layout.fillHeight: true
                Layout.fillWidth: index === 1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 30
                radius: Kirigami.Units.cornerRadius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

                Column {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing

                    Skeleton { width: Kirigami.Units.gridUnit * 8 }
                    Skeleton { width: parent.width * 0.9; height: Kirigami.Units.gridUnit * 1.6 }
                    Skeleton { width: parent.width * 0.7; height: Kirigami.Units.gridUnit * 1.6 }
                    Skeleton { width: parent.width * 0.8; height: Kirigami.Units.gridUnit * 1.6 }
                }
            }
        }
    }
}
