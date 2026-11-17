// The card beside the device: its name, then the sections to choose from.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Pane {
    id: menu

    property string title: ""
    property string subtitle: ""
    // [{key, text, icon}]
    property var sections: []
    property string current: ""
    signal picked(string key)

    padding: Kirigami.Units.smallSpacing
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
    }

    contentItem: ColumnLayout {
        spacing: 0

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            Layout.bottomMargin: 0
            level: 2
            text: menu.title
            elide: Text.ElideRight
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: text !== ""
            text: menu.subtitle
            opacity: 0.7
            elide: Text.ElideRight
        }
        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
        }
        // Placeholders until the device has been read.
        Repeater {
            model: menu.sections.length === 0 ? 4 : 0

            Skeleton {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.gridUnit * 3
                implicitHeight: Kirigami.Units.gridUnit * 1.4
            }
        }
        Repeater {
            model: menu.sections

            QQC2.ItemDelegate {
                required property var modelData

                Layout.fillWidth: true
                text: modelData.text
                icon.name: modelData.icon
                icon.color: highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                highlighted: menu.current === modelData.key
                onClicked: menu.picked(modelData.key)
            }
        }
        Item { Layout.fillHeight: true }
    }
}
