pragma Singleton

import QtQuick
import Quickshell

import "../src/AppIdentity.js" as AppIdentity
import "../src/ModelSync.js" as ModelSync
import "../core"

Singleton
{
    id: serviceDock

    property alias model: dockModel
    ListModel { id: dockModel }

    property var pinned: []
    property var unpinned: []
    property var windowsCache: []
    property var seenAt: ({})
    property string focusedKey: ""
    property var itemCache: new Map()
    property var modelItems: []

    function itemKey(item)
    {
        if (item.type === "separator") return "separator";
        return (item.is_pinned ? "pinned:" : "app:") + item.key;
    }

    function update(runningWindows)
    {
        const list = Array.isArray(runningWindows) ? runningWindows : [];
        windowsCache = list;

        const merge = Config.dockMerge !== false;

        const byApp = new Map();
        const appOrder = [];

        for (let i = 0; i < list.length; i++)
        {
            const w = list[i];
            const k = AppIdentity.appKey(w);

            if (!byApp.has(k)) { byApp.set(k, []); appOrder.push(k); }
            byApp.get(k).push(w);
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

        for (const wins of byApp.values()) wins.sort((a, b) => Number(a.id) - Number(b.id));

        const nextCache = new Map();
        const makeItem = (key, wins, pinned) =>
        {
            const cacheKey = (pinned ? "pinned:" : "app:") + key;
            const lastId = ServiceWindowActions.lastFocused[key];
            const cached = itemCache.get(cacheKey);
            if (cached && cached.lastId === lastId && cached.windows.length === wins.length
                && wins.every((window, index) => window === cached.windows[index]))
            {
                nextCache.set(cacheKey, cached);
                return cached.item;
            }
            const focused = wins.find(w => w.is_focused === true);
            const last = wins.find(w => w.id === lastId);
            const shown = focused || last || wins[0];

            const item = {
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
            nextCache.set(cacheKey, { windows: wins, lastId: lastId, item: item });
            return item;
        };

        const newItems = [];

        for (let i = 0; i < pinned.length; i++)
        {
            const wins = byApp.get(pinned[i]) || [];
            newItems.push(makeItem(pinned[i], merge ? wins : wins.slice(0, 1), true));
        }

        const groups = [];
        const pinnedKeys = new Set(pinned);

        for (const k of appOrder)
        {
            const wins = byApp.get(k);
            const isPinned = pinnedKeys.has(k);

            if (merge)
            {
                if (!isPinned) groups.push({ key: k, wins: wins });
                continue;
            }

            for (const w of wins.slice(isPinned ? 1 : 0)) groups.push({ key: "win:" + w.id, wins: [w] });
        }

        const ranks = new Map(unpinned.map((key, index) => [key, index]));
        groups.forEach((group, index) => { if (!ranks.has(group.key)) ranks.set(group.key, unpinned.length + index); });
        groups.sort((a, b) => ranks.get(a.key) - ranks.get(b.key));

        if (groups.length > 0)
        {
            newItems.push({ type: "separator" });
            for (const g of groups) newItems.push(makeItem(g.key, g.wins, false));
        }

        const nextUnpinned = groups.map(g => g.key);
        if (!sameOrder(unpinned, nextUnpinned)) unpinned = nextUnpinned;
        itemCache = nextCache;
        sync(newItems);
    }

    function sameOrder(a, b) { return a.length === b.length && a.every((value, index) => value === b[index]) }

    function sync(items)
    {
        const previous = modelItems;
        if (dockModel.count === items.length && previous.length === items.length
            && items.every((item, index) => itemKey(item) === itemKey(previous[index])))
        {
            for (let i = 0; i < items.length; i++)
            {
                const item = items[i], old = previous[i];
                if (item === old) continue;
                for (const role in item)
                    if (item[role] !== old[role]) dockModel.setProperty(i, role, item[role]);
            }
        }
        else ModelSync.sync(dockModel, items, itemKey);
        modelItems = items;
    }

    function move(from, to)
    {
        if (from === to || from < 0 || to < 0 || from >= dockModel.count || to >= dockModel.count) return;
        const pc = pinned.length;
        const groupOf = i => i < pc ? 0 : (i === pc && dockModel.get(i).type === "separator" ? -1 : 1);
        const fromGroup = groupOf(from), toGroup = groupOf(to);
        if (fromGroup < 0 || toGroup < 0 || fromGroup !== toGroup) return;

        modelItems = [];
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
        if (sameOrder(pinned, list)) return;
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
            if (serviceDock.sameOrder(serviceDock.pinned, Config.dockPinned)) return;
            serviceDock.pinned = Config.dockPinned.slice();
            serviceDock.update(serviceDock.windowsCache);
        }
    }

    Component.onCompleted:
    {
        pinned = Config.dockPinned.slice();
        update(ServiceCompositor.windowList);
    }
}
