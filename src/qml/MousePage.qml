import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Kirigami.Page {
    id: devicePage

    property string serial: ""
    property string startSection: ""
    // A button index to select at start (used with --route).
    property string startSelect: ""
    property var device: null
    property string section: "assignments"
    // Index of the selected button in device.KeyAssignment.
    property string selectedButton: ""
    property bool busy: false
    property string loadError: ""
    // Set while a control is mid-drag, so the periodic re-read waits.
    property bool holdRefresh: false
    // The last change the device refused, shown in a banner until dismissed.
    property string problem: ""
    // Live measurements by part number, for devices made of parts.
    property var readings: ({})
    property string lastShape: ""
    readonly property bool system: device !== null && KeyLayout.parts(device).length > 0

    // What kind of device this is, as OpenLinkHub's settings addresses name it.
    property string kind: "mouse"
    readonly property string family: kind === "headset" ? "headset" : "mouse"
    // Only the sections this model has anything for.
    readonly property var sections: {
        const list = []
        if (!device)
            return list
        const parts = KeyLayout.parts(device)
        if (parts.length > 0)
            list.push({ key: "parts", text: kind === "memory" ? "Modules" : kind === "power" ? "Power" : "Fans and Sensors",
                        icon: kind === "memory" ? "media-flash" : kind === "power" ? "battery-profile-performance" : "temperature-normal" })
        if (device.RGBModes && device.RGBModes.length > 0 && device.DeviceProfile
                && (device.DeviceProfile.RGBProfile !== undefined || parts.some(p => p.rgb !== undefined && p.rgb !== "")))
            list.push({ key: "lighting", text: "Lighting Effects", icon: "color-management-symbolic" })
        if (device.HasLCD === true && device.LCDModes)
            list.push({ key: "lcd", text: "Screen", icon: "video-display" })
        if ((device.ExternalLedDevice && device.ExternalLedDevice.length > 0) || (device.LinkAdapter && parts.some(p => p.IsLinkAdapter === true)))
            list.push({ key: "ports", text: "LED Ports", icon: "network-connect" })
        if (device.DeviceProfile && device.DeviceProfile.WidgetAreas)
            list.push({ key: "widgets", text: "Widgets", icon: "view-grid" })
        if (device.KeyAssignment && Object.keys(device.KeyAssignment).length > 0)
            list.push({ key: "assignments", text: "Key Assignments", icon: "input-mouse" })
        if (device.MinDPI && device.DeviceProfile && device.DeviceProfile.Profiles)
            list.push({ key: "dpi", text: "DPI", icon: "speedometer" })
        list.push({ key: "device", text: "Device Settings", icon: "configure" })
        return list
    }
    onSectionsChanged: {
        if (sections.length > 0 && !sections.some(s => s.key === section))
            section = sections.some(s => s.key === startSection) ? startSection : sections[0].key
    }

    padding: Kirigami.Units.largeSpacing

    // Reads the device. Measurements are split off so the settings (and every
    // control bound to them) are only replaced when a setting really changed,
    // or when always is true (after a change of our own).
    function load(always) {
        Hub.call("GET", "/api/devices/" + serial, null, function (ok, data, message) {
            if (!ok || !data.device) {
                devicePage.loadError = message || "This device did not answer."
                return
            }
            devicePage.loadError = ""
            devicePage.readings = KeyLayout.takeReadings(data.device)
            const shape = JSON.stringify(data.device)
            if (always === true || shape !== devicePage.lastShape || devicePage.device === null) {
                devicePage.lastShape = shape
                devicePage.device = data.device
            }
        })
    }

    // Shows a short confirmation in the status line.
    function say(text) {
        status.show(text)
    }

    function send(method, path, body, done, okText) {
        body.deviceId = serial
        busy = true
        Hub.call(method, path, body, function (ok, data, message) {
            devicePage.busy = false
            if (!ok)
                devicePage.problem = message || "The mouse did not accept that change."
            else if (okText)
                status.show(okText)
            devicePage.load(true)
            if (done)
                done(ok, data)
        })
    }

    Connections {
        target: applicationWindow()
        function onLightsChanged() { devicePage.load() }
    }

    // OpenLinkHub cannot announce changes, so the page asks several times a
    // second and compares the answer with the last one. Nothing is redrawn
    // unless something really changed (temperatures in the answer are
    // ignored, since they change constantly).
    property string lastSeen: ""

    function watch() {
        if (busy || holdRefresh)
            return
        Hub.fetchText("/api/devices/" + serial, function (text) {
            const seen = text.replace(/"(CpuTemp|GpuTemp)":[-0-9.]+/g, "")
            if (text === "" || seen === devicePage.lastSeen || devicePage.busy || devicePage.holdRefresh)
                return
            devicePage.lastSeen = seen
            devicePage.load()
        })
    }

    Timer {
        // Fan speeds and temperatures do not need more than once a second.
        interval: devicePage.system ? 1000 : 250
        repeat: true
        running: devicePage.visible && devicePage.device !== null && applicationWindow().visible
        onTriggered: devicePage.watch()
    }

    Component.onCompleted: {
        if (startSection !== "")
            section = startSection
        selectedButton = startSelect
        load()
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Kirigami.Units.gridUnit * 130)
        spacing: Kirigami.Units.largeSpacing

        DeviceStrip {
            Layout.fillWidth: true
            current: devicePage.serial
            onRefresh: devicePage.load(true)
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: devicePage.problem !== ""
            type: Kirigami.MessageType.Error
            text: devicePage.problem
            showCloseButton: true
            onVisibleChanged: {
                if (!visible)
                    devicePage.problem = ""
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 14.5
            spacing: Kirigami.Units.largeSpacing

            SectionMenu {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                title: devicePage.title
                subtitle: !devicePage.device ? ""
                    : devicePage.device.BatteryLevel > 0 ? "Battery " + devicePage.device.BatteryLevel + "%"
                    : devicePage.device.firmware ? "Firmware " + devicePage.device.firmware : ""
                sections: devicePage.sections
                current: devicePage.section
                onPicked: key => devicePage.section = key
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    anchors.fill: parent
                    active: devicePage.system
                    sourceComponent: SysOverview { page: devicePage }
                }
                MouseView {
                    anchors.fill: parent
                    anchors.bottomMargin: Kirigami.Units.gridUnit * 2
                    interactive: devicePage.section === "assignments"
                    visible: devicePage.device !== null && !devicePage.system
                    device: devicePage.device
                    diagram: devicePage.device ? deviceImages.info(devicePage.device.product) : ({})
                    traced: devicePage.device ? deviceImages.outline(devicePage.device.product, devicePage.device.Usb === false) : ({})
                    selected: devicePage.section === "assignments" ? devicePage.selectedButton : ""
                    onButtonTapped: index => devicePage.selectedButton = index
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: devicePage.device === null && devicePage.loadError !== ""
                    icon.name: "dialog-warning"
                    text: "Could not read this device"
                    explanation: devicePage.loadError
                    helpfulAction: Kirigami.Action {
                        text: "Try again"
                        icon.name: "view-refresh"
                        onTriggered: devicePage.load()
                    }
                }
                PageSkeleton {
                    anchors.fill: parent
                    visible: devicePage.device === null && devicePage.loadError === ""
                    part: "view"
                }
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Kirigami.Units.gridUnit * 2
                    visible: devicePage.device !== null
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        visible: devicePage.section === "assignments"
                        opacity: 0.7
                        text: !devicePage.device || !devicePage.device.KeyAssignment || devicePage.selectedButton === "" || !devicePage.device.KeyAssignment[devicePage.selectedButton]
                            ? "Click a button to reassign it."
                            : devicePage.device.KeyAssignment[devicePage.selectedButton].name + " selected"
                    }
                    Item { Layout.fillWidth: true }
                    StatusLine {
                        id: status
                        busy: devicePage.busy
                    }
                }
            }
        }

        PageSkeleton {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 16, devicePage.height * 0.42)
            visible: devicePage.device === null && devicePage.loadError === ""
            part: "panels"
        }
        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 16, devicePage.height * 0.42)
            visible: devicePage.device !== null
            active: devicePage.device !== null
            sourceComponent: devicePage.device === null ? null
                : devicePage.section === "assignments" ? assignments
                : devicePage.section === "lighting" ? (devicePage.device.DeviceProfile.RGBProfile === undefined ? partLighting : lighting)
                : devicePage.section === "dpi" ? dpi
                : devicePage.section === "parts" ? partList
                : devicePage.section === "lcd" ? screen
                : devicePage.section === "ports" ? ports
                : devicePage.section === "widgets" ? widgets : deviceSettings
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
        id: partList
        SysChannels { page: devicePage }
    }
    Component {
        id: partLighting
        SysLighting { page: devicePage }
    }
    Component {
        id: ports
        SysPorts { page: devicePage }
    }
    Component {
        id: widgets
        SysWidgets { page: devicePage }
    }
    Component {
        id: screen
        SysLcd { page: devicePage }
    }
    Component {
        id: deviceSettings
        MsDevice { page: devicePage }
    }
}
