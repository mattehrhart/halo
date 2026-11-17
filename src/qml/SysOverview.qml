// Live readings for a device made of parts: fans, pumps, sensors, memory
// modules or power rails. One tile per part.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Item {
    id: view

    required property var page
    readonly property var device: page.device
    readonly property var parts: KeyLayout.parts(device)

    QQC2.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Flow {
            width: view.width
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: view.parts

                QQC2.Pane {
                    id: tile

                    required property var modelData
                    readonly property var now: view.page.readings[String(modelData.channelId)] || ({})
                    readonly property var lines: KeyLayout.readingLines(modelData, now)

                    width: Kirigami.Units.gridUnit * 11
                    height: Kirigami.Units.gridUnit * 6
                    padding: Kirigami.Units.largeSpacing
                    Kirigami.Theme.colorSet: Kirigami.Theme.View
                    Kirigami.Theme.inherit: false

                    background: Rectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: Kirigami.Theme.backgroundColor
                        border.width: 1
                        border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: KeyLayout.partName(tile.modelData)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: text !== "" && text !== KeyLayout.partName(tile.modelData)
                            text: tile.modelData.name || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 2
                            text: tile.lines.length > 0 ? tile.lines[0]
                                : tile.modelData.rgb ? KeyLayout.title(tile.modelData.rgb) : "—"
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: tile.lines.length > 1
                            text: tile.lines.slice(1).join("  ·  ")
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
