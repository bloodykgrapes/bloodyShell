import QtQuick

import ".."
import "../../core"

Overlay
{
    id: power

    active: OverlayState.powerActive
    onHide: OverlayState.hide("power")

    Item
    {
        anchors.centerIn: parent

        opacity: power.reveal
        scale: 1 - 0.06 * power.settle
        transform: Translate { y: power.lift }

        PowerContent { }
    }
}
