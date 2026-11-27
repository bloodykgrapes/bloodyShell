pragma ComponentBehavior: Bound

import QtQuick

import "../../core"
import "components"

Item
{
    id: content

    required property var host
    readonly property alias startPanel: start.panel
    readonly property alias endPanel: end.panel
    readonly property alias startWidgets: start.widgetArea
    readonly property alias endWidgets: end.widgetArea
    readonly property alias island: islandLoader.item
    readonly property bool hoveringWidgets: start.hoveringWidgets || end.hoveringWidgets

    readonly property rect startBody: zoneBody(start, true)
    readonly property rect endBody: zoneBody(end, false)
    readonly property real total: host.isHorizontal ? width : height
    readonly property real cornerInset: host.depth + (clustered ? Theme.barPadding : 0)
    readonly property real gap: Theme.panelGap
    readonly property int style: Config.barType
    readonly property bool clustered: Registry.usesStatusBubbles(style)
    readonly property bool leading: style === Enums.BarLeft
    readonly property bool trailing: style === Enums.BarRight
    readonly property real islandSpan: island ? Math.max(0, island.span) : 0
    readonly property rect menuBody: island?.panelRect ?? Qt.rect(0, 0, 0, 0)
    readonly property bool menuExpanded: menuBody.width > 0 && menuBody.height > 0
    readonly property real menuStart: host.isHorizontal ? menuBody.x : menuBody.y
    readonly property real menuEnd: menuStart + (host.isHorizontal ? menuBody.width : menuBody.height)
    readonly property real islandOuterStart: Math.min(islandCenter - islandSpan / 2, menuExpanded ? menuStart : total)
    readonly property real islandOuterEnd: Math.max(islandCenter + islandSpan / 2, menuExpanded ? menuEnd : 0)
    readonly property real clusterGap: islandSpan > 0 ? gap : gap / 2
    readonly property real menuInset: Theme.frameThickness + gap
    readonly property real sideSpace: leading || trailing ? start.islandAlong + end.islandAlong + 2 * gap
        : Math.max(start.islandAlong, end.islandAlong) + gap
    readonly property real centerLimit: Math.max(32, total - 2 * cornerInset - 2 * gap
        - (leading || trailing ? start.islandAlong + end.islandAlong : 2 * Math.max(start.islandAlong, end.islandAlong)))
    readonly property real islandCenter: leading ? cornerInset + islandSpan / 2
        : trailing ? total - cornerInset - islandSpan / 2 : total / 2
    readonly property real startPosition: leading ? islandOuterEnd + clusterGap
        : trailing ? islandOuterStart - clusterGap - end.islandAlong - gap - start.islandAlong
        : islandOuterStart - clusterGap - start.islandAlong
    readonly property real endPosition: leading ? startPosition + start.islandAlong + gap
        : trailing ? islandOuterStart - clusterGap - end.islandAlong : islandOuterEnd + clusterGap

    function zoneBody(zone, first)
    {
        if (clustered || !zone.hasWidgets) return Qt.rect(0, 0, 0, 0);
        if (!Config.barAttach || style !== Enums.BarWaves) return zone.islandRect;
        return zone.toRect(first ? 0 : zone.islandA0, first ? zone.islandA1 : total,
            zone.islandDepth, zone.baseOuter);
    }

    onClusteredChanged:
    {
        if (MenuState.menuActive && (MenuState.menuOwner === start || MenuState.menuOwner === end))
            MenuState.close();
    }

    component Zone: BarZone
    {
        anchors.fill: parent
        compact: content.total < 720
        bodyPadding: content.clustered ? 0 : Theme.barPadding
        thickness: content.host.thickness
        islandDepth: content.host.depth
        cornerInset: content.cornerInset
        revealed: content.host.revealed
    }

    Zone
    {
        id: start
        align: "start"
        alongStart: content.clustered ? Math.max(content.cornerInset, content.startPosition) : -1
        widgets: content.clustered
            ? (content.host.hasIsland ? ["media", "tray", "keyboard"] : ["tray", "statusConnections"])
            : ["workspaces", "window"]
    }
    Zone
    {
        id: end
        align: "end"
        alongStart: content.clustered ? Math.min(content.endPosition, content.total - content.cornerInset - islandAlong) : -1
        widgets: content.clustered
            ? (content.host.hasIsland ? ["volume", "network", "bluetooth"] : ["statusSystem", "clock", "update"])
            : (content.host.hasIsland ? ["tray", "status", "update"] : ["tray", "status", "clock", "update"])
    }

    Loader
    {
        id: islandLoader
        anchors.fill: parent
        active: content.host.hasIsland
        sourceComponent: Island
        {
            screen: content.host.screen
            centerLimit: content.centerLimit
            center: content.islandCenter
            depth: content.host.depth
            flushStart: Config.barAttach && content.leading
            flushEnd: Config.barAttach && content.trailing
            menuStartInset: content.menuInset + (content.clustered && !content.leading ? content.sideSpace : 0)
            menuEndInset: content.menuInset + (content.clustered && !content.trailing ? content.sideSpace : 0)
        }
    }
}
