import QtQuick
import Quickshell

import "../../../core"
import "../../../services"

Item
{
    id: altTab

    required property var host
    readonly property alias inputRegion: inputMask

    Region { id: inputMask; item: ServiceAltTab.presented ? content : null }

    AltTabContent
    {
        id: content
        anchors.centerIn: parent
        width: Math.max(1, Math.min(parent.width - 64, 1200))
        height: Math.max(1, Math.min(parent.height - 100, 280))
        opacity: positioned ? altTab.host.altTabReveal : 0
        transform: Translate { y: Config.animationsFluid ? (1 - altTab.host.altTabReveal) * 24 : 0 }
        focus: ServiceAltTab.active
        Component.onCompleted: if (ServiceAltTab.active) forceActiveFocus()
        Connections
        {
            target: ServiceAltTab
            function onActiveChanged() { if (ServiceAltTab.active) content.forceActiveFocus() }
        }
    }
}
