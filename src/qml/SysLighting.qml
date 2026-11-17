// Lighting for every part of a hub, cooler or memory kit at once.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

RowLayout {
    id: root

    required property var page
    readonly property var device: page.device
    readonly property var lit: KeyLayout.parts(device).filter(p => p.rgb !== undefined && p.rgb !== "")
    // The effect every part shares, or "" when they differ.
    readonly property string mode: lit.length > 0 && lit.every(p => p.rgb === lit[0].rgb) ? lit[0].rgb : ""
    readonly property bool hasBrightness: device.DeviceProfile.BrightnessSlider !== undefined && device.DeviceProfile.BrightnessSlider !== null

    spacing: Kirigami.Units.largeSpacing

    Panel {
        title: "Lighting Type"
        description: root.mode === "" ? "Parts use different effects. Pick one to set them all." : ""
        Layout.preferredWidth: Kirigami.Units.gridUnit * 30
        Layout.fillWidth: false

        TypeTiles {
            readonly property var modes: KeyLayout.orderedModes(root.device.RGBModes)

            Layout.fillWidth: true
            fallbackIcon: "color-management"
            types: modes.map((mode, index) => ({ id: index, text: KeyLayout.title(mode) }))
            current: modes.indexOf(root.mode)
            onPicked: id => {
                if (modes[id] !== root.mode && !root.page.busy)
                    root.page.send("POST", "/api/color", { channelId: -1, profile: modes[id] }, null, KeyLayout.title(modes[id]))
            }
        }
    }

    Panel {
        title: root.mode === "" ? "Mixed" : KeyLayout.title(root.mode)
        Layout.fillWidth: true

        EffectSettings {
            id: effect

            Layout.fillWidth: true
            visible: root.mode !== ""
            page: root.page
            mode: root.mode
            startColor: profile ? KeyLayout.rgb(profile.start) : "#ffffff"
            endColor: profile ? KeyLayout.rgb(profile.end) : "#ffffff"
            onChanged: (first, second, speed) => {
                const part = c => ({ red: Math.round(c.r * 255), green: Math.round(c.g * 255), blue: Math.round(c.b * 255), temperature: 0 })
                root.page.send("PUT", "/api/color/change", {
                    profile: root.mode,
                    startColor: part(first),
                    endColor: part(root.mode === "static" ? first : second),
                    middleColor: part(KeyLayout.rgb(effect.profile.middle)),
                    speed: speed,
                    alternateColors: effect.profile.alternateColors,
                    rgbDirection: effect.profile.rgbDirection
                }, null, "Effect updated")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.hasBrightness && root.mode !== ""
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            visible: root.hasBrightness
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                text: "Brightness"
            }
            QQC2.Slider {
                id: level

                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.hasBrightness ? root.device.DeviceProfile.BrightnessSlider : 100
                enabled: !root.page.busy
                Accessible.name: "Brightness"
                onPressedChanged: {
                    root.page.holdRefresh = pressed
                    if (!pressed && Math.round(value) !== root.device.DeviceProfile.BrightnessSlider)
                        root.page.send("POST", "/api/brightness/gradual", { brightness: Math.round(value) }, null,
                                       "Brightness " + Math.round(value) + "%")
                }
            }
            QQC2.Label {
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
                horizontalAlignment: Text.AlignRight
                text: Math.round(level.value) + "%"
            }
        }
    }
}
