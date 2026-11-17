import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    // Keys in the selection that have an adjustable switch.
    readonly property var targets: page.selectedIds.filter(id => page.keymap.byId[id] && KeyLayout.adjustable(page.keymap.byId[id].raw))
    readonly property var first: targets.length > 0 ? page.keymap.byId[targets[0]].raw : null

    spacing: Kirigami.Units.largeSpacing

    function mm(tenths) {
        return (Math.round(tenths) / 10).toFixed(1) + " mm"
    }

    function settings(keyId, allKeys) {
        return {
            keyIndex: keyId,
            actuationAllKeys: allKeys,
            actuationPoint: Math.round(point.value),
            enableActuationPointReset: resetOn.checked,
            actuationResetPoint: Math.round(reset.value),
            enableSecondaryActuationPoint: secondOn.checked,
            secondaryActuationPoint: Math.round(second.value),
            secondaryActuationResetPoint: Math.round(secondReset.value)
        }
    }

    function applySelected() {
        page.sendEach("/api/keyboard/updateActuation", targets.map(id => settings(id, false)), null,
                      targets.length === 1 ? "Key updated" : targets.length + " keys updated")
    }

    function applyAll() {
        const any = targets.length > 0 ? targets[0] : page.keymap.keys.find(k => KeyLayout.adjustable(k.raw)).id
        page.send("POST", "/api/keyboard/updateActuation", settings(any, true), null, "All keys updated")
    }

    // Show the first selected key's current values whenever the selection
    // or the device data changes.
    onFirstChanged: {
        if (!first)
            return
        point.value = first.actuationPoint
        resetOn.checked = first.enableActuationPointReset
        reset.value = first.actuationResetPoint
        secondOn.checked = first.enableSecondaryActuationPoint
        second.value = first.secondaryActuationPoint
        secondReset.value = first.secondaryActuationResetPoint
    }

    component Travel: QQC2.Slider {
        Layout.fillWidth: true
        from: 1
        to: 40
    }
    component Reading: QQC2.Label {
        Layout.minimumWidth: readingSize.width
        horizontalAlignment: Text.AlignRight
    }
    TextMetrics {
        id: readingSize
        text: "4.0 mm"
    }

    Panel {
        title: "Selected Keys"
        description: "Travel before a key registers."
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.weight: Font.DemiBold
            text: root.targets.length === 0 ? "None"
                : root.targets.slice(0, 14).map(id => KeyLayout.spokenName(root.page.keymap.byId[id].name)).join(", ")
                  + (root.targets.length > 14 ? " and " + (root.targets.length - 14) + " more" : "")
        }
    }

    Panel {
        title: "Actuation Point"
        Layout.fillWidth: true

        GridLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 34
            columns: 3
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing

            QQC2.Label { text: "Press distance" }
            Travel {
                id: point
                value: 20
                Accessible.name: "Press distance"
            }
            Reading { text: root.mm(point.value) }

            QQC2.Switch {
                id: resetOn
                Layout.columnSpan: 3
                text: "Separate release point"
            }
            QQC2.Label {
                visible: resetOn.checked
                text: "Release distance"
            }
            Travel {
                id: reset
                visible: resetOn.checked
                value: 19
                Accessible.name: "Release distance"
            }
            Reading {
                visible: resetOn.checked
                text: root.mm(reset.value)
            }

            QQC2.Switch {
                id: secondOn
                Layout.columnSpan: 3
                text: "Secondary actuation point"
            }
            QQC2.Label {
                visible: secondOn.checked
                text: "Second press distance"
            }
            Travel {
                id: second
                visible: secondOn.checked
                value: 35
                Accessible.name: "Second press distance"
            }
            Reading {
                visible: secondOn.checked
                text: root.mm(second.value)
            }
            QQC2.Label {
                visible: secondOn.checked
                text: "Second release distance"
            }
            Travel {
                id: secondReset
                visible: secondOn.checked
                value: 34
                Accessible.name: "Second release distance"
            }
            Reading {
                visible: secondOn.checked
                text: root.mm(secondReset.value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: root.targets.length > 1 ? "Apply to " + root.targets.length + " Selected Keys" : "Apply to Selected Key"
                enabled: root.targets.length > 0 && !root.page.busy
                onClicked: root.applySelected()
            }
            QQC2.Button {
                text: "Apply to All Keys…"
                enabled: !root.page.busy
                onClicked: confirmAll.open()
            }
        }
    }

    Kirigami.PromptDialog {
        id: confirmAll

        title: "Apply to All Keys?"
        subtitle: "All keys will use " + root.mm(point.value) + "."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: root.applyAll()
    }
}
