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

    spacing: Kirigami.Units.gridUnit

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
                root.page.send("POST", "/api/mouse/dpiColors", { colorZones: colors })
        })
    }

    Panel {
        title: "DPI Stages"
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: "The DPI button steps through the stages. Each stage's colour shows on the mouse when it is chosen. Sniper applies while its button is held."
        }

        Repeater {
            id: rows

            model: root.stageIds

            RowLayout {
                id: row

                required property int modelData
                readonly property var stage: root.device.DeviceProfile.Profiles[String(modelData)]
                property int dpi: stage.Value
                property color tint: KeyLayout.rgb(stage.Color)

                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    text: row.stage.name + (!row.stage.Sniper && root.device.DeviceProfile.Profile === row.modelData ? "  ●" : "")
                    font.weight: !row.stage.Sniper && root.device.DeviceProfile.Profile === row.modelData ? Font.DemiBold : Font.Normal
                    Accessible.name: row.stage.name
                        + (!row.stage.Sniper && root.device.DeviceProfile.Profile === row.modelData ? ", in use" : "")
                }
                QQC2.Slider {
                    Layout.fillWidth: true
                    from: root.device.MinDPI
                    to: Math.min(root.device.MaxDPI, 12000)
                    value: row.dpi
                    onMoved: row.dpi = Math.round(value / 50) * 50
                    Accessible.name: row.stage.name + " DPI"
                }
                QQC2.SpinBox {
                    from: root.device.MinDPI
                    to: root.device.MaxDPI
                    stepSize: 50
                    editable: true
                    value: row.dpi
                    onValueModified: row.dpi = value
                    Accessible.name: row.stage.name + " DPI"
                }
                ColorButton {
                    label: row.stage.name + " colour"
                    value: row.tint
                    onChosen: picked => row.tint = picked
                }
            }
        }

        QQC2.Button {
            text: "Apply"
            icon.name: "dialog-ok-apply"
            enabled: !root.page.busy
            onClicked: root.save()
        }
    }
}
