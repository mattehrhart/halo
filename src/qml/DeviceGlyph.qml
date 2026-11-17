// A device's outline at icon size, for the tabs.
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: glyph

    property var diagram: ({})
    // The traced outline to fall back on, and whether the device is a keyboard.
    property var traced: ({})
    property bool keyboardKind: false
    property string fallback: "preferences-devices-tree"

    readonly property bool hasDiagram: diagram !== null && diagram !== undefined && diagram.width !== undefined
    readonly property bool keyboard: keyboardKind || (hasDiagram && diagram.kind === "keyboard")
    readonly property var tracedView: traced && traced.views && traced.views.length > 0 ? traced.views[0] : null
    readonly property bool exact: keyboard || hasDiagram || tracedView !== null
    // A mouse is shown by its last outline, the view from above.
    readonly property var outline: hasDiagram && diagram.outlines ? diagram.outlines[diagram.outlines.length - 1]
        : tracedView ? tracedView.outline : []
    readonly property rect bounds: {
        if (keyboard)
            return hasDiagram ? Qt.rect(0, 0, diagram.width, diagram.height) : Qt.rect(0, 0, 100, 38)
        let left = 1e9, top = 1e9, right = 0, bottom = 0
        for (const p of outline) {
            left = Math.min(left, p[0]); right = Math.max(right, p[0])
            top = Math.min(top, p[1]); bottom = Math.max(bottom, p[1])
        }
        return outline.length > 0 ? Qt.rect(left, top, right - left, bottom - top) : Qt.rect(0, 0, 1, 1)
    }
    readonly property real zoom: Math.min(width / bounds.width, height / bounds.height)
    readonly property color ink: Kirigami.Theme.textColor

    implicitWidth: height * bounds.width / bounds.height

    Kirigami.Icon {
        anchors.fill: parent
        visible: !glyph.exact
        source: glyph.fallback
    }
    Item {
        visible: glyph.exact
        anchors.centerIn: parent
        width: glyph.bounds.width * glyph.zoom
        height: glyph.bounds.height * glyph.zoom

        Rectangle {
            visible: glyph.keyboard
            anchors.fill: parent
            radius: 3
            color: Qt.rgba(glyph.ink.r, glyph.ink.g, glyph.ink.b, 0.08)
            border.width: 1.5
            border.color: Qt.rgba(glyph.ink.r, glyph.ink.g, glyph.ink.b, 0.7)

            // A few rows of keys, to read as a keyboard at this size.
            Column {
                anchors.fill: parent
                anchors.margins: parent.height * 0.2
                spacing: parent.height * 0.08

                Repeater {
                    model: 4

                    Rectangle {
                        width: parent.width
                        height: Math.max(1, (parent.height - 3 * parent.spacing) / 4)
                        radius: 1
                        color: Qt.rgba(glyph.ink.r, glyph.ink.g, glyph.ink.b, 0.45)
                    }
                }
            }
        }
        Shape {
            visible: !glyph.keyboard && glyph.outline.length > 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1.5
                strokeColor: Qt.rgba(glyph.ink.r, glyph.ink.g, glyph.ink.b, 0.7)
                fillColor: Qt.rgba(glyph.ink.r, glyph.ink.g, glyph.ink.b, 0.08)
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        const list = glyph.outline.map(p => Qt.point((p[0] - glyph.bounds.x) * glyph.zoom, (p[1] - glyph.bounds.y) * glyph.zoom))
                        if (list.length > 0)
                            list.push(list[0])
                        return list
                    }
                }
            }
        }
    }
}
