import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: devicePage

    property string serial: ""
    property string startSection: ""
    property var device: null
    property string section: "assignments"
    // Index of the selected button in device.KeyAssignment.
    property string selectedButton: ""
    property bool busy: false
    property string loadError: ""

    readonly property var sections: [
        { key: "assignments", text: "Key Assignments", icon: "input-mouse" },
        { key: "lighting", text: "Lighting Effects", icon: "color-management" },
        { key: "dpi", text: "DPI", icon: "speedometer" },
        { key: "device", text: "Device Settings", icon: "configure" }
    ]

    padding: 0

    actions: [
        Kirigami.Action {
            text: "Refresh"
            icon.name: "view-refresh"
            onTriggered: devicePage.load()
        }
    ]

    function load() {
        Hub.call("GET", "/api/devices/" + serial, null, function (ok, data, message) {
            if (!ok || !data.device) {
                devicePage.loadError = message || "This device did not answer."
                return
            }
            devicePage.loadError = ""
            devicePage.device = data.device
        })
    }

    function send(method, path, body, done) {
        body.deviceId = serial
        busy = true
        Hub.call(method, path, body, function (ok, data, message) {
            devicePage.busy = false
            if (!ok)
                applicationWindow().showPassiveNotification(message || "The mouse did not accept that change.")
            devicePage.load()
            if (done)
                done(ok, data)
        })
    }

    Component.onCompleted: {
        for (const s of sections) {
            if (s.key === startSection)
                section = startSection
        }
        load()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SectionMenu {
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            sections: devicePage.sections
            current: devicePage.section
            onPicked: key => devicePage.section = key
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 12

                MouseView {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    visible: devicePage.device !== null
                    device: devicePage.device
                    selected: devicePage.section === "assignments" ? devicePage.selectedButton : ""
                    onButtonTapped: index => {
                        devicePage.selectedButton = index
                        devicePage.section = "assignments"
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: devicePage.device === null && devicePage.loadError !== ""
                    icon.name: "dialog-warning"
                    text: "Could not read the mouse"
                    explanation: devicePage.loadError
                    helpfulAction: Kirigami.Action {
                        text: "Try again"
                        icon.name: "view-refresh"
                        onTriggered: devicePage.load()
                    }
                }
                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: devicePage.device === null && devicePage.loadError === ""
                    visible: running
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.largeSpacing
                    visible: devicePage.device !== null && devicePage.device.BatteryLevel > 0
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: !devicePage.device ? "battery-full" : devicePage.device.BatteryLevel <= 15 ? "battery-low"
                            : devicePage.device.BatteryLevel <= 50 ? "battery-good" : "battery-full"
                    }
                    QQC2.Label {
                        text: "Battery " + (devicePage.device ? devicePage.device.BatteryLevel : 0) + " %"
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            QQC2.Pane {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 16, devicePage.height * 0.46)
                padding: Kirigami.Units.largeSpacing
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false

                contentItem: Loader {
                    active: devicePage.device !== null
                    sourceComponent: devicePage.section === "assignments" ? assignments
                        : devicePage.section === "lighting" ? lighting
                        : devicePage.section === "dpi" ? dpi : deviceSettings
                }
            }
        }
    }

    Component {
        id: assignments
        MsAssignments { page: devicePage }
    }
    Component {
        id: lighting
        MsLighting { page: devicePage }
    }
    Component {
        id: dpi
        MsDpi { page: devicePage }
    }
    Component {
        id: deviceSettings
        MsDevice { page: devicePage }
    }
}
