import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    // [{name, internal, value}] from OpenLinkHub: the shortcuts game mode blocks.
    property var locks: []
    // [{id, name}] keys that can be one half of a FlashTap pair.
    property var tapKeys: []
    property var flashTap: null
    readonly property var rates: Object.keys(device.PollingRates || {}).map(Number).filter(v => v > 0).sort((a, b) => a - b)
        .map(v => ({ value: v, name: KeyLayout.rate(device.PollingRates[String(v)]) }))

    spacing: Kirigami.Units.largeSpacing

    function reload() {
        Hub.call("GET", "/api/keyboard/getPerformance/" + page.serial, null, function (ok, data) {
            if (ok && data.data)
                root.locks = data.data
        })
        Hub.call("GET", "/api/keyboard/getFlashTap/" + page.serial, null, function (ok, data) {
            if (ok && data.data)
                root.flashTap = data.data
        })
        Hub.call("POST", "/api/keyboard/getKeys/", { deviceId: page.serial }, function (ok, data) {
            if (!ok || !data.data)
                return
            const list = []
            for (const id in data.data)
                list.push({ id: Number(id), name: KeyLayout.spokenName(data.data[id]) })
            list.sort((a, b) => a.id - b.id)
            root.tapKeys = list
        })
    }

    function tapIndex(slot) {
        if (!flashTap || !flashTap.keys || !flashTap.keys[slot])
            return -1
        // FlashTap stores the key's USB code; match it to the key list by name.
        const name = KeyLayout.spokenName(flashTap.keys[slot].Name)
        return tapKeys.findIndex(k => k.name === name)
    }

    function saveLocks() {
        const body = {}
        for (let i = 0; i < lockBoxes.count; i++)
            body[lockBoxes.itemAt(i).modelData.internal] = lockBoxes.itemAt(i).checked
        page.send("POST", "/api/keyboard/setPerformance", body, () => root.reload(), "Game mode updated")
    }

    function saveFlashTap() {
        if (tapA.currentIndex < 0 || tapB.currentIndex < 0)
            return
        const c = tapColor.value
        page.send("POST", "/api/keyboard/setFlashTap", {
            flashTapActive: tapOn.checked ? 1 : 0,
            flashTapKeys: [root.tapKeys[tapA.currentIndex].id, root.tapKeys[tapB.currentIndex].id],
            flashTapMode: tapMode.currentIndex,
            flashTapColor: { red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255) }
        }, () => root.reload(), "FlashTap updated")
    }

    Component.onCompleted: reload()

    QQC2.Label {
        visible: root.rates.length === 0 && root.locks.length === 0 && root.flashTap === null
        Layout.alignment: Qt.AlignTop
        opacity: 0.7
        text: "This keyboard has no performance settings."
    }

    Panel {
        visible: root.rates.length > 0
        title: "Polling Rate"
        description: "Reconnects briefly on change."
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        QQC2.ComboBox {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            model: root.rates
            textRole: "name"
            currentIndex: root.rates.findIndex(r => r.value === root.device.DeviceProfile.PollingRate)
            enabled: !root.page.busy
            onActivated: index => root.page.send("POST", "/api/keyboard/pollingRate", { pollingRate: root.rates[index].value }, null, "Polling rate " + root.rates[index].name)
            Accessible.name: "Polling rate"
        }
    }

    Panel {
        visible: root.locks.length > 0
        title: "Game Mode"
        description: "Blocked while Win Lock is on."
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        Repeater {
            id: lockBoxes

            model: root.locks

            QQC2.CheckBox {
                required property var modelData

                Layout.fillWidth: true
                // "Disable Win Key" -> "Win key"
                text: KeyLayout.sentence(modelData.name.replace(/^Disable /, ""))
                checked: modelData.value
                onToggled: root.saveLocks()
            }
        }
    }

    Panel {
        // Only on models that have it.
        visible: root.flashTap !== null && root.flashTap.keys !== undefined && root.flashTap.keys !== null
        title: "FlashTap"
        description: "When opposing keys are held together."
        Layout.fillWidth: true

        QQC2.Switch {
            id: tapOn

            text: "Use FlashTap"
            checked: root.flashTap !== null && root.flashTap.active === 1
            onToggled: root.saveFlashTap()
        }
        GridLayout {
            visible: tapOn.checked
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            QQC2.Label { text: "First key" }
            QQC2.ComboBox {
                id: tapA

                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                model: root.tapKeys
                textRole: "name"
                currentIndex: root.tapIndex("0")
                onActivated: root.saveFlashTap()
                Accessible.name: "First key"
            }
            QQC2.Label { text: "Second key" }
            QQC2.ComboBox {
                id: tapB

                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                model: root.tapKeys
                textRole: "name"
                currentIndex: root.tapIndex("1")
                onActivated: root.saveFlashTap()
                Accessible.name: "Second key"
            }
            QQC2.Label { text: "Priority" }
            QQC2.ComboBox {
                id: tapMode

                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                model: ["Neither", "Last pressed wins", "First pressed wins"]
                currentIndex: root.flashTap ? root.flashTap.mode : 1
                onActivated: root.saveFlashTap()
                Accessible.name: "When both are held"
            }
            QQC2.Label { text: "Key color" }
            ColorButton {
                id: tapColor

                label: "FlashTap key color"
                value: root.flashTap ? KeyLayout.rgb(root.flashTap.color) : "#fac800"
                onChosen: root.saveFlashTap()
            }
        }
    }
}
