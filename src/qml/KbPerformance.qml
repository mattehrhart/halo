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

    spacing: Kirigami.Units.gridUnit

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
        page.send("POST", "/api/keyboard/setPerformance", body, () => root.reload())
    }

    function saveFlashTap() {
        const c = tapColor.value
        page.send("POST", "/api/keyboard/setFlashTap", {
            flashTapActive: tapOn.checked ? 1 : 0,
            flashTapKeys: [root.tapKeys[tapA.currentIndex].id, root.tapKeys[tapB.currentIndex].id],
            flashTapMode: tapMode.currentIndex,
            flashTapColor: { red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255) }
        }, () => root.reload())
    }

    Component.onCompleted: reload()

    Panel {
        title: "Polling Rate"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 13
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "How often the keyboard reports to the PC. The keyboard reconnects briefly when this changes."
        }
        Repeater {
            model: Object.keys(root.device.PollingRates || {}).map(Number).filter(v => v > 0).sort((a, b) => a - b)

            QQC2.RadioButton {
                required property int modelData

                Layout.fillWidth: true
                text: root.device.PollingRates[String(modelData)]
                checked: root.device.DeviceProfile.PollingRate === modelData
                enabled: !root.page.busy
                onClicked: root.page.send("POST", "/api/keyboard/pollingRate", { pollingRate: modelData })
            }
        }
    }

    Panel {
        title: "Game Mode"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "Shortcuts to block while the keyboard's lock key is on."
        }
        Repeater {
            id: lockBoxes

            model: root.locks

            QQC2.CheckBox {
                required property var modelData

                Layout.fillWidth: true
                text: modelData.name
                checked: modelData.value
            }
        }
        QQC2.Button {
            text: "Apply"
            icon.name: "dialog-ok-apply"
            enabled: root.locks.length > 0 && !root.page.busy
            onClicked: root.saveLocks()
        }
    }

    Panel {
        title: "FlashTap"
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "Decides what happens when two opposite keys, such as A and D, are held together."
        }
        QQC2.Switch {
            id: tapOn

            text: "Use FlashTap"
            checked: root.flashTap !== null && root.flashTap.active === 1
        }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            enabled: tapOn.checked

            QQC2.ComboBox {
                id: tapA

                Kirigami.FormData.label: "First key:"
                model: root.tapKeys
                textRole: "name"
                currentIndex: root.tapIndex("0")
            }
            QQC2.ComboBox {
                id: tapB

                Kirigami.FormData.label: "Second key:"
                model: root.tapKeys
                textRole: "name"
                currentIndex: root.tapIndex("1")
            }
            QQC2.ComboBox {
                id: tapMode

                Kirigami.FormData.label: "When both are held:"
                model: ["Neither key counts", "The last key pressed wins", "The first key pressed wins"]
                currentIndex: root.flashTap ? root.flashTap.mode : 1
            }
            ColorSwatches {
                id: tapColor

                Kirigami.FormData.label: "Key colour:"
                Layout.fillWidth: true
                value: root.flashTap ? KeyLayout.rgb(root.flashTap.color) : "#fac800"
            }
        }
        QQC2.Button {
            text: "Apply"
            icon.name: "dialog-ok-apply"
            enabled: root.flashTap !== null && tapA.currentIndex >= 0 && tapB.currentIndex >= 0 && !root.page.busy
            onClicked: root.saveFlashTap()
        }
    }
}
