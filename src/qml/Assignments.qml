// Key and button assignments, shared by the keyboard and mouse pages.
// Every choice is sent as it is made.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    required property var page
    // [{id: "50", name: "Q", a: {default, actionType, actionCommand, actionHold, ...}}]
    property var entries: []
    // Show every entry in the list, or only the ones that were changed.
    property bool showAll: true
    property string selectedId: ""
    // Assignment type ids this device can take, in display order.
    property var offered: []
    property string savePath: ""
    property string noun: "button"
    signal choose(string id)

    readonly property var device: page.device
    readonly property var current: entries.find(e => e.id === selectedId) || null
    readonly property var listed: showAll ? entries : entries.filter(e => !e.a.default || e.id === selectedId)
    readonly property var types: offered.filter(id => device.KeyAssignmentTypes && device.KeyAssignmentTypes[String(id)] !== undefined)
        .map(id => ({ id: id, text: typeName(id) }))
    // type -> [{value, name}], filled the first time a type is opened.
    property var choices: ({})
    // The type picked just now, while its value is still to be chosen.
    property int pendingType: -1
    readonly property int shownType: pendingType >= 0 ? pendingType : current && !current.a.default ? current.a.actionType : -1
    readonly property var options: choices[shownType] || []

    spacing: Kirigami.Units.largeSpacing

    // OpenLinkHub's name for a type, shortened where it would not fit a tile.
    function typeName(id) {
        const name = device.KeyAssignmentTypes[String(id)]
        const short = {
            "None": "Disable", "Brightness +": "Lights Brighter", "Brightness -": "Lights Dimmer",
            "Screen Brightness +": "Screen Brighter", "Screen Brightness -": "Screen Dimmer"
        }
        return short[name] || name
    }

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
            list.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }))
            const next = Object.assign({}, root.choices)
            next[type] = list
            root.choices = next
        })
    }

    function describe(a) {
        if (!a || a.default)
            return "Default"
        if (a.actionType === 0)
            return "Disabled"
        if (a.actionType === 10)
            return "Macro"
        const action = device.InputActions ? device.InputActions[String(a.actionCommand)] : null
        if (action && action.Name !== "None")
            return action.Name
        return device.KeyAssignmentTypes[String(a.actionType)] || "Custom"
    }

    function save(isDefault, type, value, hold) {
        const body = {
            keyIndex: Number(selectedId),
            enabled: isDefault,
            pressAndHold: hold,
            keyAssignmentType: type,
            keyAssignmentValue: value,
            toggleDelay: current && current.a.toggleDelay ? current.a.toggleDelay : 0,
            onRelease: false
        }
        pendingType = -1
        page.send("POST", savePath, body, null, isDefault ? current.name + " reset to default" : current.name + " assigned")
    }

    function pickType(type) {
        if (!current)
            return
        if (sourceFor(type) === "") {
            save(false, type, 0, false)
        } else {
            pendingType = type
            loadChoices(type)
        }
    }

    onSelectedIdChanged: pendingType = -1
    onShownTypeChanged: loadChoices(shownType)

    Panel {
        title: "Assignments"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            visible: root.listed.length === 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "No custom assignments."
        }
        Repeater {
            model: root.listed

            QQC2.ItemDelegate {
                id: row

                required property var modelData

                Layout.fillWidth: true
                highlighted: root.selectedId === modelData.id
                onClicked: root.choose(modelData.id)
                Accessible.name: modelData.name + ", " + root.describe(modelData.a)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    }
                    QQC2.Label {
                        text: root.describe(row.modelData.a)
                        color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }
    }

    Panel {
        title: "Assignment Type"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 23
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            visible: root.current === null
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "Select a " + root.noun + "."
        }
        TypeTiles {
            Layout.fillWidth: true
            visible: root.current !== null
            enabled: !root.page.busy
            types: root.types
            current: root.shownType
            onPicked: id => root.pickType(id)
        }
    }

    Panel {
        title: root.current ? root.current.name : "Details"
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            // Only where the drop-down below is not already saying it.
            visible: root.current !== null && (root.shownType < 0 || root.sourceFor(root.shownType) === "")
            opacity: 0.7
            text: root.current === null ? "" : root.current.a.default ? "Default" : root.describe(root.current.a)
        }
        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            visible: root.current !== null && root.shownType >= 0 && root.sourceFor(root.shownType) !== ""

            QQC2.ComboBox {
                id: value

                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                model: root.options
                textRole: "name"
                enabled: !root.page.busy && root.options.length > 0
                currentIndex: root.pendingType >= 0 || !root.current ? -1
                    : root.options.findIndex(o => o.value === root.current.a.actionCommand)
                displayText: currentIndex < 0 ? (root.options.length === 0 && root.shownType === 10 ? "No macros yet" : "Choose…") : currentText
                onActivated: index => root.save(false, root.shownType, root.options[index].value, hold.checked)
                Accessible.name: "What it sends"
            }
            QQC2.CheckBox {
                id: hold

                text: "Repeat while held"
                checked: root.current !== null && root.current.a.actionHold === true
                enabled: !root.page.busy && root.pendingType < 0
                onToggled: root.save(false, root.shownType, root.current.a.actionCommand, checked)
            }
        }
        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                visible: root.pendingType >= 0
                text: "Cancel"
                onClicked: root.pendingType = -1
            }
            QQC2.Button {
                visible: root.current !== null && !root.current.a.default && root.pendingType < 0
                text: "Reset to Default"
                icon.name: "edit-undo"
                enabled: !root.page.busy
                onClicked: root.save(true, 0, 0, false)
            }
        }
    }
}
