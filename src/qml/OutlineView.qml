// A device shown by its traced outline: one shape per view, side by side.
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: view

    // {name, views: [{width, height, outline}]} from deviceImages.outline().
    property var outline: ({})

    readonly property var views: outline && outline.views ? outline.views : []
    readonly property real gap: 60
    readonly property real totalWidth: views.reduce((sum, v) => sum + v.width, 0) + gap * Math.max(0, views.length - 1)
    readonly property real tallest: views.reduce((most, v) => Math.max(most, v.height), 1)
    readonly property real zoom: views.length > 0 ? Math.min(width / totalWidth, height / tallest, 1.6) : 1
    readonly property color ink: Kirigami.Theme.textColor

    Row {
        anchors.centerIn: parent
        spacing: view.gap * view.zoom

        Repeater {
            model: view.views

            Shape {
                required property var modelData

                width: modelData.width * view.zoom
                height: view.tallest * view.zoom
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: Qt.rgba(view.ink.r, view.ink.g, view.ink.b, 0.4)
                    fillColor: Qt.rgba(view.ink.r, view.ink.g, view.ink.b, 0.04)
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline {
                        path: {
                            const down = (view.tallest - modelData.height) / 2
                            const list = modelData.outline.map(p => Qt.point(p[0] * view.zoom, (p[1] + down) * view.zoom))
                            list.push(list[0])
                            return list
                        }
                    }
                }
            }
        }
    }
}
