// What a cooler's or hub's screen shows.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var profile: device.DeviceProfile
    // Hubs keep one setting per screen; other coolers have a single screen.
    readonly property bool perScreen: profile.LCDModes !== undefined && profile.LCDModes !== null && typeof profile.LCDModes === "object"
    readonly property var screens: {
        const parts = KeyLayout.parts(device)
        if (perScreen)
            return Object.keys(profile.LCDModes).map(Number).sort((a, b) => a - b)
        return parts.length > 0 ? [parts[0].channelId] : [0]
    }

    function options(map) {
        return Object.keys(map || {}).map(Number).sort((a, b) => a - b).map(v => ({ value: v, name: String(map[String(v)]).charAt(0).toUpperCase() + String(map[String(v)]).slice(1) }))
    }

    function current(perScreenMap, single, screen) {
        return root.perScreen && perScreenMap ? perScreenMap[String(screen)] : single
    }

    // Pictures saved in OpenLinkHub for the "Image / GIF" mode; null until
    // read, and undefined when this OpenLinkHub cannot list them.
    property var images: null
    property bool sending: false

    function loadImages() {
        Hub.call("GET", "/api/lcd/images", null, function (ok, data) {
            root.images = ok && data && Array.isArray(data.data) ? data.data.map(i => i.Name) : (ok ? [] : undefined)
        })
    }

    Component.onCompleted: loadImages()

    Connections {
        target: hubService
        function onUploaded(ok, message) {
            root.sending = false
            if (ok)
                root.page.say("Image added")
            else
                root.page.problem = message || "The image was not accepted."
            root.loadImages()
        }
    }

    FileDialog {
        id: chooser

        title: "Add Image"
        nameFilters: ["Images (*.gif *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            root.sending = true
            hubService.upload(Hub.base + "/api/lcd/upload", selectedFile)
        }
    }

    spacing: Kirigami.Units.largeSpacing

    Repeater {
        model: root.screens

        Panel {
            id: card

            required property int modelData
            readonly property var part: KeyLayout.parts(root.device).find(p => p.channelId === modelData)

            title: root.screens.length > 1 && part ? KeyLayout.partName(part) : "Screen"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            Layout.fillWidth: false

            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing

                QQC2.Label { text: "Shows" }
                QQC2.ComboBox {
                    readonly property var list: root.options(root.device.LCDModes)

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    enabled: !root.page.busy
                    textRole: "name"
                    model: list
                    currentIndex: list.findIndex(o => o.value === root.current(root.profile.LCDModes, root.profile.LCDMode, card.modelData))
                    Accessible.name: "Screen shows"
                    onActivated: i => root.page.send("POST", "/api/lcd", { channelId: card.modelData, mode: list[i].value }, null, list[i].name)
                }

                QQC2.Label {
                    visible: picture.visible
                    text: "Image"
                }
                QQC2.ComboBox {
                    id: picture

                    readonly property var list: root.images || []

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    // Only the image mode (10) uses a picture.
                    visible: root.current(root.profile.LCDModes, root.profile.LCDMode, card.modelData) === 10 && root.images !== undefined
                    enabled: !root.page.busy && list.length > 0
                    model: list
                    currentIndex: list.indexOf(root.perScreen && root.profile.LCDImages ? root.profile.LCDImages[String(card.modelData)] : root.profile.LCDImage)
                    displayText: root.images === null ? "Loading…" : list.length === 0 ? "No images yet" : currentIndex < 0 ? "Choose…" : currentText
                    Accessible.name: "Screen image"
                    onActivated: i => root.page.send("POST", "/api/lcd/image", { channelId: card.modelData, image: list[i] }, null, list[i])
                }

                QQC2.Label {
                    visible: turn.visible
                    text: "Rotation"
                }
                QQC2.ComboBox {
                    id: turn

                    readonly property var list: root.options(root.device.LCDRotations)

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    visible: list.length > 0
                    enabled: !root.page.busy
                    textRole: "name"
                    model: list
                    currentIndex: list.findIndex(o => o.value === root.current(root.profile.LCDRotations, root.profile.LCDRotation, card.modelData))
                    Accessible.name: "Screen rotation"
                    onActivated: i => root.page.send("POST", "/api/lcd/rotation", { channelId: card.modelData, rotation: list[i].value }, null, "Rotation " + list[i].name.toLowerCase())
                }

                QQC2.Label {
                    visible: glow.visible
                    text: "Brightness"
                }
                QQC2.ComboBox {
                    id: glow

                    readonly property var list: root.options(root.device.LCDBrightnessLevels)

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    visible: list.length > 0 && root.perScreen && root.profile.LCDBrightness !== undefined && root.profile.LCDBrightness !== null
                    enabled: !root.page.busy
                    textRole: "name"
                    model: list
                    currentIndex: visible ? list.findIndex(o => o.value === root.profile.LCDBrightness[String(card.modelData)]) : -1
                    Accessible.name: "Screen brightness"
                    onActivated: i => root.page.send("POST", "/api/lcd/brightness", { channelId: card.modelData, brightness: list[i].value }, null, "Screen " + list[i].name)
                }
            }
        }
    }
    Panel {
        title: "Images"
        description: "GIF, JPG, WebP or BMP, up to 5 MB."
        visible: root.images !== undefined
        Layout.fillWidth: true

        Repeater {
            model: root.images === null ? 3 : 0

            Skeleton {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }
        }
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            visible: root.images !== null && root.images !== undefined && root.images.length === 0
            icon.name: "insert-image"
            text: "No images yet"
            explanation: "Add one to show it on the screen."
        }
        Repeater {
            model: root.images || []

            QQC2.Label {
                required property string modelData

                text: modelData
                elide: Text.ElideRight
            }
        }
        QQC2.Button {
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: root.sending ? "Adding…" : "Add Image…"
            icon.name: "list-add"
            enabled: !root.sending
            onClicked: chooser.open()
        }
    }
    Item {
        visible: root.images === undefined
        Layout.fillWidth: true
    }
}
