pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../src/Kdl.js" as Kdl
import "../src/ModelSync.js" as ModelSync
import "../common"
import "../core"

Singleton
{
    id: serviceCompositor

    ListModel { id: workspaces }
    readonly property alias workspacesList: workspaces
    property int    workspaceRevision: 0
    property string focusedOutput: ""
    property var    focusedWorkspaceId: null

    readonly property bool focusedWorkspaceEmpty: focusedWorkspaceId !== null && !windowList.some(w => w.workspace_id === focusedWorkspaceId)

    property var windowList: []
    property var focusedWindowId: null
    property var lastWindowId: null

    readonly property var    lastWindow:    windowList.find(w => w.id === lastWindowId) || null
    readonly property string windowTitle:   lastWindow ? lastWindow.title : ""
    readonly property string windowAppId:   lastWindow ? lastWindow.app_id : ""
    readonly property bool   windowFocused: focusedWindowId !== null

    property bool overviewOpen: false

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

        if (e.WindowsChanged)        windowsApply(e.WindowsChanged.windows);
        if (e.WindowOpenedOrChanged) windowUpsert(e.WindowOpenedOrChanged.window);
        if (e.WindowClosed)          windowRemove(e.WindowClosed.id);
        if (e.WindowFocusChanged)    windowFocus(e.WindowFocusChanged.id);
        if (e.WindowUrgencyChanged)  windowSet(e.WindowUrgencyChanged.id, "is_urgent", e.WindowUrgencyChanged.urgent === true);

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
    function windowsApply(list)
    {
        windowList = list.map(windowRecord);
        if (lastWindowId !== null && !windowList.some(w => w.id === lastWindowId)) lastWindowId = null;
        const focused = windowList.find(w => w.is_focused);
        windowFocus(focused ? focused.id : null);
    }
    function windowUpsert(w)
    {
        const entry = windowRecord(w);
        const list = windowList.slice();
        const i = list.findIndex(x => x.id === entry.id);
        if (i >= 0 && JSON.stringify(list[i]) === JSON.stringify(entry)) return;
        if (i >= 0) list[i] = entry; else list.push(entry);
        windowList = list;
        if (entry.is_focused) windowFocus(entry.id);
    }
    function windowRemove(id)
    {
        if (!windowList.some(w => w.id === id)) return;
        windowList = windowList.filter(w => w.id !== id);
        if (focusedWindowId === id) focusedWindowId = null;
        if (lastWindowId === id) lastWindowId = null;
    }
    function windowFocus(id)
    {
        focusedWindowId = id === undefined ? null : id;
        if (focusedWindowId !== null) lastWindowId = focusedWindowId;
        let changed = false;
        const next = windowList.map(w =>
        {
            const focused = w.id === focusedWindowId;
            if (w.is_focused === focused) return w;
            changed = true;
            return Object.assign({}, w, { is_focused: focused });
        });
        if (changed) windowList = next;
    }

    function workspacesApply(list)
    {
        const sorted = list.slice().sort((a, b) => String(a.output).localeCompare(String(b.output)) || a.idx - b.idx);
        for (const w of sorted) if (w.is_focused) { focusedOutput = w.output || ""; focusedWorkspaceId = w.id; }

        const items = sorted.map(w => ({
            wsId: w.id, wsIdx: w.idx, output: w.output || "",
            focused: w.is_focused === true, activated: w.is_active === true, urgent: w.is_urgent === true
        }));
        if (ModelSync.sync(workspaces, items, "wsId")) workspaceRevision++;
    }

    function workspacesSet(id, key, value)
    {
        for (let i = 0; i < workspaces.count; i++) if (workspaces.get(i).wsId === id) { workspaces.setProperty(i, key, value); return }
    }
    function workspacesActivate(id, focused)
    {
        let output = null;
        for (let i = 0; i < workspaces.count; i++) if (workspaces.get(i).wsId === id) output = workspaces.get(i).output;
        if (output === null) return;

        for (let i = 0; i < workspaces.count; i++)
        {
            const it = workspaces.get(i), self = it.wsId === id;
            if (it.output === output && it.activated !== self) workspaces.setProperty(i, "activated", self);
            if (focused && it.focused !== self) workspaces.setProperty(i, "focused", self);
        }
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

    readonly property string dir: Paths.niriDir
    readonly property string helper: Paths.niriHelper

    readonly property string layoutName: "03-layout.kdl"
    readonly property string windowName: "04-window.kdl"
    readonly property string inputName: "01-input.kdl"

    property bool   focusRing: true
    property int    focusRingWidth: 2
    property string focusRingColor: ""
    property int    gaps: 16
    property bool   animations: true
    property bool   dimInactive: false
    property real   dimOpacity: 0.9
    property int    cornerRadius: 0
    property bool   focusFollowsMouse: false

    property bool   loaded: false
    property string error: ""

    function refresh() { layoutView.reload(); windowView.reload(); inputView.reload() }

    function setFocusRing(on)       { edit(layoutName, t => withFocusRing(t, (t, b) => on ? Kdl.removeNode(t, b, "off") : Kdl.setNode(t, b, "off", "off"))) }
    function setFocusRingWidth(w)   { edit(layoutName, t => withFocusRing(t, (t, b) => Kdl.setNode(t, b, "width", "width " + Math.round(w)))) }

    function setAccent(color)       { edit(layoutName, t => withFocusRing(t, (t, b) => Kdl.setNode(t, b, "active-color", "active-color " + Kdl.quote(color)))) }
    function setGaps(px)            { edit(layoutName, t => withBlock(t, ["layout"], (t, b) => Kdl.setNode(t, b, "gaps", "gaps " + Math.round(px)))) }
    function setAnimations(on)      { edit(layoutName, t => withBlock(t, ["animations"], (t, b) => on ? Kdl.removeNode(t, b, "off") : Kdl.setNode(t, b, "off", "off"))) }
    function setFocusFollowsMouse(on) { edit(inputName, t => withBlock(t, ["input"], (t, b) => on ? Kdl.setNode(t, b, "focus-follows-mouse", "focus-follows-mouse") : Kdl.removeNode(t, b, "focus-follows-mouse"))) }

    function setCornerRadius(px)
    {
        edit(windowName, t =>
        {
            const rule = generalRule(t);
            if (rule) return Kdl.setNode(t, rule, "geometry-corner-radius", "geometry-corner-radius " + Math.round(px));
            return t.replace(/\s*$/, "") + "\n\nwindow-rule {\n    geometry-corner-radius " + Math.round(px) + "\n    clip-to-geometry true\n}\n";
        });
    }
    function setDimInactive(on)
    {
        edit(windowName, t =>
        {
            const rule = dimRule(t);
            if (on)
            {
                if (rule) return Kdl.setNode(t, rule, "opacity", "opacity " + number(dimOpacity));
                return t.replace(/\s*$/, "") + "\n\nwindow-rule {\n    match is-active=false\n    opacity " + number(dimOpacity) + "\n}\n";
            }
            if (!rule) return t;

            const own = Kdl.topLines(t, rule).filter(l => l.text.trim() !== "" && !Kdl.isComment(l.text));
            const onlyDim = own.every(l => /^\s*(match\s+is-active=false|opacity\b)/.test(l.text));
            if (!onlyDim) return Kdl.removeNode(t, rule, "opacity");
            const before = t.substring(0, rule.start).replace(/\s*$/, "");
            const after = t.substring(rule.close + 1).replace(/^\s*/, "");
            return before + (after !== "" ? "\n\n" + after : "\n");
        });
    }
    function setDimOpacity(value)
    {
        dimOpacity = value;
        edit(windowName, t => { const rule = dimRule(t); return rule ? Kdl.setNode(t, rule, "opacity", "opacity " + number(value)) : t });
    }

    function number(v) { return String(Math.round(v * 100) / 100) }

    function withBlock(text, path, fn)
    {
        let parent = null;
        for (const name of path)
        {
            const block = parent ? Kdl.findBlock(text, name, parent.open, parent.close) : Kdl.findBlock(text, name, 0);
            if (!block)
            {
                if (parent)
                {
                    const indent = parent.indent + "    ";
                    const head = text.substring(0, parent.close).replace(/[ \t]*$/, "");
                    text = head + indent + name + " {\n" + indent + "}\n" + parent.indent + text.substring(parent.close);
                }
                else text = text.replace(/\s*$/, "") + "\n\n" + name + " {\n}\n";
                return withBlock(text, path, fn);
            }
            parent = block;
        }
        return fn(text, parent);
    }
    function withFocusRing(text, fn) { return withBlock(text, ["layout", "focus-ring"], fn) }

    function generalRule(text)
    {
        return Kdl.findBlocks(text, "window-rule", 0).find(r => !Kdl.topLines(text, r).some(l => /^\s*match\b/.test(l.text))) || null;
    }
    function dimRule(text)
    {
        return Kdl.findBlocks(text, "window-rule", 0).find(r => Kdl.topLines(text, r).some(l => /^\s*match\s+is-active=false\s*$/.test(l.text))) || null;
    }

    property var drafts: ({})
    property var ready: ({})
    property var queued: []

    function current(name)
    {
        if (drafts[name] !== undefined) return drafts[name];
        return name === layoutName ? layoutView.loadedText : name === windowName ? windowView.loadedText : inputView.loadedText;
    }

    function edit(name, fn)
    {
        if (!ready[name]) { queued = queued.concat([[name, fn]]); return; }
        const base = current(name);
        const next = fn(base);
        if (next === base) return;
        const all = Object.assign({}, drafts);
        all[name] = next;
        drafts = all;
        error = "";
        parse(name, next);
        flush.restart();
    }

    Timer
    {
        id: flush
        interval: 350
        onTriggered:
        {
            if (writer.busy) { restart(); return; }
            const names = Object.keys(serviceCompositor.drafts);
            if (names.length === 0) return;
            const name = names[0];
            const all = Object.assign({}, serviceCompositor.drafts);
            const text = all[name];
            delete all[name];
            serviceCompositor.drafts = all;
            writer.run([serviceCompositor.helper, "write", name, text.replace(/\s*$/, "")]);
        }
    }

    CommandProcess
    {
        id: writer
        onCompleted: code =>
        {
            if (code !== 0)
            {
                serviceCompositor.error = writer.errorMessage(Tr.tr("service.compositor.saveFailed"));
                serviceCompositor.refresh();
            }
            if (Object.keys(serviceCompositor.drafts).length > 0) flush.restart();
        }
    }

    function parse(name, text)
    {
        if (name === layoutName)
        {
            const layout = Kdl.findBlock(text, "layout", 0);
            const ring = layout ? Kdl.findBlock(text, "focus-ring", layout.open, layout.close) : null;
            const anim = Kdl.findBlock(text, "animations", 0);
            gaps = layout ? parseInt(Kdl.value(text, layout, "gaps") || "16", 10) : 16;
            focusRing = ring ? Kdl.value(text, ring, "off") === null : true;
            focusRingWidth = ring ? parseInt(Kdl.value(text, ring, "width") || "4", 10) : 4;
            focusRingColor = ring ? (Kdl.value(text, ring, "active-color") || "") : "";
            animations = anim ? Kdl.value(text, anim, "off") === null : true;
        }
        else if (name === windowName)
        {
            const general = generalRule(text), dim = dimRule(text);
            cornerRadius = general ? parseInt(Kdl.value(text, general, "geometry-corner-radius") || "0", 10) : 0;
            const opacity = dim ? Kdl.value(text, dim, "opacity") : null;
            dimInactive = opacity !== null && parseFloat(opacity) < 1;
            if (opacity !== null) dimOpacity = parseFloat(opacity);
        }
        else
        {
            const input = Kdl.findBlock(text, "input", 0);
            focusFollowsMouse = input ? Kdl.value(text, input, "focus-follows-mouse") !== null : false;
        }
    }

    component NiriFile: FileView
    {
        required property string name
        property string loadedText: ""
        path: serviceCompositor.dir + "/" + name
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            loadedText = text();
            serviceCompositor.parse(name, loadedText);
            serviceCompositor.loaded = true;
            if (serviceCompositor.ready[name]) return;
            const all = Object.assign({}, serviceCompositor.ready);
            all[name] = true;
            serviceCompositor.ready = all;
            const waiting = serviceCompositor.queued.filter(q => q[0] === name);
            serviceCompositor.queued = serviceCompositor.queued.filter(q => q[0] !== name);
            for (const q of waiting) serviceCompositor.edit(q[0], q[1]);
        }
    }

    NiriFile { id: layoutView; name: serviceCompositor.layoutName }
    NiriFile { id: windowView; name: serviceCompositor.windowName }
    NiriFile { id: inputView; name: serviceCompositor.inputName }

    readonly property string accent:     String(Theme.colorAccent)
    onAccentChanged:     setAccent(accent)
}
