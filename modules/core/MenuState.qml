pragma Singleton

import QtQuick
import Quickshell

import "../services"

Singleton
{
    id: menuState

    property var trayContextItem: null

    property string menuCurrent: ""
    property bool   menuActive: false
    property var    menuOwner: null
    property var    menuWidget: null
    property bool   menuKeyboard: false

    function toggle(menu, source)
    {
        const id = String(menu);

        if (Config.debug) console.log("[MENU] toggle menu (" + id + ") source (" + source +")");
        if (id === "") return;

        let p = source;
        while (p && !p.isIsland) p = p.parent;
        if (!p)
        {
            console.warn("MenuState: the widget has no island");
            return;
        }

        if (menuActive && menuOwner === p && menuCurrent === id)
        {
            close();
            return;
        }

        menuCurrent = id;
        menuKeyboard = false;
        menuActive = true;

        menuOwner = p;
        menuWidget = source;
    }
    function close()
    {
        if (Config.debug) console.log("[MENU] close");

        menuActive = false;
        menuWidget = null;
        menuOwner = null;
        menuCurrent = "";
        trayContextItem = null;
        menuKeyboard = false;
    }
    Connections
    {
        target: menuState.menuWidget
        ignoreUnknownSignals: true
        function onActiveChanged() { if (menuState.menuWidget && !menuState.menuWidget.active) menuState.close() }
    }

    property var menuFocusWindow: null
    Connections
    {
        target: ServiceCompositor
        enabled: menuState.menuActive

        function onFocusedWorkspaceIdChanged() { menuState.close() }
        function onOverviewOpenChanged() { menuState.close() }
        function onFocusedWindowIdChanged()
        {
            const id = ServiceCompositor.focusedWindowId;
            if (id !== null && id !== menuState.menuFocusWindow) menuState.close();
        }
    }

    onMenuActiveChanged: if (menuActive) menuFocusWindow = ServiceCompositor.focusedWindowId === null ? -1 : ServiceCompositor.focusedWindowId
}
