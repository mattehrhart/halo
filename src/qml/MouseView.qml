// A mouse drawn as a simple diagram: its outline from the side and from
// above, each button as an outlined shape, and its lights in their colors.
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Item {
    id: view

    property var device: null
    // The selected button's index in device.KeyAssignment, or "".
    property string selected: ""
    // Whether buttons respond to the pointer.
    property bool interactive: true
    // This model's diagram (see tools/make-device-diagrams.py).
    property var diagram: ({})
    // The traced outline to show when this model has no diagram.
    property var traced: ({})
    signal buttonTapped(string index)

    readonly property bool exact: diagram !== null && diagram !== undefined && diagram.width !== undefined
    readonly property real zoom: exact ? Math.min(width / diagram.width, height / diagram.height) : 1
    readonly property color ink: Kirigami.Theme.textColor
    readonly property string mode: device && device.DeviceProfile && device.DeviceProfile.RGBProfile ? device.DeviceProfile.RGBProfile : "off"
    // Seconds the current effect has been playing in the preview.
    property real clock: 0

    FrameAnimation {
        running: view.visible && ["static", "off", KeyLayout.zoneMode(view.device)].indexOf(view.mode) < 0
        onTriggered: view.clock += frameTime
    }
    onModeChanged: clock = 0

    function shade(amount) {
        return Qt.rgba(ink.r, ink.g, ink.b, amount)
    }

    function indexOf(name) {
        if (!device || !device.KeyAssignment)
            return ""
        for (const index in device.KeyAssignment) {
            if (device.KeyAssignment[index].name === name)
                return index
        }
        return ""
    }

    // The color of a lighting zone right now.
    function zone(number) {
        if (!device || mode === "off" || device.DeviceProfile.RgbOff)
            return Qt.rgba(0, 0, 0, 1)
        if (mode === KeyLayout.zoneMode(device)) {
            const z = device.DeviceProfile.ZoneColors[String(number)]
            return z ? KeyLayout.onScreen(KeyLayout.rgb(z.Color), KeyLayout.dimming(device, false)) : Qt.rgba(0, 0, 0, 1)
        }
        // Each zone is one light; the device numbers them from the logo.
        return KeyLayout.keyColor({ raw: {}, light: view.exact ? (number === 0 ? 1 : 0) : number }, device, clock)
    }

    function points(list, close) {
        const path = list.map(p => Qt.point(p[0], p[1]))
        if (close)
            path.push(path[0])
        return path
    }

    // No diagram for this model: its traced outline, and under it a lamp
    // for each lighting zone in that zone's color.
    readonly property var zoneIds: device && device.DeviceProfile && device.DeviceProfile.ZoneColors
        ? Object.keys(device.DeviceProfile.ZoneColors).map(Number).sort((a, b) => a - b) : []

    OutlineView {
        visible: !view.exact
        anchors.fill: parent
        anchors.bottomMargin: lamps.visible ? lamps.height + Kirigami.Units.largeSpacing : 0
        outline: view.traced
    }
    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        visible: !view.exact && view.device !== null && !(view.traced && view.traced.views)
        icon.name: "preferences-devices-tree"
        text: view.device ? view.device.product : ""
    }
    Row {
        id: lamps

        visible: !view.exact && view.zoneIds.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: Kirigami.Units.gridUnit

        Repeater {
            model: view.zoneIds

            Row {
                required property int modelData
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.gridUnit
                    height: width
                    radius: width / 2
                    color: KeyLayout.lightInk(view.zone(modelData), view.ink, 0.15, 1)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: view.device.DeviceProfile.ZoneColors[String(modelData)].Name || ""
                    color: view.shade(0.7)
                }
            }
        }
    }

    Item {
        id: frame

        // Keep the active highlight color even while the window is in the background.
        Kirigami.Theme.colorGroup: Kirigami.Theme.Active
        Kirigami.Theme.inherit: false
        visible: view.exact
        anchors.centerIn: parent
        width: view.exact ? view.diagram.width * view.zoom : 0
        height: view.exact ? view.diagram.height * view.zoom : 0

        // Everything is drawn in the diagram's own units and scaled as one.
        component Canvas: Shape {
            width: view.diagram.width
            height: view.diagram.height
            scale: view.zoom
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
        }

        Repeater {
            model: view.exact ? view.diagram.outlines : []

            Canvas {
                required property var modelData

                ShapePath {
                    strokeWidth: 3
                    strokeColor: view.shade(0.4)
                    fillColor: view.shade(0.04)
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: view.points(modelData, true) }
                }
            }
        }
        Repeater {
            model: view.exact && view.diagram.details ? view.diagram.details : []

            Canvas {
                required property var modelData

                ShapePath {
                    strokeWidth: 2
                    strokeColor: view.shade(0.22)
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: view.points(modelData, false) }
                }
            }
        }

        // Lights that are not buttons.
        Repeater {
            model: view.exact && view.diagram.lights ? view.diagram.lights : []

            Rectangle {
                required property var modelData
                readonly property color tint: view.zone(modelData.zone)

                x: modelData.box[0] * view.zoom
                y: modelData.box[1] * view.zoom
                width: modelData.box[2] * view.zoom
                height: modelData.box[3] * view.zoom
                radius: height / 2
                color: KeyLayout.lightInk(tint, view.ink, 0.12, 1)
            }
        }

        Repeater {
            model: view.exact ? Object.keys(view.diagram.shapes) : []

            Canvas {
                id: button

                required property string modelData
                readonly property string index: view.indexOf(modelData)
                readonly property bool picked: index !== "" && view.selected === index
                readonly property var corners: view.diagram.shapes[modelData]
                readonly property var mark: view.diagram.labels ? view.diagram.labels[modelData] : undefined
                readonly property color tint: mark ? view.zone(mark.zone) : Qt.rgba(0, 0, 0, 1)
                readonly property bool dark: tint.r + tint.g + tint.b < 0.02

                containsMode: Shape.FillContains
                enabled: index !== "" && view.interactive

                Accessible.role: Accessible.Button
                Accessible.name: modelData

                ShapePath {
                    strokeWidth: button.picked ? 6 : 2.5
                    strokeColor: button.picked ? Kirigami.Theme.highlightColor
                        : button.mark ? KeyLayout.lightInk(button.tint, view.ink, 0.3, 0.75) : view.shade(0.3)
                    fillColor: button.picked ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.22)
                        : hover.hovered ? view.shade(0.12)
                        : button.mark ? KeyLayout.lightInk(button.tint, view.ink, 0.05, 0.18) : view.shade(0.05)
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: view.points(button.corners, true) }
                }
                // The button's printed number, lit, and tilted like the button.
                Text {
                    visible: button.mark !== undefined
                    x: button.corners.reduce((sum, p) => sum + p[0], 0) / button.corners.length - width / 2
                    y: button.corners.reduce((sum, p) => sum + p[1], 0) / button.corners.length - height / 2
                    rotation: Math.atan2(button.corners[1][1] - button.corners[0][1], button.corners[1][0] - button.corners[0][0]) * 180 / Math.PI
                    text: button.mark ? button.mark.text : ""
                    color: KeyLayout.lightInk(button.tint, view.ink, 0.4, 1)
                    font.pixelSize: 50
                    font.weight: Font.DemiBold
                }
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: view.buttonTapped(button.index)
                }
            }
        }
    }
}
