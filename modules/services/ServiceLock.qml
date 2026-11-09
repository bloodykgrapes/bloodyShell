pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

import "../core"
import "../ui/lock"

Singleton
{
    id: serviceLock

    readonly property bool locked: state.locked
    property bool checking: false

    property bool failed: false
    property int  failures: 0

    property bool leaving: false

    PersistentProperties
    {
        id: state
        reloadableId: "bloodyShell-lock"
        property bool locked: false
    }

    function lock()
    {
        if (state.locked) return;
        failed = false;
        leaving = false;
        MenuState.close();
        state.locked = true;
    }

    property string pending: ""
    function submit(password)
    {
        if (!state.locked || checking) return;
        if (password === "") { fail(""); return; }
        pending = password;
        failed = false;
        checking = true;
        if (!pam.start()) fail("could not start the password check");
    }
    function fail(reason)
    {
        if (reason !== "") console.warn("[lock]", reason);
        pending = "";
        checking = false;
        failed = true;
        failures++;
    }

    PamContext
    {
        id: pam

        config: "login"

        onResponseRequiredChanged:
        {
            if (!responseRequired) return;
            respond(serviceLock.pending);
            serviceLock.pending = "";
        }
        onCompleted: result =>
        {
            if (result !== PamResult.Success) { serviceLock.fail(result === PamResult.MaxTries ? "too many attempts" : ""); return; }
            serviceLock.pending = "";
            serviceLock.checking = false;
            serviceLock.failed = false;
            serviceLock.failures = 0;
            serviceLock.leaving = true;
            unlockLater.interval = Config.animationsEnabled ? 460 : 0;
            unlockLater.restart();
        }
        onError: error => serviceLock.fail("password check failed (PamError " + error + ")")
    }

    Timer { id: unlockLater; onTriggered: { state.locked = false; serviceLock.leaving = false } }

    WlSessionLock
    {
        locked: state.locked

        WlSessionLockSurface
        {
            color: "black"
            Lock { anchors.fill: parent }
        }
    }

    Process
    {
        id: sleepDelay
        running: true

        command: ["setpriv", "--pdeathsig", "KILL", "systemd-inhibit", "--no-ask-password", "--what=sleep", "--mode=delay", "--who=bloodyShell",
                  "--why=Lock the screen before sleep", "sleep", "infinity"]
    }

    Process
    {
        running: true
        command: ["setpriv", "--pdeathsig", "KILL", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser
        {
            onRead: line =>
            {
                if (line.indexOf("PrepareForSleep") < 0) return;
                if (/\(true\)/.test(line))
                {
                    serviceLock.lock();
                    release.restart();
                }
                else sleepDelay.running = true;
            }
        }
    }

    Timer { id: release; interval: 300; onTriggered: sleepDelay.running = false }
}
