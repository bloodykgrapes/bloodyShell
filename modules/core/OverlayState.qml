pragma Singleton

import QtQuick
import Quickshell

Singleton
{
    id: overlayState

    readonly property var windows: Registry.windows
    property string current: ""
    property string mounted: ""
    readonly property bool active: current !== ""
    property bool inhibited: false

    property int settingsPage: 0
    property bool settingsPopup: false
    property string screenName: ""
    property point origin: Qt.point(0, 0)

    function show(name)
    {
        if (inhibited) return;
        if (!windows.includes(name) && name !== "desktopMenu") return;
        if (name === "launcher" && !Config.launcherEnabled) return;
        if (name === "helper") Config.set("helperSeen", true);
        MenuState.close();
        unmountTimer.stop();
        if (name !== "desktopMenu") screenName = "";
        mounted = name;
        current = name;
    }

    function showDesktopMenu(screen, x, y)
    {
        screenName = screen;
        origin = Qt.point(x, y);
        show("desktopMenu");
    }

    function hide(name)
    {
        if (name !== current) return;
        current = "";
        unmountTimer.restart();
    }

    function close() { if (active) hide(current) }

    function toggle(name) { current === name ? hide(name) : show(name) }

    Timer
    {
        id: unmountTimer
        interval: Config.animationsEnabled ? Theme.animationDurationClose + 50 : 0
        onTriggered: if (!overlayState.active) overlayState.mounted = ""
    }
}
