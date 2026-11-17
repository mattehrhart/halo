// Colors and speed for the effect that is running. Every change is reported
// straight away through changed(), so the device follows as you adjust.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

GridLayout {
    id: root

    required property var page
    // The effect's two colors as the user chose them (before any dimming).
    property color startColor: "#ffffff"
    property color endColor: "#ffffff"
    signal changed(color first, color second, int speed)

    readonly property var device: page.device
    // The effect being edited; pages for devices made of parts set this.
    property string mode: device.DeviceProfile.RGBProfile || ""
    readonly property var profile: device.Rgb && device.Rgb.profiles ? device.Rgb.profiles[mode] : null
    readonly property bool hasColors: profile !== null && KeyLayout.usesColors(mode)
    readonly property bool hasSpeed: profile !== null && KeyLayout.usesSpeed(mode)
    readonly property real labelWidth: Kirigami.Units.gridUnit * 6

    columns: 2
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: Kirigami.Units.largeSpacing

    QQC2.Label {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        visible: !root.hasColors && !root.hasSpeed
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: root.mode === "off" ? "The lights are off." : "No settings."
    }

    QQC2.Label {
        Layout.preferredWidth: root.labelWidth
        visible: root.hasColors
        text: root.mode === "static" ? "Color" : "First color"
    }
    ColorButton {
        id: first

        visible: root.hasColors
        label: root.mode === "static" ? "Color" : "First color"
        value: root.startColor
        onChosen: picked => root.changed(picked, second.value, 11 - Math.round(speed.value))
    }

    QQC2.Label {
        Layout.preferredWidth: root.labelWidth
        visible: second.visible
        text: "Second color"
    }
    ColorButton {
        id: second

        visible: root.hasColors && root.mode !== "static"
        label: "Second color"
        value: root.endColor
        onChosen: picked => root.changed(first.value, picked, 11 - Math.round(speed.value))
    }

    QQC2.Label {
        Layout.preferredWidth: root.labelWidth
        visible: root.hasSpeed
        text: "Speed"
    }
    QQC2.Slider {
        id: speed

        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 16
        visible: root.hasSpeed
        from: 1
        to: 10
        // OpenLinkHub counts 1 as fastest; show it the natural way round.
        value: root.profile ? 11 - Math.max(1, Math.min(10, root.profile.speed)) : 5
        Accessible.name: "Speed, slow to fast"
        onPressedChanged: {
            if (!pressed)
                root.changed(first.value, second.value, 11 - Math.round(value))
        }
    }
}
