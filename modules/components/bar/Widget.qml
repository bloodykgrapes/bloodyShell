import QtQuick

import "../../core"

Item
{
    id: widget

    default property alias content: box.data

    readonly property bool menuOpen: MenuState.menuWidget === widget
    readonly property bool vertical: Config.barSide === Enums.EdgeLeft || Config.barSide === Enums.EdgeRight

    property bool active: true
    property url  menu: ""

    property real padding: 0

    implicitWidth: vertical
        ? Math.min(box.implicitWidth + padding * 2, Theme.barVerticalWidth)
        : box.implicitWidth + padding * 2
    implicitHeight: Math.max(Theme.barWidgetHeight, box.implicitHeight)

    function toggleMenu() { MenuState.toggle(menu, widget) }

    property real wheelRest: 0
    function wheelSteps(wheel)
    {
        const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
        wheelRest += delta;
        const steps = wheelRest > 0 ? Math.floor(wheelRest / 120) : Math.ceil(wheelRest / 120);
        wheelRest -= steps * 120;
        return steps;
    }

    Row
    {
        id: box

        x: widget.padding
        height: widget.height
    }
}
