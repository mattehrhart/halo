import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var buttonIds: Object.keys(device.KeyAssignment || {}).map(Number).sort((a, b) => a - b).map(String)
    readonly property var current: page.selectedButton !== "" ? device.KeyAssignment[page.selectedButton] : null
    readonly property var typeIds: Object.keys(device.KeyAssignmentTypes || {}).map(Number).sort((a, b) => a - b)

    // What is being edited for the selected button.
    property int editType: 0
    property int editValue: 0
    property bool editDefault: true
    property bool editHold: false
    property bool editRelease: false
    // type -> [{value, name}], filled the first time a type is opened.
    property var choices: ({})
    readonly property var options: choices[editType] || []

    spacing: Kirigami.Units.gridUnit

    // Where each assignment type gets its list of things to send.
    function sourceFor(type) {
        if (type === 1)
            return "/api/input/media"
        if (type === 3)
            return "/api/input/keyboard"
        if (type === 9)
            return "/api/input/mouse"
        if (type === 10)
            return "/api/macro/"
        return ""
    }

    function loadChoices(type) {
        const path = sourceFor(type)
        if (path === "" || choices[type])
            return
        Hub.call("GET", path, null, function (ok, data) {
            if (!ok || !data.data)
                return
            const list = []
            for (const id in data.data)
                list.push({ value: Number(id), name: data.data[id].Name || data.data[id].name || id })
            list.sort((a, b) => a.name.localeCompare(b.name))
            const next = Object.assign({}, root.choices)
            next[type] = list
            root.choices = next
        })
    }

    function describe(a) {
        if (!a || a.default)
            return "Default"
        const type = device.KeyAssignmentTypes[String(a.actionType)] || "Custom"
        const action = device.InputActions ? device.InputActions[String(a.actionCommand)] : null
        if (a.actionType === 10)
            return "Macro"
        return action && action.Name !== "None" ? action.Name : type
    }

    function startEditing() {
        if (!current)
            return
        editType = current.actionType
        editValue = current.actionCommand
        editDefault = current.default
        editHold = current.actionHold
        editRelease = current.onRelease
        loadChoices(editType)
    }

    function save() {
        page.send("POST", "/api/mouse/updateKeyAssignment", {
            keyIndex: Number(page.selectedButton),
            enabled: editDefault,
            pressAndHold: editHold,
            keyAssignmentType: editType,
            keyAssignmentValue: sourceFor(editType) === "" ? 0 : editValue,
            onRelease: editRelease
        })
    }

    onCurrentChanged: startEditing()
    Component.onCompleted: {
        if (page.selectedButton === "" && buttonIds.length > 0)
            page.selectedButton = buttonIds[0]
        startEditing()
    }

    Panel {
        title: "Buttons"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 17
        Layout.fillWidth: false

        Repeater {
            model: root.buttonIds

            QQC2.ItemDelegate {
                id: row

                required property string modelData
                readonly property var entry: root.device.KeyAssignment[modelData]

                Layout.fillWidth: true
                highlighted: root.page.selectedButton === modelData
                onClicked: root.page.selectedButton = modelData
                Accessible.name: entry.name + ", " + root.describe(entry)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.entry.name
                        elide: Text.ElideRight
                        color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    }
                    QQC2.Label {
                        text: root.describe(row.entry)
                        color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }
    }

    Panel {
        title: "Assignment Type"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 13
        Layout.fillWidth: false
        enabled: root.current !== null

        QQC2.CheckBox {
            text: "Keep the button's normal job"
            checked: root.editDefault
            onToggled: root.editDefault = checked
        }
        Kirigami.Separator { Layout.fillWidth: true }
        Repeater {
            model: root.typeIds

            QQC2.RadioButton {
                required property int modelData

                Layout.fillWidth: true
                enabled: !root.editDefault
                text: root.device.KeyAssignmentTypes[String(modelData)]
                checked: root.editType === modelData
                onClicked: {
                    root.editType = modelData
                    root.editValue = 0
                    root.loadChoices(modelData)
                }
            }
        }
    }

    Panel {
        title: root.current ? root.current.name : "Assignment"
        Layout.fillWidth: true
        enabled: root.current !== null

        QQC2.Label {
            Layout.fillWidth: true
            visible: root.editDefault
            wrapMode: Text.WordWrap
            text: "This button does what it normally does. Untick “Keep the button's normal job” to give it something else."
        }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            visible: !root.editDefault

            QQC2.ComboBox {
                Kirigami.FormData.label: "Sends:"
                visible: root.sourceFor(root.editType) !== ""
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                model: root.options
                textRole: "name"
                currentIndex: root.options.findIndex(o => o.value === root.editValue)
                onActivated: index => root.editValue = root.options[index].value
                Accessible.name: "What the button sends"
            }
            QQC2.Label {
                visible: root.editType === 10 && root.options.length === 0
                text: "No macros have been made yet."
                color: Kirigami.Theme.disabledTextColor
            }
            QQC2.CheckBox {
                text: "Repeat while the button is held"
                checked: root.editHold
                enabled: !root.editRelease
                onToggled: root.editHold = checked
            }
            QQC2.CheckBox {
                text: "Act when the button is released"
                checked: root.editRelease
                enabled: !root.editHold
                onToggled: root.editRelease = checked
            }
        }
        QQC2.Button {
            text: "Apply"
            icon.name: "dialog-ok-apply"
            enabled: !root.page.busy && (root.editDefault || root.sourceFor(root.editType) === "" || root.options.findIndex(o => o.value === root.editValue) >= 0)
            onClicked: root.save()
        }
    }
}
