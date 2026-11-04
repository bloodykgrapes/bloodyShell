import QtQuick

import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetSystem
    menu: Registry.widgets.system.menu

    WidgetButton
    {
        icon: ServiceSystem.logo
        monochrome: true

        active: widgetSystem.menuOpen
        onClicked: widgetSystem.toggleMenu()
    }
}
