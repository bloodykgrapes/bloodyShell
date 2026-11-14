pragma Singleton

import QtQuick
import Quickshell

import "../core"
import "../compositors" as Compositors

Singleton
{
    id: serviceCompositor

    readonly property string name: Quickshell.env("NIRI_SOCKET") || String(Quickshell.env("XDG_CURRENT_DESKTOP")).toLowerCase().split(":").includes("niri") ? "niri" : ""
    readonly property var backend: adapter.item
    readonly property bool available: backend !== null
    readonly property string displayName: backend ? backend.displayName : ""
    readonly property var capabilities: backend ? backend.capabilities : ({})
    readonly property var configFiles: backend ? backend.configFiles : ({})
    readonly property var versionCommand: backend ? backend.versionCommand : []
    readonly property var logoutCommand: backend ? backend.logoutCommand : []
    readonly property var workspacesList: backend ? backend.workspacesList : emptyWorkspaces
    readonly property string keyboardLayout: shortLayout(keyboardLayoutName)
    readonly property int workspaceRevision: backend ? backend.workspaceRevision : 0
    readonly property string focusedOutput: backend ? backend.focusedOutput : ""
    readonly property var focusedWorkspaceId: backend ? backend.focusedWorkspaceId : null
    readonly property var windowList: backend ? backend.windowList : []
    readonly property var windowLayouts: backend ? backend.windowLayouts : ({})
    readonly property var focusedWindowId: backend ? backend.focusedWindowId : null
    readonly property var lastWindowId: backend ? backend.lastWindowId : null
    readonly property var lastWindow: backend ? backend.lastWindow : null
    readonly property string windowTitle: backend ? backend.windowTitle : ""
    readonly property string windowAppId: backend ? backend.windowAppId : ""
    readonly property bool windowFocused: backend ? backend.windowFocused : false
    readonly property bool overviewOpen: backend ? backend.overviewOpen : false
    readonly property var fullscreenOutputs: backend ? backend.fullscreenOutputs : []
    readonly property var keyboardLayouts: backend ? backend.keyboardLayouts : []
    readonly property int keyboardLayoutIndex: backend ? backend.keyboardLayoutIndex : -1
    readonly property string keyboardLayoutName: backend ? backend.keyboardLayoutName : ""
    readonly property var captureStreams: backend ? backend.captureStreams : []

    ListModel { id: emptyWorkspaces }
    Loader
    {
        id: adapter
        active: serviceCompositor.name === "niri"
        sourceComponent: Compositors.Niri {}
    }

    function configuration(args) { return available ? Paths.commandFor("compositor", ["config", name].concat(args)) : []; }
    function supports(capability) { return capabilities[capability] === true; }
    function fullscreenOnOutput(name) { return fullscreenOutputs.includes(name); }
    function activeWorkspaceOnOutput(name) { return backend ? backend.activeWorkspaceOnOutput(name) : null; }
    function workspaceHasWindowsOnOutput(name) { return backend ? backend.workspaceHasWindowsOnOutput(name) : false; }
    function workspaceEmptyOnOutput(name) { return backend ? backend.workspaceEmptyOnOutput(name) : false; }
    function focusWindow(id) { if (supports("windows")) backend.focusWindow(id); }
    function closeWindow(id) { if (supports("windows")) backend.closeWindow(id); }
    function focusWorkspace(output, index) { if (supports("workspaces")) backend.focusWorkspace(output, index); }
    function focusWorkspaceRelative(output, step) { if (supports("workspaces")) backend.focusWorkspaceRelative(output, step); }
    function nextKeyboardLayout() { if (supports("keyboardLayout")) backend.nextKeyboardLayout(); }
    function setKeyboardLayout(index) { if (supports("keyboardLayout")) backend.setKeyboardLayout(index); }
    function powerOffMonitors() { if (supports("powerOutputs")) backend.powerOffMonitors(); }

    function shortLayout(name)
    {
        if (!name) return "";
        const langs =
        ({
            english: "EN", russian: "RU", ukrainian: "UA", belarusian: "BY", german: "DE", french: "FR",
            spanish: "ES", italian: "IT", portuguese: "PT", polish: "PL", czech: "CZ", turkish: "TR",
            japanese: "JP", korean: "KR", chinese: "ZH", arabic: "AR", hebrew: "HE", greek: "GR"
        });
        const word = name.split(" ")[0].toLowerCase();
        if (langs[word] !== undefined) return langs[word];
        const m = name.match(/\(([^)]+)\)/);
        return (m ? m[1] : name).slice(0, 2).toUpperCase();
    }

}
