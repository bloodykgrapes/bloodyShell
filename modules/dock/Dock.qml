import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "../components"
import "../components/dock"
import "../core"
import "../services"

PanelWindow
{
    id: dock

    required property var modelData
    screen: modelData

    readonly property bool isHorizontal: Config.dockSide === Enums.EdgeTop || Config.dockSide === Enums.EdgeBottom
    readonly property int  side: Config.dockSide

    readonly property real  base: Config.dockIconSize
    readonly property real  thickness: base + Theme.dockPadding * 2
    readonly property alias container: content.container

    readonly property bool barHere:    Config.barEnabled && screen !== null && Config.screensShown("barScreens").indexOf(screen.name) >= 0
    readonly property bool barOnSide:  barHere && side === Config.barSide
    readonly property bool onStrip:    barOnSide && Config.barType <= Enums.BarFrame
    readonly property bool onFloating: barOnSide && Config.barType === Enums.BarFloating
    readonly property bool onFrame:    barHere && !barOnSide && Config.barType === Enums.BarFrame
    readonly property real barDepth:   !barOnSide ? 0 : Config.barType <= Enums.BarFrame ? Theme.barThickness : Theme.barMargin + Theme.barThickness

    readonly property bool attached:       Config.dockType === Enums.DockAttached && !(barOnSide && Config.barType === Enums.BarIslands)
    readonly property bool framed:         attached && onFrame
    readonly property real frameThickness: onFrame ? Theme.barFrameThickness : 0

    readonly property real ground:  !attached ? 0 : onStrip || onFloating ? barDepth : framed ? frameThickness : 0
    readonly property real attach:  ground > 0 ? ground - 2 : 0
    readonly property real edgeGap: attached ? attach : Math.max(barDepth, frameThickness) + Theme.dockMargin

    function edgeRect(a0, a1, d0, d1)
    {
        switch (side)
        {
            case 0:  return Qt.rect(a0, d0, a1 - a0, d1 - d0);
            case 1:  return Qt.rect(a0, height - d1, a1 - a0, d1 - d0);
            case 2:  return Qt.rect(d0, a0, d1 - d0, a1 - a0);
            default: return Qt.rect(width - d1, a0, d1 - d0, a1 - a0);
        }
    }

    readonly property rect barArea: !attached || !barOnSide ? Qt.rect(0, 0, 0, 0)
                                  : onFloating ? edgeRect(Theme.barMargin, (isHorizontal ? width : height) - Theme.barMargin, Theme.barMargin, barDepth)
                                  : edgeRect(-100, (isHorizontal ? width : height) + 100, -100, ground)

    anchors
    {
        top: side !== Enums.EdgeBottom
        left: side !== Enums.EdgeRight
        right: side !== Enums.EdgeLeft
        bottom: side !== Enums.EdgeTop
    }
    implicitHeight: isHorizontal ? (screen ? screen.height : 1000) : 0
    implicitWidth:  isHorizontal ? 0 : (screen ? screen.width : 1000)

    color: "transparent"
    aboveWindows: true

    exclusionMode: ExclusionMode.Ignore

    PanelWindow
    {
        screen: dock.screen
        visible: !Config.dockHideAuto
        color: "transparent"
        mask: Region { }

        anchors.top: dock.side === Enums.EdgeTop
        anchors.bottom: dock.side === Enums.EdgeBottom
        anchors.left: dock.side === Enums.EdgeLeft
        anchors.right: dock.side === Enums.EdgeRight

        implicitWidth: 1
        implicitHeight: 1

        exclusiveZone: dock.attached ? Math.max(0, dock.thickness + dock.attach - dock.ground) : dock.thickness + Theme.dockMargin
    }

    WlrLayershell.keyboardFocus: popup.mode === "menu" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region
    {
        Region { item: trigger }
        Region { item: hitArea }
        Region { item: popupMask }
        Region { item: dismiss }
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

    MouseArea
    {
        id: dismiss

        width: popup.mode === "menu" ? dock.width : 0
        height: popup.mode === "menu" ? dock.height : 0
        onClicked: dock.popupClose()
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

        x: dock.isHorizontal ? content.container.x : (dock.side === Enums.EdgeRight ? content.container.x - dock.zoomOverflow : content.container.x)
        y: dock.isHorizontal ? (dock.side === Enums.EdgeBottom ? content.container.y - dock.zoomOverflow : content.container.y) : content.container.y
        width:  content.container.width  + (dock.isHorizontal ? 0 : dock.zoomOverflow)
        height: content.container.height + (dock.isHorizontal ? dock.zoomOverflow : 0)

        HoverHandler { id: dockHover }
    }

    BackgroundEffect.blurRegion: Theme.blur && content.container.visible ? content.glass : null

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
