import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device

    spacing: Kirigami.Units.largeSpacing

    // {"1": "1 minute", ...} -> [{value: 1, name: "1 minute"}, ...] in number order.
    function options(map) {
        return Object.keys(map || {}).map(Number).sort((a, b) => a - b).map(v => ({ value: v, name: map[String(v)] }))
    }

    component Choice: QQC2.ComboBox {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        textRole: "name"
        enabled: !root.page.busy
    }

    Panel {
        title: "Connection"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            QQC2.Label { text: "Type"; opacity: 0.7 }
            QQC2.Label { text: root.device.Usb === false ? "Wireless receiver" : "USB cable" }
            QQC2.Label { text: "Firmware"; opacity: 0.7; visible: !!root.device.firmware }
            QQC2.Label { text: root.device.firmware || ""; visible: !!root.device.firmware }
        }
        // Whatever Halo has no control for yet is still in OpenLinkHub's own page.
        QQC2.Button {
            text: "More in OpenLinkHub"
            icon.name: "internet-services"
            onClicked: Qt.openUrlExternally(Hub.base + "/device/" + root.page.serial)
        }
    }

    Item {
        visible: !behavior.visible
        Layout.fillWidth: true
    }
    Panel {
        id: behavior

        title: "Behavior"
        Layout.fillWidth: true
        visible: sleep.list.length > 0 || polling.list.length > 0 || lift.list.length > 0
            || (root.device.DeviceProfile && (root.device.DeviceProfile.AngleSnapping !== undefined || root.device.DeviceProfile.ButtonOptimization !== undefined))

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                visible: sleep.visible
                text: "Sleep after"
            }
            Choice {
                id: sleep

                readonly property var list: root.options(root.device.SleepModes)

                visible: list.length > 0 && !root.device.Usb
                model: list
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.SleepMode)
                onActivated: index => root.page.send("POST", "/api/" + root.page.family + "/sleep", { sleepMode: list[index].value }, null, "Sleep after " + list[index].name)
                Accessible.name: "Sleep after"
            }

            QQC2.Label {
                visible: polling.visible
                text: "Polling rate"
            }
            Choice {
                id: polling

                readonly property var list: root.options(root.device.PollingRates).filter(o => o.value > 0)
                    .map(o => ({ value: o.value, name: KeyLayout.rate(o.name) }))

                visible: list.length > 0
                model: list
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.PollingRate)
                onActivated: index => root.page.send("POST", "/api/mouse/pollingRate", { pollingRate: list[index].value }, null, "Polling rate " + list[index].name)
                Accessible.name: "Polling rate"
            }

            QQC2.Label {
                visible: lift.visible
                text: "Lift height"
            }
            Choice {
                id: lift

                readonly property var list: root.options(root.device.LiftHeights)

                visible: list.length > 0
                model: list
                currentIndex: list.findIndex(o => o.value === root.device.DeviceProfile.LiftHeight)
                onActivated: index => root.page.send("POST", "/api/mouse/liftHeight", { liftHeight: list[index].value }, null, "Lift height " + list[index].name)
                Accessible.name: "Lift height"
            }

            QQC2.Label {
                text: "Angle snapping"
                visible: root.device.DeviceProfile.AngleSnapping !== undefined
            }
            QQC2.Switch {
                visible: root.device.DeviceProfile.AngleSnapping !== undefined
                checked: root.device.DeviceProfile.AngleSnapping === 1
                enabled: !root.page.busy
                onToggled: root.page.send("POST", "/api/mouse/angleSnapping", { angleSnapping: checked ? 1 : 0 }, null, "Angle snapping " + (checked ? "on" : "off"))
                Accessible.name: "Angle snapping"
            }

            QQC2.Label {
                text: "Faster button response"
                visible: root.device.DeviceProfile.ButtonOptimization !== undefined
            }
            QQC2.Switch {
                visible: root.device.DeviceProfile.ButtonOptimization !== undefined
                checked: root.device.DeviceProfile.ButtonOptimization === 1
                enabled: !root.page.busy
                onToggled: root.page.send("POST", "/api/mouse/buttonOptimization", { buttonOptimization: checked ? 1 : 0 }, null, "Button response " + (checked ? "faster" : "normal"))
                Accessible.name: "Faster button response"
            }
        }
    }

    Panel {
        title: "Reset"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: false

        QQC2.Button {
            text: "Reset to Defaults…"
            icon.name: "edit-reset"
            enabled: !root.page.busy
            onClicked: confirmReset.open()
        }
    }

    Kirigami.PromptDialog {
        id: confirmReset

        title: "Reset " + root.device.product + "?"
        subtitle: "Lighting, assignments and other settings for this device return to their defaults."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: root.page.send("POST", "/api/resetSettings", {}, null, "Reset to defaults")
    }
}
