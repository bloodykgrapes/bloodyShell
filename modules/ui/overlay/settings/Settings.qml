import QtQuick

import "." as Content
import "../../../core"
import ".."

OverlayView
{
    id: settings

    name: "settings"
    scrimCutout: content.navigationSurface.blurActive ? content.navigationSurface : null

    OverlayPanel
    {
        id: panel
        anchors.centerIn: parent
        width: Math.max(0, Math.min(Theme.settingsWidth, parent.width - 48))
        height: Math.max(0, Math.min(Theme.settingsHeight, parent.height - 48))
        reveal: settings.reveal
        revealSurface: true
        surfaceCutout: content.navigationSurface
        useSurfaceMaterial: false

        MouseArea { anchors.fill: parent }

        Content.SettingsContent
        {
            id: content
            anchors.fill: parent
            paintBackground: false
            navigationSurfaceHost: panel.surfaceLayer
        }
    }
}
