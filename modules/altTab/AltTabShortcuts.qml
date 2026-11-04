import QtQuick
import Quickshell
import Quickshell.Io

import "../core"
import "../services"

Scope
{
    Shortcut
    {
        sequence: "Alt+Tab"
        context: Qt.ApplicationShortcut
        enabled: Config.initialized && !ServiceLock.locked && !ServiceAltTab.active
        onActivated: ServiceAltTab.cycle(1)
    }
    Shortcut
    {
        sequence: "Alt+Shift+Tab"
        context: Qt.ApplicationShortcut
        enabled: Config.initialized && !ServiceLock.locked && !ServiceAltTab.active
        onActivated: ServiceAltTab.cycle(-1)
    }

    IpcHandler
    {
        target: "altTab"
        function begin(reverse: bool): void
        {
            ServiceAltTab.cycle(reverse ? -1 : 1);
        }
    }

}
