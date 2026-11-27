import QtQuick
import Quickshell

import "../../common"
import "../../core"
import "../../services"
import "components"

Item
{
    id: dock

    required property var screen
    property bool preview: false
    readonly property bool keyboardWanted: popup.mode === "menu"
    readonly property alias inputRegion: dockInput

    readonly property bool isHorizontal: Config.dockSide === Enums.EdgeTop || Config.dockSide === Enums.EdgeBottom
    readonly property int  side: Config.dockSide

    readonly property real  base: Config.dockIconSize
    readonly property real  thickness: base + Theme.dockPadding * 2
    readonly property alias container: content.container

    property real barDepth: 0
    readonly property bool attached: Config.dockAttach
    readonly property real edgeGap: Theme.frameThickness + (barDepth > 0 || !attached ? barDepth + Theme.panelGap : 0)
    readonly property rect bodyRect:
    {
        if (!attached || !container.visible || container.reveal <= 0) return Qt.rect(0, 0, 0, 0);
        const x = container.x, y = container.y;
        const w = container.width, h = container.height;
        // Reach back to the frame even when the icons are offset to clear the bar.
        const offset = edgeGap - Theme.frameThickness;
        const bridge = Math.max(0, offset - container.slide);
        if (side === Enums.EdgeTop) return Qt.rect(x, y - bridge, w, h + bridge);
        if (side === Enums.EdgeBottom) return Qt.rect(x, y, w, h + bridge);
        if (side === Enums.EdgeLeft) return Qt.rect(x - bridge, y, w + bridge, h);
        return Qt.rect(x, y, w + bridge, h);
    }

    Region
    {
        id: dockInput
        Region { item: trigger }
        Region { item: hitArea }
        Region { item: popupMask }
    }

    readonly property bool fullscreen: !preview && screen !== null && ServiceCompositor.fullscreenOnOutput(screen.name)
    readonly property bool autoHide: Config.dockHideAuto || fullscreen
    readonly property bool revealWanted: !fullscreen && (preview || !autoHide
        || triggerHover.hovered || dockHover.hovered || content.hovered || popup.hovered
        || content.view.dragActive || popup.mode === "menu"
        || (Config.dockHideSmart && screen !== null && ServiceCompositor.workspaceEmptyOnOutput(screen.name)))
    enabled: !fullscreen
    onFullscreenChanged: if (fullscreen) Qt.callLater(() => { if (dock.fullscreen) dock.popupClose(); })

    property alias revealed: visibility.revealed
    PanelReveal
    {
        id: visibility
        wanted: dock.revealWanted
        ready: dock.initialized
        delay: Theme.dockHideDelay
    }

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => dock.initialized = true)

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
    Item
    {
        focus: true
        Keys.onEscapePressed: dock.popupClose()
    }

    Item
    {
        id: trigger

        readonly property real size: dock.fullscreen ? 0 : Theme.dockReveal
        x: dock.side === Enums.EdgeRight ? dock.width - width : 0
        y: dock.side === Enums.EdgeBottom ? dock.height - height : 0
        width:  dock.isHorizontal ? dock.width : size
        height: dock.isHorizontal ? size : dock.height

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
        width: popup.open ? popup.width : 0
        height: popup.open ? popup.height : 0
    }
}
