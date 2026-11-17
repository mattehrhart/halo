// A keyboard drawn as a simple diagram: the case outline, each key as an
// outlined cap, and its legend lit in the color the key is set to.
import QtQuick
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Item {
    id: view

    property var keymap: ({ keys: [], byId: ({}), width: 1, height: 1 })
    property var device: null
    // id -> true for every selected key
    property var selected: ({})
    // "", "actuation" or "assign": what small mark to show on a key
    property string badge: ""
    // Whether keys respond to the pointer.
    property bool interactive: true
    // This model's diagram (see tools/make-device-diagrams.py), or an empty
    // object to lay the keys out on a plain case.
    property var diagram: ({})
    signal keyTapped(int id, bool extend)

    readonly property bool exact: diagram !== null && diagram !== undefined && diagram.width !== undefined
    readonly property real pad: 42
    readonly property real canvasWidth: exact ? diagram.width : keymap.width + 2 * pad
    readonly property real canvasHeight: exact ? diagram.height : keymap.height + 2 * pad
    readonly property real zoom: Math.min(width / canvasWidth, height / canvasHeight)
    readonly property color ink: Kirigami.Theme.textColor
    readonly property string mode: device ? device.DeviceProfile.RGBProfile : "off"
    readonly property bool animated: ["keyboard", "static", "off", "cpu-temperature", "gpu-temperature"].indexOf(mode) < 0
    // Seconds the current effect has been playing in the preview.
    property real clock: 0

    // The press distance most keys share; only keys that differ show a badge.
    readonly property int usualActuation: {
        const counts = {}
        let best = 0
        let bestCount = 0
        for (const key of keymap.keys) {
            if (!KeyLayout.adjustable(key.raw))
                continue
            const v = key.raw.actuationPoint
            counts[v] = (counts[v] || 0) + 1
            if (counts[v] > bestCount) {
                bestCount = counts[v]
                best = v
            }
        }
        return best
    }

    FrameAnimation {
        running: view.visible && view.animated
        onTriggered: view.clock += frameTime
    }
    onModeChanged: clock = 0

    // The spacebar is one key with several lights; it is drawn as one cap.
    readonly property rect spacebar: {
        let left = 1e9, top = 1e9, right = 0, bottom = 0
        for (const key of keymap.keys) {
            if (key.name !== "----------")
                continue
            const at = place(key)
            left = Math.min(left, at.x); top = Math.min(top, at.y)
            right = Math.max(right, at.x + at.width); bottom = Math.max(bottom, at.y + at.height)
        }
        return right > 0 ? Qt.rect(left, top, right - left, bottom - top) : Qt.rect(0, 0, 0, 0)
    }

    function lit(key) {
        return KeyLayout.keyColor(key, view.device, view.clock)
    }

    function shade(amount) {
        return Qt.rgba(ink.r, ink.g, ink.b, amount)
    }

    // Where a key sits, in diagram units.
    function place(key) {
        if (!exact)
            return Qt.rect(pad + key.x, pad + key.y, key.w, key.h)
        const fixed = diagram.overrides ? diagram.overrides[key.name] : undefined
        if (fixed)
            return Qt.rect(fixed[0], fixed[1], fixed[2], fixed[3])
        const shift = diagram.rowShift && diagram.rowShift[String(key.row)] !== undefined ? diagram.rowShift[String(key.row)] : 0
        return Qt.rect(diagram.origin[0] + key.x * diagram.scale[0],
                       diagram.origin[1] + (key.y - diagram.rowOffset) * diagram.scale[1] + shift,
                       key.w * diagram.scale[0], key.h * diagram.scale[1])
    }

    function legend(key) {
        if (exact && diagram.symbols && diagram.symbols[key.name] !== undefined)
            return diagram.symbols[key.name]
        return key.label
    }

    Item {
        id: frame

        // Keep the active highlight color even while the window is in the background.
        Kirigami.Theme.colorGroup: Kirigami.Theme.Active
        Kirigami.Theme.inherit: false
        anchors.centerIn: parent
        width: view.canvasWidth * view.zoom
        height: view.canvasHeight * view.zoom

        // The case.
        Rectangle {
            readonly property var box: view.exact ? view.diagram.body : [0, 0, view.canvasWidth, view.canvasHeight, 20]

            x: box[0] * view.zoom
            y: box[1] * view.zoom
            width: box[2] * view.zoom
            height: box[3] * view.zoom
            radius: box[4] * view.zoom
            color: view.shade(0.04)
            border.width: Math.max(1, 2.5 * view.zoom)
            border.color: view.shade(0.4)
        }
        Repeater {
            model: view.exact && view.diagram.parts ? view.diagram.parts : []

            Rectangle {
                required property var modelData

                x: modelData.box[0] * view.zoom
                y: modelData.box[1] * view.zoom
                width: modelData.box[2] * view.zoom
                height: modelData.box[3] * view.zoom
                radius: (modelData.radius || 0) * view.zoom
                color: modelData.solid ? view.shade(0.1) : view.shade(0.03)
                border.width: 1
                border.color: view.shade(0.22)
            }
        }
        // The volume roller: a ridged bar.
        Rectangle {
            readonly property var box: view.exact && view.diagram.roller ? view.diagram.roller : [0, 0, 0, 0]

            visible: box[2] > 0
            x: box[0] * view.zoom
            y: box[1] * view.zoom
            width: box[2] * view.zoom
            height: box[3] * view.zoom
            radius: height / 2
            color: view.shade(0.06)
            border.width: 1
            border.color: view.shade(0.35)

            Row {
                anchors.centerIn: parent
                height: parent.height
                spacing: parent.width / 22

                Repeater {
                    model: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height * 0.6
                        color: view.shade(0.3)
                    }
                }
            }
        }

        Repeater {
            model: view.keymap.keys

            Item {
                id: cap

                required property var modelData
                readonly property rect at: view.place(modelData)
                readonly property bool isLight: modelData.name === "Logo" || modelData.bar === true
                readonly property bool isRoller: view.exact && view.diagram.roller !== undefined
                    && (modelData.name === "WH +" || modelData.name === "WH -")
                readonly property bool isSpace: modelData.name === "----------"
                readonly property bool picked: view.selected[modelData.id] === true
                readonly property color tint: view.lit(modelData)
                readonly property bool dark: tint.r + tint.g + tint.b < 0.02
                readonly property string label: view.legend(modelData)
                readonly property string caption: {
                    if (view.badge === "actuation" && KeyLayout.adjustable(modelData.raw) && modelData.raw.actuationPoint !== view.usualActuation)
                        return (modelData.raw.actuationPoint / 10).toFixed(1)
                    if (view.badge === "assign" && !modelData.raw.default && !modelData.raw.onlyColor)
                        return "●"
                    return ""
                }

                x: at.x * view.zoom
                y: at.y * view.zoom
                width: at.width * view.zoom
                height: at.height * view.zoom

                Accessible.role: Accessible.Button
                Accessible.name: KeyLayout.spokenName(modelData.name)

                // The cap: a faint wash of the key's color inside an outline.
                Rectangle {
                    visible: !cap.isRoller
                    anchors.fill: parent
                    anchors.margins: (cap.isLight ? 0 : 4) * view.zoom
                    // Spacebar segments butt together under one outline.
                    anchors.leftMargin: (cap.isSpace || cap.isLight ? 0 : 4) * view.zoom
                    anchors.rightMargin: (cap.isSpace || cap.isLight ? 0 : 4) * view.zoom
                    radius: cap.isLight ? Math.min(width, height) / 2 : cap.isSpace && !cap.picked ? 0 : 9 * view.zoom
                    color: cap.isLight ? KeyLayout.lightInk(cap.tint, view.ink, 0.12, 1)
                        : KeyLayout.lightInk(cap.tint, view.ink, area.containsMouse ? 0.1 : 0.05, area.containsMouse ? 0.3 : 0.18)
                    border.width: cap.picked ? Math.max(2, 5 * view.zoom) : cap.isLight || cap.isSpace ? 0 : Math.max(1, 2 * view.zoom)
                    border.color: cap.picked ? Kirigami.Theme.highlightColor : KeyLayout.lightInk(cap.tint, view.ink, 0.3, 0.75)
                }
                Text {
                    visible: !cap.isLight && !cap.isRoller && cap.label !== ""
                    anchors.centerIn: parent
                    width: parent.width - 16 * view.zoom
                    horizontalAlignment: Text.AlignHCenter
                    text: cap.label
                    color: KeyLayout.lightInk(cap.tint, view.ink, 0.4, 1)
                    font.pixelSize: Math.round(Math.max(5, (cap.label.length > 2 ? 22 : 30) * view.zoom))
                    minimumPixelSize: 4
                    fontSizeMode: Text.HorizontalFit
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: cap.caption !== ""
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 7 * view.zoom
                    width: tag.implicitWidth + 6
                    height: tag.implicitHeight + 2
                    radius: 3
                    color: Kirigami.Theme.highlightColor

                    Text {
                        id: tag

                        anchors.centerIn: parent
                        text: cap.caption
                        color: Kirigami.Theme.highlightedTextColor
                        font.pixelSize: Math.round(Math.max(7, 19 * view.zoom))
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: view.interactive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const extend = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.ShiftModifier) !== 0
                        view.keyTapped(cap.modelData.id, extend)
                    }
                }
            }
        }
            Rectangle {
            visible: view.spacebar.width > 0
            x: (view.spacebar.x + 4) * view.zoom
            y: (view.spacebar.y + 4) * view.zoom
            width: (view.spacebar.width - 8) * view.zoom
            height: (view.spacebar.height - 8) * view.zoom
            radius: 9 * view.zoom
            color: "transparent"
            border.width: Math.max(1, 2 * view.zoom)
            border.color: view.shade(0.3)
        }
    }
}
