pragma Singleton

import QtQuick
import Quickshell

import "../src/AppIdentity.js" as AppIdentity

Singleton
{
    id: serviceApplications

    readonly property var applications: DesktopEntries.applications.values || []

    function searchScore(app, tokens)
    {
        const name =     (app.name     || "").toLocaleLowerCase();
        const generic =  (app.generic  || "").toLocaleLowerCase();
        const comment =  (app.comment  || "").toLocaleLowerCase();
        const keywords = (app.keywords || []).join(" ").toLocaleLowerCase();

        let total = 0;

        for (let i = 0; i < tokens.length; i++)
        {
            const token = tokens[i];
            let score = 0;

            if (name.startsWith(token))
                score = 100;
            else if (name.indexOf(" " + token) >= 0 || name.indexOf("-" + token) >= 0)
                score = 80;
            else if (name.includes(token))
                score = 60;
            else if (generic.includes(token) || keywords.includes(token))
                score = 40;
            else if (comment.includes(token))
                score = 20;
            else return 0;

            total += score;
        }
        return total;
    }

    function search(query)
    {
        const entries = applications;
        const normalizedQuery = (query || "").trim().toLocaleLowerCase();
        const tokens = normalizedQuery.length > 0 ? normalizedQuery.split(/\s+/) : [];

        const matches = [];
        for (let i = 0; i < entries.length; i++)
        {
            const app = entries[i];
            if (!app || !app.name || app.noDisplay) continue;

            const score = tokens.length > 0 ? searchScore(app, tokens) : 1;
            if (score > 0) matches.push({ app: app, score: score });
        }

        matches.sort((a, b) => (b.score - a.score) || a.app.name.localeCompare(b.app.name));
        return matches.map(item => item.app);
    }

    function findEntry(appId)
    {
        if (!appId) return null;
        return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
    }

    function appName(appId, fallback)
    {
        if (applications.length === 0) return fallback || appId || "";
        const entry = findEntry(appId);
        return entry && entry.name ? entry.name : (fallback || appId || "");
    }

    function iconFor(appId)
    {
        if (applications.length === 0) return iconSource(appId);
        const entry = findEntry(appId);
        const name = entry && entry.icon ? entry.icon : appId;

        return iconSource(name);
    }

    function iconSource(name)
    {
        if (!name || name.length === 0) return fallbackIcon;

        if (name.startsWith("/") || name.startsWith("file://"))
            return name.startsWith("file://") ? name : "file://" + name;

        const found = ServiceAppearance.iconPath(name);
        return found !== "" ? found : fallbackIcon;
    }

    function trayIcon(url, fallback)
    {
        const none = fallback === undefined ? fallbackIcon : fallback;
        const s = String(url || "");
        if (s === "") return none;
        if (!s.startsWith("image://icon/") || s.indexOf("path=") >= 0) return s;

        const name = decodeURIComponent(s.slice("image://icon/".length).split("?")[0]);
        const found = ServiceAppearance.iconPath(name);
        return found !== "" ? found : none;
    }

    function appTokens(appId)
    {
        if (tokenCache[appId]) return tokenCache[appId];

        const out = [];
        const add = v => { const t = String(v || "").toLowerCase().replace(/\.desktop$/, ""); if (t && !out.includes(t)) out.push(t); };

        add(appId);
        add(appId.split(".").pop());
        const entry = findEntry(appId);
        if (entry) { add(entry.id); add(entry.name); }

        tokenCache[appId] = out;
        return out;
    }

    function notificationFrom(n, appId)
    {
        const tokens = appTokens(appId);
        const entry = String(n.desktopEntry || "").toLowerCase().replace(/\.desktop$/, "");
        const name = String(n.appName || "").toLowerCase();
        return (entry !== "" && (tokens.includes(entry) || tokens.includes(entry.split(".").pop())))
            || (name !== "" && tokens.includes(name));
    }

    function markLaunching(appId)
    {
        if (!appId) return;
        const map = Object.assign({}, launching);
        map[appId] = Date.now();
        launching = map;
    }

    function isLaunching(appId) { return launching[appId] !== undefined }

    function launch(appId)
    {
        if (!appId) return;
        markLaunching(appId);

        const entry = findEntry(appId);
        if (entry)
        {
            launchEntry(entry);
            return;
        }

        Quickshell.execDetached(["gtk-launch", appId.replace(/\.desktop$/i, "")]);
    }

    function launchEntry(entry)
    {
        if (!entry) return;
        if (!isLaunching(entry.id)) markLaunching(entry.id);
        entry.execute();
    }

    readonly property string fallbackIcon: ServiceAppearance.iconPath("application-x-executable")
    property var tokenCache: ({})
    property var launching: ({})
    readonly property int launchTimeoutMs: 15000

    onApplicationsChanged: tokenCache = ({})

    function updateLaunching()
    {
        const running = ServiceCompositor.windowList.map(w => w.app_id || "");
        const next = {};
        for (const key in launching)
            if (!running.some(id => AppIdentity.sameApp(id, key)) && Date.now() - launching[key] < launchTimeoutMs)
                next[key] = launching[key];
        if (Object.keys(next).length !== Object.keys(launching).length) launching = next;
    }

    function scheduleLaunchTimeout()
    {
        const deadlines = Object.keys(launching).map(key => launching[key] + launchTimeoutMs);
        if (deadlines.length === 0) { launchTimeout.stop(); return; }
        launchTimeout.interval = Math.max(1, Math.ceil(Math.min.apply(null, deadlines) - Date.now()));
        launchTimeout.restart();
    }

    onLaunchingChanged: scheduleLaunchTimeout()

    Timer
    {
        id: launchTimeout
        onTriggered:
        {
            serviceApplications.updateLaunching();
            serviceApplications.scheduleLaunchTimeout();
        }
    }

    Connections
    {
        target: ServiceCompositor
        function onWindowListChanged() { serviceApplications.updateLaunching() }
    }
}
