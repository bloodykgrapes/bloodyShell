pragma ComponentBehavior: Bound

import QtQuick

import "../components"
import "../components/bar"
import "../core"

Item
{
    id: barZone

    readonly property bool isIsland: true
    readonly property bool animated: ready && Config.animationsEnabled

    property var    widgets: []
    property string align: "start"

    property bool docked: true
    property real thickness: Theme.barThickness
    property real band: thickness
    property real stripDepth: 0
    property real stripInset: 0
    readonly property bool stripFloats: docked && stripDepth > 0
    property real islandDepth: 0
    property real cornerInset: 0
    property bool revealed: true

    property real edgeMin: 0
    property real edgeMax: total
    property real snapMin: 0
    property real snapMax: total
    property bool extendSnapped: false

    property real smoothing: Theme.barRadius

    property alias panel: panel

    readonly property bool isHorizontal: Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom
    readonly property bool isBottom: Config.barSide === Enums.EdgeBottom
    readonly property bool isRight: Config.barSide === Enums.EdgeRight

    readonly property bool visibleMenu: MenuState.menuActive && MenuState.menuOwner === barZone && MenuState.menuCurrent !== ""

    readonly property real pad: Theme.barPadding
    readonly property real total: isHorizontal ? width : height

    function toRect(a0, a1, d0, d1)
    {
        switch (Config.barSide)
        {
            case 0:  return Qt.rect(a0, d0, a1 - a0, d1 - d0);
            case 1:  return Qt.rect(a0, height - d1, a1 - a0, d1 - d0);
            case 2:  return Qt.rect(d0, a0, d1 - d0, a1 - a0);
            default: return Qt.rect(width - d1, a0, d1 - d0, a1 - a0);
        }
    }
    function mix(a, b, t) { return a + (b - a) * t }
    function inset(lo, hi, by) { return hi - lo > by * 2 ? [lo + by, hi - by] : [(lo + hi) / 2, (lo + hi) / 2] }

    readonly property real rowAlong: isHorizontal ? row.width : row.height
    readonly property bool hasWidgets: rowAlong > 0.5

    readonly property real rowStart:
    {
        const lo = docked ? stripInset + pad : cornerInset + pad;
        const hi = docked ? total - stripInset - pad : total - cornerInset - pad;
        if (align === "start") return Math.round(lo);
        if (align === "end") return Math.round(hi - rowAlong);
        return Math.round((total - rowAlong) / 2);
    }
    readonly property real rowMid: rowStart + rowAlong / 2

    readonly property real rowCenter: docked ? band - thickness / 2 : islandDepth + thickness / 2

    readonly property real islandAlong: hasWidgets ? rowAlong + pad * 2 : 0
    readonly property real islandThick: thickness
    readonly property real islandA0: align === "start" ? cornerInset
                                   : align === "end" ? total - cornerInset - islandAlong
                                   : (total - islandAlong) / 2
    readonly property real islandA1: islandA0 + islandAlong
    readonly property rect islandRect: !docked && islandAlong > 0.5
        ? toRect(islandA0, islandA1, islandDepth, islandDepth + islandThick) : Qt.rect(0, 0, 0, 0)

    readonly property bool open: visibleMenu

    readonly property real wantAlong: visibleMenu ? (isHorizontal ? menu.contentWidth : menu.contentHeight) : 0
    readonly property real wantOut:   visibleMenu ? (isHorizontal ? menu.contentHeight : menu.contentWidth) : 0

    property real fullAlong: 0
    property real fullOut: 0

    property bool floating: false

    property real anchorCenter: 0

    function refreshPanel()
    {
        if (wantAlong > 0 && wantOut > 0)
        {
            fullAlong = wantAlong + (isHorizontal ? 20 : 0);
            fullOut = wantOut + (isHorizontal ? 0 : 20);
        }
        if (!open) return;

        floating = Config.barMenu === 1;

        const w = MenuState.menuWidget;
        if (w)
        {
            const p = w.mapToItem(barZone, w.width / 2, w.height / 2);
            anchorCenter = isHorizontal ? p.x : p.y;
        }
        else anchorCenter = hasWidgets ? rowMid : total / 2;
    }
    Connections
    {
        target: MenuState
        function onMenuWidgetChanged() { barZone.refreshPanel() }
    }

    readonly property real wantStart:
    {
        const ideal = anchorCenter - fullAlong / 2;

        if (floating)
        {
            const lo = extendSnapped ? snapMin + floatGap : edgeMin;
            const hi = extendSnapped ? snapMax - floatGap - fullAlong : edgeMax - fullAlong;
            return Math.round(Math.max(lo, Math.min(hi, ideal)));
        }

        const lo = edgeMin + smoothing;
        const hi = edgeMax - smoothing - fullAlong;

        if (ideal < lo) return snapMin;
        if (ideal > hi) return Math.round(snapMax - fullAlong);

        if (stripFloats || (!docked && hasWidgets))
        {
            const near = smoothing * 2;
            const a0 = stripFloats ? stripInset : islandA0;
            const a1 = stripFloats ? total - stripInset : islandA1;
            const start = Math.abs(ideal - a0) < near ? a0
                        : Math.abs(ideal + fullAlong - a1) < near ? a1 - fullAlong
                        : ideal;
            return Math.round(Math.max(lo, Math.min(hi, start)));
        }
        return Math.round(ideal);
    }
    property real panelStart: 0
    onWantStartChanged: if (open || panelOut < 1) panelStart = wantStart
    Glide on panelStart { enabled: barZone.animated && barZone.panelOut > 1 }
    onWantAlongChanged: refreshPanel()
    onWantOutChanged: refreshPanel()
    onOpenChanged: refreshPanel()

    property real panelAlong: fullAlong
    property real panelOut: open && wantOut > 0 ? fullOut : 0

    Glide on panelOut { enabled: barZone.animated }

    Glide on panelAlong { enabled: barZone.animated && barZone.panelOut > 1 }

    readonly property real progress: fullOut > 0 ? Math.max(0, Math.min(1, panelOut / fullOut)) : 0

    readonly property real baseOuter: docked ? band : hasWidgets ? islandDepth + islandThick : islandDepth

    readonly property real panelEnd: panelStart + panelAlong
    readonly property bool snappedStart: extendSnapped && !floating && panelStart <= snapMin + 0.5
    readonly property bool snappedEnd: extendSnapped && !floating && panelEnd >= snapMax - 0.5

    readonly property real baseA0: docked ? panelStart : Math.max(panelStart, hasWidgets ? islandA0 : anchorCenter)
    readonly property real baseA1: docked ? panelEnd   : Math.min(panelEnd,   hasWidgets ? islandA1 : anchorCenter)

    readonly property real floatGap: 10
    readonly property real floatSmoothing: floatGap / 2 - 1

    readonly property var closedAlong: inset(baseA0, Math.max(baseA0, baseA1), smoothing)
    readonly property var closedDepth: stripFloats ? inset(stripDepth, band, smoothing)
                                     : docked ? [-100, band - smoothing]
                                     : hasWidgets ? inset(islandDepth, islandDepth + islandThick, smoothing)
                                     : [islandDepth - smoothing, islandDepth]
    readonly property real openA0: snappedStart ? -100 : panelStart
    readonly property real openA1: snappedEnd ? total + 100 : panelEnd

    readonly property real openD0: floating ? baseOuter + floatGap : docked && !stripFloats ? -100 : baseOuter - 1
    readonly property real openD1: floating ? baseOuter + floatGap + fullOut : baseOuter + fullOut

    readonly property real shapeA0: mix(closedAlong[0], openA0, progress)
    readonly property real shapeA1: mix(closedAlong[1], openA1, progress)
    readonly property real shapeD0: mix(closedDepth[0], openD0, progress)
    readonly property real shapeD1: mix(closedDepth[1], openD1, progress)

    readonly property real visibleD0: floating ? Math.max(baseOuter, shapeD0) : baseOuter
    readonly property real depth: Math.max(0, shapeD1 - visibleD0)
    readonly property real visibleA0: mix(closedAlong[0], panelStart, progress)
    readonly property real visibleA1: mix(closedAlong[1], panelEnd, progress)

    readonly property rect blob: progress > 0 && panelAlong >= 1 ? toRect(shapeA0, shapeA1, shapeD0, shapeD1) : Qt.rect(0, 0, 0, 0)

    property bool ready: false

    Component.onCompleted: Qt.callLater(function() { barZone.ready = true })
    Component.onDestruction: if (MenuState.menuOwner === barZone) MenuState.close()

    WidgetRow
    {
        id: row

        vertical: !barZone.isHorizontal
        widgets: barZone.widgets
        compact: false
        animate: barZone.ready

        x: barZone.isHorizontal ? barZone.rowStart
            : Math.round(barZone.isRight ? barZone.width - barZone.rowCenter - width / 2 : barZone.rowCenter - width / 2)
        y: barZone.isHorizontal ? Math.round(barZone.isBottom ? barZone.height - barZone.rowCenter - height / 2 : barZone.rowCenter - height / 2)
            : barZone.rowStart

        property real revealFade: 1
        NumberAnimation on revealFade { id: hideFade; running: false; to: 0; duration: Config.animationsEnabled ? 140 : 0; easing.type: Easing.OutCubic }

        opacity: revealFade
    }
    onRevealedChanged:
    {
        hideFade.stop();
        if (revealed) row.revealFade = 1;
        else hideFade.start();
    }

    Item
    {
        id: panel

        readonly property rect area: barZone.toRect(barZone.visibleA0, Math.max(barZone.visibleA0, barZone.visibleA1), barZone.visibleD0, barZone.visibleD0 + barZone.depth)

        x: area.x
        y: area.y
        width: area.width
        height: area.height
        visible: barZone.depth > 1 && width > 1 && height > 1

        clip: true

        MouseArea { anchors.fill: parent }

        readonly property real alongStart: barZone.visibleA0
        readonly property real alongSize: Math.max(0, barZone.visibleA1 - barZone.visibleA0)

        BarMenu
        {
            id: menu

            width: panel.width
            height: panel.height

            origin: panel.alongStart
            center: panel.alongStart + panel.alongSize / 2

            active: barZone.visibleMenu
            menu: MenuState.menuCurrent
        }
    }
}
