pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../core"
import "../bar"
import "../dock"
import "../osd"
import "../sidebars/left"
import "../sidebars/right"

FocusScope
{
    id: frame

    required property var screen
    readonly property var bar: barLoader.item
    readonly property var dock: dockLoader.item
    readonly property var island: islandLoader.item
    readonly property bool regularBar: Config.barEnabled && shown("barScreens")
    readonly property bool sidebarHere: screen && SidebarState.onOutput(screen.name)
    readonly property bool menuHere: (bar && bar.menuHere) || (island && island.menuHere) || false
    readonly property bool keyboardWanted: sidebarHere || (bar && bar.keyboardWanted) || (dock && dock.keyboardWanted) || (island && island.keyboardWanted) || false
    readonly property alias inputRegion: inputMask
    readonly property alias surface: surface
    readonly property alias leftSidebar: leftView
    readonly property alias rightSidebar: rightView
    readonly property real thickness: Math.max(0, Math.min(Theme.frameThickness, Math.min(width, height) / 4))
    readonly property bool reserveBar: regularBar && !Config.barHideAuto
    readonly property bool reserveDock: dock !== null && !Config.dockHideAuto
    readonly property var reservations:
    {
        const edges = [thickness, thickness, thickness, thickness];
        if (reserveBar && bar) edges[Config.barSide] = Math.max(edges[Config.barSide], bar.reserve);
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
    readonly property var bodyRects: mergedBodies()

    function mergedBodies()
    {
        const empty = Qt.rect(0, 0, 0, 0);
        const bodies = [
            { rect: bar && bar.inFrame ? bar.bodyRect(0) : empty, side: Config.barSide, filled: bar ? bar.filled : false },
            { rect: island ? island.bodyRect : empty, side: Config.barSide, filled: false },
            { rect: bar && bar.inFrame ? bar.bodyRect(2) : empty, side: Config.barSide, filled: bar ? bar.filled : false },
            { rect: dock ? dock.bodyRect : empty, side: Config.dockSide, filled: dock ? dock.filled : false }
        ];
        function covers(outer, inner)
        {
            return outer.width > 0 && outer.height > 0
                && Math.max(0, outer.x) <= Math.max(0, inner.x) + 0.01
                && Math.max(0, outer.y) <= Math.max(0, inner.y) + 0.01
                && Math.min(frame.width, outer.x + outer.width) >= Math.min(frame.width, inner.x + inner.width) - 0.01
                && Math.min(frame.height, outer.y + outer.height) >= Math.min(frame.height, inner.y + inner.height) - 0.01;
        }
        return bodies.map((body, index) =>
        {
            if (body.rect.width <= 0 || body.rect.height <= 0) return empty;
            const covered = bodies.some((other, otherIndex) => otherIndex !== index && other.filled && other.side === body.side
                && covers(other.rect, body.rect) && (!body.filled || !covers(body.rect, other.rect) || otherIndex < index));
            return covered ? empty : body.rect;
        });
    }

    function panel(index) { return bar ? bar.panelRect(index) : Qt.rect(0, 0, 0, 0) }
    function refreshRegions() { inputMask.changed(); regionsChanged() }

    Keys.onEscapePressed:
    {
        SidebarState.close();
        MenuState.close();
        if (dock) dock.popupClose();
    }
    onKeyboardWantedChanged: if (keyboardWanted) forceActiveFocus()

    Region
    {
        id: inputMask
        regions: [dismissInput, frame.bar ? frame.bar.inputRegion : null, frame.dock ? frame.dock.inputRegion : null, frame.island ? frame.island.inputRegion : null,
            leftView.inputRegion, rightView.inputRegion].filter(region => region !== null)
    }
    Region { id: dismissInput; item: dismiss.visible ? dismiss : null }

    FrameSurface
    {
        id: surface
        anchors.fill: parent
        z: -1
        thickness: frame.thickness
        startBody: frame.bodyRects[0]
        centerBody: frame.bodyRects[1]
        endBody: frame.bodyRects[2]
        startPanel: frame.panel(0)
        centerPanel: frame.island ? frame.island.panelRect : Qt.rect(0, 0, 0, 0)
        endPanel: frame.panel(2)
        dockBody: frame.bodyRects[3]
        leftBody: leftView.bodyRect
        rightBody: rightView.bodyRect
    }
    MouseArea
    {
        id: dismiss
        anchors.fill: parent
        visible: frame.sidebarHere || frame.menuHere || (frame.dock && frame.dock.keyboardWanted) || false
        acceptedButtons: Qt.AllButtons
        onClicked:
        {
            SidebarState.close();
            MenuState.close();
            if (frame.dock) frame.dock.popupClose();
        }
    }
    Loader
    {
        id: barLoader
        anchors.fill: parent
        active: frame.regularBar
        sourceComponent: Bar { screen: frame.screen }
        onLoaded: frame.refreshRegions()
    }
    Loader
    {
        id: dockLoader
        anchors.fill: parent
        active: Config.dockEnabled && frame.shown("dockScreens")
        sourceComponent: Dock { screen: frame.screen; barHere: frame.regularBar }
        onLoaded: frame.refreshRegions()
    }
    Loader
    {
        id: islandLoader
        anchors.fill: parent
        active: Config.islandEnabled
        sourceComponent: OSD
        {
            screen: frame.screen
            centerLimit: frame.bar ? frame.bar.centerLimit
                : Math.max(32, (side === Enums.EdgeTop || side === Enums.EdgeBottom ? frame.width : frame.height) - Theme.frameThickness * 2 - 32)
        }
    }
    LeftSidebar
    {
        id: leftView
        anchors.fill: parent
        screen: frame.screen
        barSide: frame.bar ? Config.barSide : -1
        barThickness: frame.bar ? frame.bar.thickness + frame.bar.surfaceGap : 0
    }
    RightSidebar
    {
        id: rightView
        anchors.fill: parent
        screen: frame.screen
        barSide: leftView.barSide
        barThickness: leftView.barThickness
    }

    Connections { target: frame.bar; function onRegionsChanged() { frame.refreshRegions() } }
}
