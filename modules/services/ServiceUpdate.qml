pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core"

Singleton
{
    id: serviceUpdate

    readonly property string repo: "bloodykgrapes/bloodyShell"
    readonly property string channel: Config.updateBeta ? "beta" : "release"

    readonly property string shellDir: Paths.shellDir
    readonly property string installDir: Paths.installDir
    readonly property bool   installed: shellDir === installDir
    readonly property string stateDir: Paths.stateDir
    readonly property string logFile: stateDir + "/update.log"

    property string version: "0.0.0"
    property bool versionReady: false

    function pretty(path) { const home = Quickshell.env("HOME"); return path.startsWith(home) ? "~" + path.substring(home.length) : path }

    property var releases: []
    readonly property var latest: releases.length > 0 ? releases[0] : null

    readonly property var pending: releases.filter(r => newer(r.version, version))

    readonly property var currentRelease: releases.find(r => r.version === version) || null

    readonly property string releaseTag: latest ? latest.tag : ""
    readonly property string versionLatest: latest ? latest.version : ""
    readonly property bool   availableUpdate: pending.length > 0

    readonly property bool attention: installed && availableUpdate && !installing

    property bool   checking: false
    property bool   checked: false
    property string error: ""
    property bool   installFailed: false
    property double lastChecked: 0
    property double autoAttemptedCheck: 0

    property bool   installing: false
    property string statusFile: ""
    property int    installStep: 0
    property int    installSteps: 0
    property string installText: ""

    property string updatedFrom: ""
    readonly property bool justUpdated: updatedFrom !== ""

    readonly property bool busy: checking || installing

    readonly property string phase:
    {
        if (!installed) return "dev";
        if (installing) return "installing";
        if (checking) return "checking";
        if (error !== "") return "error";
        if (availableUpdate) return "available";
        if (checked) return "current";
        return "unknown";
    }

    readonly property string status:
    {
        switch (phase)
        {
            case "dev":        return Tr.tr("service.update.developmentCopy");
            case "installing": return installText !== "" ? installText : Tr.tr("service.update.installing").arg(versionLatest);
            case "checking":   return Tr.tr("service.update.checking");
            case "error":      return error;
            case "available":  return pending.length > 1 ? Tr.tr("service.update.availableReleases").arg(versionLatest).arg(pending.length) : Tr.tr("service.update.available").arg(versionLatest);
            case "current":    return releases.length === 0 ? Tr.tr("service.update.noReleases") : Tr.tr("service.update.upToDate");
        }
        return Config.updateCheck === 0 ? Tr.tr("service.update.checksDisabled") : Tr.tr("service.update.notChecked");
    }

    function parse(v)
    {
        const s = String(v || "").trim().replace(/^v/, "");
        const dash = s.indexOf("-");
        const core = (dash < 0 ? s : s.substring(0, dash)).split(".").map(n => parseInt(n, 10) || 0);
        return { core: core, pre: dash < 0 ? [] : s.substring(dash + 1).split(".") };
    }
    function newer(a, b)
    {
        const x = parse(a), y = parse(b);
        for (let i = 0; i < Math.max(x.core.length, y.core.length); i++)
        {
            const d = (x.core[i] || 0) - (y.core[i] || 0);
            if (d !== 0) return d > 0;
        }
        if (x.pre.length === 0 || y.pre.length === 0) return x.pre.length === 0 && y.pre.length > 0;
        for (let i = 0; i < Math.max(x.pre.length, y.pre.length); i++)
        {
            const p = x.pre[i], q = y.pre[i];
            if (p === undefined) return false;
            if (q === undefined) return true;
            if (p === q) continue;
            const np = /^\d+$/.test(p), nq = /^\d+$/.test(q);
            if (np && nq) return parseInt(p, 10) > parseInt(q, 10);
            if (np !== nq) return nq;
            return p > q;
        }
        return false;
    }

    function ago(time, now)
    {
        if (!time) return Tr.tr("service.update.never");
        const s = Math.max(0, Math.round((now - time) / 1000));
        if (s < 60) return Tr.tr("service.update.justNow");
        const m = Math.round(s / 60);
        if (m < 60) return Tr.tr("service.update.minutesAgo").arg(m);
        const h = Math.round(m / 60);
        if (h < 24) return (h === 1 ? Tr.tr("service.update.hourAgo") : Tr.tr("service.update.hoursAgo")).arg(h);
        const d = Math.round(h / 24);
        return d === 1 ? Tr.tr("service.update.yesterday") : Tr.tr("service.update.daysAgo").arg(d);
    }

    function check()
    {
        if (busy || !installed) return;
        checking = true;
        error = "";
        installFailed = false;
        request.running = true;
    }

    function applyReleases(text)
    {
        let list;
        try { list = JSON.parse(text); }
        catch (e) { error = Tr.tr("service.update.invalidResponse"); return; }
        if (!Array.isArray(list)) { error = Tr.tr("service.update.invalidResponse"); return; }

        const beta = channel === "beta";
        const out = list
            .filter(r => !r.draft && (beta || !r.prerelease))
            .map(r => ({
                tag: String(r.tag_name),
                version: String(r.tag_name).replace(/^v/, ""),
                name: String(r.name || r.tag_name),
                notes: String(r.body || "").trim(),
                url: String(r.html_url || ""),
                date: String(r.published_at || r.created_at || ""),
                prerelease: !!r.prerelease
            }));

        out.sort((a, b) => newer(a.version, b.version) ? -1 : newer(b.version, a.version) ? 1 : 0);

        releases = out;
        checked = true;
        lastChecked = Date.now();
        checkStore.setText(String(lastChecked));
        Qt.callLater(serviceUpdate.autoUpdate);
    }

    function autoUpdate()
    {
        if (!Config.initialized || !Config.updateAuto || !versionReady || !installed || !checked
            || busy || error !== "" || !availableUpdate || lastChecked <= autoAttemptedCheck) return;

        autoAttemptedCheck = lastChecked;
        update();
    }

    Connections
    {
        target: Config
        function onUpdateAutoChanged() { if (Config.updateAuto) Qt.callLater(serviceUpdate.autoUpdate) }
        function onInitializedChanged() { if (Config.initialized) Qt.callLater(serviceUpdate.autoUpdate) }
    }

    Process
    {
        id: request

        command: ["curl", "-sSL", "--max-time", "15", "-w", "\n%{http_code}", "-H", "Accept: application/vnd.github+json",
                  "https://api.github.com/repos/" + serviceUpdate.repo + "/releases?per_page=30"]

        stdout: StdioCollector { id: answer }
        stderr: StdioCollector { id: complaint }
        onExited: code =>
        {
            serviceUpdate.checking = false;

            if (code !== 0)
            {
                const reason = complaint.text.trim().split("\n").pop().replace(/^curl: \(\d+\)\s*/, "");
                serviceUpdate.error = Tr.tr("service.update.connectionFailed") + (reason !== "" ? ": " + reason : "");
                if (retry.attempts < 5) { retry.attempts++; retry.restart(); }
                return;
            }
            retry.attempts = 0;

            const text = answer.text;
            const cut = text.lastIndexOf("\n");
            const http = parseInt(text.substring(cut + 1), 10);
            const body = text.substring(0, cut);

            if (http === 200) serviceUpdate.applyReleases(body);
            else if (http === 403 || http === 429) serviceUpdate.error = Tr.tr("service.update.rateLimited");
            else if (http === 404) serviceUpdate.error = Tr.tr("service.update.repositoryNotFound").arg(serviceUpdate.repo);
            else serviceUpdate.error = Tr.tr("service.update.httpError").arg(http);
        }
    }
    Timer
    {
        id: retry

        property int attempts: 0
        interval: 2 * 60 * 1000
        onTriggered: serviceUpdate.check()
    }

    onChannelChanged: if (checked) check()

    readonly property double checkInterval: [0, 0, 6, 24, 7 * 24][Math.max(0, Math.min(4, Config.updateCheck))] * 60 * 60 * 1000
    readonly property bool   scheduled: installed && Config.updateCheck >= 2

    FileView
    {
        id: checkStore

        path: serviceUpdate.stateDir + "/last-check"
        printErrors: false
        onLoaded: { const t = parseFloat(text()); if (t > 0 && t > serviceUpdate.lastChecked) serviceUpdate.lastChecked = t; }
    }

    function due() { return Date.now() - lastChecked >= checkInterval }

    Timer
    {
        interval: 15000
        running: serviceUpdate.installed && Config.updateCheck >= 1
        onTriggered: if (Config.updateCheck === 1 || serviceUpdate.due()) serviceUpdate.check()
    }
    Timer
    {
        interval: 10 * 60 * 1000
        running: serviceUpdate.scheduled
        repeat: true
        onTriggered: if (serviceUpdate.due()) serviceUpdate.check()
    }

    function update()
    {
        if (busy || !availableUpdate || !installed) return;

        installing = true;
        error = "";
        installFailed = false;
        installStep = 0;
        installSteps = 0;
        installText = Tr.tr("service.update.starting");
        statusFile = stateDir + "/update-" + Date.now() + ".status";
        timeout.restart();

        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$1\" && rm -f \"$1\"/update-*.status && BLOODYSHELL_STATUS=\"$4\" exec \"$2/setup\" update --tag \"$3\" > \"$1/update.log\" 2>&1",
            "bloodyShell-update", stateDir, installDir, releaseTag, statusFile]);
    }

    function openLog() { Qt.openUrlExternally("file://" + logFile) }

    function showPage()
    {
        const index = Registry.settings.findIndex(p => p.id === "updates");
        if (index >= 0) OverlayState.settingsPage = index;
        OverlayState.show("settings");
    }

    Timer
    {
        id: timeout
        interval: 3 * 60 * 1000
        onTriggered: if (serviceUpdate.installing) { serviceUpdate.installing = false; serviceUpdate.installFailed = true; serviceUpdate.error = "Update timed out" }
    }

    FileView
    {
        id: statusView

        path: serviceUpdate.installing ? serviceUpdate.statusFile : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            const line = text().trim();
            const step = /^step (\d+)\/(\d+) (.*)$/.exec(line);
            if (step)
            {
                serviceUpdate.installStep = parseInt(step[1], 10);
                serviceUpdate.installSteps = parseInt(step[2], 10);
                serviceUpdate.installText = step[3] + "…";
            }
            else if (line.startsWith("failed"))
            {
                serviceUpdate.installing = false;
                timeout.stop();
                serviceUpdate.installFailed = true;
                serviceUpdate.error = line.substring(6).trim() || Tr.tr("service.update.failed");
            }
            else if (line.startsWith("done"))
            {
                serviceUpdate.installStep = serviceUpdate.installSteps;
                serviceUpdate.installText = Tr.tr("service.update.restarting");
            }
        }
    }

    Timer
    {
        interval: 1000
        repeat: true
        running: serviceUpdate.installing
        onTriggered: statusView.reload()
    }

    FileView
    {
        path: serviceUpdate.shellDir + "/version"
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            const version = text().trim();
            serviceUpdate.version = version || "0.0.0";
            serviceUpdate.versionReady = version !== "";
            if (serviceUpdate.installed) versionStore.path = serviceUpdate.stateDir + "/last-version";
            Qt.callLater(serviceUpdate.autoUpdate);
        }
        onLoadFailed: serviceUpdate.versionReady = false
    }

    FileView
    {
        id: versionStore
        printErrors: false

        onLoaded:
        {
            const before = text().trim();
            if (before !== "" && before !== serviceUpdate.version && serviceUpdate.newer(serviceUpdate.version, before))
            {
                serviceUpdate.updatedFrom = before;
                announce.command = ["notify-send", "-a", "bloodyShell", "-A", "default=" + Tr.tr("common.whatsNew"), "-w", Tr.tr("service.update.completed"),
                                    Tr.tr("service.update.installed").arg(serviceUpdate.version).arg(serviceUpdate.updatedFrom)];
                announce.running = true;
                if (!serviceUpdate.checked) serviceUpdate.check();
            }
            if (before !== serviceUpdate.version) setText(serviceUpdate.version);
        }
        onLoadFailed: setText(serviceUpdate.version)
    }

    Process
    {
        id: announce

        stdout: StdioCollector { onStreamFinished: if (text.trim() === "default") serviceUpdate.showPage() }
    }
}
