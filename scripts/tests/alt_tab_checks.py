#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
put, stub, module = (helpers[key] for key in ("put", "stub", "module"))

with tempfile.TemporaryDirectory(prefix="bloodyshell-alt-tab-") as temporary:
    base = Path(temporary)
    for folder in ("core", "services", "components", "altTab", "runtime", "cache"):
        (base / folder).mkdir(mode=0o700)
    shutil.copytree(ROOT / "modules/components", base / "components", dirs_exist_ok=True)
    shutil.copyfile(ROOT / "modules/altTab/AltTabContent.qml", base / "altTab/AltTabContent.qml")
    shutil.copyfile(ROOT / "modules/altTab/AltTabCard.qml", base / "altTab/AltTabCard.qml")
    shutil.copyfile(ROOT / "modules/services/ServiceAltTab.qml", base / "services/ServiceAltTab.qml")
    for name in ("Theme", "Enums"):
        shutil.copyfile(ROOT / f"modules/core/{name}.qml", base / f"core/{name}.qml")
    stub(base, "core", "Config", '''
    property bool initialized: true
    property int themeStyle: 1
    property int themeAnimations: 2
    property bool themeAccent: true
    property int themeBackground: 0
    property real themeBackgroundBlur: 60
    property real themeBackgroundTransparent: 50
    property bool themeBorder: false
    property real themeScale: 1
    property bool animationsFluid: true
    property bool animationsEnabled: false
''')
    stub(base, "core", "Paths", 'property string shellDir: ' + json.dumps(str(base)))
    stub(base, "core", "Tr", 'function tr(key) { return key }')
    stub(base, "core", "MenuState", 'function close() {}')
    stub(base, "core", "OverlayState", '''
    property var windows: ["settings"]
    property bool settingsActive: false
    property bool launcherActive: false
    property bool powerActive: false
    property bool wallpapersActive: false
    property bool helperActive: false
    function hide(name) { this[name + "Active"] = false }
''')
    stub(base, "services", "ServiceAppearance", 'property color accent: "#8bbfff"')
    stub(base, "services", "ServiceApplications", 'function iconFor(id) { return "" }\nfunction appName(id, fallback) { return id }')
    stub(base, "services", "ServiceLock", 'property bool locked: false')
    stub(base, "services", "ServiceCompositor", '''
    property var windowList: []
    property var focusedWindowId: null
    property string focusedOutput: "test"
    property var calls: []
    function focusWindow(id) { calls = calls.concat([id]) }
''')
    module(base, "core")
    module(base, "services")
    put(base, "shell.qml", '''import QtQuick
import QtQuick.Window
import Quickshell
import "core"
import "services"
import "altTab"
ShellRoot
{
    function check(ok, message) { if (!ok) throw new Error(message) }
    Window
    {
        visible: true
        width: 1200
        height: 650
        Rectangle { anchors.fill: parent; color: "#25252b" }
        AltTabContent { id: cards; anchors.centerIn: parent; width: 1100; height: 500 }
    }
    Timer
    {
        interval: 50
        running: true
        onTriggered:
        {
            try
            {
                ServiceAltTab.cycle(1);
                check(!ServiceAltTab.active, "empty list");
                ServiceCompositor.windowList = [{id:1, app_id:"Only window", title:"Only window"}];
                ServiceAltTab.cycle(1);
                check(!ServiceAltTab.active, "single window opened an unnecessary switcher");
                ServiceCompositor.windowList = [1,2,3].map(id => ({id:id, app_id:"Window " + id, title:"Title " + id}));
                ServiceCompositor.focusedWindowId = 2;
                ServiceCompositor.focusedWindowId = 1;
                ServiceAltTab.cycle(1);
                check(ServiceAltTab.windows[ServiceAltTab.selected].id === 2, "MRU order");
                check(!ServiceAltTab.presented, "quick press flashed overlay");
                check(ServiceCompositor.calls[0] === 2, "selection did not focus immediately");
                const beforeHide = ServiceCompositor.calls.length;
                ServiceAltTab.confirm();
                check(ServiceCompositor.calls.length === beforeHide, "hide refocused the window");
                check(!ServiceAltTab.active && !ServiceAltTab.presented, "quick release left overlay visible");
                check(ServiceCompositor.calls[0] === 2, "quick switch did not focus target");
                ServiceCompositor.calls = [];
                ServiceAltTab.cycle(1);
                check(ServiceAltTab.windows[ServiceAltTab.selected].id === 1, "rapid second tap used stale compositor focus");
                const selectedBeforeInvalidInput = ServiceAltTab.selected;
                ServiceAltTab.select(-1);
                ServiceAltTab.select(99);
                ServiceAltTab.cycle(0);
                check(ServiceAltTab.selected === selectedBeforeInvalidInput, "invalid selection changed target");
                ServiceAltTab.cycle(1);
                ServiceAltTab.cycle(1);
                check(ServiceAltTab.selected === 0, "cycle wrap");
                const beforeCancel = ServiceCompositor.calls.length;
                ServiceAltTab.cancel();
                check(ServiceCompositor.calls.length === beforeCancel, "cancel changed focus");
                ServiceAltTab.cycle(-1);
                check(ServiceAltTab.windows[ServiceAltTab.selected].id === 3, "reverse entry");
                ServiceCompositor.windowList = ServiceCompositor.windowList.filter(w => w.id !== 3);
                ServiceAltTab.confirm();
                check(ServiceCompositor.calls[ServiceCompositor.calls.length - 1] !== 3, "closed window selected");
                ServiceLock.locked = true;
                ServiceAltTab.cycle(1);
                check(!ServiceAltTab.active, "locked entry");
                ServiceLock.locked = false;
                ServiceAltTab.cycle(1);
                OverlayState.settingsActive = true;
                check(!ServiceAltTab.active, "overlay conflict");
                ServiceAltTab.cycle(1);
                finish.start();
            }
            catch (error) { console.error("ALT_TAB_FAILED " + error); Qt.quit(); }
        }
    }
    Timer
    {
        id: holdCheck
        interval: 1700
        onTriggered:
        {
            if (!ServiceAltTab.active || !ServiceAltTab.presented)
                console.error("ALT_TAB_FAILED held shortcut closed automatically");
            else
            {
                ServiceAltTab.confirm();
                if (ServiceAltTab.active || ServiceAltTab.presented)
                    console.error("ALT_TAB_FAILED release did not close overlay");
                else console.log("ALT_TAB_PASSED");
            }
            Qt.quit();
        }
    }
    Timer
    {
        id: finish
        property int phase: 0
        interval: 360
        repeat: true
        onTriggered:
        {
            try
            {
                const deck = cards.children.find(child => child.objectName === "altTabDeck");
                const repeater = deck.children.find(child => child.objectName === "altTabCards");
                check(cards.positioned, "startup layout not prepared");
                check(ServiceAltTab.presented, "held shortcut did not show overlay");
                const card = repeater.itemAt(ServiceAltTab.selected);
                check(Math.abs(card.x + card.width / 2 - deck.width / 2) < 1, "startup selection not centered");
                if (phase === 0)
                {
                    Config.animationsEnabled = true;
                    ServiceAltTab.cancel();
                    ServiceAltTab.cycle(-1);
                }
                else if (phase === 1)
                {
                    ServiceAltTab.cancel();
                    ServiceAltTab.cycle(1);
                    cards.width = 700;
                }
                else { finish.stop(); holdCheck.start(); }
                phase++;
            }
            catch (error) { console.error("ALT_TAB_FAILED " + error); Qt.quit(); }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output)
    assert "ALT_TAB_PASSED" in output
    assert not re.search(r"ALT_TAB_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", output)

print("Alt+Tab state and UI checks passed.")

with tempfile.TemporaryDirectory(prefix="bloodyshell-bindings-") as temporary:
    base = Path(temporary)
    config = base / "niri/config.kdl"
    bindings = base / "niri/bloodyShell/09-alt-tab.kdl"
    bindings.parent.mkdir(parents=True)
    original = 'recent-windows {\n    binds {\n        Alt+Tab { next-window; }\n    }\n}\n'
    config.write_text(original)
    env = dict(os.environ, XDG_CONFIG_HOME=str(base), NIRI_CONFIG=str(config))
    command = ["bash", str(ROOT / "scripts/alt-tab-bindings")]
    subprocess.run(command, env=env, check=True)
    assert '"-p" ' + json.dumps(str(ROOT)) in bindings.read_text()
    stamp = bindings.stat().st_mtime_ns
    subprocess.run(command, env=env, check=True)
    assert stamp == bindings.stat().st_mtime_ns, "Bindings rewritten on every startup"
    bindings.unlink()
    conflict = original + 'invalid-test-node\n'
    config.write_text(conflict)
    result = subprocess.run(command, env=env, capture_output=True)
    assert result.returncode != 0, "Invalid configuration accepted"
    assert config.read_text() == conflict and not bindings.exists(), "Binding rollback failed"
print("Automatic binding registration, idempotence, and rollback passed.")
