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

    spacing: Kirigami.Units.largeSpacing

    function shown(name) {
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    Panel {
        title: "Key Layout"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        QQC2.ComboBox {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            model: root.device.Layouts || []
            currentIndex: (root.device.Layouts || []).indexOf(root.device.DeviceProfile.Layout)
            enabled: !root.page.busy
            onActivated: index => root.page.send("POST", "/api/keyboard/layout", { keyboardLayout: model[index] }, null, "Layout " + model[index])
            Accessible.name: "Key layout"
        }
    }

    Panel {
        title: "Profiles"
        description: "Lighting, actuation and performance."
        Layout.fillWidth: true

        QQC2.ComboBox {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            model: root.profileNames.map(name => root.shown(name))
            currentIndex: root.profileNames.indexOf(root.activeProfile)
            enabled: !root.page.busy && root.profileNames.length > 1
            onActivated: index => root.page.send("POST", "/api/userProfile/change", { userProfileName: root.profileNames[index] }, null,
                                                 "Profile " + root.shown(root.profileNames[index]))
            Accessible.name: "Profile"
        }
        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: newName

                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                placeholderText: "New profile name"
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9]{1,24}/ }
                Accessible.name: "New profile name"
                onAccepted: add.clicked()
            }
            QQC2.Button {
                id: add

                text: "Save as Profile"
                enabled: newName.text.length > 0 && !root.page.busy
                onClicked: root.page.send("PUT", "/api/userProfile", { userProfileName: newName.text }, ok => {
                    if (ok)
                        newName.clear()
                }, "Profile saved")
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
