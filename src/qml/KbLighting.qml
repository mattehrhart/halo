import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property string mode: device.DeviceProfile.RGBProfile
    readonly property bool perKey: mode === "keyboard"

    spacing: Kirigami.Units.gridUnit

    function paint(option) {
        const ids = page.selectedIds
        const c = swatches.value
        page.send("POST", "/api/keyboard/color", {
            keyId: ids.length > 0 ? ids[0] : 1,
            keyOption: option,
            keys: option === 3 ? ids : [],
            color: { red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255) }
        })
    }

    Panel {
        title: "Lighting Type"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.fillWidth: false

        Repeater {
            model: KeyLayout.orderedModes(root.device.RGBModes)

            QQC2.ItemDelegate {
                required property string modelData

                Layout.fillWidth: true
                text: KeyLayout.title(modelData)
                highlighted: root.mode === modelData
                onClicked: {
                    if (root.mode !== modelData)
                        root.page.send("POST", "/api/color", { channelId: 0, profile: modelData })
                }
            }
        }
    }

    Panel {
        title: root.perKey ? "Key Colours" : KeyLayout.title(root.mode)
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            visible: !root.perKey
            wrapMode: Text.WordWrap
            text: root.mode === "off" ? "The keyboard's lights are off."
                : "This effect lights the whole keyboard. The picture above imitates it, so the timing will not match exactly. To colour keys one by one, choose Per-key colours."
        }
        QQC2.Button {
            visible: !root.perKey
            text: "Switch to Per-key colours"
            icon.name: "color-management"
            onClicked: root.page.send("POST", "/api/color", { channelId: 0, profile: "keyboard" })
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: root.perKey
            wrapMode: Text.WordWrap
            text: "Pick a colour, then choose which keys take it."
        }
        ColorSwatches {
            id: swatches

            Layout.fillWidth: true
            visible: root.perKey
        }
        Flow {
            Layout.fillWidth: true
            visible: root.perKey
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: root.page.selectedIds.length > 1 ? "Colour " + root.page.selectedIds.length + " selected keys" : "Colour selected key"
                icon.name: "fill-color"
                enabled: root.page.selectedIds.length > 0 && !root.page.busy
                onClicked: root.paint(root.page.selectedIds.length > 1 ? 3 : 0)
            }
            QQC2.Button {
                text: "Colour its whole row"
                enabled: root.page.selectedIds.length === 1 && !root.page.busy
                onClicked: root.paint(1)
            }
            QQC2.Button {
                text: "Colour all keys"
                enabled: !root.page.busy
                onClicked: root.paint(2)
            }
        }
    }

    Panel {
        title: "Brightness"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        Layout.fillWidth: false

        Repeater {
            model: Object.keys(root.device.Brightness || {}).map(Number).sort((a, b) => a - b)

            QQC2.RadioButton {
                required property int modelData

                Layout.fillWidth: true
                text: modelData === 0 ? "Set by the effect" : root.device.Brightness[String(modelData)]
                checked: root.device.DeviceProfile.Brightness === modelData
                onClicked: root.page.send("POST", "/api/brightness", { brightness: modelData })
            }
        }
    }
}
