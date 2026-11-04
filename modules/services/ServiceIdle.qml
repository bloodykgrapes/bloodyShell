pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core"

Singleton
{
    id: serviceIdle

    component Watch: Instantiator
    {
        id: watch

        required property int seconds
        signal idle()
        signal back()

        model: seconds > 0 ? [seconds] : []
        delegate: IdleMonitor
        {
            required property int modelData
            timeout: modelData
            respectInhibitors: true
            onIsIdleChanged: isIdle ? watch.idle() : watch.back()
        }
    }

    Watch
    {
        seconds: Config.idleLock
        onIdle: ServiceLock.lock()
    }

    Watch
    {
        seconds: Config.idleDisplay

        onIdle: Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }

    Watch
    {
        seconds: Config.idleSuspend
        onIdle: ServicePower.run("suspend")
    }
}
