// The one place that talks to OpenLinkHub's local API.
pragma Singleton

import QtQuick

QtObject {
    id: hub

    property string base: "http://127.0.0.1:27003"
    property bool reachable: false
    property bool loaded: false
    // [{serial, product, kind, firmware}] for every device OpenLinkHub shows.
    property var devices: []
    // serial -> battery percent, for wireless devices.
    property var battery: ({})

    property Timer poll: Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: hub.refresh()
    }

    // done(ok, data, message): ok means HTTP success and, for writes, status 1.
    function call(method, path, body, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            let data = null
            try {
                data = JSON.parse(xhr.responseText)
            } catch (e) {
                data = null
            }
            const httpOk = xhr.status >= 200 && xhr.status < 300 && data !== null
            if (xhr.status === 0)
                hub.reachable = false
            let message = ""
            if (data && data.message)
                message = String(data.message)
            else if (xhr.status === 0)
                message = "OpenLinkHub is not answering"
            else if (!httpOk)
                message = "OpenLinkHub returned an error (" + xhr.status + ")"
            // Re-sending a value the device already has is not a failure.
            const unchanged = message === "Nothing to update"
            const ok = httpOk && (method === "GET" || data.status === 1 || unchanged)
            if (done)
                done(ok, data, message)
        }
        xhr.open(method, base + path)
        if (body !== undefined && body !== null) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send()
        }
    }

    // What a device is, from the icon OpenLinkHub gives it.
    // Fetches a page as plain text, for checking cheaply whether anything
    // changed before doing the work of reading it. done(text or "").
    function fetchText(path, done) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done(xhr.status >= 200 && xhr.status < 300 ? xhr.responseText : "")
        }
        xhr.open("GET", base + path)
        xhr.send()
    }

    function kindOf(image) {
        const name = String(image || "")
        const kinds = [["keyboard", "keyboard"], ["mousepad", "mousepad"], ["mouse", "mouse"], ["headphone-stand", "stand"],
                       ["headphone", "headset"], ["controller", "controller"], ["radiator", "cooler"], ["towers", "cooler"],
                       ["ram", "memory"], ["psu", "power"], ["lcd", "display"], ["motherboard", "motherboard"]]
        for (const pair of kinds) {
            if (name.indexOf(pair[0]) >= 0)
                return pair[1]
        }
        return "other"
    }

    function refresh() {
        call("GET", "/api/", null, function (ok, data) {
            if (!ok || !data.device) {
                hub.reachable = false
                hub.loaded = true
                return
            }
            const list = []
            const serials = Object.keys(data.device).sort()
            for (const serial of serials) {
                const d = data.device[serial]
                if (d.Hidden)
                    continue
                list.push({
                    serial: serial,
                    product: d.Product,
                    kind: kindOf(d.Image),
                    firmware: d.Firmware
                })
            }
            // Keyboards first, then mice, then the rest.
            const order = { keyboard: 0, mouse: 1, headset: 2 }
            const rank = d => order[d.kind] === undefined ? 3 : order[d.kind]
            list.sort((a, b) => rank(a) - rank(b))
            hub.devices = list
            hub.reachable = true
            hub.loaded = true
        })
        call("GET", "/api/batteryStats", null, function (ok, data) {
            if (!ok || !data.data)
                return
            const levels = {}
            for (const serial in data.data)
                levels[serial] = data.data[serial].Level
            hub.battery = levels
        })
    }
}
