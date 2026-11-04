import QtQuick

import ".."
import "../../components"
import "../../core"

Overlay
{
    id: launcher

    active: OverlayState.launcherActive
    onHide: OverlayState.hide("launcher")

    Item
    {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(24, Math.round((parent.height - content.fullHeight) / 2))

        width: Math.min(Theme.launcherWidth, parent.width - 48)
        height: Math.min(content.implicitHeight, parent.height - 48)
        clip: true
        Glide on height {}

        opacity: launcher.reveal
        scale: 1 - 0.04 * launcher.settle
        transform: Translate { y: launcher.lift }

        MouseArea { anchors.fill: parent }

        LauncherContent
        {
            id: content
            anchors.fill: parent
        }
    }
}
