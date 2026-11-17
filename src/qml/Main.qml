import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    property string hubUrl: "http://127.0.0.1:27003"
    // "keyboard", "mouse", or "keyboard/<section>": opens that page at start.
    property string startRoute: ""
    property bool routeDone: false

    title: "Linkdeck"
    width: 1320
    height: 860
    minimumWidth: 960
    minimumHeight: 640

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn
    pageStack.initialPage: HomePage {}

    function openDevice(device, section) {
        const component = device.kind === "keyboard" ? keyboardPage : device.kind === "mouse" ? mousePage : null
        if (!component) {
            showPassiveNotification(device.product + " is not supported in Linkdeck yet.")
            return
        }
        while (pageStack.depth > 1)
            pageStack.pop()
        pageStack.push(component, { serial: device.serial, title: device.product, startSection: section || "" })
    }

    function followRoute() {
        if (routeDone || startRoute === "" || !Hub.loaded)
            return
        routeDone = true
        const parts = startRoute.split("/")
        for (const device of Hub.devices) {
            if (device.kind === parts[0]) {
                openDevice(device, parts[1] || "")
                return
            }
        }
    }

    Component {
        id: keyboardPage
        KeyboardPage {}
    }
    Component {
        id: mousePage
        MousePage {}
    }

    Connections {
        target: Hub
        function onLoadedChanged() { root.followRoute() }
        function onDevicesChanged() { root.followRoute() }
    }

    Component.onCompleted: {
        Hub.base = hubUrl
        Hub.refresh()
    }
}
