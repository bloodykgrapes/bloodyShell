pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../core"
import "../../services"

Item
{
    id: bar

    required property var screen
    required property bool fullscreen
    required property bool revealed
    required property real reveal
    required property point offset
    required property bool hasIsland
    readonly property bool keyboardWanted: menuHere && MenuState.menuKeyboard
    readonly property alias inputRegion: barInput
    readonly property alias island: content.island
    readonly property bool hoveringWidgets: content.hoveringWidgets
    readonly property bool isHorizontal: Config.barSide === Enums.EdgeTop || Config.barSide === Enums.EdgeBottom
    readonly property real thickness: Theme.barThickness
    readonly property real depth: Theme.frameThickness + (Config.barAttach ? 0 : Theme.panelGap)
    readonly property real reserve: depth + thickness
    readonly property rect startBody: bodyRect(true)
    readonly property rect endBody: bodyRect(false)
    readonly property rect centerBody: island && stage.visible ? translated(island.bodyRect) : Qt.rect(0, 0, 0, 0)
    readonly property rect centerPanel: island && stage.visible ? translated(island.panelRect) : Qt.rect(0, 0, 0, 0)

    function translated(rect) { return Qt.rect(rect.x + offset.x, rect.y + offset.y, rect.width, rect.height); }
    function bodyRect(atStart)
    {
        if (!stage.visible) return Qt.rect(0, 0, 0, 0);
        if (Config.barType !== Enums.BarFull) return translated(atStart ? content.startBody : content.endBody);
        if (!atStart) return Qt.rect(0, 0, 0, 0);
        const inset = Config.barAttach ? 0 : depth;
        if (isHorizontal) return translated(Qt.rect(inset, Config.barSide === Enums.EdgeTop ? depth : height - reserve,
            Math.max(0, width - 2 * inset), thickness));
        return translated(Qt.rect(Config.barSide === Enums.EdgeLeft ? depth : width - reserve, inset,
            thickness, Math.max(0, height - 2 * inset)));
    }
    readonly property bool menuHere: MenuState.menuActive && owns(MenuState.menuOwner)
    readonly property bool menuPanelVisible: menuHere && (MenuState.menuOwner?.panel?.visible ?? false)
    enabled: !fullscreen
    property real wheelRest: 0

    function wheelSteps(delta)
    {
        wheelRest += delta;
        const steps = wheelRest > 0 ? Math.floor(wheelRest / 120) : Math.ceil(wheelRest / 120);
        wheelRest -= steps * 120;
        return steps;
    }
    function owns(item)
    {
        for (let p = item; p; p = p.parent) if (p === stage) return true;
        return false;
    }

    Region
    {
        id: barInput
        Region { item: content.startWidgets.width > 0 && content.startWidgets.height > 0 ? content.startWidgets : null }
        Region { item: content.endWidgets.width > 0 && content.endWidgets.height > 0 ? content.endWidgets : null }
        Region { item: content.startPanel.enabled && content.startPanel.visible ? content.startPanel : null }
        Region { item: content.endPanel.enabled && content.endPanel.visible ? content.endPanel : null }
        Region { regions: bar.island ? [bar.island.inputRegion] : [] }
    }

    Item
    {
        id: stage

        width: bar.width
        height: bar.height
        x: bar.offset.x
        y: bar.offset.y

        readonly property bool fading: bar.reveal > 0 && bar.reveal < 1
        opacity: Math.min(1, bar.reveal * 1.6)
        visible: bar.reveal > 0
        layer.enabled: fading

        focus: true
        Keys.onEscapePressed: MenuState.close()
        WheelHandler
        {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event =>
            {
                if (Config.barScrollAction === 0) return;
                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                const steps = bar.wheelSteps(delta);
                if (steps !== 0)
                {
                    if (Config.barScrollAction === 1) ServiceAudio.changeVolume(steps * 0.02);
                    else ServiceDisplay.setBrightness(ServiceDisplay.brightness + steps * 0.02);
                }
                event.accepted = true;
            }
        }
        BarContent { id: content; anchors.fill: parent; host: bar }
    }
}
