import QtQuick
import Quickshell

import "../../../services"
import ".."

Item
{
    id: altTab

    required property var host
    readonly property alias inputRegion: inputMask
    readonly property real reveal: content.positioned ? host.altTabReveal : 0

    Region { id: inputMask; item: ServiceAltTab.presented ? panel.surface : null }

    OverlayPanel
    {
        id: panel
        anchors.centerIn: parent
        width: Math.max(1, Math.min(parent.width - 64, 1200))
        height: Math.max(1, Math.min(parent.height - 100, 280))
        decorated: false
        reveal: altTab.reveal

        AltTabContent
        {
            id: content
            anchors.fill: parent
            focus: ServiceAltTab.active
            Component.onCompleted: if (ServiceAltTab.active) forceActiveFocus()
            Connections
            {
                target: ServiceAltTab
                function onActiveChanged() { if (ServiceAltTab.active) content.forceActiveFocus() }
            }
        }
    }
}
