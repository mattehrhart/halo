// The list of sections down the left side of a device page.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Pane {
    id: menu

    // [{key, text, icon}]
    property var sections: []
    property string current: ""
    signal picked(string key)

    padding: 0
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    contentItem: ListView {
        model: menu.sections
        interactive: contentHeight > height
        topMargin: Kirigami.Units.smallSpacing
        clip: true

        delegate: QQC2.ItemDelegate {
            id: row

            required property var modelData

            width: ListView.view.width
            text: modelData.text
            icon.name: modelData.icon
            highlighted: menu.current === modelData.key
            onClicked: menu.picked(modelData.key)
        }
    }

    Kirigami.Separator {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
