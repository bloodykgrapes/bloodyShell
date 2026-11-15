import QtQuick

import "." as Content
import "../../../core"
import "../../../common"
import ".."

OverlayView
{
    id: helper

    name: "helper"

    SurfaceShadow
    {
        surface: card
        cornerRadius: Theme.settingsRadius
        opacity: helper.reveal
        scale: card.scale
        transform: Translate { y: helper.lift }
    }

    Content.HelperContent
    {
        id: card
        anchors.centerIn: parent
        width: Math.max(0, Math.min(800, parent.width - 48))
        height: Math.max(0, Math.min(640, parent.height - 48))
        opacity: helper.reveal
        scale: 1 - 0.05 * helper.settle
        transform: Translate { y: helper.lift }
        onFinished: OverlayState.hide("helper")
    }
}
