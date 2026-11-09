import QtQuick

import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: widgetNotifications
    objectName: "notificationsWidget"
    menu: Registry.widgets.notifications.menu

    onMenuOpenChanged: if (menuOpen) ServiceNotifications.markRead()

    WidgetButton
    {
        icon: Icon.notifications
        monochrome: true
        text: ServiceNotifications.unread > 0 ? String(ServiceNotifications.unread) : ""

        active: widgetNotifications.menuOpen
        onClicked: widgetNotifications.toggleMenu()
    }
}
