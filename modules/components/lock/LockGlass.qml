import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../../core"

ClippingRectangle
{
    id: lockGlass

    property bool  edge: true
    property color tint: Theme.lockGlass

    color: "transparent"

    property Item surface: null
    readonly property Item source: surface && Theme.lockSampled ? surface.glassSource : null
    Component.onCompleted:
    {
        for (let p = parent; p; p = p.parent)
            if (p.glassSource !== undefined) { surface = p; break; }
        Qt.callLater(place);
    }

    property rect area: Qt.rect(0, 0, 1, 1)
    property bool hovered: false
    function place()
    {
        if (!source) return;
        const a = lockGlass.mapToItem(source, 0, 0), b = lockGlass.mapToItem(source, lockGlass.width, lockGlass.height);
        const r = Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.max(1, Math.abs(b.x - a.x)), Math.max(1, Math.abs(b.y - a.y)));
        if (r.x !== area.x || r.y !== area.y || r.width !== area.width || r.height !== area.height) area = r;
    }
    onSourceChanged: Qt.callLater(place)
    onWidthChanged: Qt.callLater(place)
    onHeightChanged: Qt.callLater(place)
    onVisibleChanged: if (visible) Qt.callLater(place)
    Connections
    {
        target: lockGlass.surface
        function onWidthChanged() { Qt.callLater(lockGlass.place) }
        function onHeightChanged() { Qt.callLater(lockGlass.place) }
    }

    onHoveredChanged: settle.restart()
    Timer { id: settle; interval: 400 }
    FrameAnimation
    {
        running: lockGlass.visible && lockGlass.source !== null && (lockGlass.surface.moving || settle.running)
        onTriggered: lockGlass.place()
        onRunningChanged: if (!running) lockGlass.place()
    }

    ShaderEffectSource
    {
        id: piece
        anchors.fill: parent
        visible: false
        sourceItem: lockGlass.source
        sourceRect: lockGlass.area
    }

    MultiEffect
    {
        anchors.fill: parent
        source: piece
        visible: lockGlass.source !== null
        blurEnabled: Theme.lockBlur > 0
        blur: Theme.lockBlur
        blurMax: 40
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: lockGlass.tint }
    Rectangle
    {
        visible: lockGlass.edge
        anchors.fill: parent
        radius: lockGlass.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.lockGlassEdge
    }
}
