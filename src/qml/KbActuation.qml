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

    spacing: Kirigami.Units.gridUnit

    function mm(tenths) {
        return (tenths / 10).toFixed(1) + " mm"
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
        page.sendEach("/api/keyboard/updateActuation", targets.map(id => settings(id, false)))
    }

    function applyAll() {
        const any = targets.length > 0 ? targets[0] : page.keymap.keys.find(k => KeyLayout.adjustable(k.raw)).id
        page.send("POST", "/api/keyboard/updateActuation", settings(any, true))
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

    Panel {
        title: "Keys"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.fillWidth: false

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "The number on each key is how far down it must be pressed before it registers. Select keys on the keyboard, set the distance, then apply."
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.weight: Font.DemiBold
            text: root.targets.length === 0 ? "No keys selected"
                : root.targets.slice(0, 14).map(id => KeyLayout.spokenName(root.page.keymap.byId[id].name)).join(", ")
                  + (root.targets.length > 14 ? " and " + (root.targets.length - 14) + " more" : "")
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: root.targets.length > 1
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "The sliders start from the first selected key's settings."
        }
    }

    Panel {
        title: "Actuation Point"
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label { text: "Press distance" }
            QQC2.Slider {
                id: point

                Layout.fillWidth: true
                from: 1
                to: 40
                stepSize: 1
                value: 20
                snapMode: QQC2.Slider.SnapAlways
                Accessible.name: "Press distance"
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                horizontalAlignment: Text.AlignRight
                text: root.mm(point.value)
            }
        }

        QQC2.Switch {
            id: resetOn
            text: "Set the release distance separately"
        }
        RowLayout {
            Layout.fillWidth: true
            enabled: resetOn.checked

            QQC2.Label { text: "Release distance" }
            QQC2.Slider {
                id: reset

                Layout.fillWidth: true
                from: 1
                to: 40
                stepSize: 1
                value: 19
                snapMode: QQC2.Slider.SnapAlways
                Accessible.name: "Release distance"
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                horizontalAlignment: Text.AlignRight
                text: root.mm(reset.value)
            }
        }

        QQC2.Switch {
            id: secondOn
            text: "Second action further down the press"
        }
        RowLayout {
            Layout.fillWidth: true
            enabled: secondOn.checked

            QQC2.Label { text: "Second press distance" }
            QQC2.Slider {
                id: second

                Layout.fillWidth: true
                from: 1
                to: 40
                stepSize: 1
                value: 35
                snapMode: QQC2.Slider.SnapAlways
                Accessible.name: "Second press distance"
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                horizontalAlignment: Text.AlignRight
                text: root.mm(second.value)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            enabled: secondOn.checked

            QQC2.Label { text: "Second release distance" }
            QQC2.Slider {
                id: secondReset

                Layout.fillWidth: true
                from: 1
                to: 40
                stepSize: 1
                value: 34
                snapMode: QQC2.Slider.SnapAlways
                Accessible.name: "Second release distance"
            }
            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                horizontalAlignment: Text.AlignRight
                text: root.mm(secondReset.value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: root.targets.length > 1 ? "Apply to " + root.targets.length + " selected keys" : "Apply to selected key"
                icon.name: "dialog-ok-apply"
                enabled: root.targets.length > 0 && !root.page.busy
                onClicked: root.applySelected()
            }
            QQC2.Button {
                text: "Apply to every key"
                enabled: !root.page.busy
                onClicked: root.applyAll()
            }
        }
    }
}
