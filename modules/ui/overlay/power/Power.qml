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
        width: content.width
        height: content.height

        opacity: power.reveal
        scale: Math.min(1, Math.max(0.1, (power.width - 48) / width), Math.max(0.1, (power.height - 48) / height)) * (1 - 0.06 * power.settle)
        transform: Translate { y: power.lift }

        Content.PowerContent { id: content; active: power.active }
    }
}
