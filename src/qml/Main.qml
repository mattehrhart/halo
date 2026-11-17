import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "layout.js" as KeyLayout

Kirigami.ApplicationWindow {
    id: root

    property string hubUrl: "http://127.0.0.1:27003"
    // "keyboard", "mouse", "keyboard/<section>" or "keyboard/<section>/<key id>": opens that page at start.
    property string startRoute: ""
    property bool routeDone: false

    title: "Halo"
    width: 1320
    height: 860
    minimumWidth: 960
    minimumHeight: 660

    // No header bar: the device tabs name the device, and Refresh sits beside them.
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.NoNavigationButtons
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn

    // The device shown last time, so the app opens where it was left.
    Settings {
        id: remembered

        category: "Window"
        property string lastSerial: ""
    }

    function openDevice(device, section, select) {
        // Keyboards have their own page; every other device shares one that
        // shows whatever that device offers.
        const component = device.kind === "keyboard" ? keyboardPage : mousePage
        remembered.lastSerial = device.serial
        // Device pages replace one another; there is no page to go back to.
        pageStack.clear()
        const options = { serial: device.serial, title: device.product, startSection: section || "", startSelect: select || "" }
        if (device.kind !== "keyboard")
            options.kind = device.kind
        pageStack.push(component, options)
    }

    // Opens a device as soon as the list is known: the one named on the
    // command line, else the one used last, else the first.
    function followRoute() {
        if (routeDone || !Hub.loaded || !Hub.reachable || Hub.devices.length === 0)
            return
        routeDone = true
        const parts = startRoute.split("/")
        let device = Hub.devices.find(d => startRoute !== "" && (d.kind === parts[0] || d.serial === parts[0]))
        if (!device)
            device = Hub.devices.find(d => d.serial === remembered.lastSerial) || Hub.devices[0]
        openDevice(device, startRoute !== "" ? parts[1] || "" : "", startRoute !== "" ? parts[2] || "" : "")
        // For testing from the command line: --route keyboard/lighting/lightsoff (or lightson)
        if (parts[2] === "lightsoff" || parts[2] === "lightson")
            shell.lightsOff = parts[2] === "lightsoff"
    }

    // With the service gone or every device unplugged, fall back to the
    // status page; a device opens again as soon as one is found.
    function checkDevices() {
        const lost = !Hub.reachable || Hub.devices.length === 0
        if (lost && Hub.loaded && (routeDone || pageStack.depth === 0 || !onSetup)) {
            routeDone = false
            onSetup = true
            pageStack.clear()
            pageStack.push(statusPage)
        } else if (!lost) {
            onSetup = false
            followRoute()
        } else {
            followRoute()
        }
    }

    Component {
        id: statusPage
        HomePage {}
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
        function onLoadedChanged() { root.ensureService(); root.checkDevices() }
        function onDevicesChanged() { root.checkDevices(); root.publishDevices() }
        function onBatteryChanged() { root.checkBattery(); root.publishDevices() }
        function onReachableChanged() { root.checkDevices() }
    }

    // Closing the window keeps Halo in the tray; Quit is in the menus.
    onClosing: close => {
        if (shell.closeToTray) {
            close.accepted = false
            root.hide()
        } else {
            shell.quit()
        }
    }

    // Lights Off turns every device's lighting off and remembers what each
    // was showing; turning it back on restores that.
    Settings {
        id: lighting

        category: "Lighting"
        property string before: "{}"
    }

    // Turns every device's lights off, or back to what they were. Keyboards
    // and mice have one effect; hubs, coolers and memory have one per part.
    function setLights(off) {
        const before = JSON.parse(lighting.before)
        const done = () => root.lightsChanged()
        for (const device of Hub.devices) {
            Hub.call("GET", "/api/devices/" + device.serial, null, function (ok, data) {
                if (!ok || !data.device || !data.device.DeviceProfile)
                    return
                const whole = data.device.DeviceProfile.RGBProfile
                if (whole !== undefined) {
                    if (off && whole !== "off") {
                        before[device.serial] = whole
                        lighting.before = JSON.stringify(before)
                        Hub.call("POST", "/api/color", { deviceId: device.serial, channelId: 0, profile: "off" }, done)
                    } else if (!off && whole === "off") {
                        const was = typeof before[device.serial] === "string" ? before[device.serial] : "static"
                        Hub.call("POST", "/api/color", { deviceId: device.serial, channelId: 0, profile: was }, done)
                    }
                    return
                }
                const lit = KeyLayout.parts(data.device).filter(p => p.rgb !== undefined && p.rgb !== "")
                if (lit.length === 0)
                    return
                if (off && lit.some(p => p.rgb !== "off")) {
                    const each = {}
                    for (const part of lit)
                        each[String(part.channelId)] = part.rgb
                    before[device.serial] = each
                    lighting.before = JSON.stringify(before)
                    // A negative channel means every part.
                    Hub.call("POST", "/api/color", { deviceId: device.serial, channelId: -1, profile: "off" }, done)
                } else if (!off && lit.every(p => p.rgb === "off")) {
                    const each = before[device.serial] && typeof before[device.serial] === "object" ? before[device.serial] : {}
                    for (const part of lit)
                        Hub.call("POST", "/api/color", { deviceId: device.serial, channelId: part.channelId,
                                                         profile: each[String(part.channelId)] || "static" }, done)
                }
            })
        }
    }
    signal lightsChanged()

    // One alert per device each time its battery falls to 15 % or below.
    property var warned: ({})

    function checkBattery() {
        if (!shell.batteryAlerts)
            return
        for (const device of Hub.devices) {
            const level = Hub.battery[device.serial]
            if (level === undefined)
                continue
            if (level > 20) {
                delete warned[device.serial]
            } else if (level <= 15 && !warned[device.serial]) {
                warned[device.serial] = true
                shell.notify(device.product + " Battery Low", level + "% remaining")
            }
        }
    }

    Connections {
        target: shell
        function onLightsRequested(off) { root.setLights(off) }
        function onDeviceRequested(serial) {
            const device = Hub.devices.find(d => d.serial === serial)
            if (device)
                root.openDevice(device, "")
        }
        function onProfileRequested(serial, profile) {
            Hub.call("POST", "/api/userProfile/change", { deviceId: serial, userProfileName: profile }, function () {
                root.lightsChanged()
                root.publishDevices()
            })
        }
    }

    // Gives the tray menu each device's battery level and profiles.
    // What the tray was last given; it is only rebuilt when this changes,
    // so an open tray menu is not closed by the regular battery check.
    property string published: ""

    function publish(list) {
        const now = JSON.stringify(list)
        if (now === published)
            return
        published = now
        shell.setDevices(list)
    }

    function publishDevices() {
        const list = []
        let waiting = Hub.devices.length
        if (waiting === 0)
            publish([])
        Hub.devices.forEach((device, position) => {
            Hub.call("GET", "/api/devices/" + device.serial, null, function (ok, data) {
                const profiles = ok && data.device && data.device.userProfiles ? Object.keys(data.device.userProfiles).sort() : []
                const level = Hub.battery[device.serial]
                list[position] = {
                    serial: device.serial,
                    product: device.product,
                    battery: level === undefined ? -1 : level,
                    profiles: profiles,
                    active: profiles.find(name => data.device.userProfiles[name] && data.device.userProfiles[name].Active) || ""
                }
                if (--waiting === 0)
                    root.publish(list)
            })
        })
    }

    Kirigami.Dialog {
        id: about

        title: "About Halo"
        standardButtons: Kirigami.Dialog.Close
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 24

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    source: "io.github.mattehrhart.Halo"
                }
                ColumnLayout {
                    spacing: 0

                    Kirigami.Heading {
                        level: 2
                        text: "Halo " + shell.version
                    }
                    QQC2.Label {
                        text: "Lighting and key settings for gaming keyboards and mice"
                        opacity: 0.7
                    }
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Free software under the GNU General Public License, version 3 or later."
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Devices are controlled through OpenLinkHub by Nikola Jurkovic, included under the GPL-3.0."
            }
            Kirigami.UrlButton {
                url: "https://github.com/jurkovic-nikola/OpenLinkHub"
                text: "OpenLinkHub on GitHub"
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: "Halo is an independent project, not affiliated with any device maker."
            }
        }
    }

    function showAbout() {
        about.open()
    }

    // With nothing answering, run the copy of OpenLinkHub that ships with
    // Halo, then keep asking until it is up.
    function ensureService() {
        if (Hub.loaded && !Hub.reachable && hubService.bundled && !hubService.running && !serviceTried) {
            serviceTried = true
            hubService.start()
        }
    }
    property bool serviceTried: false
    property bool onSetup: false

    Timer {
        interval: 1500
        repeat: true
        running: Hub.loaded && !Hub.reachable && hubService.running
        onTriggered: Hub.refresh()
    }

    Component.onCompleted: {
        Hub.base = hubUrl
        Hub.refresh()
    }
}
