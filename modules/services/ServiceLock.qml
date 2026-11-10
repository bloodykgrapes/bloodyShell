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
    readonly property bool secure: sessionLock.secure
    readonly property int unlockDuration: !Config.animationsEnabled ? 0 : Config.animationsFluid ? 380 : 220
    property bool checking: false

    property bool failed: false
    property int  failures: 0

    property bool leaving: false
    property bool preparingForSleep: false
    property bool sleepMonitorReady: false
    onSecureChanged: releaseSleepDelay()

    PersistentProperties
    {
        id: state
        reloadableId: "bloodyShell-lock"
        property bool locked: false
    }

    function lock()
    {
        unlockLater.stop();
        leaving = false;
        if (state.locked) return;
        failed = false;
        MenuState.close();
        state.locked = true;
    }

    property string pending: ""
    function submit(password)
    {
        if (!state.locked || checking || leaving || preparingForSleep) return;
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
            if (!serviceLock.checking || serviceLock.preparingForSleep) return;
            if (result !== PamResult.Success) { serviceLock.fail(result === PamResult.MaxTries ? "too many attempts" : ""); return; }
            serviceLock.pending = "";
            serviceLock.checking = false;
            serviceLock.failed = false;
            serviceLock.failures = 0;
            serviceLock.leaving = true;
            unlockLater.interval = serviceLock.unlockDuration;
            unlockLater.restart();
        }
        onError: error => { if (serviceLock.checking) serviceLock.fail("password check failed (PamError " + error + ")") }
    }

    Timer
    {
        id: unlockLater
        onTriggered:
        {
            if (serviceLock.preparingForSleep) return;
            state.locked = false;
            serviceLock.leaving = false;
        }
    }

    Connections
    {
        target: Config
        function onAnimationsEnabledChanged()
        {
            if (!Config.animationsEnabled && serviceLock.leaving)
            {
                unlockLater.interval = 0;
                unlockLater.restart();
            }
        }
    }

    WlSessionLock
    {
        id: sessionLock
        locked: state.locked

        WlSessionLockSurface
        {
            color: "black"
            Lock
            {
                anchors.fill: parent
                visible: !serviceLock.preparingForSleep && ServicePower.pendingAction !== "suspend"
            }
        }
    }

    function prepareForSleep(sleeping)
    {
        preparingForSleep = sleeping;
        checking = false;
        pending = "";
        pam.abort();
        lock();
        if (sleeping) releaseSleepDelay();
        else armSleepDelay();
    }

    function armSleepDelay()
    {
        if (!sleepMonitorReady || preparingForSleep || sleepDelay.running) return;
        sleepDelay.stdinEnabled = true;
        sleepDelay.running = true;
    }

    function releaseSleepDelay()
    {
        if (preparingForSleep && secure) sleepDelay.stdinEnabled = false;
    }

    function sleepEvent(line)
    {
        const signal = /org\.freedesktop\.login1\.Manager\.PrepareForSleep\s*\(\s*(true|false)\s*,?\s*\)/.exec(line);
        if (signal) prepareForSleep(signal[1] === "true");
        else if (line.startsWith("The name org.freedesktop.login1 is owned by "))
        {
            sleepMonitorReady = true;
            armSleepDelay();
        }
        else if (line.startsWith("The name org.freedesktop.login1 does not have an owner"))
        {
            sleepMonitorReady = false;
            sleepDelay.stdinEnabled = false;
        }
    }

    Process
    {
        id: sleepDelay
        stdinEnabled: true

        command: ["setpriv", "--pdeathsig", "KILL", "systemd-inhibit", "--no-ask-password", "--what=sleep", "--mode=delay", "--who=bloodyShell",
                  "--why=Lock the screen before sleep", "sh", "-c", "printf 'ready\\n'; read -r released; exit 0"]
        stdout: SplitParser { onRead: line => { if (line === "ready") serviceLock.releaseSleepDelay() } }
        onRunningChanged:
        {
            if (running || !serviceLock.sleepMonitorReady || serviceLock.preparingForSleep) return;
            if (!stdinEnabled) Qt.callLater(serviceLock.armSleepDelay);
            else retryDelay.restart();
        }
        onExited: code => { if (code !== 0) console.warn("[lock] Could not hold the sleep delay:", code) }
    }

    Process
    {
        id: sleepMonitor
        running: true
        environment: ({ LC_ALL: "C" })
        command: ["setpriv", "--pdeathsig", "KILL", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser { onRead: line => serviceLock.sleepEvent(line) }
        onRunningChanged:
        {
            if (running) return;
            serviceLock.sleepMonitorReady = false;
            sleepDelay.stdinEnabled = false;
            retryMonitor.restart();
        }
        onExited: code => console.warn("[lock] Sleep monitor stopped:", code)
    }

    Timer { id: retryDelay; interval: 2000; onTriggered: serviceLock.armSleepDelay() }
    Timer { id: retryMonitor; interval: 2000; onTriggered: sleepMonitor.running = true }
}
