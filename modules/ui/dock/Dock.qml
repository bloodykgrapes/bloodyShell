import QtQuick
import Quickshell

import "../../core"
import "../../services"
import "components"

Item
{
    id: dock

    required property var screen
    readonly property bool keyboardWanted: popup.mode === "menu"
    readonly property alias inputRegion: dockInput

    readonly property bool isHorizontal: Config.dockSide === Enums.EdgeTop || Config.dockSide === Enums.EdgeBottom
    readonly property int  side: Config.dockSide

    readonly property real  base: Config.dockIconSize
    readonly property real  thickness: base + Theme.dockPadding * 2
    readonly property alias container: content.container

    property bool barHere: Config.barEnabled && screen !== null && Config.screensShown("barScreens").indexOf(screen.name) >= 0
    readonly property bool barOnSide:  barHere && side === Config.barSide
    readonly property bool inFrame: Config.dockType === Enums.InFrame || filled
    readonly property bool islands: Config.dockType === Enums.Islands
    readonly property bool filled: Config.dockType === Enums.Filled
    readonly property real barDepth: barOnSide ? Theme.barThickness + Theme.frameThickness + (Config.barType === Enums.Islands ? 6 : 0) + 12 : 0
    readonly property real edgeGap: Math.max(Theme.frameThickness, barDepth) + (inFrame ? 0 : Theme.dockMargin)
    readonly property rect bodyRect:
    {
        if (!container.visible || !inFrame) return Qt.rect(0, 0, 0, 0);
        if (!filled) return Qt.rect(container.x, container.y, container.width, container.height);
        const r = Theme.barRadius;
        switch (side)
        {
            case Enums.EdgeTop: return Qt.rect(-r, -r, width + r * 2, Math.max(0, container.y + container.height + r));
            case Enums.EdgeBottom: return Qt.rect(-r, container.y, width + r * 2, Math.max(0, height - container.y + r));
            case Enums.EdgeLeft: return Qt.rect(-r, -r, Math.max(0, container.x + container.width + r), height + r * 2);
            default: return Qt.rect(container.x, -r, Math.max(0, width - container.x + r), height + r * 2);
        }
    }

    Region
    {
        id: dockInput
        Region { item: trigger }
        Region { item: hitArea }
        Region { item: popupMask }
    }

    readonly property bool revealWanted: !Config.dockHideAuto
        || triggerHover.hovered || dockHover.hovered || content.hovered || popup.hovered
        || content.view.dragActive || popup.mode === "menu"
        || (Config.dockHideSmart && ServiceCompositor.focusedWorkspaceEmpty)

    property bool revealed: true
    onRevealWantedChanged:
    {
        if (revealWanted) { hideDelay.stop(); revealed = true }
        else hideDelay.restart();
    }
    Timer { id: hideDelay; interval: Theme.dockHideDelay; onTriggered: dock.revealed = dock.revealWanted }

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => { dock.initialized = true; if (!dock.revealWanted) hideDelay.restart() })

    readonly property real zoomScale: 1.25

    readonly property real zoomOverflow: Math.ceil(10 + base * (zoomScale - 1))

    readonly property int separatorIndex: ServiceDock.model.count > ServiceDock.pinned.length ? ServiceDock.pinned.length : -1

    function separatorItem() { return separatorIndex >= 0 ? content.view.itemAtIndex(separatorIndex) : null }

    function pinnedBefore(coord)
    {
        let count = 0;
        for (let i = 0; i < ServiceDock.pinned.length; i++)
        {
            const it = content.view.itemAtIndex(i);
            if (it && (isHorizontal ? it.x + it.width / 2 : it.y + it.height / 2) < coord) count++;
        }
        return count;
    }

    readonly property int previewDelay: 350
    property var previewPending: null

    function previewEnter(item)
    {
        if (content.view.dragActive || popup.mode === "menu") return;
        previewHide.stop();

        if (popup.mode === "preview") { popup.target = item; return; }

        previewPending = item;
        previewShow.restart();
    }
    function previewLeave(item)
    {
        if (previewPending === item) { previewShow.stop(); previewPending = null; }
        if (popup.mode === "preview") previewHide.restart();
    }
    function menuOpen(item)
    {
        SidebarState.close();
        MenuState.close();
        previewShow.stop();
        previewHide.stop();
        popup.target = item;
        popup.mode = "menu";
    }
    function popupClose()
    {
        previewShow.stop();
        previewHide.stop();
        previewPending = null;
        popup.mode = "";
        popup.target = null;
    }

    Timer
    {
        id: previewShow
        interval: dock.previewDelay
        onTriggered:
        {
            if (dock.previewPending && dock.previewPending.containsMouse)
            {
                popup.target = dock.previewPending;
                popup.mode = "preview";
            }
            dock.previewPending = null;
        }
    }
    Timer
    {
        id: previewHide
        interval: 260
        onTriggered:
        {
            const over = popup.target && popup.target.containsMouse;
            if (popup.mode === "preview" && !popup.hovered && !over) dock.popupClose();
        }
    }
    Connections
    {
        target: popup
        function onHoveredChanged() { if (!popup.hovered && popup.mode === "preview") previewHide.restart() }
    }

    Connections
    {
        target: MenuState
        function onMenuActiveChanged() { if (MenuState.menuActive) dock.popupClose() }
    }
    Connections
    {
        target: OverlayState
        function onActiveChanged() { if (OverlayState.active) dock.popupClose() }
    }
    Connections
    {
        target: SidebarState
        function onActiveChanged() { if (SidebarState.active) dock.popupClose() }
    }

    Item
    {
        focus: true
        Keys.onEscapePressed: dock.popupClose()
    }

    Item
    {
        id: trigger

        x: dock.side === Enums.EdgeRight ? dock.width - width : 0
        y: dock.side === Enums.EdgeBottom ? dock.height - height : 0
        width:  dock.isHorizontal ? dock.width : Theme.dockReveal
        height: dock.isHorizontal ? Theme.dockReveal : dock.height

        HoverHandler { id: triggerHover }
    }

    Item
    {
        id: hitArea

        visible: content.container.visible

        x: dock.isHorizontal ? content.container.x : (dock.side === Enums.EdgeRight ? content.container.x - dock.zoomOverflow : content.container.x)
        y: dock.isHorizontal ? (dock.side === Enums.EdgeBottom ? content.container.y - dock.zoomOverflow : content.container.y) : content.container.y
        width: content.container.visible ? content.container.width + (dock.isHorizontal ? 0 : dock.zoomOverflow) : 0
        height: content.container.visible ? content.container.height + (dock.isHorizontal ? dock.zoomOverflow : 0) : 0

        HoverHandler { id: dockHover }
    }

    DockContent { id: content; anchors.fill: parent; host: dock }

    DockPopup
    {
        id: popup
        host: dock
    }

    Item
    {
        id: popupMask

        x: popup.x
        y: popup.y
        width: popup.visible ? popup.width : 0
        height: popup.visible ? popup.height : 0
    }
}
