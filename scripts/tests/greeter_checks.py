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
            assert (base / "state/.appearance.lock").stat().st_mode & 0o777 == 0o644, "Other users cannot lock the shared login settings"
            config = configparser.ConfigParser(interpolation=None)
            config.read(base / "state/theme.conf")
            data = config["General"]
            assert "wallpaperCurrent" not in data and not list((base / "state").glob("wallpaper*")), "Desktop wallpaper was automatically shared"
            assert data["animationLevel"] == "2" and not data.getboolean("widgetClock24") and data["shellLanguage"] == "ru"
            assert "privateValue" not in data and "themeStyle" not in data and "accentColor" not in data
            shared_files = [base / "state/avatars/tester", base / "state/theme.conf"]
            modified = {path: path.stat().st_mtime_ns for path in shared_files}
            resources["export"](source, base / "state")
            assert all(path.stat().st_mtime_ns == modified[path] for path in shared_files), "Unchanged login appearance rewrote shared files"
            chosen = resources["set_greeter_wallpaper"](str(wallpaper), base / "state")
            chosen_path = Path(chosen["wallpaper"])
            assert chosen_path.read_bytes() == b"test" and chosen_path.stat().st_mode & 0o777 == 0o644
            layouts = [{"layout": "us", "variant": ""}, {"layout": "ru", "variant": "phonetic"}]
            resources["export"](source, base / "state", layouts)
            resources["export"](source, base / "state")
            config.read(base / "state/theme.conf")
            assert json.loads(config["General"]["keyboardLayouts"]) == layouts
            assert Path(config["General"]["wallpaperCurrent"]) == chosen_path
            try:
                resources["export"](source, base / "state", [{"layout": "us\ninvalid=1"}])
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid login-screen keyboard layout was accepted")
            replacement = base / "replacement.jpg"
            replacement.write_bytes(b"new wallpaper")
            (base / "home/.face").write_bytes(b"new avatar")
            source.write_text(json.dumps(dict(wallpaperCurrent=str(replacement))))
            resources["export"](source, base / "state")
            assert chosen_path.read_bytes() == b"test", "Desktop change replaced the manual login wallpaper"
            assert (base / "state/avatars/tester").read_bytes() == b"new avatar"
            for extension in ("jfif", "bmp", "gif"):
                image = base / ("image." + extension)
                image.write_bytes(b"wallpaper image")
                chosen = resources["set_greeter_wallpaper"](str(image), base / "state")
                chosen_path = Path(chosen["wallpaper"])
                assert chosen_path.read_bytes() == b"wallpaper image"
                assert list((base / "state").glob("wallpaper-*")) == [chosen_path], "Manual replacement left an unused wallpaper"
            # Exercise authentication and failure cleanup with private files only.
            execute = subprocess.run
            def elevated(command, **kwargs):
                assert command[:3] == ["sudo", "-u", "#" + str((base / "state").stat().st_uid)]
                command = command[3:]
                if command[0] == "-n":
                    command = command[1:]
                assert command[0] in ("install", "mv", "rm")
                assert Path(command[-1]).parent == base / "state"
                return execute(command, **kwargs)
            with patch("os.access", return_value=False), patch("subprocess.run", side_effect=elevated):
                chosen = resources["set_greeter_wallpaper"](str(replacement), base / "state")
            chosen_path = Path(chosen["wallpaper"])
            assert chosen_path.read_bytes() == b"new wallpaper"
            before = (base / "state/theme.conf").read_bytes()
            pending = base / "pending.png"
            pending.write_bytes(b"failed wallpaper")
            def denied(command, **kwargs):
                if "install" in command and command[-2].endswith("/theme.conf"):
                    raise subprocess.CalledProcessError(1, command)
                return elevated(command, **kwargs)
            with patch("os.access", return_value=False), patch("subprocess.run", side_effect=denied):
                try:
                    resources["set_greeter_wallpaper"](str(pending), base / "state")
                except subprocess.CalledProcessError:
                    pass
                else:
                    raise AssertionError("Failed login wallpaper write was accepted")
            assert (base / "state/theme.conf").read_bytes() == before
            assert list((base / "state").glob("wallpaper-*")) == [chosen_path] and not list((base / "state").glob(".theme-*")), "Failed wallpaper left unused files"
            assert resources["greeter_wallpaper_status"](base / "state", str(replacement))["matches"]
            # Another user's automatic appearance export keeps the one shared wallpaper.
            with patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(base / "home"), pw_name="other")):
                resources["export"](source, base / "state")
            config.read(base / "state/theme.conf")
            assert Path(config["General"]["wallpaperCurrent"]) == chosen_path
            (base / "home/.face").unlink()
            source.write_text('{}')
            resources["export"](source, base / "state")
            config = configparser.ConfigParser(interpolation=None)
            config.read(base / "state/theme.conf")
            assert Path(config["General"]["wallpaperCurrent"]) == chosen_path and "avatarUser" not in config["General"]
            assert not (base / "state/avatars/tester").exists()
            (base / "state/avatars/other").unlink()
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
            (base / "state/.appearance.lock").unlink()
            secret = base / "private-file"
            secret.write_bytes(b"private")
            secret.chmod(0o600)
            (base / "state/.appearance.lock").symlink_to(secret)
            for operation in (lambda: resources["export"](source, base / "state"),
                              lambda: resources["set_greeter_wallpaper"](str(wallpaper), base / "state")):
                try:
                    operation()
                except OSError:
                    pass
                else:
                    raise AssertionError("Login appearance followed a lock symlink")
            assert secret.read_bytes() == b"private" and secret.stat().st_mode & 0o777 == 0o600
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
        property var sizes: [Qt.size(1366,768), Qt.size(1024,768), Qt.size(800,600), Qt.size(683,512), Qt.size(533,400), Qt.size(768,1024)]
        onTriggered: {
            try {
                if (step > 0) {
                    const content = tests.find(greeter, "greeterContent"), footer = tests.find(greeter, "greeterFooter");
                    const a = content.mapToItem(greeter, 0, 0), b = content.mapToItem(greeter, content.width, content.height);
                    if (window.height >= 600 && window.height <= 800) tests.check(content.scale <= 0.84, "Laptop login content is oversized");
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


def avatar_checks():
    screenshot = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-sddm-avatar-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "home"):
            (base / name).mkdir(mode=0o700)
        shutil.copytree(ROOT / "dots/sddm", base / "greeter")
        (base / "portrait #%.png").write_bytes(screenshot["png"](400, 100))
        (base / "shared/avatars").mkdir(parents=True)
        (base / "shared/avatars/tester").write_bytes(screenshot["png"](100, 100))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "greeter"

ShellRoot {
    QtObject {
        id: accounts
        property int count:1
        property int lastIndex:0
        property string lastUser:"tester"
        property string picture:""
        function index(row,column) { return row; }
        function data(row,role) { return ["tester","Tester","/nonexistent",picture][role-Qt.UserRole-1]; }
    }
    Window {
        id: window; visible:true; width:1280; height:960
        Loader { id: loader; anchors.fill:parent; active:false; sourceComponent:Main { accountModel:accounts } }
        TestCase {
            id: events; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<250 && !predicate();i++) wait(10); check(predicate(),message); }
            function colors(avatar) {
                const image=grabImage(window.contentItem);
                let light=0,color=0;
                for(let y=8;y<avatar.height-8;y++) for(let x=8;x<avatar.width-8;x++) {
                    const point=avatar.mapToItem(window.contentItem,x,y), px=Math.round(point.x), py=Math.round(point.y);
                    const r=image.red(px,py), g=image.green(px,py), b=image.blue(px,py);
                    if(r>150 && g>150 && b>150) light++;
                    if((r>100 && r>g*2) || (g>100 && g>r*2) || (b>100 && b>r*2)) color++;
                }
                const corner=avatar.mapToItem(window.contentItem,2,2);
                check(image.red(Math.round(corner.x),Math.round(corner.y))<80 && image.green(Math.round(corner.x),Math.round(corner.y))<80 && image.blue(Math.round(corner.x),Math.round(corner.y))<80,"Avatar image escaped its circular edge");
                return {light:light,color:color};
            }
            function exercise() {
                Theme.configuration={animationLevel:"0"}; loader.active=true;
                until(()=>loader.item && findChild(loader.item,"greeterAvatar"),"Login avatar did not load");
                const avatar=findChild(loader.item,"greeterAvatar"), image=findChild(avatar,"greeterAvatarImage"), placeholder=findChild(avatar,"greeterAvatarPlaceholder");
                until(()=>placeholder.status===Image.Ready,"User placeholder did not load"); wait(40);
                check(!avatar.ready && placeholder.visible && colors(avatar).light>100,"Missing picture displayed only a shadow");
                const directory=String(Qt.resolvedUrl("portrait #%.png")).replace(/portrait.*$/,"");
                accounts.picture=directory+"missing.png";
                until(()=>image.status===Image.Null,"Missing account image did not fall back"); wait(40);
                check(placeholder.visible && colors(avatar).light>100,"Missing image hid the placeholder");
                const portrait=decodeURIComponent(String(Qt.resolvedUrl("portrait%20%23%25.png")).replace(/^file:\\/\\//,""));
                accounts.picture=portrait;
                until(()=>avatar.ready,"Valid account picture did not render"); wait(40);
                check(!placeholder.visible && String(image.source).includes("%23") && String(image.source).includes("%25"),"Account picture path was not encoded correctly");
                const pixels=colors(avatar);
                check(pixels.color>3000 && pixels.light===0,"Avatar texture is blank or covered by the placeholder");
                window.contentItem.grabToImage(result=>result.saveToFile("/tmp/bloodyShell-sddm-avatar-preview.png")); wait(80);
                Theme.configuration={animationLevel:"0",avatarUser:"tester",stateDir:decodeURIComponent(directory.replace(/^file:\/\//,""))+"shared"};
                until(()=>avatar.ready && String(image.source).endsWith("/shared/avatars/tester"),"Shared avatar without a filename extension did not render"); wait(40);
                check(colors(avatar).color>3000,"Shared avatar is blank");
                Theme.configuration={animationLevel:"0",avatarUser:"tester",stateDir:decodeURIComponent(directory.replace(/^file:\/\//,""))+"absent"};
                until(()=>avatar.ready && String(image.source).includes("%23"),"Missing shared avatar did not use the account image");
                accounts.picture=directory+"missing-again.png";
                until(()=>!avatar.ready && image.status===Image.Null,"Old avatar remained after a missing image"); wait(40);
                const fallback=colors(avatar);
                check(placeholder.visible && fallback.light>100 && fallback.color===0,"Fallback disappeared or retained a stale photo after changing users");
                accounts.picture=portrait; until(()=>avatar.ready,"Avatar did not recover after a failed image");
                loader.item.manualMode=true; wait(40);
                check(!avatar.ready && placeholder.visible && colors(avatar).light>100,"Manual login hid the fallback icon");
                loader.active=false; wait(40); loader.active=true;
                until(()=>loader.item && findChild(loader.item,"greeterAvatar").ready,"Initial shared/account picture did not load");
                console.log("GREETER_AVATAR_PASSED visible placeholder, failed-image fallback, circular photo rendering, encoded paths, replacement and manual login without shader masking"); Qt.quit();
            }
        }
        Timer { interval:100; running:true; onTriggered:{try{events.exercise();}catch(error){console.error("GREETER_AVATAR_FAILED",error);Qt.quit();}} }
    }
}
''')
        env = dict(os.environ, HOME=str(base / "home"), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "GREETER_AVATAR_PASSED" in output, output
        assert not any(message in output for message in ("GREETER_AVATAR_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output


if __name__ == "__main__":
    checks()
    avatar_checks()
