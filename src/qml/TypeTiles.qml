// A grid of icon tiles for choosing a lighting type or what a key should do.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Flow {
    id: tiles

    // [{id, text}]
    property var types: []
    property int current: -1
    signal picked(int id)
    // Icon for a tile whose name matches nothing in the table below.
    property string fallbackIcon: "preferences-desktop-keyboard-shortcut"

    spacing: Kirigami.Units.smallSpacing

    // Type numbers mean different things on different devices, so go by name.
    function iconFor(text) {
        const t = text.toLowerCase()
        const table = [
            ["disable", "dialog-cancel"], ["media", "media-playback-start"], ["dpi", "transform-scale"],
            ["keyboard", "input-keyboard"], ["sniper", "crosshairs"], ["mouse", "input-mouse"],
            ["macro", "format-list-ordered"], ["profile", "document-multiple"], ["screen", "video-display-brightness"],
            ["brighter", "high-brightness"], ["dimmer", "low-brightness"], ["scroll up", "go-up"],
            ["scroll down", "go-down"], ["zoom in", "zoom-in"], ["zoom out", "zoom-out"],
            ["per-key", "input-keyboard"], ["zone", "input-mouse"], ["static", "fill-color"],
            ["rainbow", "color-management"], ["wave", "draw-bezier-curves"], ["pulse", "view-refresh"],
            ["shift", "exchange-positions"], ["warp", "transform-shear-left"], ["circle", "draw-circle"],
            ["spinner", "transform-rotate"], ["rotator", "transform-rotate"], ["flicker", "flashlight-on"],
            ["storm", "weather-storm"], ["gradient", "color-gradient"], ["marquee", "go-next"],
            ["sequential", "view-list-details"], ["nebula", "weather-fog"], ["watercolor", "draw-brush"],
            ["lights off", "system-shutdown"], ["temperature", "temperature-normal"]
        ]
        for (const row of table) {
            if (t.indexOf(row[0]) >= 0)
                return row[1]
        }
        return tiles.fallbackIcon
    }

    // Tiles share the row evenly, so there is no ragged gap at the end.
    readonly property int columns: Math.max(2, Math.floor((width + spacing) / (Kirigami.Units.gridUnit * 5.2 + spacing)))
    readonly property real tileWidth: Math.floor((width - (columns - 1) * spacing) / columns)

    // Scrolls the card so the chosen tile can be seen.
    function reveal(item) {
        let flick = tiles.parent
        while (flick && flick.contentY === undefined)
            flick = flick.parent
        if (!flick || !item)
            return
        const top = item.mapToItem(flick.contentItem, 0, 0).y
        if (top < flick.contentY)
            flick.contentY = top
        else if (top + item.height > flick.contentY + flick.height)
            flick.contentY = top + item.height - flick.height
    }

    Repeater {
        model: tiles.types

        QQC2.AbstractButton {
            id: tile

            required property var modelData
            readonly property bool chosen: tiles.current === modelData.id

            width: tiles.tileWidth
            height: Kirigami.Units.gridUnit * 3.8
            text: modelData.text
            hoverEnabled: true
            onClicked: tiles.picked(modelData.id)
            onChosenChanged: {
                if (chosen)
                    Qt.callLater(tiles.reveal, tile)
            }
            Component.onCompleted: {
                if (chosen)
                    Qt.callLater(tiles.reveal, tile)
            }
            Accessible.name: modelData.text
            Accessible.role: Accessible.RadioButton
            Accessible.checked: chosen

            background: Rectangle {
                readonly property color accent: Kirigami.Theme.highlightColor

                radius: Kirigami.Units.cornerRadius
                color: tile.chosen ? Qt.rgba(accent.r, accent.g, accent.b, 0.28)
                    : tile.down ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.16)
                    : tile.hovered ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.10)
                    : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)
                border.width: tile.chosen || tile.visualFocus ? 2 : 1
                border.color: tile.chosen ? accent : tile.visualFocus ? Kirigami.Theme.focusColor
                    : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
            }

            contentItem: ColumnLayout {
                spacing: 2

                Item { Layout.fillHeight: true }
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    source: tiles.iconFor(tile.modelData.text)
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
