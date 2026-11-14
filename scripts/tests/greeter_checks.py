#!/usr/bin/env python3

import configparser
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-sddm-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "state", "home"):
            (base / name).mkdir(mode=0o700)
        shutil.copytree(ROOT / "dots/sddm", base / "greeter")
        resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
        wallpaper = base / "wallpaper with spaces.png"
        wallpaper.write_bytes(b"test")
        (base / "home/.face").write_bytes(b"avatar")
        source = base / "source.json"
        source.write_text(json.dumps(dict(shellLanguage="ru", wallpaperCurrent=str(wallpaper), privateValue="not exported", themeAnimations=2, themeAccent=True, barWidgetClock24=False)))
        account = SimpleNamespace(pw_dir=str(base / "home"), pw_name="tester")
        with patch("pwd.getpwuid", return_value=account):
            old_mask = os.umask(0o077)
            try:
                resources["export"](source, base / "state")
            finally:
                os.umask(old_mask)
            assert (base / "state/avatars").stat().st_mode & 0o777 == 0o755
            config = configparser.ConfigParser(interpolation=None)
            config.read(base / "state/theme.conf")
            data = config["General"]
            assert Path(data["wallpaperCurrent"]).read_bytes() == b"test"
            assert data["animationLevel"] == "2" and not data.getboolean("widgetClock24") and data["shellLanguage"] == "ru"
            assert "privateValue" not in data and "themeStyle" not in data and "accentColor" not in data
            shared_files = [Path(data["wallpaperCurrent"]), base / "state/avatars/tester", base / "state/theme.conf"]
            modified = {path: path.stat().st_mtime_ns for path in shared_files}
            resources["export"](source, base / "state")
            assert all(path.stat().st_mtime_ns == modified[path] for path in shared_files), "Unchanged login appearance rewrote shared files"
            layouts = [{"layout": "us", "variant": ""}, {"layout": "ru", "variant": "phonetic"}]
            resources["export"](source, base / "state", layouts)
            assert all(path.stat().st_mtime_ns == modified[path] for path in shared_files[:2]), "Keyboard layout export recopied unchanged images"
            config.read(base / "state/theme.conf")
            assert json.loads(config["General"]["keyboardLayouts"]) == layouts
            resources["export"](source, base / "state")
            config.read(base / "state/theme.conf")
            assert json.loads(config["General"]["keyboardLayouts"]) == layouts, "Appearance refresh lost keyboard layouts"
            try:
                resources["export"](source, base / "state", [{"layout": "us\ninvalid=1"}])
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid login-screen keyboard layout was accepted")
            assert (base / "state/avatars/tester").read_bytes() == b"avatar"
            replacement = base / "replacement.jpg"
            replacement.write_bytes(b"new wallpaper")
            (base / "home/.face").write_bytes(b"new avatar")
            source.write_text(json.dumps(dict(wallpaperCurrent=str(replacement))))
            resources["export"](source, base / "state")
            assert (base / "state/wallpaper.jpg").read_bytes() == b"new wallpaper"
            assert not (base / "state/wallpaper.png").exists(), "Wallpaper replacement left a stale copy"
            assert (base / "state/avatars/tester").read_bytes() == b"new avatar"
            assert (base / "state/wallpaper.jpg").stat().st_mode & 0o777 == 0o644
            assert (base / "state/avatars/tester").stat().st_mode & 0o777 == 0o644
            (base / "home/.face").unlink()
            source.write_text('{}')
            resources["export"](source, base / "state")
            config = configparser.ConfigParser(interpolation=None)
            config.read(base / "state/theme.conf")
            assert "wallpaperCurrent" not in config["General"] and "avatarUser" not in config["General"]
            assert not list((base / "state").glob("wallpaper.*")) and not (base / "state/avatars/tester").exists()
            (base / "state/avatars").rmdir()
            (base / "home/tester").write_bytes(b"preserve")
            (base / "state/avatars").symlink_to(base / "home", target_is_directory=True)
            try:
                resources["export"](source, base / "state")
            except ValueError:
                pass
            else:
                raise AssertionError("Export followed a user-created avatar symlink")
            assert (base / "home/tester").read_bytes() == b"preserve"
            (base / "state/avatars").unlink()
        assert not any("Quickshell" in path.read_text() for path in (ROOT / "dots/sddm").glob("*.qml"))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "greeter"

ShellRoot {
    id: tests
    property int clears: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    QtObject {
        id: accounts
        property int count: 1
        property int lastIndex: 0
        property string lastUser: "tester"
        function index(row, column) { return row; }
        function data(row, role) { return ["tester", "A long account name for a compact display", "/nonexistent", ""][role - Qt.UserRole - 1]; }
    }
    QtObject {
        id: desktops
        property int count: 2
        property int lastIndex: 1
        function index(row, column) { return row; }
        function data(row, role) { return ["/usr/share/wayland-sessions", row ? "niri.desktop" : "other.desktop", 1, row ? "Niri Wayland session" : "Other"][role - Qt.UserRole - 1]; }
    }
    QtObject {
        id: proxy
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        property var calls: []
        property var actions: []
        signal loginFailed()
        signal loginSucceeded()
        signal informationMessage(string message)
        function login(user, password, session) { calls = calls.concat([{user:user, password:password, session:session}]); }
        function suspend() { actions = actions.concat(["suspend"]); }
        function reboot() { actions = actions.concat(["reboot"]); }
        function powerOff() { actions = actions.concat(["poweroff"]); }
    }
    Window {
        id: window; visible: true; width: 1280; height: 800
        Main { id: greeter; anchors.fill: parent; authenticator: proxy; accountModel: accounts; desktopModel: desktops }
    }
    Connections { target: greeter; function onClearSecret() { tests.clears++; } }
    Timer {
        interval: 150; running: true
        onTriggered: {
            try {
                Theme.configuration = { animationLevel: "0", widgetClock24: "false", shellLanguage: "ru" };
                tests.check(!Theme.animationsEnabled && !Theme.widgetClock24 && Theme.shellLanguage === "ru", "SDDM theme preferences were not read");
                tests.check(greeter.user.name === "tester" && greeter.session.name === "Niri Wayland session", "SDDM models or remembered session were not used");
                greeter.submit("test-secret");
                tests.check(greeter.busy && proxy.calls.length === 1 && proxy.calls[0].session === 1 && tests.clears > 0, "Login did not use SDDM or clear its password");
                greeter.submit("duplicate"); greeter.cancelAuthentication();
                tests.check(proxy.calls.length === 1 && greeter.busy, "Concurrent login was accepted or authentication was falsely cancelled");
                proxy.loginFailed();
                tests.check(greeter.failed && !greeter.busy && !greeter.leaving, "Rejected login did not restore input");
                greeter.manualMode = true; greeter.manualUsername = "other'user with spaces";
                greeter.submit("retry");
                tests.check(proxy.calls[1].user === "other'user with spaces", "Manual username was changed or shell-quoted");
                proxy.informationMessage("Signing in"); tests.check(greeter.statusMessage === "Signing in", "SDDM status was ignored");
                proxy.loginSucceeded(); tests.check(greeter.leaving, "Successful login did not leave the greeter");
                proxy.loginFailed(); greeter.authenticator = null;
                greeter.submit("preview"); greeter.power("reboot");
                tests.check(proxy.calls.length === 2 && proxy.actions.length === 0, "Preview performed authentication or a power action");
                greeter.authenticator = proxy; proxy.canPowerOff = false; greeter.power("poweroff");
                tests.check(proxy.actions.length === 0, "Disabled power action was accepted");
                proxy.canPowerOff = true; greeter.power("poweroff");
                tests.check(proxy.actions[0] === "poweroff", "Power action bypassed SDDM");
                greeter.authenticator = null; greeter.statusMessage = "A long sign-in status that must fit the available display space.";
                preview.start();
            } catch (error) { console.error("GREETER_FAILED", error); Qt.quit(); }
        }
    }
    Timer {
        id: preview; interval: 100; repeat: true
        property int step: 0
        property var sizes: [Qt.size(1024,768), Qt.size(800,600), Qt.size(683,512), Qt.size(533,400), Qt.size(768,1024)]
        onTriggered: {
            try {
                if (step > 0) {
                    const content = tests.find(greeter, "greeterContent"), footer = tests.find(greeter, "greeterFooter");
                    const a = content.mapToItem(greeter, 0, 0), b = content.mapToItem(greeter, content.width, content.height);
                    tests.check(a.x >= 15 && a.y >= 15 && b.x <= window.width - 15 && b.y <= footer.y - 15, "Login screen clipped at " + window.width + "x" + window.height);
                }
                if (step === sizes.length) { console.log("GREETER_PASSED native SDDM models, authentication, power permissions, previews, export privacy, and responsive layout"); Qt.quit(); return; }
                window.width = sizes[step].width; window.height = sizes[step].height; step++;
            } catch (error) { console.error("GREETER_FAILED", error); Qt.quit(); }
        }
    }
}
''')
        env = dict(os.environ, HOME=str(base / "home"), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "GREETER_PASSED" in output, output
        assert not any(message in output for message in ("GREETER_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output


if __name__ == "__main__":
    checks()
