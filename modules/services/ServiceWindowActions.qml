pragma Singleton

import QtQuick
import Quickshell

import "../src/AppIdentity.js" as AppIdentity

Singleton
{
    id: serviceWindowActions

    property var lastFocused: ({})

    function updateHistory()
    {
        const next = Object.create(null);
        const windows = ServiceCompositor.windowList;
        for (const window of windows)
        {
            const key = AppIdentity.appKey(window);
            if (window.id === lastFocused[key]) next[key] = window.id;
        }
        for (const window of windows)
            if (window.is_focused) next[AppIdentity.appKey(window)] = window.id;
        const keys = Object.keys(next);
        if (keys.length !== Object.keys(lastFocused).length || keys.some(key => next[key] !== lastFocused[key]))
            lastFocused = next;
    }

    function trayDesktopEntry(item)
    {
        if (!item) return null;

        const values = [item.id, item.tooltipTitle, item.title];

        for (const value of values)
        {
            if (!value) continue;

            const entry = DesktopEntries.byId(String(value));
            if (entry) return entry;
        }

        for (const value of values)
        {
            if (!value) continue;

            const entry = DesktopEntries.heuristicLookup(String(value));
            if (entry) return entry;
        }

        return null;
    }

    function trayWindow(item, entry)
    {
        if (!item) return null;

        const identifiers = [
            item.id,
            item.tooltipTitle,
            item.title
        ];

        if (entry)
            identifiers.push(entry.id, entry.name, entry.startupClass);

        const windows = Array.isArray(ServiceCompositor.windowList)
            ? ServiceCompositor.windowList
            : [];

        const matches = [];

        for (const window of windows)
        {
            if (!window || window.id === undefined || !window.app_id)
                continue;

            let score = 0;

            for (const identifier of identifiers)
            {
                score = Math.max(
                    score,
                    AppIdentity.trayIdentityScore(identifier, window.app_id)
                );
            }

            if (score > 0)
                matches.push({ window: window, score: score });
        }

        if (matches.length === 0) return null;

        matches.sort((a, b) => b.score - a.score);

        const bestScore = matches[0].score;
        const best = matches.filter(match => match.score === bestScore);

        const last = best.find(match =>
            String(lastFocused[AppIdentity.appKey(match.window)] || "")
            === String(match.window.id)
        );

        return last?.window
            || best.find(match => match.window.is_focused === true)?.window
            || best[0].window;
    }

    function activateTrayItem(item)
    {
        if (!item) return "none";

        const entry = trayDesktopEntry(item);
        const targetWindow = trayWindow(item, entry);

        if (targetWindow)
        {
            ServiceCompositor.focusWindow(targetWindow.id);
            return "window";
        }

        if (item.onlyMenu && item.hasMenu) return "menu";
        if (item.onlyMenu)
        {
            if (!entry) return "none";

            ServiceApplications.launchEntry(entry);
            return "launch";
        }

        item.activate();
        return "activated";
    }

    function activateMediaPlayer(player)
    {
        if (!player) return false;

        const desktopId = String(player.desktopEntry || "");
        const identity = String(player.identity || "");
        const dbusName = String(player.dbusName || "");

        const dbusApp = dbusName
            .replace(/^org\.mpris\.MediaPlayer2\./i, "")
            .replace(/\.instance.*$/i, "");

        const entry = (desktopId ? ServiceApplications.findEntry(desktopId) : null)
            || (identity ? ServiceApplications.findEntry(identity) : null)
            || (dbusApp ? ServiceApplications.findEntry(dbusApp) : null);

        const candidates = [];

        function addCandidates(value)
        {
            for (const variant of AppIdentity.mediaAppVariants(value))
                if (!candidates.includes(variant)) candidates.push(variant);
        }

        addCandidates(desktopId);
        addCandidates(identity);
        addCandidates(dbusName);
        addCandidates(dbusApp);

        if (entry)
        {
            addCandidates(entry.id);
            addCandidates(entry.name);
        }

        const windows = Array.isArray(ServiceCompositor.windowList) ? ServiceCompositor.windowList : [];
        const matching = windows.filter(window =>
        {
            if (!window || !window.app_id) return false;

            const variants = AppIdentity.mediaAppVariants(window.app_id);

            return candidates.some(candidate => variants.includes(candidate));
        });

        if (matching.length > 0)
        {

            const last = matching.find(window => String(lastFocused[AppIdentity.appKey(window)] || "") === String(window.id));

            const target = last
                || matching.find(window => window.is_focused === true)
                || matching[0];

            ServiceCompositor.focusWindow(target.id);
            return true;
        }

        if (player.canRaise)
        {
            player.raise();
            return true;
        }
        if (entry)
        {
            ServiceApplications.launchEntry(entry);
            return true;
        }
        return false;
    }

    Connections
    {
        target: ServiceCompositor
        function onWindowListChanged() { serviceWindowActions.updateHistory() }
    }

    Component.onCompleted: updateHistory()
}
