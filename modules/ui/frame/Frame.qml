pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../animations"
import "../../common"
import "../../core"
import "../../services"
import "../bar"
import "../dock"

FocusScope
{
    id: frame

    required property var screen
    property bool preview: false
    readonly property bool fullscreen: !preview && screen !== null && ServiceCompositor.fullscreenOnOutput(screen.name)
    property real frameReveal: fullscreen ? 0 : 1
    Glide on frameReveal {}
    readonly property var bar: barLoader.item
    readonly property var dock: dockLoader.item
    readonly property var island: bar?.island ?? null
    readonly property bool barEdgeOccupied: preview || shown("barScreens")
    readonly property bool islandHere: Config.islandEnabled && barEdgeOccupied
        && (preview || screen?.name === ServiceIsland.primaryOutput)
    readonly property real barDepth: Theme.barThickness + (Config.barAttach ? 0 : Theme.panelGap)
    readonly property bool menuHere: bar?.menuHere ?? false
    readonly property bool barRevealWanted: barEdgeOccupied && !fullscreen && (preview || !Config.barHideAuto || edgeHover.hovered
        || bar?.hoveringWidgets || island?.hoveringBody || menuHere
        || (Config.barHideSmart && ServiceCompositor.workspaceEmptyOnOutput(screen.name)))
    readonly property bool barRevealed: !fullscreen && barVisibility.revealed
    property real barReveal: barRevealed ? 1 : 0
    Glide on barReveal {}
    readonly property bool barInputActive: !fullscreen && barReveal > 0
    readonly property point barOffset:
    {
        const distance = Math.round((1 - barReveal) * (Theme.frameThickness + barDepth + 4));
        const side = Config.barSide;
        return Qt.point(side === Enums.EdgeLeft ? -distance : side === Enums.EdgeRight ? distance : 0,
            side === Enums.EdgeTop ? -distance : side === Enums.EdgeBottom ? distance : 0);
    }
    readonly property bool popupHere: popupSurface.children.some(item => item.visible)
    readonly property bool keyboardWanted: popupHere || (bar && bar.keyboardWanted) || (dock && dock.keyboardWanted) || false
    readonly property alias popupLayer: popupSurface
    readonly property alias inputRegion: inputMask
    readonly property alias surface: surface
    readonly property real layoutThickness: Math.max(0, Math.min(Theme.frameThickness, Math.min(width, height) / 4))
    readonly property real thickness: layoutThickness * frameReveal
    readonly property bool reserveDock: dock !== null && !Config.dockHideAuto
    // Fullscreen changes visibility, not the work area to which windows return.
    readonly property var reservations:
    {
        const edges = [layoutThickness, layoutThickness, layoutThickness, layoutThickness];
        if (barEdgeOccupied && !Config.barHideAuto) edges[Config.barSide] = layoutThickness + barDepth;
        if (reserveDock && dock && dock.container.visible)
            edges[Config.dockSide] = Math.max(edges[Config.dockSide], dock.thickness + dock.edgeGap);
        return edges.map(value => Math.ceil(value));
    }
    signal regionsChanged()

    function shown(key)
    {
        const selected = Config.screensShown(key);
        return screen && (selected.includes(screen.name) || !Quickshell.screens.some(output => selected.includes(output.name)));
    }
    function refreshRegions() { if (inputMask) inputMask.changed(); regionsChanged() }
    onBarOffsetChanged: refreshRegions()

    PanelReveal { id: barVisibility; wanted: frame.barRevealWanted; delay: Theme.barHideDelay }

    onFullscreenChanged:
    {
        if (!fullscreen) return;
        barVisibility.revealed = false;
        Qt.callLater(() => { if (fullscreen && menuHere) MenuState.close(); });
    }

    Keys.onEscapePressed:
    {
        MenuState.close();
        if (dock) dock.popupClose();
    }
    onKeyboardWantedChanged: if (keyboardWanted && !popupHere) forceActiveFocus()

    Region
    {
        id: inputMask
        regions: [dismissInput, popupInput, barEdgeInput, frame.barInputActive ? frame.bar?.inputRegion ?? null : null,
            frame.dock && !frame.fullscreen ? frame.dock.inputRegion : null].filter(region => region !== null)
    }
    Region { id: dismissInput; item: dismiss.visible ? dismiss : null }
    Region { id: popupInput; item: frame.popupHere ? popupSurface : null }
    Region { id: barEdgeInput; item: edgeTrigger.visible ? edgeTrigger : null }

    Item
    {
        id: edgeTrigger
        readonly property bool horizontal: Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom
        visible: frame.barEdgeOccupied && Config.barHideAuto && !frame.fullscreen
        width: horizontal ? frame.width : Theme.barReveal
        height: horizontal ? Theme.barReveal : frame.height
        x: Config.barSide === Enums.EdgeRight ? frame.width - width : 0
        y: Config.barSide === Enums.EdgeBottom ? frame.height - height : 0
        HoverHandler { id: edgeHover }
    }

    FrameSurface
    {
        id: surface
        anchors.fill: parent
        // Siblings after this item paint above the frame. Negative stacking can
        // disappear behind the transparent layer-shell surface on some backends.
        z: 0
        visible: frame.thickness > 0.001 || (frame.bar?.reveal ?? 0) > 0 || dockBody.width > 0
        materialEnabled: true
        thickness: frame.thickness
        startBody: frame.bar ? frame.bar.startBody : Qt.rect(0, 0, 0, 0)
        centerBody: frame.bar?.centerBody ?? Qt.rect(0, 0, 0, 0)
        endBody: frame.bar ? frame.bar.endBody : Qt.rect(0, 0, 0, 0)
        centerPanel: frame.bar?.centerPanel ?? Qt.rect(0, 0, 0, 0)
        dockBody: frame.dock ? frame.dock.bodyRect : Qt.rect(0, 0, 0, 0)
    }
    MouseArea
    {
        id: dismiss
        anchors.fill: parent
        visible: (frame.bar?.menuPanelVisible ?? false) || (frame.dock && frame.dock.keyboardWanted) || false
        acceptedButtons: Qt.AllButtons
        onClicked:
        {
            MenuState.close();
            if (frame.dock) frame.dock.popupClose();
        }
    }
    Loader
    {
        id: barLoader
        anchors.fill: parent
        active: frame.barEdgeOccupied
        sourceComponent: Bar
        {
            screen: frame.screen
            fullscreen: frame.fullscreen
            revealed: frame.barRevealed
            reveal: frame.barReveal
            offset: frame.barOffset
            hasIsland: frame.islandHere
        }
        onLoaded: frame.refreshRegions()
    }
    Loader
    {
        id: dockLoader
        anchors.fill: parent
        active: Config.dockType !== Enums.PanelDisabled && (frame.preview || frame.shown("dockScreens"))
        sourceComponent: Dock
        {
            screen: frame.screen
            preview: frame.preview
            barDepth: frame.barEdgeOccupied && side === Config.barSide ? frame.barDepth : 0
        }
        onLoaded: frame.refreshRegions()
    }
    Item { id: popupSurface; anchors.fill: parent; z: 1000 }

}
