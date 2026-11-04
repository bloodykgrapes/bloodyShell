pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../core"
import "../services"

PanelWindow
{
    id: bar

    required property var modelData
    screen: modelData

    anchors
    {
        top:    Config.barSide !== Enums.EdgeBottom
        left:   Config.barSide !== Enums.EdgeRight
        right:  Config.barSide !== Enums.EdgeLeft
        bottom: Config.barSide !== Enums.EdgeTop
    }
    implicitHeight: isHorizontal ? (screen ? screen.height : 0) : 0
    implicitWidth:  isHorizontal ? 0 : (screen ? screen.width : 0)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: menuHere && MenuState.menuKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool isHorizontal: Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom
    readonly property real thickness:    Theme.barThickness

    readonly property bool docked:   Config.barType === Enums.BarDefault || Config.barType === Enums.BarFrame
    readonly property bool frame:    Config.barType === Enums.BarFrame
    readonly property bool floating: Config.barType === Enums.BarFloating
    readonly property bool islands:  Config.barType === Enums.BarIslands

    readonly property real frameThickness: frame ? Theme.barFrameThickness : 0
    readonly property real frameRadius:    frame ? Theme.barFrameRadius : 0

    readonly property real reserve: docked ? thickness : Theme.barMargin + thickness

    readonly property bool menuHere: MenuState.menuActive && owns(MenuState.menuOwner)

    readonly property bool revealWanted: !Config.barHideAuto || hover.hovered || triggerHover.hovered || menuHere
                                         || (Config.barHideSmart && ServiceCompositor.focusedWorkspaceEmpty)
    property bool revealed: true
    property real reveal: revealed ? 1 : 0
    Glide on reveal {}

    onRevealWantedChanged:
    {
        if (revealWanted) { hideDelay.stop(); revealed = true }
        else hideDelay.restart();
    }
    Component.onCompleted: if (!revealWanted) hideDelay.restart()
    Timer { id: hideDelay; interval: Theme.barHideDelay; onTriggered: bar.revealed = bar.revealWanted }

    readonly property bool slides: !frame
    readonly property real slide:  slides ? (1 - reveal) * (reserve + 4) : 0

    function owns(item)
    {
        for (let p = item; p; p = p.parent) if (p === stage) return true;
        return false;
    }

    component EdgeReserve: PanelWindow
    {
        required property int edge
        readonly property real zone: edge !== Config.barSide || Config.barHideAuto ? bar.frameThickness : bar.reserve

        screen: bar.screen
        visible: zone > 0
        color: "transparent"
        mask: Region { }

        anchors.top:    edge === 0
        anchors.bottom: edge === 1
        anchors.left:   edge === 2
        anchors.right:  edge === 3

        implicitWidth: 1
        implicitHeight: 1
        exclusiveZone: zone
    }

    EdgeReserve { edge: 0 }
    EdgeReserve { edge: 1 }
    EdgeReserve { edge: 2 }
    EdgeReserve { edge: 3 }

    mask: Region
    {
        Region { item: content.strip }
        Region { item: content.island0 }
        Region { item: content.island1 }
        Region { item: content.island2 }
        Region { item: content.panel0 }
        Region { item: content.panel1 }
        Region { item: content.panel2 }
        Region { item: dismiss }
        Region { item: trigger }
    }
    BackgroundEffect.blurRegion: Theme.blur ? content.glass : null

    function regionsMoved()
    {
        if (mask) mask.changed();
        if (BackgroundEffect.blurRegion) BackgroundEffect.blurRegion.changed();
    }

    MouseArea
    {
        id: dismiss
        width: MenuState.menuActive ? bar.width : 0
        height: bar.height
        onClicked: MenuState.close()
    }

    Item
    {
        id: stage

        width: bar.width
        height: bar.height
        x: Math.round(Config.barSide === Enums.EdgeLeft ? -bar.slide : Config.barSide === Enums.EdgeRight ? bar.slide : 0)
        y: Math.round(Config.barSide === Enums.EdgeTop ? -bar.slide : Config.barSide === Enums.EdgeBottom ? bar.slide : 0)

        readonly property bool fading: bar.slides && !bar.revealed && bar.reveal > 0 && bar.reveal < 1
        opacity: fading ? Math.min(1, bar.reveal * 1.6) : 1
        visible: bar.reveal > 0 || !bar.slides
        layer.enabled: fading

        onXChanged: bar.regionsMoved()
        onYChanged: bar.regionsMoved()

        focus: true
        Keys.onEscapePressed: MenuState.close()
        HoverHandler { id: hover }

        BarContent { id: content; anchors.fill: parent; host: bar }
    }

    Item
    {
        id: trigger

        readonly property real size: Config.barHideAuto ? Theme.barReveal : 0

        x: Config.barSide === Enums.EdgeRight ? bar.width - width : 0
        y: Config.barSide === Enums.EdgeBottom ? bar.height - height : 0
        width:  bar.isHorizontal ? bar.width : size
        height: bar.isHorizontal ? size : bar.height

        HoverHandler { id: triggerHover }
    }
}
