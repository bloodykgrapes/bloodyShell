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
    readonly property bool islandStyle: Config.launcherStyle === Enums.LauncherIsland

    OverlayPanel
    {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: launcher.islandStyle
            ? Theme.frameThickness + Theme.barThickness + (Config.barAttach ? 0 : Theme.panelGap) + 8
            : Math.max(24, Math.round((parent.height - content.fullHeight) / 2))

        width: Math.max(0, Math.min(launcher.islandStyle ? Theme.launcherWidth + 56 : Theme.launcherWidth, parent.width - 48))
        height: Math.max(0, Math.min(content.implicitHeight, parent.height - 48))
        Glide on height {}

        radius: launcher.islandStyle ? Theme.radiusLarge + 4 : Theme.launcherRadius
        reveal: launcher.reveal

        MouseArea { anchors.fill: parent }

        Content.LauncherContent
        {
            id: content
            anchors.fill: parent
            color: "transparent"
            border.width: 0
            surfaceRadius: panel.radius
        }
    }
}
