import QtQuick
import Quickshell

import "common"
import "core"
import "services"

ShellRoot
{
    id: tests
    property int commandStage: 0
    property int commandCompletions: 0
    property bool commandsDone: false
    property bool overlaysDone: false
    property bool launchesDone: false

    function check(condition, message)
    {
        if (!condition)
        {
            console.error("REGRESSION_FAILED", message);
            Qt.quit();
            throw new Error(message);
        }
    }

    function finish()
    {
        if (commandsDone && overlaysDone && launchesDone)
        {
            console.log("REGRESSIONS_PASSED");
            Qt.quit();
        }
    }

    Item
    {
        id: island
        property bool isIsland: true
        Item { id: widget; property bool active: true }
    }

    function checkDockAndWindows()
    {

        void ServiceApplications.launching;
        void ServiceWindowActions.lastFocused;
        void ServiceDock.model;
        Config.dockPinned = ["org.example.Editor"];
        const editor1 = { id: 1, app_id: "org.example.Editor", title: "One", is_focused: true };
        const editor2 = { id: 2, app_id: "org.example.Editor", title: "Two", is_focused: false };
        const browser = { id: 3, app_id: "org.example.Browser", title: "Browser", is_focused: false };
        ServiceCompositor.windowList = [editor1, editor2, browser];
        check(ServiceDock.model.count === 3, "merged pinned app, separator and browser");
        check(ServiceDock.model.get(0).count === 2, "merged editor has two windows");
        ServiceDock.activateApp(ServiceDock.model.get(0));
        check(ServiceCompositor.focusedCalls.slice(-1)[0] === 2, "dock activation cycles windows");
        ServiceDock.closeAll(ServiceDock.model.get(0));
        check(JSON.stringify(ServiceCompositor.closedCalls) === "[1,2]", "closeAll uses compositor actions");
        Config.dockPinned = ["org.example.Editor", "org.example.Browser"];
        ServiceDock.move(0, 1);
        check(Config.dockPinned[0] === "org.example.Browser", "dragging persists pinned order");
        ServiceDock.unpin("org.example.Browser");
        check(ServiceDock.pinned.length === 1 && ServiceDock.model.count === 3, "unpin keeps a running app in the model");

        const tray = { id: "org.example.Editor", title: "Editor", onlyMenu: false, activate: () => check(false, "tray should focus existing window") };
        const target = ServiceWindowActions.trayWindow(tray, null);
        check(target && target.id === 1, "tray restores last-focused window");
        check(ServiceWindowActions.activateTrayItem(tray) === "window", "tray action result");
        check(ServiceCompositor.focusedCalls.slice(-1)[0] === 1, "tray passes a valid window ID");

        Config.dockMerge = false;
        check(ServiceDock.model.count === 4, "unmerged windows retain pinned entry");
        Config.dockMerge = true;
        ServiceCompositor.windowList = [browser];
        check(ServiceDock.model.get(0).is_running === false, "closed pinned app stays visible");
        check(ServiceWindowActions.lastFocused["org.example.Editor"] === undefined, "closed window history removed");
        check(ServiceWindowActions.activateMediaPlayer({ desktopEntry: "missing-app", identity: "", dbusName: "", canRaise: true, raise: () => commandStage = 10 }), "media raise fallback");
        check(commandStage === 10, "MPRIS fallback invoked");
        commandStage = 0;
        ServiceApplications.markLaunching("org.example.Browser");
        ServiceApplications.updateLaunching();
        check(!ServiceApplications.isLaunching("org.example.Browser"), "running app clears launch state");
        ServiceApplications.launching = { "missing-app": Date.now() - 16000 };
        ServiceApplications.updateLaunching();
        check(!ServiceApplications.isLaunching("missing-app"), "launch state expires");
    }

    Component.onCompleted: Qt.callLater(() =>
    {
        check(Paths.settingsDir === Quickshell.env("XDG_CONFIG_HOME") + "/bloodyShell", "settings honor XDG_CONFIG_HOME");
        check(Paths.stateDir === Quickshell.env("XDG_CACHE_HOME") + "/bloodyShell", "state honors XDG_CACHE_HOME");
        check(Paths.shellDir + "/assets/wallpapers" === String(Quickshell.shellDir) + "/assets/wallpapers", "wallpapers follow checkout");
        check(Enums.EdgeRight === 3 && Enums.InFrame === 0 && Enums.OutFrame === 1, "frame styles and shared enum values are stable");
        checkDockAndWindows();
        ServiceApplications.launching = { earliest: Date.now() - 14900, later: Date.now() - 14500 };
        launchDeadline.start();
        MenuState.toggle("test.qml", widget);
        check(MenuState.menuActive, "menu opens");
        widget.active = false;
        check(!MenuState.menuActive, "inactive widget closes its menu");
        check(MenuState.menuWidget === null && MenuState.menuOwner === null, "menu references cleared");
        OverlayState.show("launcher");
        OverlayState.show("settings");
        OverlayState.show("power");
        overlayCheck.start();
        command.run(["/bin/sh", "-c", "printf 'detail\\nlast error\\n' >&2; exit 7"]);
        check(!command.run(["/bin/true"]), "busy command rejects concurrent start");
    })

    Timer
    {
        id: overlayCheck
        interval: 320
        onTriggered:
        {
            tests.check(!(OverlayState.mounted === "launcher") && !(OverlayState.mounted === "settings"), "rapid switching cleans every hidden overlay");
            tests.check((OverlayState.current === "power") && (OverlayState.mounted === "power"), "current overlay stays mounted");
            OverlayState.hide("power");
            OverlayState.show("power");
            OverlayState.show("unknown");
            OverlayState.hide("unknown");
            Config.launcherEnabled = false;
            OverlayState.show("launcher");
            reopenCheck.start();
        }
    }
    Timer
    {
        id: reopenCheck
        interval: 320
        onTriggered:
        {
            tests.check((OverlayState.current === "power") && (OverlayState.mounted === "power"), "reopened overlay survives pending cleanup");
            tests.check(!(OverlayState.current === "launcher"), "disabled launcher stays closed");
            tests.overlaysDone = true;
            tests.finish();
        }
    }

    Timer
    {
        id: launchDeadline
        interval: 250
        onTriggered:
        {
            tests.check(!ServiceApplications.isLaunching("earliest"), "earliest launch expires at its deadline");
            tests.check(ServiceApplications.isLaunching("later"), "later launch keeps its own deadline");
            finalDeadline.start();
        }
    }
    Timer
    {
        id: finalDeadline
        interval: 400
        onTriggered:
        {
            tests.check(!ServiceApplications.isLaunching("later"), "next launch expires without polling");
            tests.launchesDone = true;
            tests.finish();
        }
    }

    CommandProcess
    {
        id: command
        onCompleted: code =>
        {
            tests.commandCompletions++;
            tests.check(!busy, "completion clears command busy state");
            if (tests.commandStage === 0)
            {
                tests.check(code === 7 && errorText === "last error", "exit code and stderr captured");
                tests.commandStage = 1;
                Qt.callLater(() => command.run(["/definitely-missing-bloodyShell-test-command"]));
            }
            else if (tests.commandStage === 1)
            {
                tests.check(code === -1 && errorText === "", "missing binary completes without stale stderr");
                tests.commandStage = 2;
                Qt.callLater(() => command.run(["/bin/true"]));
            }
            else
            {
                if (tests.commandStage === 2)
                {
                    tests.check(code === 0, "command recovers after failed start");
                    tests.commandStage = 3;
                    Qt.callLater(() => command.run(["/bin/sh", "-c", "kill -TERM $$"]));
                }
                else
                {
                    tests.check(code === -1 && tests.commandCompletions === 4, "crashed command fails and completes once");
                    tests.commandsDone = true;
                    tests.finish();
                }
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("REGRESSION_FAILED timeout"); Qt.quit(); } }
}
