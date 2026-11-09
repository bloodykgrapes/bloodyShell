pragma Singleton

import QtQuick
import Quickshell

import "../services"

Singleton
{
    id: sidebars

    property string current: ""
    property string output: ""
    readonly property bool active: current !== ""

    function toggle(side, screen)
    {
        if (!["left", "right"].includes(side) || ServiceLock.locked || OverlayState.inhibited) return;
        if (current === side && output === screen) { close(); return; }
        OverlayState.close();
        ServiceAltTab.cancel();
        MenuState.close();
        output = screen || ServiceCompositor.focusedOutput;
        current = side;
    }
    function close() { current = "" }
    function onOutput(name) { return active && (output === "" || name === output) }

    Connections { target: OverlayState; function onCurrentChanged() { if (OverlayState.active) sidebars.close() } }
    Connections { target: OverlayState; function onInhibitedChanged() { if (OverlayState.inhibited) sidebars.close() } }
    Connections { target: MenuState; function onMenuActiveChanged() { if (MenuState.menuActive) sidebars.close() } }
    Connections { target: ServiceAltTab; function onActiveChanged() { if (ServiceAltTab.active) sidebars.close() } }
    Connections { target: ServiceLock; function onLockedChanged() { if (ServiceLock.locked) sidebars.close() } }
    Connections { target: ServiceCompositor; function onFocusedWorkspaceIdChanged() { sidebars.close() } }
}
