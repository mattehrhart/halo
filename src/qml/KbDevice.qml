import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var profileNames: Object.keys(device.userProfiles || {}).sort()
    readonly property string activeProfile: {
        for (const name of profileNames) {
            if (device.userProfiles[name].Active)
                return name
        }
        return ""
    }

    spacing: Kirigami.Units.gridUnit

    Panel {
        title: "Keyboard"
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
            QQC2.ComboBox {
                Kirigami.FormData.label: "Key layout:"
                model: root.device.Layouts || []
                currentIndex: (root.device.Layouts || []).indexOf(root.device.DeviceProfile.Layout)
                enabled: !root.page.busy
                onActivated: index => root.page.send("POST", "/api/keyboard/layout", { keyboardLayout: model[index] })
            }
        }
    }

    Panel {
        title: "Profiles"
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "A profile holds this keyboard's lighting, actuation and performance settings."
        }
        Repeater {
            model: root.profileNames

            QQC2.RadioButton {
                required property string modelData

                Layout.fillWidth: true
                text: modelData
                checked: modelData === root.activeProfile
                enabled: !root.page.busy
                onClicked: {
                    if (modelData !== root.activeProfile)
                        root.page.send("POST", "/api/userProfile/change", { userProfileName: modelData })
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: newName

                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                placeholderText: "New profile name"
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9]{1,24}/ }
                Accessible.name: "New profile name"
            }
            QQC2.Button {
                text: "Save current settings as new profile"
                icon.name: "document-save-as"
                enabled: newName.text.length > 0 && !root.page.busy
                onClicked: root.page.send("PUT", "/api/userProfile", { userProfileName: newName.text }, ok => {
                    if (ok)
                        newName.clear()
                })
            }
        }
    }
}
