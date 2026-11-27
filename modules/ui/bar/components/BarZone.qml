pragma ComponentBehavior: Bound

import QtQuick

import "../../../animations"
import "../../../common"
import "../../../core"

Item
{
    id: barZone

    readonly property bool isIsland: true
    readonly property bool animated: ready && Config.animationsEnabled

    property int side: Config.barSide
    property var    widgets: []
    property string align: "start"
    property real alongStart: -1

    property bool adaptive: false
    property bool compact: false
    property bool attachedMenu: false
    property bool animateWidgets: true
    readonly property real contentThickness: row.slots.reduce((thickness, slot) => Math.max(thickness, slot && slot.shown ? slot.crossSize : 0), 0)
    readonly property Item singleWidget: row.slots.length === 1 && row.slots[0] ? row.slots[0].widget : null
    property real thickness: Theme.barThickness
    property real islandDepth: 0
    property real cornerInset: 0
    property bool revealed: true
    property alias panel: panel
    readonly property alias widgetArea: row
    readonly property bool hoveringWidgets: widgetHover.hovered

    readonly property bool isHorizontal: barZone.side === Enums.EdgeTop || barZone.side === Enums.EdgeBottom
    readonly property bool isBottom: barZone.side === Enums.EdgeBottom
    readonly property bool isRight: barZone.side === Enums.EdgeRight

    readonly property bool visibleMenu: MenuState.menuActive && MenuState.menuOwner === barZone && MenuState.menuCurrent !== ""

    readonly property real pad: Theme.barPadding
    property real bodyPadding: Theme.barPadding
    readonly property real total: isHorizontal ? width : height
    readonly property real edgeInset: Theme.frameThickness + Theme.panelGap
    property real menuStartInset: edgeInset
    property real menuEndInset: edgeInset
    readonly property real horizontalPadding: isHorizontal ? Theme.menuPadding * 2 : 0
    readonly property real availableAlong: Math.max(0, total - menuStartInset - menuEndInset)
    readonly property real availableDepth: Math.max(0, (isHorizontal ? height : width) - edgeInset
        - menuNear)

    function toRect(a0, a1, d0, d1)
    {
        switch (barZone.side)
        {
            case 0:  return Qt.rect(a0, d0, a1 - a0, d1 - d0);
            case 1:  return Qt.rect(a0, height - d1, a1 - a0, d1 - d0);
            case 2:  return Qt.rect(d0, a0, d1 - d0, a1 - a0);
            default: return Qt.rect(width - d1, a0, d1 - d0, a1 - a0);
        }
    }
    function mix(a, b, t) { return a + (b - a) * t }

    readonly property real rowAlong: isHorizontal ? row.width : row.height
    readonly property bool hasWidgets: rowAlong > 0.5

    readonly property real rowStart:
    {
        if (alongStart >= 0) return Math.round(alongStart + (islandAlong - rowAlong) / 2);
        const lo = cornerInset + pad;
        const hi = total - cornerInset - pad;
        if (align === "start") return Math.round(lo);
        if (align === "end") return Math.round(hi - rowAlong);
        return Math.round((total - rowAlong) / 2);
    }
    readonly property real rowMid: rowStart + rowAlong / 2

    readonly property real rowCenter: islandDepth + thickness / 2

    readonly property real islandAlong: hasWidgets ? rowAlong + bodyPadding * 2 * (adaptive ? Math.min(1, thickness / Theme.barThickness) : 1) : 0
    readonly property real islandThick: thickness
    readonly property real islandA0: alongStart >= 0 ? alongStart : align === "start" ? cornerInset
                                   : align === "end" ? total - cornerInset - islandAlong
                                   : (total - islandAlong) / 2
    readonly property real islandA1: islandA0 + islandAlong
    readonly property rect islandRect: islandAlong > 0.5
        ? toRect(islandA0, islandA1, islandDepth, islandDepth + islandThick) : Qt.rect(0, 0, 0, 0)

    readonly property bool open: visibleMenu

    readonly property real wantAlong: visibleMenu ? (isHorizontal ? menu.contentWidth : menu.contentHeight) : 0
    readonly property real wantOut:   visibleMenu ? (isHorizontal ? menu.contentHeight : menu.contentWidth) : 0

    property real fullAlong: 0
    property real fullOut: 0

    readonly property real anchorCenter:
    {
        const widget = open ? MenuState.menuWidget : null;
        if (!widget) return hasWidgets ? rowMid : total / 2;
        if (row.slots.length === 1 && row.slots[0]?.widget === widget)
            return rowMid;

        // Read the ancestors' animated geometry as well as the trigger itself.
        // mapToItem alone does not make those coordinates binding dependencies.
        let node = widget;
        while (node && node !== barZone)
        {
            const geometry = [node.x, node.y, node.width, node.height];
            if (node instanceof WidgetSlot && node.widget === widget)
            {
                const rect = node.contentRect;
                return isHorizontal ? row.x + node.x + rect.x + rect.width / 2
                                    : row.y + node.y + rect.y + rect.height / 2;
            }
            node = node.parent;
        }
        const point = widget.mapToItem(barZone, widget.width / 2, widget.height / 2);
        return isHorizontal ? point.x : point.y;
    }

    property bool panelMeasured: false

    function refreshPanelSize()
    {
        if (wantAlong > 0 && wantOut > 0)
        {
            fullAlong = wantAlong + horizontalPadding;
            fullOut = wantOut;
        }
        Qt.callLater(syncPanelAnchor);
    }

    function fitStart(start, span) { return Math.max(menuStartInset, Math.min(total - menuEndInset - span, start)) }

    readonly property real wantStart: fitStart(anchorCenter - fullAlong / 2, fullAlong)
    property real panelStart: 0
    property real panelAnchor: 0
    function syncPanelAnchor()
    {
        if (!open || wantAlong <= 0 || wantOut <= 0)
        {
            panelMeasured = false;
            return;
        }
        panelAnchor = anchorCenter;
        panelStart = wantStart;
        panelMeasured = true;
    }
    // Bubble positions depend on the expanding Island. Resolve the anchor
    // after the geometry bindings have settled, outside their change handlers.
    onWantStartChanged: if (open) Qt.callLater(syncPanelAnchor)
    onAnchorCenterChanged: if (open) Qt.callLater(syncPanelAnchor)
    Glide on panelStart { enabled: barZone.animated && barZone.progress > 0.001 && (barZone.isHorizontal || !menu.contentAnimatesHeight) }
    onWantAlongChanged: refreshPanelSize()
    onWantOutChanged: refreshPanelSize()
    onOpenChanged:
    {
        if (!open) panelMeasured = false;
        else refreshPanelSize();
    }

    property real panelAlong: fullAlong
    property real panelOut: fullOut

    // An inline expansion already changes the content height on every animation frame.
    Glide on panelOut { enabled: barZone.animated && barZone.progress > 0.001 && (!barZone.isHorizontal || !menu.contentAnimatesHeight) }

    Glide on panelAlong { enabled: barZone.animated && barZone.progress > 0.001 && (barZone.isHorizontal || !menu.contentAnimatesHeight) }

    readonly property real progress: reveal.progress

    EdgeReveal
    {
        id: reveal
        opened: barZone.open && barZone.panelMeasured
        animated: barZone.animated
    }

    readonly property real baseOuter: islandDepth + thickness
    readonly property real menuNear: baseOuter + (attachedMenu ? 0 : Theme.panelGap)
    readonly property real menuDepth: Math.min(panelOut, availableDepth) * progress
    readonly property real panelSpan: Math.min(panelAlong, availableAlong)
    readonly property real fittedStart: fitStart(panelStart, panelSpan)
    readonly property real panelEnd: fittedStart + panelSpan
    readonly property real contentSpan: Math.min(fullAlong, availableAlong)
    readonly property real contentCenter: fitStart(wantStart, contentSpan) + contentSpan / 2
    readonly property real anchorStart: attachedMenu ? Math.max(islandA0, Math.min(islandA1, fittedStart))
        : Math.min(panelEnd, Math.max(fittedStart, panelAnchor - pad))
    readonly property real anchorEnd: attachedMenu ? Math.max(anchorStart, Math.min(islandA1, panelEnd))
        : Math.max(anchorStart, Math.min(panelEnd, panelAnchor + pad))
    readonly property real visibleA0: mix(anchorStart, fittedStart, progress)
    readonly property real visibleA1: mix(anchorEnd, panelEnd, progress)
    // The surface grows from the compact body. Menu content starts below the clock.
    readonly property rect attachedMenuRect: attachedMenu && progress > 0 && visibleA1 > visibleA0 && menuDepth > 0
        ? toRect(visibleA0, visibleA1, islandDepth, menuNear + menuDepth) : Qt.rect(0, 0, 0, 0)

    property bool ready: false

    Component.onCompleted: Qt.callLater(function() { barZone.ready = true })
    Component.onDestruction: if (MenuState.menuOwner === barZone) MenuState.close()

    WidgetRow
    {
        id: row

        side: barZone.side
        vertical: !barZone.isHorizontal
        expandCross: barZone.adaptive || !Config.barAttach
        widgets: barZone.widgets
        compact: barZone.compact
        animate: barZone.ready && barZone.animateWidgets

        x: barZone.isHorizontal ? barZone.rowStart
            : Math.round(barZone.isRight ? barZone.width - barZone.rowCenter - width / 2 : barZone.rowCenter - width / 2)
        y: barZone.isHorizontal ? Math.round(barZone.isBottom ? barZone.height - barZone.rowCenter - height / 2 : barZone.rowCenter - height / 2)
            : barZone.rowStart

        property real revealFade: 1
        NumberAnimation on revealFade { id: hideFade; running: false; to: 0; duration: Config.animationsEnabled ? 140 : 0; easing.type: Easing.OutCubic }

        opacity: revealFade
        HoverHandler { id: widgetHover; blocking: false }
    }
    onRevealedChanged:
    {
        hideFade.stop();
        if (revealed) row.revealFade = 1;
        else hideFade.start();
    }

    FloatingPanelSurface
    {
        anchors.fill: panel
        z: -1
        visible: !barZone.attachedMenu && panel.visible
        reveal: barZone.progress
    }

    Item
    {
        id: panel

        readonly property rect area: barZone.toRect(barZone.visibleA0, barZone.visibleA1, barZone.menuNear, barZone.menuNear + barZone.menuDepth)

        x: area.x
        y: area.y
        width: area.width
        height: area.height
        visible: width > 1 && height > 1
        enabled: barZone.open

        clip: true

        MouseArea { anchors.fill: parent }

        readonly property real alongStart: barZone.visibleA0
        readonly property real alongSize: Math.max(0, barZone.visibleA1 - barZone.visibleA0)

        BarMenu
        {
            id: menu

            width: panel.width
            height: panel.height
            maximumWidth: barZone.isHorizontal ? Math.max(0, barZone.availableAlong - barZone.horizontalPadding) : barZone.availableDepth
            maximumHeight: barZone.isHorizontal ? barZone.availableDepth : barZone.availableAlong

            side: barZone.side
            origin: barZone.attachedMenu ? (barZone.isHorizontal ? panel.x : panel.y) : panel.alongStart
            // Reveal the Island over content already centered in its open bounds.
            center: barZone.attachedMenu ? barZone.contentCenter : panel.alongStart + panel.alongSize / 2

            active: barZone.visibleMenu
            menu: MenuState.menuCurrent
            revealOpacity: reveal.contentOpacity
        }
    }
}
