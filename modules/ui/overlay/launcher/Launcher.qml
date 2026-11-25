import QtQuick

import "." as Content
import "../../../animations"
import "../../../core"
import ".."

OverlayView
{
    id: launcher

    name: "launcher"
    scrimCutout: panel.blurSurface

    OverlayPanel
    {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(24, Math.round((parent.height - content.fullHeight) / 2))

        width: Math.max(0, Math.min(Theme.launcherWidth, parent.width - 48))
        height: Math.max(0, Math.min(content.implicitHeight, parent.height - 48))
        Glide on height {}

        radius: Theme.launcherRadius
        reveal: launcher.reveal

        MouseArea { anchors.fill: parent }

        Content.LauncherContent
        {
            id: content
            anchors.fill: parent
            color: "transparent"
            border.width: 0
        }
    }
}
