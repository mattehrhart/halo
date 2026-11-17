import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var stageIds: Object.keys(device.DeviceProfile.Profiles || {}).map(Number).sort((a, b) => a - b)
    readonly property real low: device.MinDPI
    readonly property real high: device.MaxDPI

    spacing: Kirigami.Units.largeSpacing

    // The slider is logarithmic, so low and high DPI get equal room.
    function toSlider(dpi) {
        return Math.log(dpi / low) / Math.log(high / low)
    }

    function fromSlider(position) {
        return Math.max(low, Math.min(high, Math.round(low * Math.pow(high / low, position) / 50) * 50))
    }

    function save() {
        const stages = {}
        const colors = {}
        for (let i = 0; i < rows.count; i++) {
            const row = rows.itemAt(i)
            stages[String(row.modelData)] = row.dpi
            colors[String(row.modelData)] = {
                red: Math.round(row.tint.r * 255), green: Math.round(row.tint.g * 255), blue: Math.round(row.tint.b * 255)
            }
        }
        page.send("POST", "/api/mouse/dpi", { stages: stages }, function (ok) {
            if (ok)
                root.page.send("POST", "/api/mouse/dpiColors", { colorZones: colors }, null, "DPI saved")
        })
    }

    Panel {
        title: "DPI Stages"
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: rows

                model: root.stageIds

                // One stage: its color, name, slider and exact value. The
                // stage the mouse is on is marked with a bar in its color.
                QQC2.Control {
                    id: row

                    required property int modelData
                    readonly property var stage: root.device.DeviceProfile.Profiles[String(modelData)]
                    readonly property bool inUse: !stage.Sniper && root.device.DeviceProfile.Profile === modelData
                    property int dpi: stage.Value
                    property color tint: KeyLayout.rgb(stage.Color)

                    Layout.fillWidth: true
                    Layout.topMargin: stage.Sniper ? Kirigami.Units.largeSpacing : 0
                    padding: Kirigami.Units.smallSpacing
                    leftPadding: Kirigami.Units.largeSpacing

                    background: Rectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: row.inUse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.14)
                            : "transparent"

                        Rectangle {
                            visible: row.inUse
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 3
                            width: 3
                            radius: 1.5
                            color: Kirigami.Theme.highlightColor
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        // Picks the stage the mouse uses. The sniper stage is
                        // only ever active while its button is held.
                        QQC2.RadioButton {
                            opacity: row.stage.Sniper ? 0 : 1
                            enabled: !row.stage.Sniper && !root.page.busy
                            checked: row.inUse
                            onClicked: {
                                if (!row.inUse)
                                    root.page.send("POST", "/api/mouse/dpiStage", { dpiStage: row.modelData }, null, row.stage.name + " in use")
                                checked = Qt.binding(() => row.inUse)
                            }
                            Accessible.name: "Use " + row.stage.name
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: 600
                            QQC2.ToolTip.text: "Use this stage"
                        }
                        ColorButton {
                            implicitWidth: Kirigami.Units.gridUnit * 1.6
                            label: row.stage.name + " color"
                            value: row.tint
                            onChosen: picked => {
                                row.tint = picked
                                root.save()
                            }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                            spacing: 0

                            QQC2.Label {
                                text: row.stage.name
                                font.weight: row.inUse ? Font.DemiBold : Font.Normal
                            }
                            QQC2.Label {
                                visible: row.inUse || row.stage.Sniper
                                text: row.stage.Sniper ? "While held" : "Current"
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                        }
                        QQC2.Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: 1
                            value: root.toSlider(row.dpi)
                            onMoved: row.dpi = root.fromSlider(value)
                            onPressedChanged: {
                                // Hold off re-reading the mouse while a slider is being dragged.
                                root.page.holdRefresh = pressed
                                if (!pressed && row.dpi !== row.stage.Value)
                                    root.save()
                            }
                            Accessible.name: row.stage.name + " DPI"
                        }
                        QQC2.SpinBox {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                            from: root.low
                            to: root.high
                            stepSize: 50
                            editable: true
                            value: row.dpi
                            onValueModified: {
                                row.dpi = value
                                root.save()
                            }
                            Accessible.name: row.stage.name + " DPI"
                        }
                    }
                }
            }
        }
    }
}
