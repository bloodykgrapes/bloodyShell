import QtQuick

import "../../../core"
import "../../../services"
import "../components"

Widget
{
    id: widgetMedia
    menu: Registry.widgets.media.menu

    WidgetButton
    {
        bubble: Registry.usesStatusBubbles(Config.barType)
        icon: Icon.music
        active: widgetMedia.menuOpen || ServiceMedia.playing
        color: ServiceMedia.available ? Theme.text2 : Theme.text3

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onWheel: wheel =>
        {
            wheel.accepted = true;
            const steps = widgetMedia.wheelSteps(wheel);
            if (steps > 0) ServiceMedia.previous();
            else if (steps < 0) ServiceMedia.next();
        }
        onClicked: mouse =>
        {
            if (mouse.button === Qt.MiddleButton) ServiceMedia.toggle();
            else if (mouse.button === Qt.RightButton) ServiceMedia.raise();
            else widgetMedia.toggleMenu();
        }
    }
}
