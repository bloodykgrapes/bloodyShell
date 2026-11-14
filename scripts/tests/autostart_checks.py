#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import select
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/bloodyShell"


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
                XDG_DATA_DIRS=str(base / "system-data"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                XDG_CURRENT_DESKTOP="niri", LANG="en_US.UTF-8", LC_ALL="", LC_MESSAGES="", PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])


def run_files(base):
    env = fixture(base)
    def command(*args, success=True):
        result = subprocess.run([sys.executable, str(HELPER), "internal", "autostart", *args], env=env, capture_output=True, text=True, timeout=6)
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
    watcher = subprocess.Popen([sys.executable, str(HELPER), "internal", "autostart", "watch"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        assert select.select([watcher.stdout], [], [], 3)[0] and watcher.stdout.readline().strip() == "ready"
        put(base / "config/autostart/external.desktop", app)
        assert select.select([watcher.stdout], [], [], 3)[0] and watcher.stdout.readline().strip() == "changed"
    finally:
        watcher.terminate()
        watcher.communicate(timeout=3)
    print("XDG precedence, user overrides, metadata preservation, literal commands, add/remove, and file watching passed.")


def default_entries(base):
    recorder = base / "bin/default-recorder"
    put(recorder, '#!/usr/bin/env python3\nimport json,os,sys\nwith open(os.environ["TEST_DEFAULT_LOG"],"a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n')
    recorder.chmod(0o700)
    for role, category, mime in (("browser", "WebBrowser", "x-scheme-handler/http;x-scheme-handler/https;"),
                                 ("file-manager", "FileManager", "inode/directory;"),
                                 ("terminal", "TerminalEmulator", "")):
        for suffix in ("A", "B"):
            put(base / f"data/applications/{role}{suffix}.desktop",
                f'[Desktop Entry]\nType=Application\nName={role} {suffix}\nName[ru]={role} {suffix} RU\nExec="{recorder}" {role}{suffix} %U\nCategories={category};\nMimeType={mime}\n')
    put(base / "system-data/applications/browserA.desktop", '[Desktop Entry]\nType=Application\nName=Wrong precedence\nExec=/bin/true\nCategories=WebBrowser;\n')
    put(base / "data/applications/directory-editor.desktop", '[Desktop Entry]\nType=Application\nName=Folder-capable editor\nExec=/bin/true %F\nCategories=Utility;Development;IDE;\nMimeType=text/plain;inode/directory;\n')
    for name, extra in (("hidden", "Hidden=true"), ("nodisplay", "NoDisplay=true"), ("other-desktop", "OnlyShowIn=GNOME;"), ("missing", "TryExec=bloodyShell-app-does-not-exist")):
        put(base / f"data/applications/{name}.desktop", '[Desktop Entry]\nType=Application\nName=Excluded\nExec=/bin/true\nCategories=WebBrowser;FileManager;TerminalEmulator;\n'+extra+'\n')


def run_defaults(base):
    env = fixture(base)
    default_entries(base)
    env.update(TEST_DEFAULT_LOG=str(base / "launches"), DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyShell-defaults-no-bus")
    mime = base / "config/mimeapps.list"
    original = '[Default Applications]\nx-scheme-handler/http=browserA.desktop;\ninode/directory=file-managerA.desktop;\nimage/png=keep.desktop;\n'
    put(mime, original)
    def command(*args, success=True):
        result = subprocess.run([sys.executable, str(HELPER), *args], env=env, text=True, capture_output=True, timeout=6)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result
    listing = json.loads(command("internal", "applications", "status").stdout)
    assert all([app["id"] for app in listing["applications"][role]] == [role+"A.desktop", role+"B.desktop"] for role in listing["applications"]), listing
    assert listing["current"]["browser"] == "browserA.desktop" and listing["current"]["file-manager"] == "file-managerA.desktop"
    assert not (base / "state/bloodyShell").exists(), "Discovery created an ownership journal"
    settings = {"applicationBrowser": "browserB.desktop", "applicationFileManager": "file-managerB.desktop", "applicationTerminal": "terminalB.desktop", "keepSetting": True}
    put(base / "config/bloodyShell/settings.json", json.dumps(settings))
    listing = json.loads(command("internal", "applications", "status").stdout)
    assert all(app_id == role+"B.desktop" for role, app_id in listing["current"].items()), listing
    for role in listing["current"]:
        command("open", role)
    calls = [json.loads(line) for line in (base / "launches").read_text().splitlines()]
    assert {call[0] for call in calls} == {"browserB", "file-managerB", "terminalB"}, calls
    assert next(call for call in calls if call[0] == "file-managerB")[1] in (str(base / "home"), (base / "home").as_uri()), calls
    command("open", "not-a-role", success=False)
    command("open", "browser", "extra", success=False)
    command("internal", "applications", "set", "browser", "browserB.desktop", success=False)
    assert mime.read_text() == original, "Shortcut choices changed system associations"
    assert json.loads((base / "config/bloodyShell/settings.json").read_text()) == settings
    assert not (base / "state/bloodyShell").exists(), "Launching applications created an ownership journal"
    (base / "data/applications/browserB.desktop").unlink()
    listing = json.loads(command("internal", "applications", "status").stdout)
    assert listing["current"]["browser"] == "browserA.desktop", "Removed application left an unusable shortcut"
    env["LANG"] = "ru_RU.UTF-8"
    listing = json.loads(command("internal", "applications", "status").stdout)
    assert listing["applications"]["terminal"][0]["name"].endswith(" RU"), listing
    print("Shortcut application discovery, category filtering, XDG precedence, saved choices, literal launches, missing apps and unchanged system associations passed.")


def ui_environment(base):
    env = fixture(base)
    shutil.copytree(ROOT / "modules", base / "modules")
    (base / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
    (base / "translations").symlink_to(ROOT / "translations", target_is_directory=True)
    (base / "scripts/lib").mkdir(parents=True)
    shutil.copytree(ROOT / "scripts/lib", base / "scripts/lib", dirs_exist_ok=True)
    shutil.copy2(ROOT / "scripts/bloodyShell", base / "scripts/bloodyShell")
    put(base / "scripts/lib/appearance.sh", "#!/bin/sh\nexit 0\n")
    (base / "scripts/lib/appearance.sh").chmod(0o700)
    put(base / "modules/services/ServiceLock.qml", 'pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property bool locked: false; function lock() {} }\n')
    return env


def run_removal(base):
    base.mkdir(parents=True)
    path = base / "sample.desktop"
    put(path, "[Desktop Entry]\nType=Application\nName=Sample\nExec=/bin/true\n")
    api = runpy.run_path(str(ROOT / "scripts/lib/desktop.py"))
    app = SimpleNamespace(get_filename=lambda: str(path))
    Gio = SimpleNamespace(DesktopAppInfo=SimpleNamespace(new=lambda name: app))
    for distro, output, manager in (("arch", "sample-app\n", "pacman"), ("debian", f"sample-app:amd64: {path}\n", "apt-get"), ("fedora", "sample-app\n", "dnf")):
        with patch.object(api["runpy"], "run_path", return_value={"family": lambda: distro}), patch("subprocess.run", return_value=SimpleNamespace(returncode=0, stdout=output)) as command:
            plan = api["application_removal"](Gio, "sample")
            assert plan["manager"] == manager and plan["command"][:2] == ["sudo", manager], plan
            assert plan["command"][-2:] == ["--", plan["package"]] and "--noconfirm" not in plan["command"], plan
            assert command.call_count == 1, "Preparing removal ran a package mutation"
    with patch.object(api["runpy"], "run_path", return_value={"family": lambda: "arch"}), patch("subprocess.run", return_value=SimpleNamespace(returncode=0, stdout="sample-app\nother-app\n")) as command:
        try:
            api["application_removal"](Gio, "sample")
            raise AssertionError("Ambiguous package ownership was accepted")
        except ValueError:
            pass
        command.return_value.stdout = "--recursive\n"
        try:
            api["application_removal"](Gio, "sample")
            raise AssertionError("A package option was accepted as a name")
        except ValueError:
            pass
        command.return_value.returncode = 1
        try:
            api["application_removal"](Gio, "sample")
            raise AssertionError("An unowned launcher was accepted")
        except ValueError:
            pass
    flatpak = base / "data/flatpak/app/org.example.Sample/current/active/export/share/applications/org.example.Sample.desktop"
    put(flatpak, "[Desktop Entry]\nType=Application\nX-Flatpak=org.example.Sample\n")
    app.get_filename = lambda: str(flatpak)
    with patch.dict(os.environ, XDG_DATA_HOME=str(base / "data")), patch("subprocess.run", return_value=SimpleNamespace(returncode=0, stdout="app/org.example.Sample/x86_64/stable\n")) as command:
        plan = api["application_removal"](Gio, "org.example.Sample")
        assert plan["command"] == ["flatpak", "uninstall", "--user", "--no-related", "app/org.example.Sample/x86_64/stable"]
        assert "--delete-data" not in plan["command"] and command.call_count == 1
    app.get_filename = lambda: str(path)
    with patch.dict(api["applications_action"].__globals__, application_removal=lambda *args: dict(target="pacman:changed", command=["never-run"])), patch.object(sys, "argv", ["applications", "remove", "sample", "pacman:sample-app"]), patch("subprocess.run") as command:
        try:
            api["applications_action"](Gio)
            raise AssertionError("Changed package target was accepted after confirmation")
        except RuntimeError:
            pass
        command.assert_not_called()
    print("Application package detection, conservative removal commands, ambiguous/unowned launchers, Flatpak scope, and changed-target rejection passed.")


def run_ui(base):
    env = ui_environment(base)
    terminal = base / "bin/removal-terminal"
    put(terminal, '#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ["TEST_REMOVAL_LOG"]).write_text(json.dumps(sys.argv[1:]))\n')
    terminal.chmod(0o700)
    env.update(TEST_REMOVAL_TERMINAL=str(terminal), TEST_REMOVAL_LOG=str(base / "removal-command"))
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
    property real sectionHeight: 0
    property real pageHeight: 0
    property int catalogCount: -1
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
        id: inputTimer
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
                    if (tests.catalogCount !== page.apps.length) { tests.catalogCount = page.apps.length; return; }
                    if (!section.expanded) { section.expanded = true; return; }
                    tests.appId = app.id;
                    tests.entryId = app.id.endsWith(".desktop") ? app.id : app.id + ".desktop";
                    tests.sectionHeight = section.height;
                    tests.pageHeight = page.contentHeight;
                    const add = tests.find(section, "autostartAdd");
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 1)
                {
                    inputTimer.stop();
                    const picker = section.picker;
                    let results = tests.find(picker.contentItem, "autostartCandidates");
                    let pickerSearch = tests.find(picker.contentItem, "autostartSearch");
                    tests.check(picker.visible && picker.modal && OverlayState.settingsPopup, "Add does not open a modal application picker");
                    tests.check(results && results.count > 4 && results.interactive, "Application picker is still limited to inline rows");
                    tests.check(section.height === tests.sectionHeight && page.contentHeight === tests.pageHeight, "Opening the picker inserts rows into the page");
                    tests.check(picker.x >= 0 && picker.y >= 0 && picker.x + picker.width <= picker.parent.width && picker.y + picker.height <= picker.parent.height, "Application picker exceeds its host");
                    const pagePosition = page.contentY;
                    events.mouseWheel(results, results.width / 2, 28, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                    events.wait(200);
                    tests.check(results.contentY > 0 && page.contentY === pagePosition, "Picker scrolling moves the settings page: " + results.contentY + ", " + page.contentY + ", expected " + pagePosition);
                    events.mouseWheel(pickerSearch, pickerSearch.width / 2, pickerSearch.height / 2, 0, -120, Qt.NoButton, Qt.NoModifier, 0);
                    events.wait(60);
                    tests.check(page.contentY === pagePosition, "Search wheel events leak through the modal picker");
                    window.width = 420; window.height = 360;
                    events.wait(40);
                    tests.check(picker.width <= window.width - 32 && picker.height <= window.height - 32 && results.height > 0, "Application picker does not fit a compact window");
                    window.width = 1080; window.height = 800;
                    events.wait(40);
                    pickerSearch.grabFocus();
                    events.keyClick(Qt.Key_Down);
                    tests.check(results.activeFocus && results.currentIndex === 0, "Popup results cannot be reached from search with the keyboard");
                    events.keyClick(Qt.Key_Escape);
                    tests.check(!picker.visible && !OverlayState.settingsPopup && ServiceApplications.autostartEntries.length === 1, "Escape did not cancel the picker without adding an app");
                    const add = tests.find(section, "autostartAdd");
                    tests.check(add.activeFocus, "Closing the picker did not restore focus to Add application");
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    const cancel = tests.find(picker.contentItem, "autostartCancel");
                    events.mouseClick(cancel, cancel.width / 2, cancel.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(!picker.visible && !OverlayState.settingsPopup, "Cancel did not dismiss the picker");
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    events.mouseClick(window.contentItem, 2, 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(!picker.visible && !OverlayState.settingsPopup, "Outside click did not dismiss the picker");
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    section.choose("org.example.DoesNotExist");
                    for (let i=0;i<100 && (ServiceApplications.autostartBusy || picker.errorText === "");i++) events.wait(20);
                    tests.check(picker.visible && picker.errorText !== "", "Failed addition closed the picker or hid its error");
                    pickerSearch.text = "Autostart Fixture"; pickerSearch.textEdited(pickerSearch.text);
                    tests.check(section.candidates.length === 1 && section.candidates[0].id === tests.appId, "Popup search does not update its results");
                    events.wait(20);
                    const choose = tests.find(picker.contentItem, "autostartChoose-" + tests.appId);
                    tests.check(choose !== null, "Searchable application picker did not load");
                    events.mouseClick(choose, choose.width / 2, choose.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                    inputTimer.start();
                }
                else if (tests.phase === 2)
                {
                    if (!entry) return;
                    tests.check(entry.enabled && entry.removable, "Adding an application failed");
                    if (section.picker.visible) return;
                    tests.check(!OverlayState.settingsPopup && section.pendingApp === "", "Successful addition left popup state behind");
                    const toggle = tests.find(section, "autostartToggle-" + tests.entryId);
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 3)
                {
                    if (!entry || entry.enabled) return;
                    Quickshell.execDetached(["python3", Paths.command, "internal", "autostart", "set", tests.entryId, "true"]);
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
                    tests.check(!add.highlighted && !add.pressed && !section.picker.visible, "Disabled button keeps its hover or accepts a click");
                    add.enabled = true;
                    page.resetScroll();
                    events.mouseClick(add, add.width / 2, add.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    events.wait(Theme.animationDurationControl + 40);
                    tests.check(section.picker.visible, "Animated popup failed to open");
                    section.picker.close();
                    events.wait(Theme.animationDurationClose + 40);
                    Config.set("themeAnimations", 0);
                    section.expanded = false;
                    search.text = "Autostart Fixture"; search.textEdited(search.text);
                    events.wait(60);
                    page.resetScroll();
                    const row = tests.find(page, "applicationRow-" + tests.appId);
                    const menu = events.findChild(page, "applicationContextMenu");
                    tests.check(row && menu, "Application context menu fixture did not load");
                    events.mouseClick(row, 30, 30, Qt.RightButton, Qt.NoModifier, 0);
                    events.wait(30);
                    tests.check(menu.visible && menu.application.id === tests.appId && OverlayState.settingsPopup, "Right-click did not open the application menu");
                    tests.check(menu.x >= 8 && menu.y >= 8 && menu.x + menu.width <= window.width - 8 && menu.y + menu.height <= window.height - 8, "Application menu exceeds the window");
                    const pin = tests.find(menu.contentItem, "applicationPinToggle");
                    const notifications = tests.find(menu.contentItem, "applicationNotificationsToggle");
                    const pinRow = tests.find(menu.contentItem, "applicationPin");
                    events.mouseMove(window.contentItem, 2, 2, 0);
                    tests.check(!pinRow.hovered && !pinRow.highlighted && !pin.hovered && !pin.highlighted, "Mouse-opened menu leaves Dock pin highlighted away from the pointer");
                    events.mouseClick(pin, pin.width / 2, pin.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(ServiceDock.isPinned(tests.appId) && pin.checked, "Dock pin toggle failed");
                    events.mouseClick(notifications, notifications.width / 2, notifications.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(!ServiceNotifications.enabledFor(tests.appId) && !notifications.checked, "Notifications toggle failed");
                    tests.check(!pin.hovered && !pin.highlighted && !pinRow.highlighted, "Dock pin stays hovered after moving to another toggle");
                    OverlayState.popupsSuspended = true;
                    tests.check(menu.visible && menu.suspended && !menu.enabled && menu.opacity === 0 && !OverlayState.settingsPopup, "Application menu remained above the screenshot overlay");
                    OverlayState.popupsSuspended = false;
                    tests.check(menu.visible && menu.enabled && OverlayState.settingsPopup, "Application menu did not resume after a screenshot");
                    events.keyClick(Qt.Key_Escape);
                    tests.check(!menu.visible && !OverlayState.settingsPopup, "Escape did not close the context menu");
                    const menuButton = tests.find(page, "applicationMenu-" + tests.appId);
                    events.mouseClick(menuButton, menuButton.width / 2, menuButton.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    events.wait(30);
                    events.mouseMove(window.contentItem, 2, 2, 0);
                    tests.check(menu.visible && !menuButton.hovered && !menuButton.highlighted, "Actions button remains hovered behind its open popup");
                    events.mouseClick(window.contentItem, 2, 2, Qt.LeftButton, Qt.NoModifier, 0);
                    events.wait(30);
                    tests.check(!menu.visible && !menuButton.hovered && !menuButton.highlighted, "Actions button stays highlighted after closing its popup");
                    menuButton.focusFor(Qt.TabFocusReason);
                    events.keyClick(Qt.Key_F10, Qt.ShiftModifier);
                    events.wait(30);
                    tests.check(menu.visible, "Keyboard context menu shortcut failed");
                    tests.check(pinRow.visualFocus && pinRow.highlighted, "Keyboard application menu has no focused action");
                    const removeApp = tests.find(menu.contentItem, "applicationDelete");
                    events.mouseClick(removeApp, removeApp.width / 2, removeApp.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    const removal = events.findChild(page, "applicationRemoval");
                    tests.check(!menu.visible && removal.visible && removal.danger, "Delete did not open a confirmation popup");
                    for (let i = 0; i < 100 && removal.errorText === ""; i++) events.wait(20);
                    tests.check(!removal.acceptEnabled && removal.errorText !== "", "An unowned application was accepted for package removal");
                    const cancelRemoval = tests.find(removal.contentItem, "cancelConfirmation");
                    events.mouseClick(cancelRemoval, cancelRemoval.width / 2, cancelRemoval.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.check(!removal.visible && !OverlayState.settingsPopup, "Cancel did not dismiss application removal");
                    removal.plan = {package: "fixture-app", manager: "pacman", target: "pacman:fixture-app", terminal: [Quickshell.env("TEST_REMOVAL_TERMINAL")]};
                    removal.open();
                    events.wait(30);
                    tests.check(removal.acceptEnabled, "A prepared package cannot be confirmed");
                    const acceptRemoval = tests.find(removal.contentItem, "acceptConfirmation");
                    events.mouseClick(acceptRemoval, acceptRemoval.width / 2, acceptRemoval.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    events.wait(150);
                    tests.check(!removal.visible, "Confirmed application removal left its popup open");
                    window.width = 360; window.height = 480;
                    events.wait(30);
                    menu.openFor(menu.application, window.contentItem, 359, 479);
                    events.wait(30);
                    tests.check(menu.x + menu.width <= window.width - 8 && menu.y + menu.height <= window.height - 8, "Context menu does not fit a compact window");
                    page.visible = false;
                    events.wait(Theme.animationDurationClose + 40);
                    tests.check(!section.picker.visible && !menu.visible && !removal.visible && !OverlayState.settingsPopup, "Hidden Applications page left its popup open");
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
    assert json.loads((base / "removal-command").read_text()) == ["python3", str(base / "scripts/bloodyShell"), "internal", "applications", "remove", "org.example.Autostart", "pacman:fixture-app"]
    print("Autostart picker, application context menu, pin/notification toggles, removal confirmation, keyboard/mouse input, compact placement, and popup cleanup passed.")


def run_defaults_ui(base):
    env = ui_environment(base)
    default_entries(base)
    put(base / "config/bloodyShell/settings.json", json.dumps({"helperSeen": True, "themeAnimations": 0, "shellLanguage": "en"}))
    put(base / "shell.qml", '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
ShellRoot {
    Window {
        id: window; visible: true; width: 1080; height: 800
        PageApplications { id: page; anchors.fill: parent }
        TestCase {
            id: events; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(test, message) { for(let i=0;i<150;i++) { if(test()) return; wait(20); } throw new Error(message + ": " + ServiceApplications.defaultsError); }
            function find(item, name) { if(item.objectName===name) return item; for(const child of item.children || []) { const match=find(child,name); if(match) return match; } return null; }
            function exercise() {
                until(()=>Config.initialized && ServiceApplications.defaultOptions("terminal").length===2 && !ServiceApplications.defaultsBusy, "Application choices did not load");
                const defaults=find(page,"defaultApplicationsSection"), autostart=find(page,"autostartSection");
                check(defaults && autostart && defaults.y>autostart.y && !defaults.expanded,"Default applications foldout is missing, expanded, or misplaced");
                defaults.expanded=true; wait(50);
                ServiceApplications.defaultsError="Fixture discovery failure";
                const refresh=find(defaults,"refreshDefaultApplications");
                check(refresh && refresh.enabled,"Application discovery cannot be retried");
                refresh.clicked();
                until(()=>!ServiceApplications.defaultsBusy && ServiceApplications.defaultsError==="","Discovery retry did not recover");
                for(const role of ["browser","file-manager","terminal"]) {
                    const combo=find(defaults,"defaultApplication-"+role);
                    check(combo && combo.enabled && combo.options.length===2,"Wrong candidates: "+role);
                    check(combo.parent.parent.valueText==={browser:"Super+W","file-manager":"Super+E",terminal:"Super+T"}[role],"Shortcut hint is missing: "+role);
                    combo.forceActiveFocus(); keyClick(Qt.Key_Space); wait(30);
                    check(combo.open && OverlayState.settingsPopup,"Dropdown did not open: "+role);
                    keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); wait(20);
                    check(!combo.open && combo.current===role+"B.desktop","Choice was not applied: "+role);
                }
                check(Config.applicationBrowser==="browserB.desktop" && Config.applicationFileManager==="file-managerB.desktop" && Config.applicationTerminal==="terminalB.desktop","Choices did not persist in shell settings");
                window.width=420; wait(60);
                for(const role of ["browser","file-manager","terminal"]) {
                    const combo=find(defaults,"defaultApplication-"+role);
                    check(combo.width>0 && combo.width<=combo.parent.width,"Compact dropdown exceeds its row: "+role);
                }
                window.width=1080; wait(40);
                const browser=find(defaults,"defaultApplication-browser");
                browser.forceActiveFocus(); keyClick(Qt.Key_Space); wait(20);
                ServiceApplications.refreshDefaults();
                check(browser.enabled && browser.open,"Background discovery interrupted the selector");
                browser.selected("browserA.desktop");
                until(()=>!ServiceApplications.defaultsBusy,"Background discovery did not finish");
                check(browser.current==="browserA.desktop" && browser.open,"Discovery discarded the current selection or closed its popup");
                Config.set("applicationBrowser","browserB.desktop");
                defaults.expanded=false; wait(40);
                check(!browser.open && !OverlayState.settingsPopup,"Collapsing the section left its popup open");
                ServiceApplications.defaultApplications=Object.assign({},ServiceApplications.defaultApplications,{terminal:[]});
                check(!find(defaults,"defaultApplication-terminal").enabled,"An empty category still accepts a selection");
                Config.set("applicationBrowser","browserA.desktop");
                check(browser.current==="browserA.desktop","External preference change did not update the selector");
                Config.set("applicationBrowser","browserB.desktop");
                wait(450);
                page.visible=false; wait(40);
                check(ServiceApplications.autostartClients.length===0,"Closing the page left subscriptions behind");
                console.log("DEFAULT_APPLICATIONS_UI_PASSED placement, filtering, keyboard selection, saved choices, compact layout, empty categories and popup cleanup");
                Qt.quit();
            }
        }
        Timer { interval:150; running:true; onTriggered:{ try { events.exercise(); } catch(error) { console.error("DEFAULT_APPLICATIONS_UI_FAILED",error); Qt.quit(); } } }
    }
}
''')
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyShell-defaults-no-session",
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyShell-defaults-no-system", NIRI_SOCKET="/tmp/bloodyShell-defaults-no-niri")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=10)
    output=result.stdout+result.stderr
    print(output)
    assert result.returncode==0 and "DEFAULT_APPLICATIONS_UI_PASSED" in output, output
    assert not re.search(r"DEFAULT_APPLICATIONS_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), output
    settings=json.loads((base / "config/bloodyShell/settings.json").read_text())
    assert settings["applicationBrowser"]=="browserB.desktop" and settings["applicationFileManager"]=="file-managerB.desktop" and settings["applicationTerminal"]=="terminalB.desktop", settings
    assert not (base / "config/mimeapps.list").exists(), "Shortcut selection wrote MIME associations"


def main():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-autostart-") as temporary:
        base = Path(temporary)
        run_removal(base / "removal")
        run_defaults(base / "defaults")
        run_defaults_ui(base / "defaults-ui")
        run_files(base / "files")
        run_ui(base / "ui")


if __name__ == "__main__":
    main()
