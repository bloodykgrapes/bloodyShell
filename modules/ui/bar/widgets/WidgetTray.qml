import QtQuick
import Quickshell.Services.SystemTray

import "../../../core"
import "../components"

Widget
{
    id: widgetTray
    menu: Registry.widgets.tray.menu

    active: SystemTray.items.values.length > 0

    WidgetButton
    {
        icon: Icon.tray
        active: widgetTray.menuOpen
        onClicked: widgetTray.toggleMenu()
    }
}
