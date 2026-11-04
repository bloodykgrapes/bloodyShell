import QtQuick

import "../components"
import "../core"

Item
{
    Timer
    {
        interval: 0
        running: Config.initialized
        onTriggered: bindings.run(["bash", Paths.shellDir + "/scripts/alt-tab-bindings"])
    }

    CommandProcess
    {
        id: bindings
        onCompleted: code =>
        {
            if (code !== 0) console.warn("Alt+Tab bindings: " + bindings.errorMessage("Could not register niri bindings"));
        }
    }
}
