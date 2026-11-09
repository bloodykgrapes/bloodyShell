import QtQuick

import "." as Content
import ".."

OverlayView
{
    id: power

    name: "power"

    Item
    {
        anchors.centerIn: parent

        opacity: power.reveal
        scale: 1 - 0.06 * power.settle
        transform: Translate { y: power.lift }

        Content.PowerContent { }
    }
}
