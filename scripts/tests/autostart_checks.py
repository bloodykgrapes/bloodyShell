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


def run_associations(base):
    env = fixture(base)
    default_entries(base)
    put(base / "data/applications/mimeinfo.cache", "[MIME Cache]\ninode/directory=file-managerA.desktop;file-managerB.desktop;directory-editor.desktop;\ntext/plain=directory-editor.desktop;\n")
    mime = base / "config/mimeapps.list"
    put(mime, "[Default Applications]\ninode/directory=file-managerA.desktop;\nimage/png=keep.desktop;\n")
    settings = base / "config/bloodyShell/settings.json"
    put(settings, '{"applicationFileManager":"file-managerA.desktop"}')
    original_settings = settings.read_bytes()
    def command(*args, success=True):
        result = subprocess.run([sys.executable, str(HELPER), "internal", "applications", "associations", *args], env=env, text=True, capture_output=True, timeout=6)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return json.loads(result.stdout) if success else None
    listing = command("status")
    assert len(listing["entries"]) == 30
    folders = next(entry for entry in listing["entries"] if entry["id"] == "folders")
    assert folders["current"] == "file-managerA.desktop"
    assert "file-managerB.desktop" in [app["id"] for app in folders["applications"]]
    result = command("set", "folders", "file-managerB.desktop")
    assert next(entry for entry in result["entries"] if entry["id"] == "folders")["current"] == "file-managerB.desktop"
    assert "image/png=keep.desktop;" in mime.read_text()
    before = mime.read_bytes()
    for args in (("set", "pdf", "file-managerB.desktop"), ("set", "unknown", "file-managerA.desktop"), ("set", "folders", "../../escape.desktop")):
        command(*args, success=False)
        assert mime.read_bytes() == before, "Invalid association request changed defaults"
    assert settings.read_bytes() == original_settings, "File associations changed niri shortcut choices"
    print("File associations passed: discovery, supported apps, user defaults, unrelated MIME/shortcut preservation and invalid requests.")


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
    put(base / "config/bloodyShell/settings.json", json.dumps({"helperSeen": True, "motionStyle": 0}))
    original = "[Desktop Entry]\nType=Application\nName=System fixture\nExec=/bin/true\n"
    put(base / "system/autostart/system.desktop", original)
    put(base / "system/autostart/override.desktop", original)
    override = "[Desktop Entry]\nHidden=true\n"
    put(base / "config/autostart/override.desktop", override)
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
        PageApplications { id: overview; anchors.fill: parent; visible: tests.phase < 5 }
        PageAllApplications { id: page; anchors.fill: parent; visible: tests.phase >= 5 }
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
                const section = tests.find(overview, "autostartSection");
                if (tests.phase === 0)
                {
                    const app = ServiceApplications.search("Autostart Fixture")[0];
                    if (!app || ServiceApplications.autostartEntries.length === 0) return;
                    if (tests.catalogCount !== page.apps.length) { tests.catalogCount = page.apps.length; return; }
                    tests.appId = app.id;
                    tests.entryId = app.id.endsWith(".desktop") ? app.id : app.id + ".desktop";
                    tests.check(section.entries.length === 0, "The group counts system autostart entries");
                    tests.check(!tests.find(section, "autostartToggle-system.desktop") && !tests.find(section, "autostartToggle-override.desktop"),
                        "The group shows a system entry or its override");
                    ServiceApplications.addAutostart(tests.appId);
                    tests.phase++;
                }
                else if (tests.phase === 1)
                {
                    if (!entry || !entry.enabled) return;
                    tests.check(section.entries.length === 1, "The group did not list the user entry");
                    const toggle = tests.find(section, "autostartToggle-" + tests.entryId);
                    overview.contentY = Math.max(0, overview.contentHeight - overview.height);
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 2)
                {
                    if (!entry || entry.enabled) return;
                    const toggle = tests.find(section, "autostartToggle-" + tests.entryId);
                    events.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 3)
                {
                    if (!entry || !entry.enabled) return;
                    const remove = tests.find(section, "autostartRemove-" + tests.entryId);
                    events.mouseClick(remove, remove.width / 2, remove.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
                    tests.phase++;
                }
                else if (tests.phase === 4)
                {
                    if (entry) return;
                    tests.check(section.entries.length === 0, "Removed entry still appears in the group");
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
                    tests.check(search, "Scrolling search fixture did not load");
                    search.text = ""; search.textEdited(""); events.wait(30);
                    const position = search.mapToItem(window.contentItem, 0, 0);
                    page.contentY = 120;
                    const scrolled = search.mapToItem(window.contentItem, 0, 0);
                    tests.check(Math.abs(position.y - scrolled.y) < 0.01 && page.hasHeader, "Applications search scrolls with the list");
                    search.text = "Extra application"; search.textEdited(search.text);
                    tests.check(page.contentY === 120 && page.apps.length > 0, "Typing a query scrolls back to unrelated settings");
                    search.text = ""; search.textEdited("");
                    search.text = "Autostart Fixture"; search.textEdited(search.text);
                    events.wait(60);
                    page.resetScroll();
                    const row = tests.find(page, "applicationRow-" + tests.appId);
                    const menu = events.findChild(page, "applicationContextMenu");
                    tests.check(row && menu, "Application context menu fixture did not load");
                    ServiceCompositor.backend.runningVersion = "niri 26.04";
                    Config.set("shellSurface", Enums.SurfaceBlur);
                    events.mouseClick(row, 30, 30, Qt.RightButton, Qt.NoModifier, 0);
                    events.wait(30);
                    tests.check(menu.visible && menu.application.id === tests.appId && OverlayState.settingsPopup, "Right-click did not open the application menu");
                    const menuSurface = menu.contentItem.surface.materialSurface;
                    tests.check(ShellMaterial.blur && menuSurface.color.a === 1 && !menuSurface.blurActive, "Application menu inherits Blur from the shell");
                    Config.set("shellSurface", Enums.SurfaceBackdrop);
                    tests.check(ShellMaterial.backdrop && menuSurface.color.a === 1 && !menuSurface.materialEnabled, "Application menu inherits Backdrop from the shell");
                    Config.set("shellSurface", Enums.SurfaceSolid);
                    tests.check(tests.find(menu.contentItem, "applicationAutostart")?.visible, "Application menu is missing Autostart");
                    tests.check(menu.x >= 8 && menu.y >= 8 && menu.x + menu.width <= window.width - 8 && menu.y + menu.height <= window.height - 8, "Application menu exceeds the window");
                    menu.close();
                    for (const mode of [Enums.MotionFluid, Enums.MotionGlide])
                    {
                        Config.set("motionStyle",mode);
                        menu.openFor(menu.application,window.contentItem,window.width-2,window.height-2);
                        events.wait(30);
                        const reveal = tests.find(menu.contentItem,"applicationMenuReveal");
                        tests.check(reveal.progress>0 && reveal.progress<1 && reveal.revealWidth<reveal.width && reveal.revealHeight<reveal.height,
                            "Application context menu does not expand in both dimensions");
                        const rowWidth = tests.find(menu.contentItem,"applicationPin").width;
                        events.wait(Theme.animationDurationControl+40);
                        tests.check(reveal.revealWidth===reveal.width && reveal.revealHeight===reveal.height && tests.find(menu.contentItem,"applicationPin").width===rowWidth,
                            "Application context menu resizes its content during expansion");
                        menu.close();events.wait(30);
                        tests.check(reveal.progress>0 && reveal.progress<1 && reveal.revealHeight<reveal.height,"Application context menu does not shrink on close");
                        const interrupted = reveal.progress;
                        menu.openFor(menu.application,window.contentItem,window.width-2,window.height-2);
                        tests.check(reveal.progress>=interrupted-0.02,"Reopening resets the application menu expansion");
                        events.wait(Theme.animationDurationControl+40);
                        menu.close();events.wait(Theme.animationDurationClose+40);
                    }
                    Config.set("motionStyle", Enums.MotionDirect);
                    menu.openFor(menu.application,row,30,30);events.wait(30);
                    const pin = tests.find(menu.contentItem, "applicationPinToggle");
                    const notifications = tests.find(menu.contentItem, "applicationNotificationsToggle");
                    const startup = tests.find(menu.contentItem, "applicationAutostartToggle");
                    const pinRow = tests.find(menu.contentItem, "applicationPin");
                    const startupWasEnabled = startup.checked;
                    startup.toggled(!startupWasEnabled);
                    for (let i = 0; i < 100 && startup.checked === startupWasEnabled; i++) events.wait(20);
                    tests.check(startup.checked !== startupWasEnabled, "Application menu did not change autostart");
                    startup.toggled(startupWasEnabled);
                    for (let i = 0; i < 100 && startup.checked !== startupWasEnabled; i++) events.wait(20);
                    tests.check(startup.checked === startupWasEnabled, "Application menu did not restore autostart");
                    if (!startupWasEnabled && menu.startupEntry?.removable)
                    {
                        ServiceApplications.removeAutostart(menu.startupEntry.id);
                        for (let i = 0; i < 100 && menu.startupEntry; i++) events.wait(20);
                    }
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
                    const launchApp = tests.find(menu.contentItem, "applicationLaunch");
                    tests.check(launchApp && launchApp.y < removeApp.y, "Launch is missing above Delete in the application menu");
                    events.keyClick(Qt.Key_Down); events.keyClick(Qt.Key_Down); events.keyClick(Qt.Key_Down);
                    tests.check(launchApp.activeFocus, "Keyboard navigation does not move from Notifications to Launch");
                    pinRow.focusFor(Qt.TabFocusReason);
                    Config.set("motionStyle", Enums.MotionGlide);
                    events.mouseMove(pinRow, 40, pinRow.height / 2, 0);
                    events.wait(450);
                    const viewport = tests.find(menu.contentItem, "settingsPopupBody");
                    const topLeft = pinRow.mapToItem(viewport, 0, 0);
                    const bottomRight = pinRow.mapToItem(viewport, pinRow.width, pinRow.height);
                    tests.check(topLeft.x >= 0 && topLeft.y >= 0 && bottomRight.x <= viewport.width && bottomRight.y <= viewport.height,
                        "Hovered action is clipped by the menu viewport");
                    Config.set("motionStyle", Enums.MotionDirect);
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
                    window.width = 360; window.height = 245;
                    events.wait(30);
                    menu.openFor(menu.application, window.contentItem, window.width - 1, window.height - 1);
                    events.wait(30);
                    tests.check(menu.x + menu.width <= window.width - 8 && menu.y + menu.height <= window.height - 8, "Context menu does not fit a compact window");
                    events.keyClick(Qt.Key_Up);
                    const compactBody = tests.find(menu.contentItem, "settingsPopupBody");
                    const lastAction = tests.find(menu.contentItem, "applicationDelete");
                    const lastTop = lastAction.mapToItem(compactBody, 0, 0).y;
                    tests.check(lastAction.activeFocus && compactBody.contentY > 0 && lastTop >= 0 && lastTop + lastAction.height <= compactBody.height,
                        "Keyboard focus does not reveal the last action in a short window");
                    page.visible = false;
                    events.wait(Theme.animationDurationClose + 40);
                    tests.check(!menu.visible && !removal.visible && !OverlayState.settingsPopup, "Hidden Applications page left its popup open");
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
    assert not (base / "config/autostart/system.desktop").exists()
    assert (base / "config/autostart/override.desktop").read_text() == override
    assert not (base / "config/autostart/org.example.Autostart.desktop").exists()
    assert json.loads((base / "removal-command").read_text()) == ["python3", str(base / "scripts/bloodyShell"), "internal", "applications", "remove", "org.example.Autostart", "pacman:fixture-app"]
    print("Autostart entries, application context menu, pin/notification toggles, removal confirmation, keyboard/mouse input, compact placement, and popup cleanup passed.")


def run_associations_ui(base):
    env = ui_environment(base)
    default_entries(base)
    put(base / "config/bloodyShell/settings.json", json.dumps({"helperSeen": True, "motionStyle": 0}))
    put(base / "data/applications/mimeinfo.cache", "[MIME Cache]\ninode/directory=file-managerA.desktop;file-managerB.desktop;\n")
    put(base / "config/mimeapps.list", "[Default Applications]\ninode/directory=file-managerA.desktop;\n")
    put(base / "shell.qml", '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings"
ShellRoot {
    Window { visible:true; width:1000;height:800; SettingsContent { id: settings; anchors.fill:parent } }
    TestCase {
        id:events;when:false;optional:true
        function check(ok,message){if(!ok)throw new Error(message);}
        function until(predicate,message){for(let i=0;i<400&&!predicate();i++)wait(10);check(predicate(),message);}
        function exercise(){
            Config.set("motionStyle", Enums.MotionDirect);
            settings.selectID("applications");
            const find = name => findChild(settings, name);
            until(()=>find("openApplicationPage-fileAssociations"),"Applications overview did not load");
            const parentTab = settings.currentTab;
            check(find("defaultApplicationsSection") && find("autostartSection"),"Applications overview is missing its groups");
            check(!find("fileAssociationsSection") && !find("applicationsList"),"Subpage contents load on the overview");
            find("openApplicationPage-fileAssociations").clicked();
            until(()=>find("fileAssociationsSection"),"File associations subpage did not load");
            const section = find("fileAssociationsSection");
            check(settings.currentPage.id==="fileAssociations" && settings.parentPage.id==="applications" && settings.currentTab===parentTab,
                "File associations is outside Applications navigation");
            until(()=>!section.busy&&section.entries.length===30,"File associations did not load");
            const images=findChild(section,"fileAssociationGroup-images");
            check(images && images.entries.length===8,"Image associations do not cover common formats");
            check(findChild(images,"fileAssociation-webp") && findChild(images,"fileAssociation-avif") && findChild(images,"fileAssociation-svg"),"Expanded image formats are missing");
            const folders=findChild(section,"fileAssociation-folders");
            check(folders.current==="file-managerA.desktop"&&folders.options.some(app=>app.value==="file-managerB.desktop"),"Association choices or current app are wrong");
            folders.selected("file-managerB.desktop");until(()=>!section.busy,"Association write did not finish");
            check(section.error===""&&findChild(section,"fileAssociation-folders").current==="file-managerB.desktop","Selected application was not saved");
            settings.goBack();
            until(()=>find("openApplicationPage-allApplications"),"Back did not return to the Applications overview");
            find("openApplicationPage-allApplications").clicked();
            until(()=>find("applicationsSearch") && find("applicationsList"),"All applications subpage did not load");
            check(settings.currentPage.id==="allApplications" && settings.parentPage.id==="applications" && settings.currentTab===parentTab,
                "All applications is outside Applications navigation");
            const search = find("applicationsSearch");
            until(()=>ServiceApplications.search("browser").length>0 && ServiceApplications.search("file-manager").length>0,
                "Installed applications did not load");
            const browser = ServiceApplications.search("browser")[0];
            const fileManager = ServiceApplications.search("file-manager")[0];
            search.text="browser"; search.textEdited("browser");
            until(()=>find("applicationRow-"+browser.id),"Search did not find the browser");
            check(!find("applicationRow-"+fileManager.id),"Search left unrelated applications visible");
            settings.goBack();
            until(()=>find("defaultApplicationsSection"),"Back from All applications did not restore the overview");
            console.log("ASSOCIATIONS_UI_PASSED application navigation, list search and saved associations");Qt.quit();
        }
    }
    Timer {interval:200;running:Config.initialized;onTriggered:{try{events.exercise();}catch(error){console.error("ASSOCIATIONS_UI_FAILED",error);Qt.quit();}}}
}
''')
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyShell-associations-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyShell-associations-no-system-bus")
    env.pop("WAYLAND_DISPLAY",None)
    result=subprocess.run(["qs","-p",str(base),"--no-color"],env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    assert result.returncode==0 and "ASSOCIATIONS_UI_PASSED" in output,output
    assert not re.search(r"ASSOCIATIONS_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration",output),output
    print("Applications navigation passed: both subpages, Back, list search and saved associations.")


def run_defaults_ui(base):
    env = ui_environment(base)
    default_entries(base)
    put(base / "config/bloodyShell/settings.json", json.dumps({"helperSeen": True, "motionStyle": 0, "shellLanguage": "en"}))
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
                check(defaults && autostart && defaults.y<autostart.y,"Default applications group is missing or misplaced");
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
                page.visible=false; wait(40);
                check(!browser.open && !OverlayState.settingsPopup,"Leaving Applications left its popup open");
                page.visible=true; wait(40);
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
        run_associations(base / "associations")
        run_associations_ui(base / "associations-ui")
        run_defaults_ui(base / "defaults-ui")
        run_files(base / "files")
        run_ui(base / "ui")


if __name__ == "__main__":
    main()
