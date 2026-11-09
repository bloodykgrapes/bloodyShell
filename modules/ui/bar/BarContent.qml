pragma ComponentBehavior: Bound

import QtQuick

import "../../core"
import "components"

Item
{
    id: content

    required property var host
    readonly property alias panel0: start.panel
    readonly property alias panel2: end.panel
    readonly property var bodies: [start.islandRect, Qt.rect(0, 0, 0, 0), end.islandRect]
    readonly property var panels: [start.blob, Qt.rect(0, 0, 0, 0), end.blob]
    readonly property real total: host.isHorizontal ? width : height
    readonly property real centerLimit: Math.max(32, total - 2 * (Math.max(start.rowAlong, end.rowAlong) + cornerInset + 16))
    readonly property real cornerInset: Theme.frameThickness + Theme.sidebarCorner + 6

    component Zone: BarZone
    {
        anchors.fill: parent
        docked: false
        thickness: content.host.thickness
        detached: content.host.islands
        islandDepth: Theme.frameThickness + content.host.surfaceGap
        cornerInset: content.cornerInset
        edgeMin: content.cornerInset
        edgeMax: content.total - content.cornerInset
        snapMin: edgeMin
        snapMax: edgeMax
        revealed: content.host.revealed
    }

    Zone { id: start; align: "start"; widgets: ["workspaces", "window"] }
    Zone { id: end; align: "end"; widgets: ["tray", "status", "clock", "notifications", "update"] }
}
