import QtQuick
import Quickshell
import Quickshell.Wayland

import "../../animations"
import "../../core"
import "../../services"

PanelWindow
{
    id: window

    readonly property bool opened: Config.virtualKeyboardEnabled && ServiceVirtualKeyboard.visible && !ServiceLock.locked && !ServiceScreenshot.active
    property real reveal: opened ? 1 : 0
    Ease on reveal { duration: window.opened ? Theme.animationDurationOpen : Theme.animationDurationClose }

    screen: Quickshell.screens.find(s => s.name === ServiceVirtualKeyboard.output) || Quickshell.screens[0] || null
    visible: reveal > 0.001 && !ServiceLock.locked && !ServiceScreenshot.active
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: content.height + 24
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "bloodyShell:keyboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: content }

    KeyboardContent
    {
        id: content
        x: (window.width - width) / 2
        y: 12 + (1 - window.reveal) * (height + 24)
        width: Math.max(1, Math.min(840, window.width - 32))
        height: implicitHeight
        opacity: window.reveal
        enabled: window.opened
    }
}
