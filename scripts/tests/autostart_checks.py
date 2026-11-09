#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/runtime/autostart"


def put(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def fixture(base):
    for name in ("home", "config", "system", "lower", "data/applications", "system-data/applications", "cache", "runtime", "bin"):
        (base / name).mkdir(parents=True, mode=0o700)
    put(base / "bin/systemctl", "#!/bin/sh\nprintf 'active\\n'\n")
    (base / "bin/systemctl").chmod(0o700)
    for name in ("niri", "awww", "cava"):
        put(base / "bin" / name, "#!/bin/sh\nexit 1\n")
        (base / "bin" / name).chmod(0o700)
    return dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                XDG_CONFIG_DIRS=str(base / "system") + ":" + str(base / "lower"), XDG_DATA_HOME=str(base / "data"),
                XDG_DATA_DIRS=str(base / "system-data"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                XDG_CURRENT_DESKTOP="niri", LANG="en_US.UTF-8", LC_ALL="", LC_MESSAGES="", PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])


def run_files(base):
    env = fixture(base)
    def command(*args, success=True):
        result = subprocess.run([sys.executable, str(HELPER), *args], env=env, capture_output=True, text=True, timeout=6)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return json.loads(result.stdout) if success else result.stderr
    original = "# Keep comments\n[Desktop Entry]\nType=Application\nName=System app\nName[ru]=Системное\nExec=/bin/true %U\nIcon=application-x-executable\nX-Custom-Key=keep %s\nOnlyShowIn=niri;\n"
    system = base / "system/autostart/system.desktop"
    put(system, original)
    put(base / "lower/autostart/system.desktop", original.replace("System app", "Wrong precedence"))
    put(base / "system/autostart/masked.desktop", original.replace("System app", "Masked"))
    put(base / "config/autostart/masked.desktop", "[Desktop Entry]\nHidden=true\nX-User-Key=preserve\n")
    put(base / "system/autostart/desktop.desktop", original.replace("OnlyShowIn=niri;", "OnlyShowIn=GNOME;"))
    put(base / "system/autostart/missing.desktop", original + "TryExec=bloodyshell-nonexistent-autostart-program\n")
    put(base / "system/autostart/override.desktop", original.replace("OnlyShowIn=niri;", "OnlyShowIn=GNOME;"))
    put(base / "config/autostart/override.desktop", "[Desktop Entry]\nType=Application\nName=User override\nExec=/bin/true\n")
    listing = command("list")
    entries = {entry["id"]: entry for entry in listing["entries"]}
    assert listing["session"] == "active"
    assert entries["system.desktop"]["name"] == "System app"
    assert not entries["masked.desktop"]["enabled"] and entries["masked.desktop"]["valid"]
    assert entries["desktop.desktop"]["reason"] == "desktop"
    assert entries["missing.desktop"]["reason"] == "executable"
    assert entries["override.desktop"]["name"] == "User override" and entries["override.desktop"]["reason"] == ""
    env["LANG"] = "ru_RU.UTF-8"
    localized = {entry["id"]: entry for entry in command("list")["entries"]}
    assert localized["system.desktop"]["name"] == "Системное" and localized["override.desktop"]["name"] == "User override"
    env["LANG"] = "en_US.UTF-8"
    command("set", "system.desktop", "false")
    assert system.read_text() == original
    assert "Hidden=true" in (base / "config/autostart/system.desktop").read_text()
    command("set", "masked.desktop", "true")
    restored = (base / "config/autostart/masked.desktop").read_text()
    assert "Exec=/bin/true %U" in restored and "X-User-Key=preserve" in restored and "Hidden=false" in restored
    executable = '/bin/true "literal $(touch should-not-exist)" %U'
    app = "# Application metadata\n[Desktop Entry]\nType=Application\nName=Autostart Fixture\nExec=" + executable + "\nX-Unknown=keep\n\n[Desktop Action Test]\nName=Action\nExec=/bin/false\nHidden=action-value\n"
    put(base / "data/applications/org.example.Autostart.desktop", app)
    put(base / "system-data/applications/org.example.Autostart.desktop", app.replace("Autostart Fixture", "Wrong application"))
    command("add", "org.example.Autostart")
    target = base / "config/autostart/org.example.Autostart.desktop"
    added = target.read_text()
    assert executable in added and "X-Unknown=keep" in added and "Hidden=action-value" in added
    assert "# Application metadata" in added and "Name=Autostart Fixture" in added
    assert "X-BloodyShell-AppId=org.example.Autostart" in added and not (base / "should-not-exist").exists()
    command("add", "org.example.Autostart.desktop", success=False)
    command("set", target.name, "false")
    assert "Hidden=true" in target.read_text() and "Hidden=action-value" in target.read_text()
    command("set", target.name, "true")
    assert "Hidden=false" in target.read_text()
    command("remove", target.name)
    assert not target.exists()
    command("remove", "system.desktop", success=False)
    for invalid in ("../escape.desktop", "/tmp/escape.desktop", ".desktop", "line\nbreak.desktop"):
        command("set", invalid, "false", success=False)
        command("add", invalid, success=False)
    put(base / "data/applications/vendor/extra.desktop", app)
    command("add", "vendor-extra.desktop")
    assert (base / "config/autostart/vendor-extra.desktop").exists()
    link = base / "config/autostart/link.desktop"
    link.symlink_to(system)
    command("set", link.name, "false")
    assert not link.is_symlink() and system.read_text() == original
    command("remove", link.name)
    put(base / "config/autostart/gnome.desktop", original + "X-GNOME-Autostart-enabled=false\n")
    assert not next(entry for entry in command("list")["entries"] if entry["id"] == "gnome.desktop")["enabled"]
    command("set", "gnome.desktop", "true")
    assert "X-GNOME-Autostart-enabled=true" in (base / "config/autostart/gnome.desktop").read_text()
    (base / "config/autostart/loop.desktop").symlink_to("loop.desktop")
    assert not list((base / "config/autostart").glob(".bloodyShell-*.tmp"))
    watcher = subprocess.Popen([sys.executable, str(HELPER), "watch"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert select.select([watcher.stdout], [], [], 3)[0] and watcher.stdout.readline().strip() == "ready"
        put(base / "config/autostart/external.desktop", app)
        assert select.select([watcher.stdout], [], [], 3)[0] and watcher.stdout.readline().strip() == "changed"
    finally:
        watcher.terminate()
        watcher.communicate(timeout=3)
    print("XDG precedence, user overrides, metadata preservation, literal commands, add/remove, and file watching passed.")


def run_ui(base):
    env = fixture(base)
    shutil.copytree(ROOT / "modules", base / "modules")
    (base / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
    (base / "translations").symlink_to(ROOT / "translations", target_is_directory=True)
    (base / "scripts/runtime").mkdir(parents=True)
    shutil.copy2(HELPER, base / "scripts/runtime/autostart")
    put(base / "scripts/runtime/appearance", "#!/bin/sh\nexit 0\n")
    (base / "scripts/runtime/appearance").chmod(0o700)
    put(base / "modules/services/ServiceLock.qml", 'pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property bool locked: false; function lock() {} }\n')
    put(base / "config/bloodyShell/settings.json", json.dumps({"helperSeen": True, "themeAnimations": 0}))
    original = "[Desktop Entry]\nType=Application\nName=System fixture\nExec=/bin/true\n"
    put(base / "system/autostart/system.desktop", original)
    put(base / "data/applications/org.example.Autostart.desktop", "[Desktop Entry]\nType=Application\nName=Autostart Fixture\nExec=/bin/true %U\nIcon=application-x-executable\n")
    for index in range(20):
        put(base / f"data/applications/org.example.Extra{index}.desktop", f"[Desktop Entry]\nType=Application\nName=Extra application {index}\nExec=/bin/true\n")
    put(base / "shell.qml", r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot
{
    id: tests
    property int phase: 0
    property string appId: ""
    property string entryId: ""
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name)
    {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    Window
    {
        id: window
        visible: true
        width: 1080; height: 800
        PageApplications { id: page; anchors.fill: parent }
        TestCase { id: events; name: "AutostartInput"; when: false; optional: true }
    }
    Timer
    {
        interval: 80; repeat: true; running: true
        onTriggered:
        {
            if (!Config.initialized || ServiceApplications.autostartBusy) return;
            try
            {
                const entry = ServiceApplications.autostartEntries.find(item => item.id === tests.entryId);
                const section = tests.find(page, "autostartSection");
                if (tests.phase === 0)
                {
                    const app = ServiceApplications.search("Autostart Fixture")[0];
                    if (!app || ServiceApplications.autostartEntries.length === 0) return;
                    tests.appId = app.id;
                    tests.entryId = app.id.endsWith(".desktop") ? app.id : app.id + ".desktop";
                    section.expanded = true;
                    const add = tests.find(section, "autostartAdd");
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 1)
                {
                    const results = tests.find(section, "autostartCandidates");
                    const pickerSearch = tests.find(section, "autostartSearch");
                    tests.check(results && section.candidates.length === 4 && results.height === 4 * 56, "Autostart picker is not limited to four static rows");
                    tests.check(page.interactive && results.contentY === undefined, "Page scrolling or static results changed");
                    const matches = section.candidates.map(app => app.id).join(",");
                    const pagePosition = page.contentY;
                    events.mouseWheel(results, results.width / 2, 28, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                    tests.check(page.contentY > pagePosition, "Wheel over static results does not scroll the page");
                    const nextPosition = page.contentY;
                    events.mouseWheel(pickerSearch, pickerSearch.width / 2, pickerSearch.height / 2, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                    tests.check(page.contentY > nextPosition, "Wheel over autostart search does not scroll the page");
                    tests.check(section.candidates.map(app => app.id).join(",") === matches, "Scrolling changes the static matches");
                    page.resetScroll();
                    pickerSearch.text = "Autostart Fixture"; pickerSearch.textEdited(pickerSearch.text);
                    tests.check(section.candidates.length === 1 && section.candidates[0].id === tests.appId, "Static picker does not update on search");
                    const choose = tests.find(section, "autostartChoose-" + tests.appId);
                    tests.check(choose !== null, "Searchable application picker did not load");
                    events.mouseClick(choose, choose.width / 2, choose.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 2)
                {
                    if (!entry) return;
                    tests.check(entry.enabled && entry.removable, "Adding an application failed");
                    const toggle = tests.find(section, "autostartToggle-" + tests.entryId);
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 3)
                {
                    if (!entry || entry.enabled) return;
                    Quickshell.execDetached(["python3", Paths.shellDir + "/scripts/runtime/autostart", "set", tests.entryId, "true"]);
                    tests.phase++;
                }
                else if (tests.phase === 4)
                {
                    if (!entry || !entry.enabled) return;
                    const remove = tests.find(section, "autostartRemove-" + tests.entryId);
                    events.mouseClick(remove, remove.width / 2, remove.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 5)
                {
                    if (entry) return;
                    const toggle = tests.find(section, "autostartToggle-system.desktop");
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 6)
                {
                    const system = ServiceApplications.autostartEntries.find(item => item.id === "system.desktop");
                    if (system.enabled) return;
                    tests.check(system.system && !system.removable, "System entry lost its override behavior");
                    const toggle = tests.find(section, "autostartToggle-system.desktop");
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 7)
                {
                    const system = ServiceApplications.autostartEntries.find(item => item.id === "system.desktop");
                    if (!system.enabled) return;
                    tests.check(ServiceApplications.autostartError === "", ServiceApplications.autostartError);
                    ServiceApplications.addAutostart("org.example.DoesNotExist");
                    tests.phase++;
                }
                else
                {
                    stop();
                    tests.check(ServiceApplications.autostartError !== "", "Failed operations are not reported");
                    tests.check(ServiceApplications.autostartEntries.some(item => item.id === "system.desktop"), "Failed operation discarded the entries");
                    const search = tests.find(page, "applicationsSearch");
                    tests.check(search && page.contentHeight > page.height, "Scrolling search fixture did not load");
                    const position = search.mapToItem(window.contentItem, 0, 0);
                    page.contentY = 120;
                    const scrolled = search.mapToItem(window.contentItem, 0, 0);
                    tests.check(Math.abs(position.y - scrolled.y) < 0.01, "Applications search moves when the page scrolls");
                    search.text = "Extra application"; search.textEdited(search.text);
                    tests.check(page.contentY === 0 && page.apps.length > 0, "Typing a query leaves results outside the view");
                    search.text = ""; search.textEdited("");
                    Config.set("themeAnimations", 2);
                    const add = tests.find(section, "autostartAdd");
                    tests.check(String(add.color) === String(Theme.colorField) && add.border.width === 0, "Settings button does not match field controls");
                    events.mouseMove(add, add.width / 2, add.height / 2, 0);
                    tests.check(add.hovered && String(add.color) === String(Theme.colorField), "Hover changes the button base color");
                    events.mousePress(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(add.pressed && String(add.color) === String(Theme.colorField), "Press changes the button base color");
                    add.enabled = false;
                    events.mouseRelease(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(!add.hovered && !add.pressed && !section.adding, "Disabled button keeps its hover or accepts a click");
                    page.visible = false;
                    tests.check(!ServiceApplications.autostartWatching, "Hidden Applications page keeps its file watcher");
                    console.log("AUTOSTART_UI_PASSED"); Qt.quit();
                }
            }
            catch (error) { console.error("AUTOSTART_UI_FAILED", tests.phase, error); Qt.quit() }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("AUTOSTART_UI_FAILED timeout", tests.phase, ServiceApplications.autostartError); Qt.quit() } }
}
''')
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-no-session-bus",
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-no-system-bus", NIRI_SOCKET="/tmp/bloodyshell-no-niri")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=16)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "AUTOSTART_UI_PASSED" in output, "Autostart UI checks failed"
    assert not re.search(r"AUTOSTART_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), "Autostart QML error"
    assert (base / "system/autostart/system.desktop").read_text() == original
    assert "Hidden=false" in (base / "config/autostart/system.desktop").read_text()
    assert not (base / "config/autostart/org.example.Autostart.desktop").exists()
    print("Applications picker, fixed search, button states, autostart actions, external changes, and watcher suspension passed.")


def main():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-autostart-") as temporary:
        base = Path(temporary)
        run_files(base / "files")
        run_ui(base / "ui")


if __name__ == "__main__":
    main()
