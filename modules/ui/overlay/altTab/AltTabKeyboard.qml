import QtQuick
import QtQuick.Window
import Quickshell.Io

import "../../../common"
import "../../../core"
import "../../../services"

Item
{
    id: keyboard

    readonly property var targetWindow: keyboard.Window.window

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
        function begin(reverse: bool): void { ServiceAltTab.cycle(reverse ? -1 : 1) }
    }

    Timer
    {
        interval: 0
        running: Config.initialized
        onTriggered: build.run(["python3", Paths.runtimeScriptsDir + "/build-keyboard-monitor"])
    }

    CommandProcess
    {
        id: build
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code === 0) monitor.source = result.text.trim();
            else console.warn("Alt+Tab keyboard monitor: " + errorMessage("Could not load Qt keyboard state monitor"));
        }
    }

    Loader { id: monitor }

    Binding
    {
        target: monitor.item
        property: "targetWindow"
        value: keyboard.targetWindow
        when: monitor.status === Loader.Ready
    }
    Binding
    {
        target: monitor.item
        property: "listening"
        value: ServiceAltTab.active
        when: monitor.status === Loader.Ready
    }

    Connections
    {
        target: monitor.item
        function onReleased() { ServiceAltTab.confirm() }
    }
}
