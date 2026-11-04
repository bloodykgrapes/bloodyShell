import QtQuick

import ".."
import "../../core"

Overlay
{
    id: helper

    active: OverlayState.helperActive
    onHide: OverlayState.hide("helper")

    HelperContent
    {
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 48)
        height: Math.min(600, parent.height - 48)
        opacity: helper.reveal
        scale: 1 - 0.05 * helper.settle
        transform: Translate { y: helper.lift }
        onFinished: OverlayState.hide("helper")
    }
}
