import QtQuick
import "layout.js" as KeyLayout

Assignments {
    id: root

    // Keys that can be given a job: not light-only parts such as the light bar.
    entries: page.keymap.keys.filter(k => !k.raw.onlyColor && k.name !== "Logo")
        .map(k => ({ id: String(k.id), name: KeyLayout.spokenName(k.name), a: k.raw }))
    showAll: false
    selectedId: page.selectedIds.length > 0 && entries.some(e => e.id === String(page.selectedIds[0])) ? String(page.selectedIds[0]) : ""
    offered: [3, 9, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 0]
    savePath: "/api/keyboard/updateKeyAssignment"
    noun: "key"
    onChoose: id => {
        const next = {}
        next[Number(id)] = true
        page.selected = next
    }
}
