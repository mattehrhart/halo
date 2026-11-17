// Setup: shown until a device can be controlled. It walks through the three
// things that must be true, and fixes or explains each one.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: page

    title: "Set Up Halo"

    // {found, usable}: supported devices plugged in, and how many this user may open.
    property var access: hubService.access()
    readonly property bool serviceUp: Hub.reachable
    readonly property bool allowed: access.found > 0 && access.usable >= access.found
    readonly property string command: hubService.rulesCommand()

    Timer {
        interval: 2000
        running: page.visible
        repeat: true
        onTriggered: {
            page.access = hubService.access()
            Hub.refresh()
        }
    }

    component Step: RowLayout {
        id: step

        property bool done: false
        property bool waiting: false
        property string title: ""
        property string detail: ""
        default property alias extra: more.data

        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium

            Kirigami.Icon {
                anchors.fill: parent
                visible: !step.waiting
                source: step.done ? "emblem-ok-symbolic" : "emblem-important-symbolic"
                color: step.done ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
                isMask: true
            }
            QQC2.BusyIndicator {
                anchors.fill: parent
                running: step.waiting
                visible: step.waiting
            }
        }
        ColumnLayout {
            id: more

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 4
                font.weight: Font.DemiBold
                text: step.title
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: step.detail
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 34)
        spacing: Kirigami.Units.gridUnit

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            source: "io.github.mattehrhart.Halo"
        }
        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 1
            text: "Set Up Halo"
        }

        Step {
            title: "Device service"
            done: page.serviceUp
            waiting: !page.serviceUp && hubService.running
            detail: page.serviceUp ? "OpenLinkHub is running."
                : hubService.running ? "Starting OpenLinkHub…"
                : hubService.problem !== "" ? "OpenLinkHub did not start: " + hubService.problem
                : hubService.bundled ? "OpenLinkHub is not running."
                : "OpenLinkHub is not installed. Get it from github.com/jurkovic-nikola/OpenLinkHub."

            QQC2.Button {
                visible: !page.serviceUp && !hubService.running && hubService.bundled
                text: "Start"
                onClicked: hubService.start()
            }
        }

        Step {
            title: "Device access"
            done: page.allowed
            detail: page.access.found === 0 ? "No supported device is plugged in."
                : page.allowed ? "Halo can reach your devices."
                : page.command === "" ? "Your devices need a one-time permission. Install OpenLinkHub's udev rule (99-openlinkhub.rules) to grant it."
                : "Your devices need a one-time permission. Run this in a terminal:"

            RowLayout {
                Layout.fillWidth: true
                visible: page.access.found > 0 && !page.allowed && page.command !== ""
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    Layout.fillWidth: true
                    readOnly: true
                    text: page.command
                    font.family: "monospace"
                    Accessible.name: "Permission command"
                    onActiveFocusChanged: {
                        if (activeFocus)
                            selectAll()
                    }
                }
                QQC2.Button {
                    text: "Copy"
                    icon.name: "edit-copy"
                    onClicked: hubService.copy(page.command)
                }
            }
        }

        Step {
            title: "Devices"
            done: Hub.devices.length > 0
            waiting: page.serviceUp && page.allowed && Hub.devices.length === 0
            detail: Hub.devices.length > 0 ? Hub.devices.map(d => d.product).join(", ")
                : page.serviceUp && page.allowed ? "Looking for devices…" : "Waiting for the steps above."
        }
    }
}
