// Settings for each part of a hub, cooler, memory kit or power supply:
// its name, fan curve and lighting.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var parts: KeyLayout.parts(device)
    readonly property var modes: KeyLayout.orderedModes(device.RGBModes || [])
    // Fan curves saved in OpenLinkHub.
    property var curves: []
    readonly property bool anyMode: parts.some(p => p.operatingModes && Object.keys(p.operatingModes).length > 0)
    readonly property bool anySpeed: parts.some(p => p.HasSpeed === true) && !device.FanModes
    readonly property bool anyLight: modes.length > 0 && parts.some(p => p.rgb !== undefined)
    readonly property var fanModes: Object.keys(device.FanModes || {}).map(Number).sort((a, b) => a - b)
        .map(v => ({ value: v, name: device.FanModes[String(v)] }))

    spacing: Kirigami.Units.largeSpacing

    property bool curvesRead: false

    function loadCurves() {
        Hub.call("GET", "/api/temperatures/", null, function (ok, data) {
            if (ok && data.data)
                root.curves = Object.keys(data.data).filter(name => !data.data[name].Hidden).sort()
            root.curvesRead = true
        })
    }

    Component.onCompleted: {
        loadCurves()
        // Test hook: --route <device>/parts/curves opens the editor.
        if (page.startSelect === "curves")
            curveEditor.open()
    }

    FanCurves {
        id: curveEditor
        onChanged: root.loadCurves()
    }

    Panel {
        title: root.page.kind === "memory" ? "Modules" : "Fans and Sensors"
        // A power supply's outputs have nothing to set; they are read above.
        visible: root.fanModes.length === 0
        Layout.fillWidth: true

        GridLayout {
            Layout.fillWidth: true
            columns: 5
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: "Name"; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: "Type"; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: root.anySpeed ? "Fan curve" : ""; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: root.anyLight ? "Lighting" : ""; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: root.anyMode ? "Header mode" : ""; opacity: 0.7; font: Kirigami.Theme.smallFont }

            Repeater {
                model: root.parts

                QQC2.TextField {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    text: KeyLayout.partName(modelData)
                    enabled: modelData.label !== undefined
                    maximumLength: 32
                    Accessible.name: "Name of " + (modelData.name || "part")
                    onEditingFinished: {
                        const wanted = text.trim()
                        if (wanted === "" || wanted === KeyLayout.partName(modelData)) {
                            text = KeyLayout.partName(modelData)
                            return
                        }
                        root.page.send("POST", "/api/label", { channelId: modelData.channelId, deviceType: 0, label: wanted }, null, "Renamed")
                    }
                }
            }
            Repeater {
                model: root.parts

                QQC2.Label {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 1
                    Layout.fillWidth: true
                    text: KeyLayout.partKind(modelData)
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
            Repeater {
                model: root.parts

                QQC2.ComboBox {
                    required property var modelData
                    required property int index
                    readonly property var list: root.curves.indexOf(modelData.profile) < 0 && modelData.profile ? root.curves.concat([modelData.profile]) : root.curves

                    Layout.row: index + 1
                    Layout.column: 2
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    visible: root.anySpeed && modelData.HasSpeed === true
                    enabled: !root.page.busy
                    model: list
                    currentIndex: list.indexOf(modelData.profile)
                    displayText: !root.curvesRead ? "Loading…" : list.length === 0 ? "No curves" : currentText
                    Accessible.name: "Fan curve for " + KeyLayout.partName(modelData)
                    onActivated: i => {
                        if (list[i] !== modelData.profile)
                            root.page.send("POST", "/api/speed", { channelId: modelData.channelId, profile: list[i] }, null, list[i])
                    }
                }
            }
            Repeater {
                model: root.parts

                QQC2.ComboBox {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 3
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    visible: root.anyLight && modelData.rgb !== undefined && modelData.rgb !== ""
                    enabled: !root.page.busy
                    model: root.modes.map(m => KeyLayout.title(m))
                    currentIndex: root.modes.indexOf(modelData.rgb)
                    Accessible.name: "Lighting for " + KeyLayout.partName(modelData)
                    onActivated: i => {
                        if (root.modes[i] !== modelData.rgb)
                            root.page.send("POST", "/api/color", { channelId: modelData.channelId, profile: root.modes[i] }, null, KeyLayout.title(root.modes[i]))
                    }
                }
            }
            Repeater {
                model: root.parts

                QQC2.ComboBox {
                    required property var modelData
                    required property int index
                    readonly property var list: Object.keys(modelData.operatingModes || {}).map(Number).sort((a, b) => a - b)
                        .map(v => ({ value: v, name: modelData.operatingModes[String(v)] }))

                    Layout.row: index + 1
                    Layout.column: 4
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    visible: list.length > 0
                    enabled: !root.page.busy
                    textRole: "name"
                    model: list
                    currentIndex: list.findIndex(m => m.value === modelData.headerMode)
                    Accessible.name: "Header mode for " + KeyLayout.partName(modelData)
                    onActivated: i => root.page.send("POST", "/api/operatingMode", { channelId: modelData.channelId, operatingMode: list[i].value }, null, list[i].name)
                }
            }
        }
    }

    Panel {
        title: "Fan"
        visible: root.fanModes.length > 0
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: false

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label { text: "Speed" }
            QQC2.ComboBox {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                enabled: !root.page.busy
                textRole: "name"
                model: root.fanModes
                currentIndex: root.fanModes.findIndex(m => m.value === root.device.DeviceProfile.FanMode)
                Accessible.name: "Fan speed"
                onActivated: i => root.page.send("POST", "/api/psu/speed", { fanMode: root.fanModes[i].value }, null, "Fan " + root.fanModes[i].name)
            }
        }
    }

    Panel {
        title: "Fan Curves"
        visible: root.anySpeed
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: false

        QQC2.Button {
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            text: "Edit Curves…"
            icon.name: "office-chart-line"
            onClicked: curveEditor.open()
        }
        RowLayout {
            visible: root.parts.filter(p => p.HasSpeed === true).length > 1
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label { text: "All fans" }
            QQC2.ComboBox {
                id: every

                readonly property string shared: {
                    const used = root.parts.filter(p => p.HasSpeed === true).map(p => p.profile)
                    return used.length > 0 && used[0] && used.every(p => p === used[0]) ? used[0] : ""
                }

                Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                enabled: !root.page.busy
                model: root.curves
                currentIndex: root.curves.indexOf(shared)
                displayText: !root.curvesRead ? "Loading…" : root.curves.length === 0 ? "No curves" : currentIndex < 0 ? "Mixed" : currentText
                Accessible.name: "Fan curve for all fans"
                // OpenLinkHub reads a negative channel as "every fan".
                onActivated: i => root.page.send("POST", "/api/speed", { channelId: -1, profile: root.curves[i] }, null, root.curves[i])
            }
        }
    }
    Item {
        visible: root.fanModes.length > 0
        Layout.fillWidth: true
    }
}
