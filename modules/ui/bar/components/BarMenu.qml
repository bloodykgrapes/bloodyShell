pragma ComponentBehavior: Bound

import QtQuick

import "../../../core"

Item
{
    id: barMenu

    property int side: Config.barSide
    property bool   active: false
    property string menu: ""

    readonly property bool horizontal: barMenu.side === Enums.EdgeTop || barMenu.side === Enums.EdgeBottom
    property real origin: 0
    property real center: (horizontal ? width : height) / 2

    function alongPos(size) { return Math.round(center - size / 2) - origin }

    readonly property real contentHeight: front.item ? front.item.implicitHeight : 0
    readonly property real contentWidth: front.item ? front.item.implicitWidth : 0
    readonly property bool centerOnWidget: front.item && front.item.centerOnWidget === true

    property bool   pending: false
    property bool   useB: false
    property string url: ""
    readonly property var front: useB ? slotB : slotA
    readonly property var idle:  useB ? slotA : slotB

    MenuSlot
    {
        id: slotA
        side: barMenu.side
        anchors.top: barMenu.side === Enums.EdgeTop ? parent.top : undefined
        anchors.bottom: barMenu.side === Enums.EdgeBottom ? parent.bottom : undefined
        anchors.left: barMenu.side === Enums.EdgeLeft ? parent.left : undefined
        anchors.right: barMenu.side === Enums.EdgeRight ? parent.right : undefined
        x: barMenu.horizontal ? barMenu.alongPos(width) : 0
        y: barMenu.horizontal ? 0 : barMenu.alongPos(height)
        enabled: barMenu.front === slotA && barMenu.active
        z: barMenu.front === slotA ? 1 : 0
    }

    MenuSlot
    {
        id: slotB
        side: barMenu.side
        anchors.top: barMenu.side === Enums.EdgeTop ? parent.top : undefined
        anchors.bottom: barMenu.side === Enums.EdgeBottom ? parent.bottom : undefined
        anchors.left: barMenu.side === Enums.EdgeLeft ? parent.left : undefined
        anchors.right: barMenu.side === Enums.EdgeRight ? parent.right : undefined
        x: barMenu.horizontal ? barMenu.alongPos(width) : 0
        y: barMenu.horizontal ? 0 : barMenu.alongPos(height)
        enabled: barMenu.front === slotB && barMenu.active
        z: barMenu.front === slotB ? 1 : 0
    }

    function alignSlots()
    {
        for (const slot of [slotA, slotB])
        {
            if (horizontal) slot.x = Qt.binding(() => barMenu.horizontal ? barMenu.alongPos(slot.width) : 0);
            else slot.y = Qt.binding(() => barMenu.horizontal ? 0 : barMenu.alongPos(slot.height));
        }
    }
    onSideChanged: Qt.callLater(alignSlots)

    function sync()
    {
        if (Config.debug) console.log("[menu] sync shown=" + active + " url=" + menu + " shownUrl=" + url);

        const target = active ? menu : "";
        if (target === "")
        {
            slotA.shown = false;
            slotB.shown = false;
            if (url !== "") clearTimer.restart();
            return;
        }

        clearTimer.stop();

        if (target === url) { front.shown = true; return }

        if (url === "")
        {
            useB = false;
            url = target;
            slotA.source = target;
            slotA.shown = true;
        }
        else morph(target);
    }

    function morph(target)
    {
        const outgoing = front;

        idle.source = target;
        useB = !useB;

        front.shown = true;
        outgoing.shown = false;
        url = target;

        settle.restart();
    }

    function schedule()
    {
        if (pending) return;
        pending = true;

        Qt.callLater(function()
        {
            pending = false;
            sync();
        });
    }

    onActiveChanged:       schedule()
    onMenuChanged:         schedule()
    Component.onCompleted: schedule()

    Timer
    {
        id: settle
        interval: 300
        onTriggered: barMenu.idle.source = ""
    }
    Timer
    {
        id: clearTimer
        interval: 340
        onTriggered:
        {
            if (barMenu.active) return;
            slotA.source = "";
            slotB.source = "";
            barMenu.url = "";
            barMenu.useB = false;
        }
    }
}
