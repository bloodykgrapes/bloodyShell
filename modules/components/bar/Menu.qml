import QtQuick

import "../../core"

Item
{
    id: menu

    default property alias content: col.data

    implicitWidth: Theme.menuWidth
    implicitHeight: col.implicitHeight + Theme.menuPadding * 2

    property bool opening: Config.animationsFluid
    Timer { running: menu.opening; interval: 700; onTriggered: menu.opening = false }

    Column
    {
        id: col
        x: Theme.menuPadding
        y: Theme.menuPadding
        width: parent.width - Theme.menuPadding * 2
        spacing: 2
    }
}
