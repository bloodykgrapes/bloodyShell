import QtQuick
import Quickshell.Io

import "../components"
import "../core"
import "../services"

Item
{
    id: keyboard

    required property var targetWindow

    Timer
    {
        interval: 0
        running: Config.initialized
        onTriggered: build.run(["python3", Paths.shellDir + "/scripts/build-keyboard-monitor"])
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
