pragma Singleton

import QtQuick
import Quickshell

import "../core"

Singleton
{
    id: serviceAltTab

    property bool active: false
    property bool delayElapsed: false
    readonly property bool presented: active && delayElapsed

    property var history: []
    property var windows: []
    property int selected: 0
    property string output: ""
    property var requestedFocus: null
    property var pendingFocus: null

    function focusSelection()
    {
        if (!active) return;
        const id = windows[selected]?.id;
        if (id === requestedFocus || !ServiceCompositor.windowList.some(w => w.id === id)) return;
        requestedFocus = id;
        pendingFocus = id;
        ServiceCompositor.focusWindow(id);
    }

    function remember()
    {
        const live = ServiceCompositor.windowList;
        const byId = new Map(live.map(window => [window.id, window]));
        let next = history.filter(id => byId.has(id));
        if (pendingFocus !== null && !byId.has(pendingFocus)) pendingFocus = null;
        const focused = pendingFocus !== null ? pendingFocus : ServiceCompositor.focusedWindowId;
        if (byId.has(focused) && next[0] !== focused) next = [focused].concat(next.filter(id => id !== focused));
        if (!active)
        {
            if (next.length !== history.length || next.some((id, index) => id !== history[index])) history = next;
            return byId;
        }
        const id = windows[selected]?.id;
        const updated = windows.map(w => byId.get(w.id)).filter(w => w);
        if (updated.length !== windows.length || updated.some((window, index) => window !== windows[index])) windows = updated;
        if (!windows.length) { cancel(); return byId; }
        const index = windows.findIndex(w => w.id === id);
        selected = index >= 0 ? index : Math.min(selected, windows.length - 1);
        focusSelection();
        return byId;
    }

    function select(index)
    {
        if (!active || !Number.isInteger(index) || index < 0 || index >= windows.length) return;
        selected = index;
    }

    function cycle(step)
    {
        step = Math.trunc(step);
        if (!Number.isFinite(step) || step === 0) return;
        if (ServiceLock.locked || OverlayState.inhibited || !Config.initialized) return;
        if (!active)
        {
            const byId = remember();
            const live = ServiceCompositor.windowList;
            const known = new Set(history);
            windows = history.map(id => byId.get(id)).filter(w => w)
                .concat(live.filter(w => !known.has(w.id)));
            if (windows.length < 2) return;
            output = ServiceCompositor.focusedOutput;
            selected = step < 0 ? windows.length - 1 : Math.min(1, windows.length - 1);
            OverlayState.close();
            MenuState.close();
            requestedFocus = null;
            active = true;
            focusSelection();
        }
        else
        {
            select(((selected + step) % windows.length + windows.length) % windows.length);
        }
    }

    function confirm() { if (active) cancel(); }

    function cancel()
    {
        if (!active) return;
        active = false;
        remember();
    }

    onActiveChanged:
    {
        delayElapsed = false;
        if (active) reveal.restart();
        else reveal.stop();
    }

    onSelectedChanged:
    {
        focusSelection();
    }

    Connections
    {
        target: ServiceCompositor
        function onWindowListChanged() { serviceAltTab.remember() }
        function onFocusedWindowIdChanged()
        {
            if (ServiceCompositor.focusedWindowId === serviceAltTab.pendingFocus) serviceAltTab.pendingFocus = null;
            serviceAltTab.remember();
        }
    }
    Connections
    {
        target: ServiceLock
        function onLockedChanged() { if (ServiceLock.locked) serviceAltTab.cancel() }
    }
    Connections
    {
        target: OverlayState
        function onCurrentChanged() { if (OverlayState.active) serviceAltTab.cancel() }
        function onInhibitedChanged() { if (OverlayState.inhibited) serviceAltTab.cancel() }
    }

    Timer
    {
        id: reveal
        interval: 300
        onTriggered: if (serviceAltTab.active) serviceAltTab.delayElapsed = true
    }
}
