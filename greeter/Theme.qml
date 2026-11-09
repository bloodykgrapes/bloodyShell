pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton
{
    id: root

    readonly property string dir: Quickshell.env("BLOODYSHELL_CONFIG") || "/var/lib/bloodyShell"

    property int animationLevel: 1
    readonly property bool animationsEnabled: animationLevel >= 1
    readonly property bool animationsFluid: animationLevel >= 2
    property string wallpaperCurrent: ""
    property bool widgetClock24: true
    property string shellLanguage: "system"
    readonly property var locale: shellLanguage === "system" ? Qt.locale() : Qt.locale(shellLanguage)

    FileView
    {
        path: root.dir + "/settings.json"
        printErrors: false
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            let settings;
            try { settings = JSON.parse(text()) } catch (error) { return }
            for (const key of ["animationLevel", "wallpaperCurrent", "widgetClock24", "shellLanguage"])
                if (settings[key] !== undefined && typeof settings[key] === typeof root[key]) root[key] = settings[key];
        }
    }

    readonly property string fontText: "sans-serif"
    readonly property color text1: "#f5f5f7"
    readonly property color text2: "#a1a1aa"
    readonly property color surface: "#161618"
    readonly property color surfaceStrong: "#242428"
    readonly property color colorLine: "#3a3a40"
    readonly property color colorHover: "#2c2c32"
    readonly property color colorPressed: "#3a3a42"
    readonly property color colorField: "#101012"
    readonly property color colorFieldFocus: "#1b1b1f"
    readonly property color colorAccent: text1
    readonly property color colorSelection: "#45454d"
    readonly property color colorCritical: "#ff8585"

    readonly property var easingEmphasized: [0.16, 0.85, 0.2, 1.0, 1.0, 1.0]
    readonly property var easingAccelerate: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]

    function icon(name) { return Qt.resolvedUrl("icons/" + name + ".svg") }
    function power(action)
    {
        if (!powerProcess.running) powerProcess.exec(["systemctl", action]);
    }
    Process { id: powerProcess }
}
