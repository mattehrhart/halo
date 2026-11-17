// What is plugged into a hub's lighting ports, which the hub cannot detect.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var profile: device.DeviceProfile
    readonly property var kinds: (device.ExternalLedDevice || []).map(d => ({ value: d.Index, name: d.Name }))
    readonly property var amounts: Object.keys(device.ExternalLedDeviceAmount || {}).map(Number).sort((a, b) => a - b)
        .map(v => ({ value: v, name: String(device.ExternalLedDeviceAmount[String(v)]) }))
    // [{port, kind, amount}] for hubs with one or several plain LED ports.
    readonly property var ports: {
        if (kinds.length === 0)
            return []
        if (profile.ExternalHubs && typeof profile.ExternalHubs === "object")
            return Object.keys(profile.ExternalHubs).map(Number).sort((a, b) => a - b).map(k => {
                const hub = profile.ExternalHubs[String(k)]
                return { port: hub.PortId, kind: hub.ExternalHubDeviceType, amount: hub.ExternalHubDeviceAmount }
            })
        if (profile.ExternalHubDeviceType !== undefined)
            return [{ port: 0, kind: profile.ExternalHubDeviceType, amount: profile.ExternalHubDeviceAmount }]
        return []
    }
    readonly property var adapters: KeyLayout.parts(device).filter(p => p.IsLinkAdapter === true)
    readonly property var adapterKinds: (device.LinkAdapter || []).map(a => ({ value: a.Index, name: a.Name }))

    spacing: Kirigami.Units.largeSpacing

    Panel {
        title: "LED Ports"
        description: "Tell the hub what is connected so the lights line up."
        visible: root.ports.length > 0
        Layout.fillWidth: true

        GridLayout {
            columns: 3
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: "Port"; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: "Connected"; opacity: 0.7; font: Kirigami.Theme.smallFont }
            QQC2.Label { text: "How many"; opacity: 0.7; font: Kirigami.Theme.smallFont }

            Repeater {
                model: root.ports

                QQC2.Label {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 0
                    text: root.ports.length > 1 ? "Port " + (index + 1) : "LED port"
                }
            }
            Repeater {
                model: root.ports

                QQC2.ComboBox {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 1
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    enabled: !root.page.busy
                    textRole: "name"
                    model: root.kinds
                    currentIndex: root.kinds.findIndex(k => k.value === modelData.kind)
                    Accessible.name: "Connected to port " + (index + 1)
                    onActivated: i => root.page.send("POST", "/api/hub/type", { portId: modelData.port, deviceType: root.kinds[i].value }, null, root.kinds[i].name)
                }
            }
            Repeater {
                model: root.ports

                QQC2.ComboBox {
                    required property var modelData
                    required property int index

                    Layout.row: index + 1
                    Layout.column: 2
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    enabled: !root.page.busy && modelData.kind !== 0
                    textRole: "name"
                    model: root.amounts
                    currentIndex: root.amounts.findIndex(a => a.value === modelData.amount)
                    Accessible.name: "How many on port " + (index + 1)
                    onActivated: i => root.page.send("POST", "/api/hub/amount", { portId: modelData.port, deviceAmount: root.amounts[i].value }, null, root.amounts[i].name + " connected")
                }
            }
        }
    }

    Panel {
        title: "Adapters"
        description: "What each LINK adapter is driving."
        visible: root.adapters.length > 0 && root.adapterKinds.length > 0
        Layout.fillWidth: true

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.adapters

                QQC2.Label {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 0
                    text: KeyLayout.partName(modelData)
                }
            }
            Repeater {
                model: root.adapters

                QQC2.ComboBox {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 1
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    enabled: !root.page.busy
                    textRole: "name"
                    model: root.adapterKinds
                    currentIndex: root.adapterKinds.findIndex(k => k.value === modelData.ExternalAdapter)
                    Accessible.name: "Connected to " + KeyLayout.partName(modelData)
                    onActivated: i => root.page.send("POST", "/api/hub/linkAdapter", { channelId: modelData.channelId, adapterId: root.adapterKinds[i].value }, null, root.adapterKinds[i].name)
                }
            }
        }
    }
}
