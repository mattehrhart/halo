import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Kirigami.Page {
    id: devicePage

    property string serial: ""
    property string startSection: ""
    // The device as OpenLinkHub describes it; null until loaded.
    property var device: null
    property var keymap: KeyLayout.build({})
    property string section: "lighting"
    property var selected: ({})
    property bool busy: false
    property string loadError: ""

    readonly property var selectedIds: Object.keys(selected).map(Number).sort((a, b) => a - b)
    readonly property var sections: [
        { key: "lighting", text: "Lighting Effects", icon: "color-management" },
        { key: "actuation", text: "Key Actuation", icon: "transform-move-vertical" },
        { key: "performance", text: "Performance", icon: "speedometer" },
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
            const dev = data.device
            const board = dev.DeviceProfile.Keyboards[dev.DeviceProfile.Profile]
            devicePage.keymap = KeyLayout.build(board ? board.row : {})
            devicePage.device = dev
        })
    }

    // Sends one change, then re-reads the device so the screen shows what
    // the keyboard actually accepted.
    function send(method, path, body, done) {
        body.deviceId = serial
        busy = true
        Hub.call(method, path, body, function (ok, data, message) {
            devicePage.busy = false
            if (!ok)
                applicationWindow().showPassiveNotification(message || "The keyboard did not accept that change.")
            devicePage.load()
            if (done)
                done(ok, data)
        })
    }

    // Sends the same kind of change for several keys, one after another.
    function sendEach(path, bodies, done) {
        let index = 0
        let failures = 0
        busy = true
        function next() {
            if (index >= bodies.length) {
                devicePage.busy = false
                if (failures > 0)
                    applicationWindow().showPassiveNotification(failures + " of " + bodies.length + " keys did not accept the change.")
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
        const next = extend ? Object.assign({}, selected) : {}
        if (extend && selected[id])
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

            // The stage: the keyboard itself.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 12

                KeyboardView {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    anchors.bottomMargin: Kirigami.Units.gridUnit * 2
                    visible: devicePage.device !== null
                    keymap: devicePage.keymap
                    device: devicePage.device
                    selected: devicePage.selected
                    badge: devicePage.section === "actuation" ? "actuation" : ""
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
                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: devicePage.device === null && devicePage.loadError === ""
                    visible: running
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    visible: devicePage.device !== null
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        text: devicePage.selectedIds.length === 0 ? "Click a key to select it. Hold Ctrl to select several."
                            : devicePage.selectedIds.length === 1 ? "1 key selected" : devicePage.selectedIds.length + " keys selected"
                        color: Kirigami.Theme.disabledTextColor
                    }
                    Item { Layout.fillWidth: true }
                    QQC2.BusyIndicator {
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        running: devicePage.busy
                        visible: running
                    }
                    QQC2.ToolButton {
                        text: "Select all"
                        icon.name: "edit-select-all"
                        onClicked: devicePage.selectAll()
                    }
                    QQC2.ToolButton {
                        text: "Clear selection"
                        icon.name: "edit-select-none"
                        enabled: devicePage.selectedIds.length > 0
                        onClicked: devicePage.selected = ({})
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // The controls for the chosen section.
            QQC2.Pane {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 16, devicePage.height * 0.42)
                padding: Kirigami.Units.largeSpacing
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false

                contentItem: Loader {
                    active: devicePage.device !== null
                    sourceComponent: devicePage.section === "lighting" ? lighting
                        : devicePage.section === "actuation" ? actuation
                        : devicePage.section === "performance" ? performance : deviceSettings
                }
            }
        }
    }

    Component {
        id: lighting
        KbLighting { page: devicePage }
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
