// Which widget fills each area of a touch screen such as the Xeneon Edge.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var profile: device.DeviceProfile
    readonly property var areas: Object.keys(profile.WidgetAreas || {}).map(Number).sort((a, b) => a - b)
    readonly property var widgets: profile.widgets || device.widgets || []

    // Areas come in three widths; a widget only fits the widths it lists.
    function widthOf(area) {
        return area <= 2 ? 1 : area >= 9 ? 3 : 2
    }
    function fitting(area) {
        const wide = widthOf(area)
        return [{ value: 0, name: "None" }].concat(
            widgets.filter(w => !w.columns || w.columns.indexOf(wide) >= 0).map(w => ({ value: w.id, name: w.name })))
    }

    spacing: Kirigami.Units.largeSpacing

    Panel {
        title: "Widgets"
        Layout.fillWidth: true

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            visible: root.areas.length === 0
            icon.name: "view-grid"
            text: "No widget areas"
            explanation: "This screen did not report any."
        }

        GridLayout {
            visible: root.areas.length > 0
            columns: 4
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.areas

                RowLayout {
                    id: slot

                    required property int modelData
                    readonly property var list: root.fitting(modelData)
                    readonly property var now: root.profile.WidgetAreas[String(modelData)]

                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: "Area " + slot.modelData
                        opacity: 0.7
                    }
                    QQC2.ComboBox {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        enabled: !root.page.busy
                        textRole: "name"
                        model: slot.list
                        currentIndex: slot.list.findIndex(w => w.value === (slot.now ? slot.now.widgetId : 0))
                        Accessible.name: "Widget in area " + slot.modelData
                        onActivated: i => root.page.send("POST", "/api/xeneon/setWidgetArea", { areaId: slot.modelData, widgetId: slot.list[i].value }, null, slot.list[i].name)
                    }
                }
            }
        }
    }
}
