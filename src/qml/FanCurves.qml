// Fan curves: how fast fans and pumps spin at each temperature. Curves are
// shared by every device; drag a point and it is saved when released.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    // name -> profile as OpenLinkHub describes it; null until read.
    property var curves: null
    property string current: ""
    // 1 = fans, 0 = pump (OpenLinkHub's numbering).
    property int which: 1
    property string problem: ""
    property bool confirmDelete: false
    signal changed()

    readonly property var names: curves ? Object.keys(curves).filter(n => !curves[n].Hidden).sort() : []
    readonly property var profile: curves && curves[current] ? curves[current] : null
    readonly property var points: profile && profile.points && profile.points[String(which)] ? profile.points[String(which)] : []
    // Liquid temperature never gets far past 50 °C; everything else can reach 100.
    readonly property real hottest: profile && profile.sensor === 2 ? 60 : 100
    readonly property var sensors: [{ value: 0, name: "CPU" }, { value: 1, name: "GPU" }, { value: 2, name: "Liquid" }, { value: 5, name: "CPU and GPU" }]

    title: "Fan Curves"
    standardButtons: Kirigami.Dialog.Close
    preferredWidth: Kirigami.Units.gridUnit * 52
    preferredHeight: Kirigami.Units.gridUnit * 30
    padding: Kirigami.Units.largeSpacing

    function sensorName(value) {
        const found = sensors.find(s => s.value === value)
        return found ? found.name : "Other sensor"
    }

    function load(select) {
        Hub.call("GET", "/api/temperatures/", null, function (ok, data, message) {
            if (!ok || !data.data) {
                dialog.problem = message || "Could not read the fan curves."
                dialog.curves = ({})
                return
            }
            dialog.curves = data.data
            const names = dialog.names
            if (select && names.indexOf(select) >= 0)
                dialog.current = select
            else if (names.indexOf(dialog.current) < 0)
                dialog.current = names.length > 0 ? names[0] : ""
        })
    }

    function save(list) {
        Hub.call("PUT", "/api/temperatures/updateGraph", { profile: current, updateType: which, points: list }, function (ok, data, message) {
            dialog.problem = ok ? "" : (message || "The curve was not saved.")
            dialog.load(dialog.current)
            dialog.changed()
        })
    }

    onOpened: {
        problem = ""
        confirmDelete = false
        load("")
    }
    onCurrentChanged: confirmDelete = false

    contentItem: Item {
        // Shrinks to fit a small window.
        implicitWidth: Math.min(Kirigami.Units.gridUnit * 52, dialog.parent ? dialog.parent.width - Kirigami.Units.gridUnit * 4 : Kirigami.Units.gridUnit * 52)
        implicitHeight: Math.min(Kirigami.Units.gridUnit * 28, dialog.parent ? dialog.parent.height - Kirigami.Units.gridUnit * 12 : Kirigami.Units.gridUnit * 28)

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // The list of curves and the form for a new one.
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list

                    clip: true
                    model: dialog.curves === null ? 4 : dialog.names
                    delegate: dialog.curves === null ? waiting : entry

                    Component {
                        id: waiting

                        Item {
                            width: list.width
                            height: Kirigami.Units.gridUnit * 2.4

                            Skeleton {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                            }
                        }
                    }
                    Component {
                        id: entry

                        QQC2.ItemDelegate {
                            required property string modelData

                            width: list.width
                            text: modelData
                            highlighted: modelData === dialog.current
                            onClicked: dialog.current = modelData
                        }
                    }
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            QQC2.Label {
                text: "New curve"
                font.weight: Font.DemiBold
            }
            QQC2.TextField {
                id: newName

                Layout.fillWidth: true
                placeholderText: "Name"
                maximumLength: 24
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9]*/ }
                Accessible.name: "Name of the new curve"
                onAccepted: {
                    if (add.enabled)
                        add.clicked()
                }
            }
            RowLayout {
                Layout.fillWidth: true

                QQC2.ComboBox {
                    id: newSensor

                    Layout.fillWidth: true
                    textRole: "name"
                    model: dialog.sensors
                    Accessible.name: "Temperature the new curve follows"
                }
                QQC2.Button {
                    id: add

                    text: "Add"
                    icon.name: "list-add"
                    enabled: newName.text.length >= 3 && dialog.names.indexOf(newName.text) < 0
                    onClicked: {
                        const name = newName.text
                        Hub.call("POST", "/api/temperatures/new", { profile: name, sensor: dialog.sensors[newSensor.currentIndex].value,
                                                                      static: false, zeroRpm: false, linear: false }, function (ok, data, message) {
                            dialog.problem = ok ? "" : (message || "The curve was not created.")
                            if (ok)
                                newName.text = ""
                            dialog.load(name)
                            dialog.changed()
                        })
                    }
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                text: "Letters and numbers, 3 or more."
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // The curve being edited.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: dialog.problem !== ""
                type: Kirigami.MessageType.Error
                text: dialog.problem
            }

            RowLayout {
                Layout.fillWidth: true
                visible: dialog.profile !== null
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    spacing: 0

                    Kirigami.Heading {
                        level: 3
                        text: dialog.current
                    }
                    QQC2.Label {
                        text: dialog.profile ? "Follows " + dialog.sensorName(dialog.profile.sensor) + " temperature" : ""
                        opacity: 0.7
                    }
                }
                Item { Layout.fillWidth: true }
                QQC2.ButtonGroup { id: whichGroup }
                QQC2.Button {
                    text: "Fans"
                    checkable: true
                    checked: dialog.which === 1
                    QQC2.ButtonGroup.group: whichGroup
                    onClicked: dialog.which = 1
                }
                QQC2.Button {
                    text: "Pump"
                    checkable: true
                    checked: dialog.which === 0
                    QQC2.ButtonGroup.group: whichGroup
                    onClicked: dialog.which = 0
                }
                QQC2.Button {
                    text: dialog.confirmDelete ? "Really Delete?" : "Delete"
                    icon.name: "edit-delete"
                    onClicked: {
                        if (!dialog.confirmDelete) {
                            dialog.confirmDelete = true
                            return
                        }
                        Hub.call("DELETE", "/api/temperatures/delete", { profile: dialog.current }, function (ok, data, message) {
                            dialog.problem = ok ? "" : (message || "The curve was not deleted.")
                            dialog.load("")
                            dialog.changed()
                        })
                    }
                }
            }

            // The graph: temperature across, speed up.
            Item {
                id: graph

                readonly property real gutter: Kirigami.Units.gridUnit * 3
                readonly property real foot: Kirigami.Units.gridUnit * 2
                readonly property real plotWidth: width - gutter - Kirigami.Units.gridUnit
                readonly property real plotHeight: height - foot - Kirigami.Units.gridUnit
                // A working copy for dragging. It is refilled whenever the curve
                // shown changes (another curve, Fans/Pump, or a fresh read).
                property var live: []

                function refill() {
                    live = dialog.points.map(p => ({ x: p.x, y: p.y }))
                }

                Component.onCompleted: refill()

                Connections {
                    target: dialog
                    function onPointsChanged() { graph.refill() }
                }

                function px(temperature) {
                    return gutter + Math.min(temperature, dialog.hottest) / dialog.hottest * plotWidth
                }
                function py(speed) {
                    return Kirigami.Units.gridUnit + (1 - speed / 100) * plotHeight
                }

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dialog.profile !== null && dialog.points.length > 0

                Repeater {
                    model: 5

                    Item {
                        required property int index

                        Rectangle {
                            x: graph.gutter
                            y: graph.py(index * 25)
                            width: graph.plotWidth
                            height: 1
                            color: Kirigami.Theme.textColor
                            opacity: 0.12
                        }
                        QQC2.Label {
                            x: 0
                            width: graph.gutter - Kirigami.Units.smallSpacing
                            y: graph.py(index * 25) - height / 2
                            horizontalAlignment: Text.AlignRight
                            text: index * 25 + "%"
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }
                Repeater {
                    model: Math.round(dialog.hottest / 20) + 1

                    QQC2.Label {
                        required property int index

                        x: graph.px(index * 20) - width / 2
                        y: graph.height - graph.foot + Kirigami.Units.smallSpacing
                        text: index * 20 + " °C"
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Kirigami.Theme.highlightColor
                        strokeWidth: 2
                        fillColor: "transparent"
                        PathPolyline {
                            path: graph.live.map(p => Qt.point(graph.px(p.x), graph.py(p.y)))
                        }
                    }
                }

                Repeater {
                    model: graph.live.length

                    Rectangle {
                        id: handle

                        required property int index
                        readonly property var point: graph.live[index]
                        // The first and last points stay at the ends of the scale.
                        readonly property bool pinned: index === 0 || index === graph.live.length - 1

                        x: graph.px(point.x) - width / 2
                        y: graph.py(point.y) - height / 2
                        width: Kirigami.Units.gridUnit * 0.9
                        height: width
                        radius: width / 2
                        color: grip.pressed || grip.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.backgroundColor
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                        Accessible.name: point.x + " degrees, " + point.y + " percent"

                        QQC2.ToolTip.visible: grip.pressed || grip.containsMouse
                        QQC2.ToolTip.text: (handle.pinned && index > 0 ? "Above " + graph.live[index - 1].x : point.x) + " °C  ·  " + point.y + "%"

                        MouseArea {
                            id: grip

                            anchors.fill: parent
                            anchors.margins: -Kirigami.Units.smallSpacing
                            hoverEnabled: true
                            cursorShape: Qt.SizeAllCursor
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return
                                const at = mapToItem(graph, mouse.x, mouse.y)
                                const copy = graph.live.map(p => ({ x: p.x, y: p.y }))
                                copy[handle.index].y = Math.max(0, Math.min(100, Math.round((1 - (at.y - Kirigami.Units.gridUnit) / graph.plotHeight) * 100)))
                                if (!handle.pinned) {
                                    const low = copy[handle.index - 1].x + 1
                                    const high = Math.min(copy[handle.index + 1].x, dialog.hottest) - 1
                                    copy[handle.index].x = Math.max(low, Math.min(high, Math.round((at.x - graph.gutter) / graph.plotWidth * dialog.hottest)))
                                }
                                graph.live = copy
                            }
                            onReleased: dialog.save(graph.live)
                        }
                    }
                }
            }

            // Loading and empty states.
            Skeleton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dialog.curves === null
            }
            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dialog.curves !== null && dialog.profile === null
                icon.name: "office-chart-line"
                text: dialog.names.length === 0 ? "No fan curves" : "Pick a curve"
                explanation: dialog.names.length === 0 ? "Add one on the left." : ""
            }
            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dialog.profile !== null && dialog.points.length === 0
                icon.name: "office-chart-line"
                text: "Fixed speed"
                explanation: "This curve has no points to edit."
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: graph.visible
                text: "Drag a point. Changes save when you let go."
                opacity: 0.7
            }
        }
    }
    }
}
