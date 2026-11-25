import QtQuick

import "." as Content
import "../../../core"
import ".."

OverlayView
{
    id: helper

    name: "helper"
    scrimCutout: panel.blurSurface

    OverlayPanel
    {
        id: panel
        anchors.centerIn: parent
        width: Math.max(0, Math.min(800, parent.width - 48))
        height: Math.max(0, Math.min(640, parent.height - 48))
        surfaceColor: Theme.colorSolid
        reveal: helper.reveal

        Content.HelperContent
        {
            anchors.fill: parent
            color: "transparent"
            border.width: 0
            onFinished: OverlayState.hide("helper")
        }
    }
}
