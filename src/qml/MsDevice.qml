import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device

    spacing: Kirigami.Units.gridUnit

    // {"1": "1 minute", ...} -> [{value: 1, name: "1 minute"}, ...] in number order.
    function options(map) {
        return Object.keys(map || {}).map(Number).sort((a, b) => a - b).map(v => ({ value: v, name: map[String(v)] }))
    }

    Panel {
        title: "Mouse"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.Label {
                Kirigami.FormData.label: "Model:"
                text: root.device.product
            }
            QQC2.Label {
                Kirigami.FormData.label: "Firmware:"
                text: root.device.firmware
            }
            QQC2.Label {
                Kirigami.FormData.label: "Connection:"
                text: root.device.Usb ? "USB cable" : "Wireless receiver"
            }
            QQC2.Label {
                Kirigami.FormData.label: "Battery:"
                visible: root.device.BatteryLevel > 0
                text: root.device.BatteryLevel + " %"
            }
        }
    }

    Panel {
        title: "Behaviour"
        Layout.fillWidth: true

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                id: sleep

                readonly property var list: root.options(root.device.SleepModes)

                Kirigami.FormData.label: "Sleep after:"
                visible: list.length > 0 && !root.device.Usb
                model: list
                textRole: "name"
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.SleepMode)
                enabled: !root.page.busy
                onActivated: index => root.page.send("POST", "/api/mouse/sleep", { sleepMode: list[index].value })
            }
            QQC2.ComboBox {
                id: polling

                readonly property var list: root.options(root.device.PollingRates).filter(o => o.value > 0)

                Kirigami.FormData.label: "Polling rate:"
                visible: list.length > 0
                model: list
                textRole: "name"
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.PollingRate)
                enabled: !root.page.busy
                onActivated: index => root.page.send("POST", "/api/mouse/pollingRate", { pollingRate: list[index].value })
            }
            QQC2.ComboBox {
                id: lift

                readonly property var list: root.options(root.device.LiftHeights)

                Kirigami.FormData.label: "Lift height:"
                visible: list.length > 0
                model: list
                textRole: "name"
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.LiftHeight)
                enabled: !root.page.busy
                onActivated: index => root.page.send("POST", "/api/mouse/liftHeight", { liftHeight: list[index].value })
            }
            QQC2.Switch {
                Kirigami.FormData.label: "Angle snapping:"
                checked: root.device.DeviceProfile.AngleSnapping === 1
                enabled: !root.page.busy
                onToggled: root.page.send("POST", "/api/mouse/angleSnapping", { angleSnapping: checked ? 1 : 0 })
                Accessible.name: "Angle snapping"
            }
            QQC2.Switch {
                Kirigami.FormData.label: "Faster button response:"
                checked: root.device.DeviceProfile.ButtonOptimization === 1
                enabled: !root.page.busy
                onToggled: root.page.send("POST", "/api/mouse/buttonOptimization", { buttonOptimization: checked ? 1 : 0 })
                Accessible.name: "Faster button response"
            }
        }
    }
}
