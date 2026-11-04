pragma Singleton

import QtQuick
import Quickshell

import "../core"
import "../src/AppIdentity.js" as AppIdentity

Singleton
{
    id: serviceDock

    property alias model: dockModel
    ListModel { id: dockModel }

    property var pinned: Config.dockPinned.slice()
    property var unpinned: []
    property var windowsCache: []
    property var seenAt: ({})
    property string focusedKey: ""

    function itemKey(item)
    {
        if (item.type === "separator") return "separator";
        return (item.is_pinned ? "pinned:" : "app:") + item.key;
    }

    function update(runningWindows)
    {
        const list = Array.isArray(runningWindows) ? runningWindows : [];
        windowsCache = list.slice();

        const merge = Config.dockMerge !== false;

        const byApp = {};
        const appOrder = [];

        for (let i = 0; i < list.length; i++)
        {
            const w = list[i];
            const k = AppIdentity.appKey(w);

            if (!byApp[k]) { byApp[k] = []; appOrder.push(k); }
            byApp[k].push(w);
        }

        const focusedNow = (list.find(w => w.is_focused === true) || null);
        const newFocusedKey = focusedNow ? AppIdentity.appKey(focusedNow) : "";
        if (newFocusedKey !== focusedKey)
        {
            const seen = Object.assign({}, seenAt);
            if (focusedKey !== "") seen[focusedKey] = Date.now();
            if (newFocusedKey !== "") seen[newFocusedKey] = Date.now();
            seenAt = seen;
            focusedKey = newFocusedKey;
        }

        for (const k of appOrder) byApp[k].sort((a, b) => Number(a.id) - Number(b.id));

        const makeItem = (key, wins, pinned) =>
        {
            const focused = wins.find(w => w.is_focused === true);
            const last = wins.find(w => w.id === ServiceWindowActions.lastFocused[key]);
            const shown = focused || last || wins[0];

            return {
                type: "app",
                key: key,
                id: shown ? String(shown.id) : "",
                app_id: shown && !pinned ? (shown.app_id || "") : key,
                title: shown ? (shown.title || shown.app_id || key) : key,
                is_focused: !!focused,
                is_pinned: pinned,
                is_running: wins.length > 0,
                is_urgent: wins.some(w => w.is_urgent === true),
                count: wins.length,
                windows: JSON.stringify(wins.map(w => ({ id: w.id, title: w.title || w.app_id || key, focused: w.is_focused === true, urgent: w.is_urgent === true }))),
                focused_index: focused ? wins.indexOf(focused) : -1
            };
        };

        const newItems = [];

        for (let i = 0; i < pinned.length; i++)
        {
            const wins = byApp[pinned[i]] || [];
            newItems.push(makeItem(pinned[i], merge ? wins : wins.slice(0, 1), true));
        }

        const groups = [];

        for (const k of appOrder)
        {
            const wins = byApp[k];
            const isPinned = pinned.includes(k);

            if (merge)
            {
                if (!isPinned) groups.push({ key: k, wins: wins });
                continue;
            }

            for (const w of wins.slice(isPinned ? 1 : 0)) groups.push({ key: "win:" + w.id, wins: [w] });
        }

        const orderOf = key =>
        {
            const idx = unpinned.indexOf(key);
            return idx < 0 ? 1e9 + groups.findIndex(g => g.key === key) : idx;
        };
        groups.sort((a, b) => orderOf(a.key) - orderOf(b.key));

        if (groups.length > 0)
        {
            newItems.push({ type: "separator" });
            for (const g of groups) newItems.push(makeItem(g.key, g.wins, false));
        }

        unpinned = groups.map(g => g.key);
        sync(newItems);
    }

    function sync(newItems)
    {
        const fields = ["type", "key", "app_id", "id", "title", "is_running", "is_urgent", "is_focused", "is_pinned", "count", "windows", "focused_index"];

        for (let target = 0; target < newItems.length; target++)
        {
            const incoming = newItems[target];
            const incomingKey = itemKey(incoming);
            let found = -1;

            for (let i = target; i < dockModel.count; i++)
            {
                if (itemKey(dockModel.get(i)) === incomingKey) { found = i; break; }
            }

            if (found < 0) dockModel.insert(target, incoming);
            else
            {
                if (found !== target) dockModel.move(found, target, 1);
                if (incoming.type === "separator") continue;

                const oldItem = dockModel.get(target);
                if (fields.some(f => oldItem[f] !== incoming[f])) dockModel.set(target, incoming);
            }
        }
        while (dockModel.count > newItems.length) dockModel.remove(dockModel.count - 1);
    }

    function move(from, to)
    {
        if (from === to || from < 0 || to < 0 || from >= dockModel.count || to >= dockModel.count) return;
        const pc = pinned.length;
        const groupOf = i => i < pc ? 0 : (i === pc && dockModel.get(i).type === "separator" ? -1 : 1);
        const fromGroup = groupOf(from), toGroup = groupOf(to);
        if (fromGroup < 0 || toGroup < 0 || fromGroup !== toGroup) return;

        dockModel.move(from, to, 1);
        const nextPinned = [], nextUnpinned = [];
        for (let i = 0; i < dockModel.count; i++)
        {
            const item = dockModel.get(i);
            if (item.type !== "app") continue;
            if (item.is_pinned) nextPinned.push(item.app_id);
            else nextUnpinned.push(item.key);
        }
        pinned = nextPinned;
        Config.set("dockPinned", nextPinned);
        unpinned = nextUnpinned;
        update(windowsCache);
    }

    function windowList(item)
    {
        try { return JSON.parse(item.windows || "[]"); }
        catch (e) { return []; }
    }

    function windowIds(item) { return windowList(item).map(w => w.id); }

    function activateApp(item)
    {
        const ids = windowIds(item);

        if (ids.length === 0) { ServiceApplications.launch(item.app_id); return; }
        if (ids.length === 1) { ServiceCompositor.focusWindow(ids[0]); return; }

        if (item.focused_index >= 0) ServiceCompositor.focusWindow(ids[(item.focused_index + 1) % ids.length]);
        else ServiceCompositor.focusWindow(item.id);
    }

    function cycleWindow(item, step)
    {
        const ids = windowIds(item);
        if (ids.length < 2) return;

        const i = item.focused_index >= 0 ? item.focused_index : 0;
        ServiceCompositor.focusWindow(ids[(i + step + ids.length) % ids.length]);
    }

    function pinAt(appId, index)
    {
        if (!appId || appId.startsWith("id:") || appId.startsWith("win:")) return;
        const list = pinned.filter(k => k !== appId);
        list.splice(Math.max(0, Math.min(list.length, index)), 0, appId);
        pinned = list;
        Config.set("dockPinned", list);
        update(windowsCache);
    }

    function unpin(appId)
    {
        if (!pinned.includes(appId)) return;
        const list = pinned.filter(k => k !== appId);
        pinned = list;
        Config.set("dockPinned", list);
        update(windowsCache);
    }

    function isPinned(appId) { return pinned.includes(appId) }

    function badgeCount(appId)
    {
        if (!appId || appId.startsWith("id:")) return 0;
        const seen = seenAt[appId] || 0;
        const times = ServiceNotifications.receivedAt;
        let count = 0;
        for (const n of ServiceNotifications.history)
            if ((times[n.id] || 0) > seen && ServiceApplications.notificationFrom(n, appId)) count++;
        return count;
    }

    function togglePin(appId)
    {
        if (!appId) return;
        const list = pinned.slice();
        const index = list.indexOf(appId);
        if (index >= 0) list.splice(index, 1);
        else list.push(appId);
        pinned = list;
        Config.set("dockPinned", list);
        update(windowsCache);
    }

    function closeAll(item)
    {
        for (const id of windowIds(item)) ServiceCompositor.closeWindow(id);
    }

    Connections
    {
        target: ServiceCompositor
        function onWindowListChanged() { serviceDock.update(ServiceCompositor.windowList) }
    }

    Connections
    {
        target: Config
        function onDockMergeChanged() { serviceDock.update(serviceDock.windowsCache) }
        function onDockPinnedChanged()
        {
            serviceDock.pinned = Config.dockPinned.slice();
            serviceDock.update(serviceDock.windowsCache);
        }
    }

    Component.onCompleted: update(ServiceCompositor.windowList)
}
