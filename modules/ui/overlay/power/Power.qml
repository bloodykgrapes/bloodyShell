import QtQuick

import "." as Content
import "../../../core"
import ".."

OverlayView
{
    id: power

    name: "power"
    scrimCutout: panel.blurSurface

    OverlayPanel
    {
        id: panel
        anchors.centerIn: parent
        width: content.width
        height: content.height

        scale: Math.min(1, Math.max(0.1, (power.width - 48) / width), Math.max(0.1, (power.height - 48) / height))
        surfaceColor: Theme.colorSolid
        radius: content.radius
        reveal: power.reveal

        Content.PowerContent { id: content; active: power.active; color: "transparent"; border.width: 0 }
    }
}
