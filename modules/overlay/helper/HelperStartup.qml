import QtQuick

import "../../core"
import "../../services"

Timer
{
    interval: 500
    running: Config.initialized && !Config.helperSeen && !ServiceLock.locked
        && !OverlayState.windows.some(name => OverlayState[name + "Active"])
    onTriggered: OverlayState.show("helper")
}
