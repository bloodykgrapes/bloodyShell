import QtQuick

import "../../components/bar"
import "../../core"
import "../../services"

Widget
{
    id: widgetNotifications
    menu: Registry.widgets.notifications.menu

    WidgetButton
    {
        icon: Icon.notifications
        text: ServiceNotifications.unread > 0 ? String(ServiceNotifications.unread) : ""

        active: widgetNotifications.menuOpen
        onClicked: widgetNotifications.toggleMenu()
    }
}
