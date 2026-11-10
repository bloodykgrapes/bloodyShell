import QtQuick

import "../core"

Item
{
    id: menu

    default property alias content: col.data
    property alias spacing: col.spacing
    readonly property bool active: activity.active
    property bool presented: true
    property bool centerOnWidget: false

    RenderActivity { id: activity; target: menu }

    implicitWidth: Theme.menuWidth
    implicitHeight: col.implicitHeight + Theme.menuPadding * 2

    property bool opening: Config.animationsFluid
    onPresentedChanged:
    {
        opening = presented && Config.animationsFluid;
        if (opening) openingTimer.restart();
    }
    Timer { id: openingTimer; running: menu.opening; interval: 700; onTriggered: menu.opening = false }

    Column
    {
        id: col
        x: Theme.menuPadding
        y: Theme.menuPadding
        width: parent.width - Theme.menuPadding * 2
        spacing: 2
    }
}
