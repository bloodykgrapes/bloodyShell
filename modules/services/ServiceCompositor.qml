pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../src/ModelSync.js" as ModelSync
import "../src/WindowLayout.js" as WindowLayout

Singleton
{
    id: serviceCompositor

    ListModel { id: workspaces }
    readonly property alias workspacesList: workspaces
    property int    workspaceRevision: 0
    property string focusedOutput: ""
    property var    focusedWorkspaceId: null

    property var windowList: []
    property var windowLayouts: ({})
    property var focusedWindowId: null
    property var lastWindowId: null

    readonly property var    lastWindow:    windowList.find(w => w.id === lastWindowId) || null
    readonly property string windowTitle:   lastWindow ? lastWindow.title : ""
    readonly property string windowAppId:   lastWindow ? lastWindow.app_id : ""
    readonly property bool   windowFocused: focusedWindowId !== null

    property bool overviewOpen: false
    property var fullscreenCache: ({outputs: []})
    readonly property var fullscreenOutputs: fullscreenScreens(Quickshell.screens)

    function fullscreenOnOutput(name) { return fullscreenOutputs.includes(name) }
    function activeWorkspaceOnOutput(name)
    {
        void workspaceRevision;
        for (let i = 0; i < workspaces.count; i++)
        {
            const workspace = workspaces.get(i);
            if (workspace.output === name && workspace.activated)
                return workspace;
        }
        return null;
    }

    function workspaceHasWindowsOnOutput(name)
    {
        const workspace = activeWorkspaceOnOutput(name);
        return workspace !== null && windowList.some(window => window.workspace_id === workspace.wsId);
    }

    function workspaceEmptyOnOutput(name)
    {
        const workspace = activeWorkspaceOnOutput(name);
        return workspace !== null && !windowList.some(window => window.workspace_id === workspace.wsId);
    }

    function fullscreenScreens(outputs)
    {
        void workspaceRevision;
        return WindowLayout.fullscreen(outputs, workspaces, windowList, windowLayouts, overviewOpen, fullscreenCache);
    }

    function layoutsApply(changes, replace = false)
    {
        const next = WindowLayout.update(windowLayouts, changes, replace);
        if (next !== windowLayouts) windowLayouts = next;
    }

    property var keyboardLayouts: []
    property int keyboardLayoutIndex: -1

    readonly property string keyboardLayoutName: keyboardLayouts[keyboardLayoutIndex] || ""
    readonly property string keyboardLayout:     shortLayout(keyboardLayoutName)

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

    function validWindowId(id) { return id !== -1 && id !== "" && id !== null && id !== undefined }

    function action(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)) }

    function nextKeyboardLayout()     { if (keyboardLayouts.length > 1) action(["switch-layout", "next"]) }
    function setKeyboardLayout(index) { if (index >= 0 && index < keyboardLayouts.length && index !== keyboardLayoutIndex) action(["switch-layout", String(index)]) }
    function focusWindow(id)          { if (validWindowId(id)) action(["focus-window", "--id", String(id)]) }
    function closeWindow(id)          { if (validWindowId(id)) action(["close-window", "--id", String(id)]) }

    function onOutput(output, args)
    {
        const target = output && output !== focusedOutput ? output : "";
        if (!target) { action(args); return; }
        Quickshell.execDetached(["sh", "-c", "[ -z \"$1\" ] || niri msg action focus-monitor \"$1\"; shift; exec niri msg action \"$@\"", "sh", target].concat(args));
    }
    function focusWorkspace(output, index)        { if (index >= 1) onOutput(output, ["focus-workspace", String(index)]) }
    function focusWorkspaceRelative(output, step) { if (step !== 0) onOutput(output, [step > 0 ? "focus-workspace-down" : "focus-workspace-up"]) }

    function event(line)
    {
        let e;
        try { e = JSON.parse(line) } catch (err) { return }

        if (e.WorkspacesChanged)       workspacesApply(e.WorkspacesChanged.workspaces);
        if (e.WorkspaceActivated)      workspacesActivate(e.WorkspaceActivated.id, e.WorkspaceActivated.focused === true);
        if (e.WorkspaceUrgencyChanged) workspacesSet(e.WorkspaceUrgencyChanged.id, "urgent", e.WorkspaceUrgencyChanged.urgent === true);
        if (e.WorkspaceActiveWindowChanged) workspacesSet(e.WorkspaceActiveWindowChanged.workspace_id, "activeWindowId", e.WorkspaceActiveWindowChanged.active_window_id ?? -1);

        if (e.WindowsChanged)        windowsApply(e.WindowsChanged.windows);
        if (e.WindowOpenedOrChanged) windowUpsert(e.WindowOpenedOrChanged.window);
        if (e.WindowClosed)          windowRemove(e.WindowClosed.id);
        if (e.WindowFocusChanged)    windowFocus(e.WindowFocusChanged.id);
        if (e.WindowUrgencyChanged)  windowSet(e.WindowUrgencyChanged.id, "is_urgent", e.WindowUrgencyChanged.urgent === true);
        if (e.WindowLayoutsChanged)  layoutsApply(e.WindowLayoutsChanged.changes);

        if (e.OverviewOpenedOrClosed) overviewOpen = e.OverviewOpenedOrClosed.is_open === true;

        if (e.KeyboardLayoutsChanged)
        {
            keyboardLayouts = e.KeyboardLayoutsChanged.keyboard_layouts.names;
            keyboardLayoutIndex = e.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        }
        if (e.KeyboardLayoutSwitched) keyboardLayoutIndex = e.KeyboardLayoutSwitched.idx;
    }

    function windowRecord(w)
    {
        return {
            id:           w.id,
            app_id:       w.app_id || "",
            title:        w.title || "",
            workspace_id: w.workspace_id !== undefined ? w.workspace_id : null,
            is_focused:   w.is_focused === true,
            is_urgent:    w.is_urgent === true
        };
    }
    function windowSet(id, key, value)
    {
        const index = windowList.findIndex(w => w.id === id);
        if (index < 0 || windowList[index][key] === value) return;
        const next = windowList.slice();
        next[index] = Object.assign({}, next[index], { [key]: value });
        windowList = next;
    }
    function sameWindow(a, b)
    {
        return a.id === b.id && a.app_id === b.app_id && a.title === b.title
            && a.workspace_id === b.workspace_id && a.is_focused === b.is_focused && a.is_urgent === b.is_urgent;
    }
    function windowsApply(list)
    {
        layoutsApply(list.map(window => [window.id, window.layout]), true);
        const previous = new Map(windowList.map(window => [window.id, window]));
        let focused = null;
        const next = list.map(window =>
        {
            const entry = windowRecord(window);
            if (entry.is_focused)
            {
                if (focused === null) focused = entry.id;
                else entry.is_focused = false;
            }
            const old = previous.get(entry.id);
            return old && sameWindow(old, entry) ? old : entry;
        });
        if (next.length !== windowList.length || next.some((window, index) => window !== windowList[index])) windowList = next;
        if (lastWindowId !== null && !windowList.some(w => w.id === lastWindowId)) lastWindowId = null;
        windowFocus(focused);
    }
    function windowUpsert(w)
    {
        if (w.layout !== undefined) layoutsApply([[w.id, w.layout]]);
        const entry = windowRecord(w);
        const i = windowList.findIndex(x => x.id === entry.id);
        if (i >= 0 && sameWindow(windowList[i], entry)) return;
        const list = windowList.slice();
        if (i >= 0) list[i] = entry; else list.push(entry);
        windowList = list;
        if (entry.is_focused) windowFocus(entry.id);
    }
    function windowRemove(id)
    {
        if (windowLayouts[id])
        {
            const layouts = Object.assign({}, windowLayouts);
            delete layouts[id];
            windowLayouts = layouts;
        }
        const index = windowList.findIndex(w => w.id === id);
        if (index < 0) return;
        const next = windowList.slice();
        next.splice(index, 1);
        windowList = next;
        if (focusedWindowId === id) focusedWindowId = null;
        if (lastWindowId === id) lastWindowId = null;
    }
    function windowFocus(id)
    {
        focusedWindowId = id === undefined ? null : id;
        if (focusedWindowId !== null) lastWindowId = focusedWindowId;
        let next = null;
        for (let i = 0; i < windowList.length; i++)
        {
            const w = windowList[i];
            const focused = w.id === focusedWindowId;
            if (w.is_focused === focused) continue;
            if (next === null) next = windowList.slice();
            next[i] = Object.assign({}, w, { is_focused: focused });
        }
        if (next !== null) windowList = next;
    }

    function workspacesApply(list)
    {
        const sorted = list.slice().sort((a, b) => String(a.output).localeCompare(String(b.output)) || a.idx - b.idx);
        for (const w of sorted) if (w.is_focused) { focusedOutput = w.output || ""; focusedWorkspaceId = w.id; }

        const items = sorted.map(w => ({
            wsId: w.id, wsIdx: w.idx, output: w.output || "",
            focused: w.is_focused === true, activated: w.is_active === true, urgent: w.is_urgent === true,
            activeWindowId: w.active_window_id ?? -1
        }));
        if (ModelSync.sync(workspaces, items, "wsId")) workspaceRevision++;
    }

    function workspacesSet(id, key, value)
    {
        for (let i = 0; i < workspaces.count; i++)
        {
            if (workspaces.get(i).wsId !== id) continue;
            if (workspaces.get(i)[key] !== value) { workspaces.setProperty(i, key, value); workspaceRevision++; }
            return;
        }
    }
    function workspacesActivate(id, focused)
    {
        let output = null;
        for (let i = 0; i < workspaces.count; i++) if (workspaces.get(i).wsId === id) output = workspaces.get(i).output;
        if (output === null) return;

        let changed = false;
        for (let i = 0; i < workspaces.count; i++)
        {
            const it = workspaces.get(i), self = it.wsId === id;
            if (it.output === output && it.activated !== self) { workspaces.setProperty(i, "activated", self); changed = true; }
            if (focused && it.focused !== self) { workspaces.setProperty(i, "focused", self); changed = true; }
        }
        if (changed) workspaceRevision++;
        if (focused) { focusedOutput = output; focusedWorkspaceId = id; }
    }

    Process
    {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser { onRead: line => serviceCompositor.event(line) }
        onExited: restream.restart()
    }
    Timer { id: restream; interval: 2000; onTriggered: stream.running = true }

}
