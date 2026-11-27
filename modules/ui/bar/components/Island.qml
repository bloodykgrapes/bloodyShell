pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../core"
import "../../../services"

Item
{
    id: island

    required property var screen
    required property real centerLimit
    required property real center
    required property real depth
    required property bool flushStart
    required property bool flushEnd
    required property real menuStartInset
    required property real menuEndInset

    readonly property string islandOutput: screen ? screen.name : ""
    readonly property real span: zone.islandAlong
    readonly property int side: Config.barSide
    readonly property bool menuHere: MenuState.menuActive && MenuState.menuOwner === zone
    readonly property bool hoveringBody: hover.hovered || (zone.singleWidget?.hoveringFace ?? false)
    readonly property alias inputRegion: inputMask
    readonly property rect bodyRect: ServiceLock.locked || !zone.hasWidgets ? Qt.rect(0, 0, 0, 0)
        : zone.toRect(flushStart ? 0 : zone.islandA0, flushEnd ? zone.total : zone.islandA1, depth, zone.baseOuter)
    readonly property rect panelRect: zone.attachedMenuRect

    onVisibleChanged: if (!visible && menuHere) MenuState.close()
    Component.onDestruction: if (menuHere) MenuState.close()

    Region
    {
        id: inputMask
        Region { item: body.width > 0 && body.height > 0 ? body : null }
        Region { item: zone.panel.enabled && zone.panel.visible ? zone.panel : null }
    }
    Item
    {
        id: body
        x: island.bodyRect.x; y: island.bodyRect.y
        width: island.bodyRect.width; height: island.bodyRect.height
        HoverHandler { id: hover; blocking: false }
    }
    BarZone
    {
        id: zone
        anchors.fill: parent
        side: island.side
        align: "center"
        alongStart: Math.max(0, island.center - islandAlong / 2)
        widgets: ["island"]
        adaptive: true
        animateWidgets: false
        attachedMenu: true
        thickness: Math.max(Theme.barThickness, contentThickness + 6)
        islandDepth: island.depth
        menuStartInset: island.menuStartInset
        menuEndInset: island.menuEndInset
        revealed: true
    }
}
