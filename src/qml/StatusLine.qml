// A quiet confirmation beside the device picture: a spinner while a change
// is being sent, then a tick and a few words that fade away.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: line

    property bool busy: false
    property string message: ""

    function show(text) {
        message = text
        fade.restart()
    }

    spacing: Kirigami.Units.smallSpacing

    QQC2.BusyIndicator {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        running: line.busy
        visible: line.busy
    }
    Kirigami.Icon {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        visible: !line.busy && line.message !== ""
        source: "emblem-ok-symbolic"
        color: Kirigami.Theme.positiveTextColor
        isMask: true
        opacity: label.opacity
    }
    QQC2.Label {
        id: label

        visible: line.busy || line.message !== ""
        text: line.busy ? "Applying…" : line.message
        color: Kirigami.Theme.disabledTextColor
        Accessible.role: Accessible.StatusBar

        SequentialAnimation {
            id: fade

            PropertyAction { target: label; property: "opacity"; value: 1 }
            PauseAnimation { duration: 2200 }
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: 500 }
            ScriptAction { script: { line.message = ""; label.opacity = 1 } }
        }
    }
}
