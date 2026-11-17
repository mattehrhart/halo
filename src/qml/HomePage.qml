import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    title: "Devices"

    actions: [
        Kirigami.Action {
            text: "Refresh"
            icon.name: "view-refresh"
            onTriggered: Hub.refresh()
        }
    ]

    function iconFor(kind) {
        if (kind === "keyboard")
            return "input-keyboard"
        if (kind === "mouse")
            return "input-mouse"
        if (kind === "headset")
            return "audio-headset"
        return "preferences-devices-tree"
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: Hub.loaded && !Hub.reachable
        icon.name: "network-disconnect"
        text: "OpenLinkHub is not answering"
        explanation: "Linkdeck controls your devices through the OpenLinkHub service at " + Hub.base
            + ". Check that it is running:\nsystemctl --user status OpenLinkHub"
        helpfulAction: Kirigami.Action {
            text: "Try again"
            icon.name: "view-refresh"
            onTriggered: Hub.refresh()
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: Hub.loaded && Hub.reachable && Hub.devices.length === 0
        icon.name: "input-keyboard"
        text: "No devices found"
        explanation: "OpenLinkHub is running but has not picked up a supported device."
    }

    GridLayout {
        visible: Hub.reachable && Hub.devices.length > 0
        columns: Math.max(1, Math.floor(page.width / (Kirigami.Units.gridUnit * 18)))
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.largeSpacing

        Repeater {
            model: Hub.devices

            Kirigami.AbstractCard {
                id: card

                required property var modelData
                readonly property var level: Hub.battery[modelData.serial]

                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 11
                showClickFeedback: true
                onClicked: applicationWindow().openDevice(modelData, "")

                Accessible.name: modelData.product
                Accessible.role: Accessible.Button

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.enormous
                        Layout.preferredHeight: Kirigami.Units.iconSizes.enormous
                        source: page.iconFor(card.modelData.kind)
                    }
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        level: 3
                        text: card.modelData.product
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Kirigami.Units.largeSpacing

                        QQC2.Label {
                            visible: card.modelData.firmware !== "" && card.modelData.firmware !== "n/a"
                            text: "Firmware " + card.modelData.firmware
                            color: Kirigami.Theme.disabledTextColor
                        }
                        RowLayout {
                            visible: card.level !== undefined
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: card.level <= 15 ? "battery-low" : card.level <= 50 ? "battery-good" : "battery-full"
                            }
                            QQC2.Label {
                                text: (card.level === undefined ? "" : card.level) + " %"
                                color: card.level <= 15 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            }
                        }
                    }
                }
            }
        }
    }
}
