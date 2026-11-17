// One titled card in the row along the bottom of a device page.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Pane {
    id: panel

    property string title: ""
    // One line of secondary text under the title; empty for none.
    property string description: ""
    default property alias content: body.data

    Layout.fillHeight: true
    padding: Kirigami.Units.largeSpacing
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
            level: 4
            font.weight: Font.DemiBold
            text: panel.title
            elide: Text.ElideRight
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: panel.description !== ""
            text: panel.description
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
        QQC2.ScrollView {
            id: scroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: body

                width: scroll.availableWidth
                spacing: Kirigami.Units.largeSpacing
            }
        }
    }
}
