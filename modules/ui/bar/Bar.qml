pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../animations"
import "../../core"
import "../../services"
import "components"

Item
{
    id: bar

    required property var screen
    readonly property bool keyboardWanted: menuHere && MenuState.menuKeyboard
    readonly property alias inputRegion: barInput
    readonly property real centerLimit: content.centerLimit
    readonly property alias stageItem: stage
    readonly property alias sidebarArea: sidebarArea
    readonly property bool isHorizontal: Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom
    readonly property real thickness: Theme.barThickness
    readonly property bool inFrame: Config.barType === Enums.InFrame || filled
    readonly property bool islands: Config.barType === Enums.Islands
    readonly property bool filled: Config.barType === Enums.Filled
    readonly property real surfaceGap: islands ? 6 : 0
    readonly property real reserve: Theme.frameThickness + surfaceGap + thickness
    readonly property real frameThickness: Theme.frameThickness
    signal regionsChanged()

    function bodyRect(index)
    {
        if (filled)
        {
            if (index !== 0 || !stage.visible) return Qt.rect(0, 0, 0, 0);
            const r = Theme.barRadius;
            switch (Config.barSide)
            {
                case Enums.EdgeTop: return translated(Qt.rect(-r, -r, width + r * 2, reserve + r));
                case Enums.EdgeBottom: return translated(Qt.rect(-r, height - reserve, width + r * 2, reserve + r));
                case Enums.EdgeLeft: return translated(Qt.rect(-r, -r, reserve + r, height + r * 2));
                default: return translated(Qt.rect(width - reserve, -r, reserve + r, height + r * 2));
            }
        }
        let rect = content.bodies[index];
        if (rect.width > 0 && rect.height > 0)
        {
            if (isHorizontal && index === 0) rect = Qt.rect(0, rect.y, rect.x + rect.width, rect.height);
            else if (isHorizontal && index === 2) rect = Qt.rect(rect.x, rect.y, width - rect.x, rect.height);
            else if (!isHorizontal && index === 0) rect = Qt.rect(rect.x, 0, rect.width, rect.y + rect.height);
            else if (!isHorizontal && index === 2) rect = Qt.rect(rect.x, rect.y, rect.width, height - rect.y);
        }
        return translated(rect);
    }
    function panelRect(index) { return translated(content.panels[index]) }
    function translated(rect) { return Qt.rect(rect.x + stage.x, rect.y + stage.y, rect.width, rect.height) }
    function overBand(point)
    {
        return point.x >= sidebarArea.x && point.x < sidebarArea.x + sidebarArea.width
            && point.y >= sidebarArea.y && point.y < sidebarArea.y + sidebarArea.height;
    }
    function sidebarAt(point) { return (isHorizontal ? point.x < width / 2 : point.y < height / 2) ? "left" : "right" }

    readonly property bool menuHere: MenuState.menuActive && owns(MenuState.menuOwner)

    readonly property bool hoveringBand: hover.hovered && overBand(hover.point.position)
    readonly property bool hoveringContent: hover.hovered && (overBand(hover.point.position) || overContent(hover.point.position))
    readonly property bool revealWanted: !Config.barHideAuto || hoveringContent || triggerHover.hovered || menuHere || (screen && SidebarState.onOutput(screen.name))
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

    readonly property real slide: (1 - reveal) * (reserve + 4)

    function owns(item)
    {
        for (let p = item; p; p = p.parent) if (p === stage) return true;
        return false;
    }

    function overContent(point)
    {
        for (const item of [content.panel0, content.panel2])
        {
            if (!item.visible || item.width <= 0 || item.height <= 0) continue;
            const local = stage.mapToItem(item, point.x, point.y);
            if (local.x >= 0 && local.y >= 0 && local.x < item.width && local.y < item.height) return true;
        }
        return false;
    }

    Region
    {
        id: barInput
        Region { item: content.panel0 }
        Region { item: content.panel2 }
        Region { item: sidebarArea }
        Region { item: trigger }
    }

    function regionsMoved() { regionsChanged() }

    Item
    {
        id: stage

        width: bar.width
        height: bar.height
        x: Math.round(Config.barSide === Enums.EdgeLeft ? -bar.slide : Config.barSide === Enums.EdgeRight ? bar.slide : 0)
        y: Math.round(Config.barSide === Enums.EdgeTop ? -bar.slide : Config.barSide === Enums.EdgeBottom ? bar.slide : 0)

        readonly property bool fading: !bar.revealed && bar.reveal > 0 && bar.reveal < 1
        opacity: fading ? Math.min(1, bar.reveal * 1.6) : 1
        visible: bar.reveal > 0
        layer.enabled: fading

        onXChanged: bar.regionsMoved()
        onYChanged: bar.regionsMoved()
        onVisibleChanged: bar.regionsMoved()

        focus: true
        Keys.onEscapePressed: MenuState.close()
        HoverHandler { id: hover }

        MouseArea
        {
            id: sidebarArea
            objectName: "barSidebarArea"
            x: Config.barSide === Enums.EdgeRight ? bar.width - width : 0
            y: Config.barSide === Enums.EdgeBottom ? bar.height - height : 0
            width: bar.isHorizontal ? bar.width : bar.reserve
            height: bar.isHorizontal ? bar.reserve : bar.height
            cursorShape: Qt.PointingHandCursor
            property real wheelRest: 0
            onClicked: mouse =>
            {
                if (bar.screen) SidebarState.toggle(bar.sidebarAt(mapToItem(stage, mouse.x, mouse.y)), bar.screen.name);
            }
            onWheel: wheel =>
            {
                wheelRest += wheel.angleDelta.y;
                const steps = Math.trunc(wheelRest / 120);
                wheelRest -= steps * 120;
                if (steps) ServiceAudio.changeVolume(steps * 0.05);
            }
        }

        BarContent { id: content; anchors.fill: parent; host: bar }
        BarCorner
        {
            id: leftCorner
            side: "left"
            screen: bar.screen
            hinted: bar.hoveringBand && bar.sidebarAt(hover.point.position) === side
            x: Config.barSide === Enums.EdgeRight ? bar.width - width - Theme.frameThickness : Theme.frameThickness
            y: Config.barSide === Enums.EdgeBottom ? bar.height - height - Theme.frameThickness : Theme.frameThickness
        }
        BarCorner
        {
            id: rightCorner
            side: "right"
            screen: bar.screen
            hinted: bar.hoveringBand && bar.sidebarAt(hover.point.position) === side
            x: Config.barSide === Enums.EdgeLeft ? Theme.frameThickness : bar.width - width - Theme.frameThickness
            y: Config.barSide === Enums.EdgeTop ? Theme.frameThickness : bar.height - height - Theme.frameThickness
        }

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
