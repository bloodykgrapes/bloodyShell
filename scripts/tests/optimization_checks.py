#!/usr/bin/env python3

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    baseline = os.environ.get("BLOODYSHELL_OPT_BASELINE")
    with tempfile.TemporaryDirectory(prefix="bloodyshell-optimization-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules", base / "modules")
        for folder in ("runtime", "cache", "config", "data"):
            (base / folder).mkdir(mode=0o700)

        def stub(folder, name, body):
            (base / f"modules/{folder}/{name}.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n" + body + "\n}\n")

        stub("core", "Config", 'property bool debug: false; property bool initialized: true; property bool dockMerge: true; property var dockPinned: []; property bool notificationsEnabled: true; property bool notificationsRememberDnd: false; property bool notificationsDnd: false; function set(key, value) { this[key] = value; }')
        stub("core", "OverlayState", 'property bool active: false; property bool inhibited: false; property string current: ""; function close() { active = false; current = ""; }')
        stub("core", "MenuState", 'function close() {}')
        stub("services", "ServiceLock", 'property bool locked: false')
        stub("services", "ServiceAppearance", 'function iconPath(name) { return ""; }')
        stub("core", "TestMetrics", '''
    property var catalog: []
    property var notifications: []
    property var entries: new Map()
    onCatalogChanged: entries = new Map(catalog.map(app => [app.id, app]))
    property int serializations: 0
    property int scores: 0
    property int lookups: 0
    property var counters: ({idReads:0})
    property var actions: []
    function byId(id) { lookups++; return entries.get(id) || null; }
    function heuristicLookup(id) { lookups++; return null; }
    function serialize(value) { serializations++; return JSON.stringify(value); }
    function execDetached(args) { actions = actions.concat([args]); }
''')
        with (base / "modules/core/qmldir").open("a") as stream:
            stream.write("\nsingleton TestMetrics 1.0 TestMetrics.qml\n")
        for name in ("ServiceApplications", "ServiceDock", "ServiceWindowActions", "ServiceAltTab", "ServiceCompositor", "ServiceNotifications"):
            path = Path(baseline) / f"modules/services/{name}.qml" if baseline else ROOT / f"modules/services/{name}.qml"
            source = path.read_text()
            if 'import "../core"' not in source:
                source = source.replace("import QtQuick", 'import QtQuick\nimport "../core"', 1)
            if name == "ServiceCompositor":
                source = source[:source.index('    Process\n    {\n        id: stream')] + "}\n"
            source = source.replace("Quickshell.execDetached", "TestMetrics.execDetached")
            if name == "ServiceApplications":
                source = source.replace("DesktopEntries.applications.values || []", "TestMetrics.catalog")
                source = source.replace("DesktopEntries.byId", "TestMetrics.byId").replace("DesktopEntries.heuristicLookup", "TestMetrics.heuristicLookup")
                source = source.replace("function searchScore(entry, tokens)\n    {", "function searchScore(entry, tokens)\n    {\n        TestMetrics.scores++;")
            if name == "ServiceDock":
                source = source.replace("JSON.stringify(", "TestMetrics.serialize(")
            if name == "ServiceNotifications":
                start = source.index("    NotificationServer\n")
                end = source.index("    function received(n)", start)
                source = source[:start] + '    QtObject { id: server; property var trackedNotifications: ({values:TestMetrics.notifications}) }\n\n' + source[end:]
            (base / f"modules/services/{name}.qml").write_text(source)
        sync = base / "modules/src/ModelSync.js"
        source = sync.read_text().replace("model.get(", "readRow(model, ")
        source = source.replace(".pragma library", ".pragma library\n\nvar reads = 0;\nfunction readRow(model, index) { reads++; return model.get(index); }")
        sync.write_text(source)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "modules/core"
import "modules/services"
import "modules/src/ModelSync.js" as ModelSync

ShellRoot
{
    id: tests
    property bool optimized: Quickshell.env("BLOODYSHELL_OPT_BASELINE") === ""
    property int histories: 0
    property int windowChanges: 0
    property int altHistories: 0
    Connections { target: ServiceWindowActions; function onLastFocusedChanged() { tests.histories++; } }
    Connections { target: ServiceCompositor; function onWindowListChanged() { tests.windowChanges++; } }
    Connections { target: ServiceAltTab; function onHistoryChanged() { tests.altHistories++; } }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Component.onCompleted: Qt.callLater(() =>
    {
        try
        {
            void ServiceWindowActions.lastFocused; void ServiceDock.model.count; void ServiceAltTab.active;
            TestMetrics.catalog = Array.from({length:4000}, (_, index) => ({id:"org.example.App" + String(index).padStart(4,"0"),name:"Application " + String(index).padStart(4,"0"),generic:"Editor",comment:"A useful application",keywords:["tools"],noDisplay:false}));
            Config.dockPinned = ["org.example.App0000", "org.example.App0001"];
            const list = Array.from({length:180}, (_, id) => ({id:id,app_id:"org.example.App" + String(Math.floor(id/3)).padStart(4,"0"),title:"Window " + id,workspace_id:1,is_focused:id===0,is_urgent:false}));
            ServiceCompositor.windowsApply(list);
            check(ServiceDock.model.count === 61, "Merged dock lost applications or its separator");
            TestMetrics.serializations = 0; ModelSync.reads = 0; histories = 0;
            const start = Date.now();
            for (let i = 0; i < 40; i++) ServiceCompositor.windowUpsert(Object.assign({}, ServiceCompositor.windowList[3], {title:"Changed " + i}));
            const dockMs = Date.now() - start;
            const serialized = TestMetrics.serializations, reads = ModelSync.reads, historyWrites = histories;
            check(JSON.parse(ServiceDock.model.get(1).windows)[0].title === "Changed 39", "Incremental dock lost changed titles");
            if (optimized)
            {
                check(serialized === 40, "Unchanged dock groups were serialized again: " + serialized);
                check(reads === 0, "A title-only dock update still scans native model rows: " + reads);
                check(historyWrites === 0, "Title updates invalidate window focus history");
                const before = windowChanges;
                ServiceCompositor.windowsApply(ServiceCompositor.windowList);
                check(windowChanges === before, "Identical compositor snapshots invalidate every subscriber");
            }
            ServiceCompositor.windowFocus(5);
            check(ServiceDock.model.get(1).is_focused && ServiceDock.model.get(1).focused_index === 2
                && !ServiceDock.model.get(0).is_focused, "Incremental focus lost the selected dock window");
            ServiceCompositor.windowSet(3, "is_urgent", true);
            check(ServiceDock.model.get(1).is_urgent && JSON.parse(ServiceDock.model.get(1).windows)[0].urgent, "Urgency did not invalidate the cached dock group");
            ServiceCompositor.windowSet(3, "is_urgent", false);
            check(!ServiceDock.model.get(1).is_urgent, "Cleared urgency stayed cached");
            ServiceCompositor.windowFocus(0);
            const moved = ServiceDock.model.get(3).key;
            ServiceDock.move(3, 5);
            check(ServiceDock.model.get(5).key === moved, "Unpinned ordering was not preserved");
            ServiceDock.pinAt(moved, 1);
            check(ServiceDock.isPinned(moved) && ServiceDock.model.get(1).app_id === moved, "Pinning failed after a reorder");
            ServiceDock.unpin(moved);
            check(!ServiceDock.isPinned(moved), "Unpinning did not update the model");
            Config.dockPinned = ["org.example.App0059"];
            check(ServiceDock.model.get(0).app_id === "org.example.App0059", "External pinned settings did not update the dock");
            Config.dockMerge = false;
            check(ServiceDock.model.count === 181, "Unmerged dock lost a window");
            Config.dockMerge = true;

            TestMetrics.scores = 0;
            const expectedMatches = TestMetrics.catalog.filter(app => app.name.includes("03")).length;
            const searchStart = Date.now();
            for (let i = 0; i < 100; i++) check(ServiceApplications.search("application 03").length === expectedMatches, "Search ranking or filtering changed");
            const searchMs = Date.now() - searchStart, scored = TestMetrics.scores;
            if (optimized) check(scored === 4000, "Repeated search rescored the catalog: " + scored);
            const empty = ServiceApplications.search("");
            check(empty.length === 4000 && empty[0].id === "org.example.App0000", "Empty search lost catalog sorting");
            if (optimized) check(ServiceApplications.search("  ") === empty, "Empty searches allocate duplicate catalogs");
            const catalog = TestMetrics.catalog.slice();
            catalog[0] = Object.assign({}, catalog[0], {name:"Renamed application"});
            TestMetrics.catalog = catalog;
            check(ServiceApplications.search("Renamed")[0].id === catalog[0].id, "Catalog changes retained stale search results");
            TestMetrics.lookups = 0;
            for (let i = 0; i < 150; i++) check(ServiceApplications.findEntry(catalog[0].id).name === "Renamed application", "Desktop entry lookup changed");
            const lookups = TestMetrics.lookups;
            if (optimized) check(lookups === 1, "Repeated desktop lookup still crosses into the native catalog: " + lookups);
            check(ServiceApplications.findEntry("missing") === null, "Unknown desktop entry should be absent");
            TestMetrics.catalog = catalog.concat([{id:"missing",name:"Newly installed app",keywords:[],noDisplay:false}]);
            check(ServiceApplications.findEntry("missing").name === "Newly installed app", "A cached miss hid a newly installed application");
            if (optimized)
            {
                for (let i = 0; i < 40; i++) ServiceApplications.search("application " + i);
                check(ServiceApplications.searchMemo.results.size <= 16, "Search memo grows without bounds");
                for (let i = 0; i < 180; i++) ServiceApplications.findEntry("unknown-" + i);
                check(ServiceApplications.entryMemo.entries.size <= 128, "Desktop entry memo grows without bounds");
            }

            function notification(id, app)
            {
                const item = {id:id,desktopEntry:app,appName:app,lastGeneration:false,urgency:0};
                let tracked = false;
                Object.defineProperty(item, "tracked", {
                    get: () => tracked,
                    set: value => { tracked = value; TestMetrics.notifications = value ? TestMetrics.notifications.concat([item]) : TestMetrics.notifications.filter(n => n.id !== id); }
                });
                item.dismiss = () => { item.tracked = false; };
                return item;
            }
            void ServiceNotifications.history;
            for (let i = 0; i < 300; i++)
            {
                const item = notification(i, "Example");
                ServiceNotifications.received(item);
                check(ServiceNotifications.receivedAt[i] > 0, "Live notification lost its timestamp");
                ServiceNotifications.dismiss(item);
            }
            if (optimized) check(Object.keys(ServiceNotifications.receivedAt).length === 0, "Dismissed notifications leak timestamps");
            const first = notification(301, optimized ? "__proto__" : "Example");
            const second = notification(302, optimized ? "__proto__" : "Example");
            const other = notification(303, "Other");
            ServiceNotifications.received(first); ServiceNotifications.received(other); ServiceNotifications.received(second);
            check(ServiceNotifications.groups.length === 2 && ServiceNotifications.groups[0].items[0] === second
                && ServiceNotifications.groups[0].items[1] === first, "Notification grouping changed order or lost items");
            const times = ServiceNotifications.receivedAt;
            if (optimized)
            {
                ServiceNotifications.pruneReceivedAt();
                check(ServiceNotifications.receivedAt === times, "Live timestamps are copied without a change");
            }
            ServiceNotifications.dismissGroup(first.desktopEntry.toLowerCase());
            check(ServiceNotifications.history.length === 1 && ServiceNotifications.receivedAt[303] === times[303], "Group dismissal removed another application's timestamp");
            ServiceNotifications.dismissAll();
            if (optimized) check(Object.keys(ServiceNotifications.receivedAt).length === 0, "Dismiss all retained timestamps");

            const tracked = ServiceCompositor.windowList.map(window => {
                const id = window.id;
                return Object.assign({}, window, {get id() { TestMetrics.counters.idReads++; return id; }});
            });
            for (let i = 0; i < tracked.length; i++)
            {
                const id = list[i].id;
                Object.defineProperty(tracked[i], "id", {get: () => { TestMetrics.counters.idReads++; return id; }, enumerable:true});
            }
            ServiceCompositor.windowList = tracked;
            ServiceAltTab.history = tracked.map(window => window.id).reverse();
            ServiceAltTab.remember();
            TestMetrics.counters.idReads = 0; altHistories = 0;
            const altStart = Date.now();
            for (let i = 0; i < 20; i++) ServiceAltTab.remember();
            const altMs = Date.now() - altStart, altReads = TestMetrics.counters.idReads, altWrites = altHistories;
            if (optimized)
            {
                check(altReads <= 180 * 20 * 2, "Alt+Tab repeatedly scans its live windows: " + altReads);
                check(altWrites === 0, "Unchanged Alt+Tab history still invalidates consumers");
            }
            ServiceAltTab.cycle(1);
            check(ServiceAltTab.active && ServiceAltTab.windows.length === 180 && ServiceAltTab.windows[ServiceAltTab.selected].id === 179, "MRU switching order changed");
            ServiceAltTab.cancel();
            ServiceCompositor.windowRemove(179);
            check(!ServiceAltTab.history.includes(179), "Closed window stayed in Alt+Tab history");
            ServiceCompositor.focusedOutput = "test-output";
            ServiceCompositor.focusWorkspace("test-output", 2);
            if (optimized) check(TestMetrics.actions[TestMetrics.actions.length-1][0] === "niri", "Same-output workspace action still starts a shell");
            console.log("OPTIMIZATION_METRICS", JSON.stringify({dockMs:dockMs,dockSerializations:serialized,nativeModelReads:reads,historyWrites:historyWrites,searchMs:searchMs,searchScores:scored,desktopLookups:lookups,altMs:altMs,altIdReads:altReads,altHistoryWrites:altWrites}));
            console.log("OPTIMIZATIONS_PASSED dock roles/order/pinning, compositor snapshots, bounded application caches, notification cleanup/grouping, MRU switching, and direct workspace actions");
        }
        catch (error) { console.error("OPTIMIZATIONS_FAILED", error); }
        Qt.quit();
    })
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_DATA_HOME=str(base / "data"), XDG_DATA_DIRS=str(base / "data"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "OPTIMIZATIONS_PASSED" in output, output
        assert not re.search(r"OPTIMIZATIONS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
