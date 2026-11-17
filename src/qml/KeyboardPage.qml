import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Kirigami.Page {
    id: devicePage

    property string serial: ""
    property string startSection: ""
    // A key id to select at start (used with --route).
    property string startSelect: ""
    // The device as OpenLinkHub describes it; null until loaded.
    property var device: null
    property var keymap: KeyLayout.build({})
    property string section: "lighting"
    property var selected: ({})
    property bool busy: false
    property string loadError: ""
    // Set while a control is mid-drag, so the periodic check waits.
    property bool holdRefresh: false
    // The last change the device refused, shown in a banner until dismissed.
    property string problem: ""

    readonly property var selectedIds: Object.keys(selected).map(Number).sort((a, b) => a - b)
    // Only the sections this model has anything for: adjustable switches
    // are on a few magnetic models only.
    readonly property var sections: {
        const list = [
            { key: "lighting", text: "Lighting Effects", icon: "color-management-symbolic" },
            { key: "assignments", text: "Key Assignments", icon: "input-keyboard" }
        ]
        if (keymap.keys.some(k => KeyLayout.adjustable(k.raw)))
            list.push({ key: "actuation", text: "Key Actuation", icon: "transform-move-vertical" })
        list.push({ key: "performance", text: "Performance", icon: "speedometer" })
        list.push({ key: "device", text: "Device Settings", icon: "configure" })
        return list
    }
    onSectionsChanged: {
        if (device !== null && !sections.some(s => s.key === section))
            section = "lighting"
    }

    padding: Kirigami.Units.largeSpacing

    // Keys can be selected only where a selection does something.
    readonly property bool selectable: section === "assignments" || section === "actuation"
        || (section === "lighting" && device !== null && device.DeviceProfile.RGBProfile === "keyboard")

    function load() {
        Hub.call("GET", "/api/devices/" + serial, null, function (ok, data, message) {
            if (!ok || !data.device) {
                devicePage.loadError = message || "This device did not answer."
                return
            }
            devicePage.loadError = ""
            const dev = data.device
            const board = dev.DeviceProfile.Keyboards[dev.DeviceProfile.Profile]
            // Models with a hand-made diagram keep the measurements it was drawn to.
            const drawn = deviceImages.info(dev.product || dev.Product || "").width !== undefined
            devicePage.keymap = drawn ? KeyLayout.build(board ? board.row : {}) : KeyLayout.buildGrid(board ? board.row : {})
            devicePage.device = dev
        })
    }

    // Sends one change, then re-reads the device so the screen shows what
    // the keyboard actually accepted.
    function send(method, path, body, done, okText) {
        body.deviceId = serial
        busy = true
        Hub.call(method, path, body, function (ok, data, message) {
            devicePage.busy = false
            if (!ok)
                devicePage.problem = message || "The keyboard did not accept that change."
            else if (okText)
                status.show(okText)
            devicePage.load()
            if (done)
                done(ok, data)
        })
    }

    // Sends the same kind of change for several keys, one after another.
    function sendEach(path, bodies, done, okText) {
        let index = 0
        let failures = 0
        busy = true
        function next() {
            if (index >= bodies.length) {
                devicePage.busy = false
                if (failures > 0)
                    devicePage.problem = "Part of that change was not accepted by the keyboard."
                else
                    status.show(okText || (bodies.length === 1 ? "Key updated" : bodies.length + " keys updated"))
                devicePage.load()
                if (done)
                    done(failures === 0)
                return
            }
            const body = bodies[index++]
            body.deviceId = serial
            Hub.call("POST", path, body, function (ok) {
                if (!ok)
                    failures++
                next()
            })
        }
        next()
    }

    function tapKey(id, extend) {
        // Assignments are made one key at a time.
        const multi = extend && section !== "assignments"
        const next = multi ? Object.assign({}, selected) : {}
        if (multi && selected[id])
            delete next[id]
        else
            next[id] = true
        selected = next
    }

    function selectAll() {
        const next = {}
        for (const key of keymap.keys)
            next[key.id] = true
        selected = next
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
        interval: 500
        repeat: true
        running: devicePage.visible && devicePage.device !== null && applicationWindow().visible
        onTriggered: devicePage.watch()
    }

    Connections {
        target: applicationWindow()
        function onLightsChanged() { devicePage.load() }
    }

    Component.onCompleted: {
        if (startSection !== "")
            section = startSection
        if (/^[0-9,]+$/.test(startSelect)) {
            const first = {}
            for (const id of startSelect.split(","))
                first[Number(id)] = true
            selected = first
        }
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
            onRefresh: devicePage.load()
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
                subtitle: devicePage.device ? "Firmware " + devicePage.device.firmware : ""
                sections: devicePage.sections
                current: devicePage.section
                onPicked: key => {
                    devicePage.section = key
                    if (key === "assignments" && devicePage.selectedIds.length > 1)
                        devicePage.selected = ({})
                }
            }

            // The stage: the keyboard itself.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                KeyboardView {
                    anchors.fill: parent
                    anchors.bottomMargin: Kirigami.Units.gridUnit * 2
                    visible: devicePage.device !== null
                    keymap: devicePage.keymap
                    device: devicePage.device
                    diagram: devicePage.device ? deviceImages.info(devicePage.device.product) : ({})
                    selected: devicePage.selectable ? devicePage.selected : ({})
                    interactive: devicePage.selectable
                    badge: devicePage.section === "actuation" ? "actuation" : devicePage.section === "assignments" ? "assign" : ""
                    onKeyTapped: (id, extend) => devicePage.tapKey(id, extend)
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: devicePage.device === null && devicePage.loadError !== ""
                    icon.name: "dialog-warning"
                    text: "Could not read the keyboard"
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
                        visible: devicePage.selectable
                        opacity: 0.7
                        text: {
                            const count = devicePage.selectedIds.length
                            if (devicePage.section === "assignments")
                                return count === 0 || !devicePage.keymap.byId[devicePage.selectedIds[0]] ? "Click a key to reassign it."
                                    : KeyLayout.spokenName(devicePage.keymap.byId[devicePage.selectedIds[0]].name) + " selected"
                            return count === 0 ? "Click keys to select. Ctrl-click to add."
                                : count === 1 ? "1 key selected" : count + " keys selected"
                        }
                    }
                    Item { Layout.fillWidth: true }
                    StatusLine {
                        id: status
                        busy: devicePage.busy
                    }
                    QQC2.ToolButton {
                        visible: devicePage.selectable && devicePage.section !== "assignments"
                        text: "Select All"
                        icon.name: "edit-select-all"
                        onClicked: devicePage.selectAll()
                    }
                    QQC2.ToolButton {
                        visible: devicePage.selectable && devicePage.selectedIds.length > 0
                        text: "Clear"
                        icon.name: "edit-select-none"
                        onClicked: devicePage.selected = ({})
                    }
                }
            }
        }

        // The cards for the chosen section.
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
            sourceComponent: devicePage.section === "lighting" ? lighting
                : devicePage.section === "assignments" ? assignments
                : devicePage.section === "actuation" ? actuation
                : devicePage.section === "performance" ? performance : deviceSettings
        }
    }

    Component {
        id: lighting
        KbLighting { page: devicePage }
    }
    Component {
        id: assignments
        KbAssignments { page: devicePage }
    }
    Component {
        id: actuation
        KbActuation { page: devicePage }
    }
    Component {
        id: performance
        KbPerformance { page: devicePage }
    }
    Component {
        id: deviceSettings
        KbDevice { page: devicePage }
    }
}
