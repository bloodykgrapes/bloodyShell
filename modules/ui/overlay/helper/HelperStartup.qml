import QtQuick

import "../../../core"
import "../../../services"

Timer
{
    interval: 500
    running: Config.initialized && !Config.helperSeen && !ServiceLock.locked
        && !OverlayState.active
    onTriggered: OverlayState.show("helper")
}
