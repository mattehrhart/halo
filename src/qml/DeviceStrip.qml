// The row of device pictures across the top of a device page.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: strip

    property string current: ""
    signal refresh()

    spacing: Kirigami.Units.smallSpacing

    function iconFor(kind) {
        const icons = { keyboard: "input-keyboard-symbolic", mouse: "input-mouse-symbolic", headset: "audio-headset-symbolic",
                        cooler: "temperature-normal-symbolic", memory: "media-flash-symbolic",
                        power: "battery-profile-performance-symbolic", display: "video-display-symbolic",
                        motherboard: "computer-symbolic" }
        return icons[kind] || "preferences-devices-tree"
    }

    // The tabs scroll sideways when there are more than fit.
    ListView {
        id: tabs

        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 3.4
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        spacing: strip.spacing
        model: Hub.devices
        currentIndex: Hub.devices.findIndex(d => d.serial === strip.current)
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        onCountChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        WheelHandler {
            onWheel: event => tabs.flick((event.angleDelta.y + event.angleDelta.x) * 8, 0)
        }

        delegate: QQC2.AbstractButton {
            id: tab

            required property var modelData
            readonly property bool active: modelData.serial === strip.current

            // Each tab is as wide as its picture and name need.
            width: implicitContentWidth + leftPadding + rightPadding + Kirigami.Units.largeSpacing
            height: tabs.height
            text: modelData.product
            hoverEnabled: true
            onClicked: {
                if (!active)
                    applicationWindow().openDevice(modelData, "")
            }
            Accessible.name: modelData.product
            Accessible.role: Accessible.PageTab

            background: Rectangle {
                radius: Kirigami.Units.cornerRadius
                color: tab.active ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
                    : tab.hovered ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)
                    : "transparent"
                border.width: tab.visualFocus ? 2 : 0
                border.color: Kirigami.Theme.focusColor

                // The line under the device being shown.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 3
                    radius: 1.5
                    visible: tab.active
                    color: Kirigami.Theme.highlightColor
                }
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                DeviceGlyph {
                    Layout.preferredHeight: tab.height - Kirigami.Units.largeSpacing * 2.4
                    Layout.preferredWidth: Math.min(Kirigami.Units.gridUnit * 4, implicitWidth)
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignVCenter
                    diagram: deviceImages.info(tab.modelData.product)
                    traced: deviceImages.outline(tab.modelData.product, false)
                    keyboardKind: tab.modelData.kind === "keyboard"
                    fallback: strip.iconFor(tab.modelData.kind)
                    opacity: tab.active || tab.hovered ? 1 : 0.7
                }
                QQC2.Label {
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    text: tab.modelData.product
                    elide: Text.ElideRight
                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                    opacity: tab.active || tab.hovered ? 1 : 0.7
                }
            }
        }
    }
    QQC2.ToolButton {
        icon.name: "view-refresh"
        display: QQC2.AbstractButton.IconOnly
        text: "Refresh"
        onClicked: strip.refresh()
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: 600
        QQC2.ToolTip.text: text
    }
    QQC2.ToolButton {
        id: menuButton

        icon.name: "application-menu"
        display: QQC2.AbstractButton.IconOnly
        text: "Menu"
        down: appMenu.visible || pressed
        onClicked: appMenu.visible ? appMenu.close() : appMenu.popup(menuButton, menuButton.width - appMenu.width, menuButton.height)
        // For testing from the command line: --route keyboard/lighting/menu
        Component.onCompleted: {
            if (applicationWindow().startRoute.endsWith("/menu"))
                Qt.callLater(() => menuButton.clicked())
        }
        QQC2.ToolTip.visible: hovered && !appMenu.visible
        QQC2.ToolTip.delay: 600
        QQC2.ToolTip.text: text

        QQC2.Menu {
            id: appMenu

            QQC2.MenuItem {
                text: "Lights Off"
                icon.name: "system-shutdown"
                checkable: true
                checked: shell.lightsOff
                onTriggered: shell.lightsOff = checked
            }
            QQC2.MenuSeparator {}
            QQC2.MenuItem {
                text: "Start at Login"
                checkable: true
                checked: shell.startAtLogin
                onTriggered: shell.startAtLogin = checked
            }
            QQC2.MenuItem {
                text: "Start Minimized"
                checkable: true
                checked: shell.startMinimized
                enabled: shell.trayAvailable
                onTriggered: shell.startMinimized = checked
            }
            QQC2.MenuItem {
                text: "Keep Running in Tray"
                checkable: true
                checked: shell.closeToTray
                enabled: shell.trayAvailable
                onTriggered: shell.closeToTray = checked
            }
            QQC2.MenuItem {
                text: "Low Battery Alerts"
                checkable: true
                checked: shell.batteryAlerts
                onTriggered: shell.batteryAlerts = checked
            }
            QQC2.MenuSeparator {}
            QQC2.MenuItem {
                text: "Open OpenLinkHub Dashboard"
                icon.name: "internet-services"
                onTriggered: Qt.openUrlExternally(Hub.base)
            }
            QQC2.MenuItem {
                text: "Restart Device Service"
                icon.name: "system-reboot"
                visible: hubService.running
                height: visible ? implicitHeight : 0
                onTriggered: hubService.restart()
            }
            QQC2.MenuSeparator {}
            QQC2.MenuItem {
                text: "About Halo"
                icon.name: "help-about"
                onTriggered: applicationWindow().showAbout()
            }
            QQC2.MenuItem {
                text: "Quit"
                icon.name: "application-exit"
                onTriggered: shell.quit()
            }
        }
    }
}
