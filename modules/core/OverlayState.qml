pragma Singleton

import QtQuick
import Quickshell

import "../animations/OverlayMotion.js" as Motion
import "../src/Clients.js" as Clients

Singleton
{
    id: overlayState

    readonly property var windows: Registry.windows
    readonly property int closeDuration: Config.animationsFluid ? Motion.fluidCloseDuration : Theme.animationDurationClose
    property string current: ""
    property string mounted: ""
    property string stacked: ""
    property string wallpaperTarget: "desktop"
    readonly property bool active: current !== ""
    property bool inhibited: false

    property int settingsPage: 0
    property var popupClients: []
    readonly property bool settingsPopup: popupClients.length > 0
    property bool popupsSuspended: false
    property string screenName: ""
    property point origin: Qt.point(0, 0)

    function setPopupActive(client, active)
    {
        popupClients = Clients.update(popupClients, client, active);
    }

    function show(name, target = "desktop")
    {
        if (inhibited) return;
        if (!windows.includes(name) && name !== "desktopMenu") return;
        if (name === "wallpapers") wallpaperTarget = target;
        if (name === "helper") Config.set("helperSeen", true);
        MenuState.close();
        unmountTimer.stop();
        if (name === current) return;
        stackedUnmountTimer.stop();
        if (name === "wallpapers" && active)
        {
            stacked = name;
            current = name;
            return;
        }
        if (stacked !== "" && name === mounted && active)
        {
            current = name;
            stackedUnmountTimer.restart();
            return;
        }
        stacked = "";
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
        if (name === stacked && mounted !== "")
        {
            current = mounted;
            stackedUnmountTimer.restart();
        }
        else close();
    }

    function close()
    {
        if (!active) return;
        current = "";
        stackedUnmountTimer.stop();
        unmountTimer.restart();
    }

    function toggle(name) { current === name ? hide(name) : show(name) }

    Timer
    {
        id: unmountTimer
        interval: Config.animationsEnabled ? overlayState.closeDuration + 50 : 0
        onTriggered: if (!overlayState.active) { overlayState.stacked = ""; overlayState.mounted = ""; }
    }
    Timer
    {
        id: stackedUnmountTimer
        interval: Config.animationsEnabled ? overlayState.closeDuration + 50 : 0
        onTriggered: if (overlayState.current !== overlayState.stacked) overlayState.stacked = ""
    }
}
