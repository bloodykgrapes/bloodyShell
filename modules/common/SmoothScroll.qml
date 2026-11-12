pragma ComponentBehavior: Bound

import QtQuick

import "../core"

Item
{
    id: smoothScroll

    required property Flickable view
    readonly property bool isSmoothScroll: true
    property bool horizontal: view.flickableDirection === Flickable.HorizontalFlick
    readonly property real position: horizontal ? view.contentX : view.contentY
    readonly property real minimum: horizontal ? view.originX - view.leftMargin : view.originY - view.topMargin
    readonly property real maximum: Math.max(minimum, horizontal
        ? view.originX + view.contentWidth - view.width + view.rightMargin
        : view.originY + view.contentHeight - view.height + view.bottomMargin)
    readonly property bool running: motion.running
    property real destination: position
    property real animatedPosition: 0
    property bool writing: false

    signal scrolled()

    parent: view
    anchors.fill: parent
    enabled: view.enabled && view.interactive && activity.active

    RenderActivity { id: activity; target: smoothScroll.view }

    function clamp(value) { return Math.max(minimum, Math.min(maximum, value)); }
    function stop() { motion.stop(); }
    function write(value)
    {
        writing = true;
        if (horizontal) view.contentX = clamp(value);
        else view.contentY = clamp(value);
        writing = false;
    }
    function scrollTo(value, animate = true)
    {
        stop();
        view.cancelFlick();
        destination = clamp(value);
        if (!animate || !Config.animationsEnabled || Math.abs(destination - position) < 0.5)
        {
            write(destination);
            return;
        }
        motion.from = position;
        motion.to = destination;
        motion.start();
    }
    function handleWheel(pixelDelta, angleDelta)
    {
        if (!enabled) return false;
        const delta = Config.scrollDelta(pixelDelta, angleDelta);
        if (delta === 0) return false;
        const from = running ? destination : position;
        const next = clamp(from - delta);
        if (Math.abs(next - from) < 0.01) return running;
        scrollTo(next, pixelDelta === 0);
        scrolled();
        return true;
    }
    function contain()
    {
        const next = clamp(position);
        if (running && (destination < minimum || destination > maximum)) stop();
        if (Math.abs(next - position) > 0.01) { stop(); write(next); }
    }
    function dispatchWheel(pixelDelta, angleDelta)
    {
        if (handleWheel(pixelDelta, angleDelta)) return true;
        for (let item = view.parent; item; item = item.parent)
        {
            if (!(item instanceof Flickable)) continue;
            const outer = item.children.find(child => child.isSmoothScroll === true);
            if (outer && outer.handleWheel(pixelDelta, angleDelta)) return true;
        }
        return false;
    }

    WheelHandler
    {
        parent: smoothScroll.view
        target: null
        enabled: smoothScroll.enabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event =>
        {
            if (smoothScroll.horizontal && (event.pixelDelta.x !== 0 || event.angleDelta.x !== 0))
            {
                event.accepted = false;
                return;
            }
            event.accepted = smoothScroll.dispatchWheel(event.pixelDelta.y, event.angleDelta.y);
        }
    }
    WheelHandler
    {
        parent: smoothScroll.view
        target: null
        orientation: Qt.Horizontal
        enabled: smoothScroll.enabled && smoothScroll.horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => event.accepted = smoothScroll.dispatchWheel(event.pixelDelta.x, event.angleDelta.x)
    }
    onAnimatedPositionChanged: if (motion.running) write(animatedPosition)
    onEnabledChanged: if (!enabled) stop()
    onMinimumChanged: contain()
    onMaximumChanged: contain()

    NumberAnimation
    {
        id: motion
        target: smoothScroll
        property: "animatedPosition"
        duration: 240
        easing.type: Easing.OutCubic
    }
    Connections
    {
        target: smoothScroll.view
        function onContentXChanged() { if (smoothScroll.horizontal && !smoothScroll.writing) smoothScroll.stop(); }
        function onContentYChanged() { if (!smoothScroll.horizontal && !smoothScroll.writing) smoothScroll.stop(); }
        function onDraggingChanged() { if (smoothScroll.view.dragging) smoothScroll.stop(); }
        function onFlickingChanged() { if (smoothScroll.view.flicking) smoothScroll.stop(); }
    }
    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (!Config.animationsEnabled && smoothScroll.running)
            {
                smoothScroll.stop();
                smoothScroll.write(smoothScroll.destination);
            }
        }
    }
}
