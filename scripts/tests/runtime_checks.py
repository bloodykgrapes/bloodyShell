#!/usr/bin/env python3

import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-runtime-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules/src", base / "src", ignore=shutil.ignore_patterns("keyboard"))
        (base / "runtime").mkdir(mode=0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "src/Clients.js" as Clients
import "src/ModelSync.js" as ModelSync
import "src/Visualizer.js" as Visualizer
import "src/WindowLayout.js" as WindowLayout

ShellRoot
{
    id: tests
    property int delegates: 0
    ListModel { id: model }
    QtObject { id: first }
    QtObject { id: second }
    Item
    {
        Repeater
        {
            id: rows
            model: model
            Item
            {
                required property int key
                required property string text
                Component.onCompleted: tests.delegates++
            }
        }
    }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Component.onCompleted: Qt.callLater(() =>
    {
        try
        {
            let clients = [];
            check(Clients.update(clients, first, false) === clients, "Removing an absent client allocated a new array");
            clients = Clients.update(clients, first, true);
            check(Clients.update(clients, first, true) === clients, "Duplicate client registration invalidated subscribers");
            clients = Clients.update(clients, second, true);
            clients = Clients.update(clients, first, false);
            check(clients.length === 1 && clients[0] === second, "Removing one consumer stopped another consumer");
            check(Clients.update(clients, second, false).length === 0, "Last consumer was retained");

            ModelSync.sync(model, [{key:1,text:"one"},{key:2,text:"two"}], "key");
            const original = rows.itemAt(0), other = rows.itemAt(1);
            check(!ModelSync.sync(model, [{key:1,text:"one"},{key:2,text:"two"}], "key"), "Identical model reported a change");
            check(ModelSync.sync(model, [{key:2,text:"updated"},{key:1,text:"one"}], item => item.key), "Computed identities did not reconcile");
            check(rows.itemAt(1) === original && rows.itemAt(0) === other && tests.delegates === 2, "Reordering recreated delegates");
            check(other.text === "updated", "Changed role did not reach its existing delegate");
            rows.model = null;

            let seed = 1729;
            function random() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }
            for (let round = 0; round < 120; round++)
            {
                const items = [];
                for (let i = 0; i < 80; i++)
                    if (random() > 0.3) items.push({key:i,text:"value-" + round + "-" + i});
                for (let i = items.length - 1; i > 0; i--)
                {
                    const j = Math.floor(random() * (i + 1));
                    [items[i], items[j]] = [items[j], items[i]];
                }
                ModelSync.sync(model, items, "key");
                check(model.count === items.length, "Reconcile retained a stale row");
                for (let i = 0; i < items.length; i++)
                    check(model.get(i).key === items[i].key && model.get(i).text === items[i].text, "Mixed insertion/removal/reordering corrupted the model");
                check(!ModelSync.sync(model, items, "key"), "A settled model still writes roles");
            }

            const items = Array.from({length:500}, (_, key) => ({key:key,text:String(key)}));
            ModelSync.sync(model, items, "key");
            let reads = 0;
            const tracked = {
                get count() { return model.count; },
                get(index) { reads++; return model.get(index); },
                insert(index, item) { model.insert(index, item); },
                remove(index) { model.remove(index); },
                move(from, to, count) { model.move(from, to, count); },
                setProperty(index, role, value) { model.setProperty(index, role, value); },
                clear() { model.clear(); }
            };
            ModelSync.sync(tracked, items.reverse(), "key");
            check(reads <= 1000 && model.get(0).key === 499, "Reordering repeated native model searches");
            ModelSync.sync(model, [], "key");
            check(model.count === 0 && !ModelSync.sync(model, [], "key"), "Empty model reset is not idempotent");

            for (const length of [48, 62])
            {
                const basis = Visualizer.waveBasis(64, length);
                for (const phase of [0, 0.1, 4, 25, -6])
                {
                    const points = Visualizer.wave(basis, 64, 24, 2.6, phase);
                    check(points.length === 23, "Liquid wave resolution changed");
                    for (let i = 0; i <= 20; i++)
                    {
                        const x = i / 20 * 64;
                        check(Math.abs(points[i].x - x) < 1e-7 && Math.abs(points[i].y - (24 + 2.6 * Math.sin(x / length * Math.PI * 2 + phase))) < 1e-7, "Cached trigonometry changed the liquid shape");
                    }
                }
            }
            let tileReads = 0;
            const geometry = {};
            for (let id = 0; id < 500; id++) {
                const tile = {width:1920,height:1080};
                Object.defineProperty(geometry,id,{enumerable:true,get() { tileReads++; return tile; }});
            }
            const sameLayout = [[1,{tile_size:[1920,1080],tile_pos_in_workspace_view:null}]];
            for (let i = 0; i < 1000; i++)
                check(WindowLayout.update(geometry,sameLayout,false) === geometry,"Unchanged geometry allocated a new cache");
            check(tileReads === 1000,"Unchanged geometry scanned unrelated cached windows: " + tileReads);
            const stableTile = geometry[2];
            const changedGeometry = WindowLayout.update(geometry,[[1,{tile_size:[1280,800]}]],false);
            check(changedGeometry !== geometry && changedGeometry[1].width === 1280 && changedGeometry[2] === stableTile,"Changed geometry replaced unrelated tile objects");
            const snapshot = [[1,{tile_size:[1280,800]}],[2,{tile_size:[1920,1080]}]];
            const trimmed = WindowLayout.update(changedGeometry,snapshot,true);
            check(Object.keys(trimmed).length === 2 && trimmed[2] === stableTile,"Snapshot retained removed windows or replaced unchanged tiles");
            check(WindowLayout.update(trimmed,snapshot,true) === trimmed,"Identical geometry snapshot allocated a new cache");
            const invalid = WindowLayout.update(trimmed,[[1,{tile_size:[NaN,800]}]],false);
            check(!invalid[1] && invalid[2] === stableTile,"Invalid size was retained or removed another window");

            const screens = [{name:"A",width:1920,height:1080},{name:"B",width:1280,height:800}];
            const workspaceRows = [{wsId:1,output:"A",activated:true,activeWindowId:2},{wsId:2,output:"B",activated:true,activeWindowId:1}];
            const workspaceModel = {count:workspaceRows.length,get(index) { return workspaceRows[index]; }};
            const windows = [{id:2,workspace_id:1},{id:1,workspace_id:2}];
            const cache = {outputs:[]};
            const fullscreen = WindowLayout.fullscreen(screens,workspaceModel,windows,trimmed,false,cache);
            check(fullscreen.join(",") === "A,B","Fullscreen geometry lost an output");
            check(WindowLayout.fullscreen(screens,workspaceModel,windows.map(window=>Object.assign({},window,{title:"Changed"})),trimmed,false,cache) === fullscreen,"Title updates replaced unchanged fullscreen state");
            workspaceRows[1].activated = false;
            check(WindowLayout.fullscreen(screens,workspaceModel,windows,trimmed,false,cache).join(",") === "A","Inactive workspace retained fullscreen");
            check(WindowLayout.fullscreen(screens,workspaceModel,windows,trimmed,true,cache).length === 0,"Overview retained fullscreen");
            console.log("RUNTIME_PASSED client ownership, delegate identity, mixed model updates, wave geometry, and 1000 tile reads for 1000 unchanged updates across 500 cached windows; fullscreen state identity preserved");
        }
        catch (error) { console.error("RUNTIME_FAILED", error); }
        Qt.quit();
    })
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "RUNTIME_PASSED" in output, output
        assert not re.search(r"RUNTIME_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), output


def compositor_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-unsupported-compositor-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"), NIRI_SOCKET="", XDG_CURRENT_DESKTOP="unsupported")
        env.pop("WAYLAND_DISPLAY", None)
        niri = base / "bin/niri"
        niri.write_text('#!/bin/sh\ntouch "$TEST_SCREENSHOT_BASE/unexpected-niri-command"\nexit 1\n')
        niri.chmod(0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "modules/core"
import "modules/services"
ShellRoot {
    Timer { interval: 200; running:true; onTriggered: {
        try {
            if (ServiceCompositor.available || ServiceCompositor.name !== "" || ServiceCompositor.supports("displays")) throw new Error("Unsupported compositor selected a backend");
            if (ServiceCompositor.windowList.length || ServiceCompositor.workspacesList.count || ServiceCompositor.captureStreams.length || ServiceRecording.active) throw new Error("Unavailable backend exposed stale state");
            if (ServiceCompositor.configuration(["mouse-read"]).length || ServiceCompositor.logoutCommand.length) throw new Error("Unavailable backend exposed commands");
            ServiceCompositor.focusWindow(1); ServiceCompositor.focusWorkspace("A", 1); ServiceCompositor.powerOffMonitors();
            ServiceDisplay.refresh(); ServiceDisplay.change("A", "scale", 2); ServiceKeyboard.refresh(); ServiceKeyboard.set("repeatRate", 30);
            if (Object.keys(Config.displays).length) throw new Error("Unsupported display settings were saved");
            finish.start();
        } catch (error) { console.error("COMPOSITOR_FAILED", error); Qt.quit(); }
    } }
    Timer { id:finish; interval:700; onTriggered:{ console.log("COMPOSITOR_PASSED unsupported backend has empty state, no commands, and safe settings"); Qt.quit(); } }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=5)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "COMPOSITOR_PASSED" in output, output
        assert not re.search(r"COMPOSITOR_FAILED|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
        assert not (base / "unexpected-niri-command").exists(), "Unsupported compositor ran niri commands"
        assert not (base / "config/niri").exists(), "Unsupported compositor wrote niri configuration"
    print("Unsupported compositor keeps empty state, hides unavailable capabilities, and performs no niri commands or config writes.")


if __name__ == "__main__":
    checks()
    compositor_checks()
