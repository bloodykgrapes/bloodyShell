pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../src/Clients.js" as Clients
import "../src/AppIdentity.js" as AppIdentity
import "../common"
import "../core"

Singleton
{
    id: serviceApplications

    readonly property var applications: DesktopEntries.applications.values || []

    property var autostartEntries: []
    property var autostartClients: []
    property string autostartError: ""
    property string autostartSession: "unknown"
    property bool autostartRefreshPending: false
    readonly property bool autostartWatching: autostartClients.length > 0
    readonly property bool autostartBusy: autostartCommand.busy
    readonly property string autostartHelper: Paths.runtimeScriptsDir + "/autostart"

    function setAutostartActive(client, active)
    {
        autostartClients = Clients.update(autostartClients, client, active);
    }

    function hasAutostart(appId)
    {
        const id = String(appId || "").replace(/\.desktop$/, "");
        return autostartEntries.some(entry => entry.appId === id || entry.id === id + ".desktop");
    }

    function refreshAutostart(clearError = true)
    {
        if (autostartBusy) { autostartRefreshPending = true; return; }
        if (clearError) autostartError = "";
        autostartCommand.run(["python3", autostartHelper, "list"]);
    }

    function changeAutostart(action, id, enabled)
    {
        if (autostartBusy || !id) return false;
        autostartError = "";
        const args = ["python3", autostartHelper, action, String(id)];
        if (action === "set") args.push(enabled ? "true" : "false");
        return autostartCommand.run(args);
    }

    function addAutostart(appId) { return changeAutostart("add", appId) }
    function setAutostartEnabled(id, enabled) { return changeAutostart("set", id, enabled) }
    function removeAutostart(id) { return changeAutostart("remove", id) }
    function queueAutostartRefresh() { if (autostartWatching) autostartRefresh.restart() }

    onAutostartWatchingChanged:
    {
        if (autostartWatching) refreshAutostart();
        else { autostartRefresh.stop(); autostartRefreshPending = false; }
    }

    Timer
    {
        id: autostartRefresh
        interval: 150
        onTriggered: serviceApplications.refreshAutostart(false)
    }

    CommandProcess
    {
        id: autostartCommand
        stdout: StdioCollector { id: autostartResult }
        onCompleted: code =>
        {
            if (code !== 0) serviceApplications.autostartError = errorMessage(Tr.tr("settings.autostart.failed"));
            else
            {
                try
                {
                    const result = JSON.parse(autostartResult.text);
                    serviceApplications.autostartEntries = result.entries;
                    serviceApplications.autostartSession = result.session;
                }
                catch (error) { serviceApplications.autostartError = String(error) }
            }
            if (serviceApplications.autostartRefreshPending)
            {
                serviceApplications.autostartRefreshPending = false;
                if (serviceApplications.autostartWatching) Qt.callLater(() => serviceApplications.refreshAutostart(false));
            }
        }
    }

    Process
    {
        running: serviceApplications.autostartWatching
        command: ["python3", serviceApplications.autostartHelper, "watch"]
        stdout: SplitParser { onRead: line => { if (line === "changed") serviceApplications.queueAutostartRefresh() } }
        onExited: (code, status) =>
        {
            if (serviceApplications.autostartWatching && (code !== 0 || status !== 0))
                serviceApplications.autostartError = Tr.tr("settings.autostart.watchFailed");
        }
    }

    readonly property var searchIndex: applications.filter(app => app && app.name && !app.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name)).map((app, order) => ({
        order: order,
        app: app,
        name: app.name.toLocaleLowerCase(),
        generic: (app.generic || "").toLocaleLowerCase(),
        comment: (app.comment || "").toLocaleLowerCase(),
        keywords: (app.keywords || []).join(" ").toLocaleLowerCase()
    }))

    property var searchMemo: ({ index: null, all: [], results: new Map() })
    property var entryMemo: ({ catalog: null, entries: new Map() })

    function searchScore(entry, tokens)
    {
        let total = 0;
        for (const token of tokens)
        {
            if (entry.name.startsWith(token)) total += 100;
            else if (entry.name.includes(" " + token) || entry.name.includes("-" + token)) total += 80;
            else if (entry.name.includes(token)) total += 60;
            else if (entry.generic.includes(token) || entry.keywords.includes(token)) total += 40;
            else if (entry.comment.includes(token)) total += 20;
            else return 0;
        }
        return total;
    }

    function search(query)
    {
        const entries = searchIndex;
        const memo = searchMemo;
        if (memo.index !== entries)
        {
            memo.index = entries;
            memo.all = entries.map(entry => entry.app);
            memo.results.clear();
        }
        const normalizedQuery = (query || "").trim().toLocaleLowerCase().replace(/\s+/g, " ");
        if (!normalizedQuery) return memo.all;
        if (memo.results.has(normalizedQuery))
        {
            const result = memo.results.get(normalizedQuery);
            memo.results.delete(normalizedQuery);
            memo.results.set(normalizedQuery, result);
            return result;
        }
        const tokens = normalizedQuery.split(" ");

        const matches = [];
        for (let i = 0; i < entries.length; i++)
        {
            const entry = entries[i];
            const score = searchScore(entry, tokens);
            if (score > 0) matches.push({ app: entry.app, score: score, order: entry.order });
        }

        matches.sort((a, b) => (b.score - a.score) || a.order - b.order);
        const result = matches.map(item => item.app);
        memo.results.set(normalizedQuery, result);
        if (memo.results.size > 16) memo.results.delete(memo.results.keys().next().value);
        return result;
    }

    function findEntry(appId)
    {
        if (!appId) return null;
        const catalog = applications;
        const memo = entryMemo;
        if (memo.catalog !== catalog)
        {
            memo.catalog = catalog;
            memo.entries.clear();
        }
        if (memo.entries.has(appId)) return memo.entries.get(appId);
        const entry = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        memo.entries.set(appId, entry);
        if (memo.entries.size > 128) memo.entries.delete(memo.entries.keys().next().value);
        return entry;
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

    onApplicationsChanged: { tokenCache = ({}); queueAutostartRefresh(); }

    function updateLaunching()
    {
        const keys = Object.keys(launching);
        if (keys.length === 0) return;
        const running = ServiceCompositor.windowList.map(w => w.app_id || "");
        const now = Date.now();
        const next = {};
        for (const key of keys)
            if (!running.some(id => AppIdentity.sameApp(id, key)) && now - launching[key] < launchTimeoutMs)
                next[key] = launching[key];
        if (Object.keys(next).length !== keys.length) launching = next;
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
