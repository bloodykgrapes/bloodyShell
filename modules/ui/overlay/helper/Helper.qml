import QtQuick

import "." as Content
import "../../../core"
import ".."

OverlayView
{
    id: helper

    name: "helper"

    Content.HelperContent
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
