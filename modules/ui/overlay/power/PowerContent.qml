pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

import "." as Content
import "../../../animations"
import "../../../core"
import "../../../services"

Rectangle
{
    id: powerContent

    readonly property var items: [
        { action: "lock",     title: Tr.tr("power.lock"),      icon: Icon.userLock },
        { action: "logout",   title: Tr.tr("power.logOut"),   icon: Icon.userLogOut },
        { action: "suspend",  title: Tr.tr("power.sleep"),     icon: Icon.computerSleep },
        { action: "reboot",   title: Tr.tr("power.restart"),   icon: Icon.computerReboot,   hold: true },
        { action: "poweroff", title: Tr.tr("power.shutDown"), icon: Icon.computerPowerOff, hold: true, danger: true },
    ]
    anchors.centerIn: parent
    width: row.width + padding * 2
    height: row.height + padding * 2
    readonly property int padding: 12
    readonly property int tileWidth: 112
    radius: 30
    color: Theme.colorSolid
    border.width: 1
    border.color: Theme.colorPanelEdge

    property int index: 0
    property bool active: true
    onActiveChanged: if (!active) { const tile = current(); if (tile) tile.release(); }

    property bool keyboard: false
    readonly property bool lit: keyboard || panelHover.hovered
    function select(i)
    {
        const next = (i + items.length) % items.length;
        if (next === index) return;
        const tile = current();
        if (tile) tile.release();
        index = next;
    }
    function current() { return tiles ? tiles.itemAt(index) : null }

    HoverHandler { id: panelHover; onHoveredChanged: if (hovered) powerContent.keyboard = false }

    focus: true
    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: event =>
    {
        if (event.isAutoRepeat) { event.accepted = true; return; }
        switch (event.key)
        {
            case Qt.Key_Left:
            case Qt.Key_Backtab: keyboard = true; select(index - 1); break;
            case Qt.Key_Right:
            case Qt.Key_Tab:     keyboard = true; select(index + 1); break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:   { keyboard = true; const t = current(); if (t) t.press(); break; }
            case Qt.Key_Escape:  OverlayState.hide("power"); break;
            default: return;
        }
        event.accepted = true;
    }
    Keys.onReleased: event =>
    {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
        {
            const t = current();
            if (t) t.release();
        }
    }

    ClippingRectangle
    {
        id: highlight

        readonly property var target: tiles.count > powerContent.index ? tiles.itemAt(powerContent.index) : null
        readonly property bool danger: powerContent.items[powerContent.index].danger === true

        x: row.x + powerContent.index * (powerContent.tileWidth + row.spacing)
        y: row.y
        width: powerContent.tileWidth
        height: row.height
        radius: 22
        color: danger ? Qt.rgba(Theme.colorCritical.r, Theme.colorCritical.g, Theme.colorCritical.b, 0.14) : Theme.colorSelection
        opacity: powerContent.lit ? 1 : 0

        Glide on x {}
        Smooth on opacity { duration: 180 }
        Tint on color {}

        Rectangle
        {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: highlight.height * (highlight.target ? highlight.target.progress : 0)
            readonly property color tone: highlight.danger ? Theme.colorCritical : Theme.colorAccent
            color: Qt.rgba(tone.r, tone.g, tone.b, 0.28)
        }
    }

    Row
    {
        id: row
        x: powerContent.padding
        y: powerContent.padding
        spacing: 8

        Repeater
        {
            id: tiles
            model: powerContent.items

            Content.PowerTile
            {
                required property var modelData
                required property int index

                icon: modelData.icon
                title: modelData.title
                width: powerContent.tileWidth
                danger: modelData.danger === true
                hold: modelData.hold === true
                order: index
                current: powerContent.lit && powerContent.index === index
                enabled: powerContent.active && ServicePower.pendingAction === ""

                onHovered: powerContent.select(index)
                onTriggered:
                {
                    ServicePower.run(modelData.action);
                    OverlayState.hide("power");
                }
            }
        }
    }

}
