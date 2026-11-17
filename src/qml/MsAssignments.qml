import QtQuick
import "layout.js" as KeyLayout

Assignments {
    id: root

    entries: Object.keys(page.device.KeyAssignment || {}).map(Number).sort((a, b) => a - b)
        .map(id => ({ id: String(id), name: page.device.KeyAssignment[String(id)].name, a: page.device.KeyAssignment[String(id)] }))
    showAll: true
    selectedId: page.selectedButton
    offered: [3, 9, 1, 10, 2, 8, 11, 0]
    savePath: "/api/" + page.family + "/updateKeyAssignment"
    noun: "button"
    onChoose: id => page.selectedButton = id
}
