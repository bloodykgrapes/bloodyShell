import QtQuick
import Quickshell
import Quickshell.Wayland

import "../components"
import "../core"
import "../services"

Scope
{
    AltTabBindings { }

    AltTabShortcuts { }

    PanelWindow
    {
        id: altTabWindow
        screen: Quickshell.screens.find(s => s.name === ServiceAltTab.output) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bloodyShell:altTab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: ServiceAltTab.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        property real reveal: ServiceAltTab.presented ? 1 : 0
        Ease on reveal
        {
            duration: ServiceAltTab.presented ? Theme.animationDurationOpen : Theme.animationDurationClose
        }

        visible: !ServiceLock.locked && (ServiceAltTab.active || reveal > 0.001)
        mask: Region { item: ServiceAltTab.active && ServiceAltTab.presented ? content : null }

        Rectangle
        {
            anchors.fill: parent
            color: "#99000000"
            opacity: altTabWindow.reveal
        }

        AltTabKeyboard { targetWindow: altTabWindow }

        ShortcutInhibitor
        {
            window: altTabWindow
            enabled: ServiceAltTab.active
        }

        Item
        {
            anchors.fill: parent
            focus: ServiceAltTab.active
            Keys.forwardTo: [content]
        }

        AltTabContent
        {
            id: content
            anchors.centerIn: parent
            width: Math.max(1, Math.min(parent.width - 64, 1200 * Config.themeScale))
            height: Math.max(1, Math.min(parent.height - 100, 280 * Config.themeScale))
            opacity: positioned ? altTabWindow.reveal : 0
            transform: Translate { y: Config.animationsFluid ? (1 - altTabWindow.reveal) * 24 : 0 }
            focus: ServiceAltTab.active
            onVisibleChanged: if (visible && ServiceAltTab.active) forceActiveFocus()
            Connections
            {
                target: ServiceAltTab
                function onActiveChanged()
                {
                    if (ServiceAltTab.active) content.forceActiveFocus();
                }
            }
        }
    }
}
