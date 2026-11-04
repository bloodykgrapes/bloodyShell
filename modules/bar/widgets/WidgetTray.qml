import QtQuick
import Quickshell.Services.SystemTray

import "../../components/bar"
import "../../core"

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
