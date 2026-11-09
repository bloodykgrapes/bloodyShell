import QtQuick

import "." as Content
import "../../../core"
import ".."

OverlayView
{
    id: settings

    name: "settings"

    Item
    {
        anchors.centerIn: parent
        width: Math.min(Theme.settingsWidth, parent.width - 64)
        height: Math.min(Theme.settingsHeight, parent.height - 64)

        opacity: settings.reveal
        scale: 1 - 0.05 * settings.settle
        transform: Translate { y: settings.lift }

        MouseArea { anchors.fill: parent }

        Content.SettingsContent { anchors.fill: parent }
    }
}
