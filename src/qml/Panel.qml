// One titled column in the lower half of a device page.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: panel

    property string title: ""
    default property alias content: body.data

    spacing: 0
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignTop

    Kirigami.Heading {
        Layout.fillWidth: true
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        level: 4
        text: panel.title
        elide: Text.ElideRight
    }
    Kirigami.Separator {
        Layout.fillWidth: true
        Layout.bottomMargin: Kirigami.Units.largeSpacing
    }
    QQC2.ScrollView {
        id: scroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: body

            width: scroll.availableWidth
            spacing: Kirigami.Units.largeSpacing
        }
    }
}
