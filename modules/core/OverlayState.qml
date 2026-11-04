pragma Singleton

import QtQuick
import Quickshell

Singleton
{
    id: overlayState

    readonly property var windows: Registry.windows

    property bool helperActive: false
    property bool helperMounted: false

    property bool launcherActive: false
    property bool launcherMounted: false
    property bool settingsActive: false
    property bool settingsMounted: false
    property int settingsPage: 0
    property bool settingsPopup: false
    property bool powerActive: false
    property bool powerMounted: false
    property bool wallpapersActive: false
    property bool wallpapersMounted: false

    function show(name)
    {
        if (!windows.includes(name)) return;
        if (name === "launcher" && !Config.launcherEnabled) return;
        if (name === "helper") Config.set("helperSeen", true);
        MenuState.close();
        overlayState[name + "Mounted"] = true;
        overlayState[name + "Active"] = true;
        windows.forEach(w =>
        {
            if (w !== name) overlayState[w + "Active"] = false;
        });
        unmountTimer.restart();
    }

    function hide(name)
    {
        if (!windows.includes(name)) return;
        overlayState[name + "Active"] = false;
        unmountTimer.restart();
    }

    function toggle(name)
    {
        if (!windows.includes(name)) return;
        overlayState[name + "Active"] ? hide(name) : show(name);
    }

    Timer
    {
        id: unmountTimer
        interval: Config.animationsEnabled ? Theme.animationDurationClose + 50 : 0
        onTriggered: overlayState.windows.forEach(w =>
        {
            if (!overlayState[w + "Active"]) overlayState[w + "Mounted"] = false;
        })
    }
}
