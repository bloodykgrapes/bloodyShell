#!/usr/bin/env python3

import configparser
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-appearance-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_DATA_HOME=str(base / "data"), TEST_APPEARANCE_BASE=str(base),
                   QT_QPA_PLATFORMTHEME="", XDG_CURRENT_DESKTOP="niri:GNOME")
        env.pop("WAYLAND_DISPLAY", None)
        for directory in ("home", "data", "wallpapers"):
            (base / directory).mkdir(parents=True)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0,
            wallpaperDirectory=str(base / "wallpapers"), themeStyle=0, shellLanguage="en")))
        tools = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
base = Path(os.environ["TEST_APPEARANCE_BASE"])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
if name == "gsettings":
    if args[0] == "get":
        values = {"color-scheme":((base / "scheme").read_text() if (base / "scheme").exists() else "prefer-dark"), "icon-theme":"FixtureIcons", "cursor-theme":"FixtureCursor", "cursor-size":24, "font-name":"Noto Sans 10"}
        value = values[args[2]]
        print(value if isinstance(value, int) else repr(value))
    else:
        with (base / "gtk-calls").open("a") as stream: stream.write(json.dumps(args) + "\n")
        if args[2] == "color-scheme" and os.environ.get("TEST_DENY_SCHEME"): sys.exit(1)
        if args[2] == "color-scheme": (base / "scheme").write_text(args[3])
elif name == "fc-list": print("Noto Sans")
else: raise AssertionError(name)
'''
        for name in ("gsettings", "fc-list"):
            path = base / "bin" / name
            path.write_text(tools)
            path.chmod(0o700)
        helper = ["python3", str(base / "scripts/bloodyShell"), "internal", "appearance"]
        qt = base / "config/qt6ct/qt6ct.conf"
        qt.parent.mkdir()
        qt.write_text('[Appearance]\nstyle=KeepQt\nstandard_dialogs=KeepDialogs\n\n[Fonts]\ngeneral="Keep Font,12,-1"\n')
        gtk = base / "config/gtk-3.0/settings.ini"
        gtk.parent.mkdir()
        target = base / "gtk-config-target.ini"
        target.write_text("[Settings]\ngtk-theme-name=KeepGtk\nkeep-user-setting=yes\n")
        gtk.symlink_to(target)
        gtk4 = base / "config/gtk-4.0/settings.ini"
        gtk4.parent.mkdir()
        gtk4.write_text("[Settings]\ngtk-theme-name=KeepGtk4\n")
        user_env = base / "config/environment.d/user-qt.conf"
        user_env.parent.mkdir()
        user_env.write_text("QT_QPA_PLATFORMTHEME=user-choice\n")
        portal_config = base / "config/xdg-desktop-portal/niri-portals.conf"
        portal_config.parent.mkdir(parents=True)
        portal_template = "[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.FileChooser=kde\n"
        portal_config.write_text(portal_template)
        initial = {p: p.read_bytes() for p in (qt, gtk, gtk4, user_env, portal_config)}
        result = subprocess.run(helper + ["list"], env=env, text=True, capture_output=True, check=True)
        assert not any(line.startswith(("gtk\t", "qt\t")) for line in result.stdout.splitlines())
        result = subprocess.run(helper + ["read"], env=env, text=True, capture_output=True, check=True)
        assert not any(line.startswith(("gtk-theme=", "qt-theme=", "qt-active=", "qt-configured=", "qt6ct=")) for line in result.stdout.splitlines())
        for key in ("gtk-theme", "qt-theme", "portal:FileChooser"):
            denied = subprocess.run(helper + ["set", key + "=Removed"], env=env, text=True, capture_output=True)
            assert denied.returncode != 0, "Removed setting was accepted: " + key
        assert all(p.read_bytes() == data for p, data in initial.items())
        subprocess.run(helper + ["apply"], env=env, text=True, capture_output=True, check=True)
        values = configparser.ConfigParser()
        values.read(qt)
        assert values["Appearance"]["style"] == "KeepQt" and values["Appearance"]["standard_dialogs"] == "KeepDialogs"
        assert values["Appearance"]["icon_theme"] == "FixtureIcons" and "Noto Sans" in values["Fonts"]["general"]
        values.read(gtk)
        assert gtk.is_symlink() and values["Settings"]["gtk-theme-name"] == "KeepGtk" and values["Settings"]["keep-user-setting"] == "yes"
        values.read(gtk4)
        assert values["Settings"]["gtk-theme-name"] == "KeepGtk4"
        assert user_env.read_bytes() == initial[user_env] and list(user_env.parent.iterdir()) == [user_env], "Reapply changed Qt activation"
        assert portal_config.read_text() == portal_template
        (base / "gtk-calls").unlink()
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
ShellRoot {
    id: tests
    property int phase: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function hasThemeSelector(item) {
        if (item.label === "GTK theme" || item.label === "Qt theme" || item.label === "Тема GTK" || item.label === "Тема Qt") return true;
        return (item.children || []).some(child => hasThemeSelector(child));
    }
    Window { id: window; visible: true; width: 820; height: 740; PageAppearance { id: page; anchors.fill: parent } }
    Timer {
        interval: 80; running: true; repeat: true
        onTriggered: {
            if (!Config.initialized || !ServiceAppearance.loaded || ServiceAppearance.busy) return;
            try {
                if (tests.phase === 0) {
                    tests.check(!tests.hasThemeSelector(page), "Removed theme selectors remain visible");
                    tests.check(ServiceAppearance.gtkTheme === undefined && ServiceAppearance.qtTheme === undefined, "Removed theme parameters remain available");
                    tests.check(Config.syncSystemAppearance === undefined, "Removed color scheme toggle remains available");
                    tests.check(!tests.find(page, "portalSettings") && !tests.find(page, "installedPortals") && !tests.find(page, "refreshPortals"), "Portal settings remain visible");
                    const transitions = tests.find(page, "wallpaperTransitionSelector");
                    tests.check(transitions.options.length === 14, "Wallpaper selector does not offer every awww transition");
                    for (const option of transitions.options) {
                        transitions.selected(option.value);
                        tests.check(Config.wallpaperTransition === option.value, "Wallpaper transition cannot be selected: " + option.value);
                    }
                    Config.set("wallpaperTransition", "grow");
                    tests.check(ServiceAppearance.colorScheme === "prefer-light", "System scheme did not follow the light shell theme");
                    tests.check(ServiceAppearance.iconTheme === "FixtureIcons" && ServiceAppearance.fontFamily === "Noto Sans", "Remaining appearance settings did not load");
                    Config.set("shellLanguage", "ru");
                    window.width = 640;
                    Config.set("themeStyle", Enums.ThemeDark);
                    tests.phase++;
                } else if (tests.phase === 1) {
                    tests.check(!tests.hasThemeSelector(page), "Removed translated theme selectors remain visible");
                    tests.check(ServiceAppearance.colorScheme === "prefer-dark", "System scheme did not follow the dark shell theme");
                    console.log("APPEARANCE_PASSED removed theme controls and parameters, preserved styles, automatic scheme, wallpaper transitions, and translations"); Qt.quit();
                }
            } catch (error) { console.error("APPEARANCE_FAILED", error); Qt.quit(); }
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("APPEARANCE_FAILED timeout", tests.phase); Qt.quit(); } }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=12)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "APPEARANCE_PASSED" in output, output
        assert not re.search(r"APPEARANCE_FAILED|TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign", output), output
        values.read(qt)
        assert values["Appearance"]["style"] == "KeepQt"
        assert user_env.read_bytes() == initial[user_env] and list(user_env.parent.iterdir()) == [user_env]
        assert portal_config.read_text() == portal_template
        calls = [json.loads(line) for line in (base / "gtk-calls").read_text().splitlines()]
        assert calls == [["set", "org.gnome.desktop.interface", "color-scheme", "prefer-light"],
                         ["set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"]], calls
        (base / "gtk-calls").unlink()
        settings = base / "config/bloodyShell/settings.json"
        data = json.loads(settings.read_text())
        data["themeStyle"] = 0
        settings.write_text(json.dumps(data))
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "modules/core"
import "modules/services"
ShellRoot {
    property int ticks: 0
    Component.onCompleted: void ServiceAppearance.colorScheme;
    Timer { interval: 100; running: true; repeat: true; onTriggered: {
        if (++ticks < 20) return;
        if (ServiceAppearance.schemeSyncFailed && !ServiceAppearance.busy && ServiceAppearance.error !== "")
            console.log("SCHEME_FAILURE_PASSED");
        Qt.quit();
    } }
}
''')
        denied = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, TEST_DENY_SCHEME="1"), text=True, capture_output=True, timeout=6)
        assert "SCHEME_FAILURE_PASSED" in denied.stdout + denied.stderr, denied.stdout + denied.stderr
        assert len((base / "gtk-calls").read_text().splitlines()) == 1, "Failed scheme writes retried continuously"
    print("Appearance controls, removed GTK/Qt theme parameters, config preservation and shell color synchronization passed in isolation.")


def wallpaper_checks():
    from unittest.mock import patch
    from types import SimpleNamespace

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    api = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-wallpapers-") as temporary:
        base = Path(temporary)
        (base / "bin").mkdir()
        photo = base / "photo # one.png"
        photo.write_bytes(runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["png"](80, 60))
        second = base / "second.png"
        shutil.copyfile(photo, second)
        video = base / "clip with spaces.mkv"
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=red:s=80x60:r=10", "-t", "0.3", "-c:v", "ffv1", str(video)], check=True, timeout=10)
        rejected = base / "reject.mkv"
        shutil.copyfile(video, rejected)
        (base / "bin/awww").write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
base=Path(os.environ["TEST_WALLPAPER_BASE"])
if sys.argv[1] == "query": print("DP-1: image: " + str(base / "photo # one.png"))
else:
    if (base / "deny").exists(): print("Wallpaper denied", file=sys.stderr); sys.exit(1)
    with (base / "calls").open("a") as output: output.write(json.dumps(sys.argv[1:]) + "\\n")
''')
        (base / "bin/awww").chmod(0o755)
        env = dict(os.environ, HOME=str(base), XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"), TEST_WALLPAPER_BASE=str(base), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        cli = ["python3", str(ROOT / "scripts/bloodyShell"), "internal", "wallpaper"]
        styles = ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"]
        for style in styles:
            result = subprocess.run(cli + ["apply", str(photo), "--transition", style], env=env, capture_output=True, text=True, timeout=10)
            assert result.returncode == 0 and json.loads(result.stdout)["path"] == str(photo), result.stderr
        calls = [json.loads(line) for line in (base / "calls").read_text().splitlines()]
        assert [call[call.index("--transition-type") + 1] for call in calls] == styles
        assert all(call[1] == str(photo) for call in calls), "Wallpaper names were shell-expanded"
        (base / "deny").touch()
        assert subprocess.run(cli + ["apply", str(photo)], env=env, capture_output=True).returncode != 0
        (base / "deny").unlink()
        assert subprocess.run(cli + ["apply", str(photo), "--transition", "invalid"], env=env, capture_output=True).returncode != 0
        listed = subprocess.run(cli + ["list", str(base)], env=env, capture_output=True, text=True, check=True)
        assert str(video) in json.loads(listed.stdout)["paths"]
        with patch.dict(os.environ, env):
            poster = api["wallpaper_preview"](video)
            assert poster.is_file() and poster.read_bytes().startswith(b"\x89PNG")
            modified = poster.stat().st_mtime_ns
            assert api["wallpaper_preview"](video) == poster
            assert len(list(poster.parent.glob("*.png"))) == 1 and poster.stat().st_mtime_ns >= modified
            for number in range(130):
                (poster.parent / (format(number, "064x") + ".png")).write_bytes(b"old preview")
            latest = api["wallpaper_preview"](rejected)
            assert latest.is_file() and len(list(poster.parent.glob("*.png"))) == 128, "Video preview cache is unbounded"
            source = base / "source.json"
            source.write_text(json.dumps(dict(greeterSync=True, wallpaperCurrent=str(video))))
            state = base / "shared"
            state.mkdir()
            with patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(base / "home"), pw_name="fixture")):
                api["export"](source, state)
            assert (state / "wallpaper.png").is_file(), "Video sharing did not export a still frame"
            assert not list(state.glob("*.mkv")), "Login screen received the video itself"
        management = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
        modes = ["missing", "mock"] + (["native"] if management["available"]("qt6-multimedia") else [])
        for mode in modes:
            stage = base / mode
            stage.mkdir()
            qenv = prepare(stage)
            (stage / "home").mkdir()
            qenv.update(HOME=str(stage / "home"), XDG_STATE_HOME=str(stage / "state"), TEST_WALLPAPER_BASE=str(base), PATH=str(base / "bin") + os.pathsep + qenv["PATH"])
            qenv.pop("WAYLAND_DISPLAY", None)
            (stage / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=1, wallpaperCurrent=str(photo))))
            if mode == "missing":
                component = stage / "modules/ui/desktop/VideoWallpaper.qml"
                component.write_text(component.read_text().replace("import QtMultimedia", "import MissingQtMultimedia"))
            elif mode == "mock":
                qml = stage / "qml/QtMultimedia"
                qml.mkdir(parents=True)
                (qml / "qmldir").write_text("module QtMultimedia\nMediaPlayer 1.0 MediaPlayer.qml\nVideoOutput 1.0 VideoOutput.qml\n")
                (qml / "VideoOutput.qml").write_text("import QtQuick\nItem { enum Fill {Stretch, PreserveAspectFit, PreserveAspectCrop}\nproperty int fillMode: 0 }\n")
                (qml / "MediaPlayer.qml").write_text('''import QtQuick
QtObject {
    id: player
    enum State {NoError, PlayingState, PausedState, LoadedMedia, BufferedMedia, Infinite}
    property url source
    property Item videoOutput
    property int activeAudioTrack: 0
    property int loops: 1
    property bool hasVideo: false
    property int playbackState: 0
    property int mediaStatus: 0
    property int error: 0
    signal errorOccurred(int error, string message)
    function play() { if (hasVideo) playbackState = MediaPlayer.PlayingState; }
    function pause() { playbackState = MediaPlayer.PausedState; }
    onSourceChanged: { hasVideo = false; playbackState = 0; mediaStatus = 0; decode.restart(); }
    property Timer decode: Timer {
        interval: 40
        onTriggered: {
            if (String(player.source).includes("reject")) { player.error = 1; player.errorOccurred(1, "Video rejected"); return; }
            player.error = 0; player.hasVideo = true; player.mediaStatus = MediaPlayer.LoadedMedia;
        }
    }
}
''')
                qenv["QML_IMPORT_PATH"] = str(stage / "qml")
            template = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/common"
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
ShellRoot {
    Window {
        visible: true; width: 800; height: 600
        Loader { id: playback; anchors.fill: parent; active: ServiceAppearance.videoPath !== "" && ServiceAppearance.videoComponent !== null && ServiceAppearance.videoComponent.status === Component.Ready; sourceComponent: ServiceAppearance.videoComponent }
        WallpaperImage { id: thumb; width: 160; height: 90; wallpaper: VIDEO_PATH }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(predicate, message) { for (let i=0; i<150; i++) { if (predicate()) return; wait(20); } throw new Error(message); }
            function exercise() {
                Config.set("wallpaperTransition", "invalid");
                check(Config.wallpaperTransition !== "invalid", "Invalid transition was accepted");
                Config.set("wallpaperTransition", "wave");
                check(ServiceAppearance.applyWallpaper(PHOTO_TWO), "Photo apply did not start");
                until(() => !ServiceAppearance.wallpaperBusy, "Photo apply timed out");
                check(Config.wallpaperCurrent === PHOTO_TWO, "Photo did not become current");
                Config.set("themeAnimations", 0);
                ServiceAppearance.applyWallpaper(PHOTO_ONE);
                until(() => !ServiceAppearance.wallpaperBusy, "Instant photo apply timed out");
                check(Config.wallpaperCurrent === PHOTO_ONE, "Instant photo did not become current");
                ServiceAppearance.applyWallpaper("/nonexistent/wallpaper.png");
                until(() => !ServiceAppearance.wallpaperBusy, "Invalid file did not finish");
                check(Config.wallpaperCurrent === PHOTO_ONE && ServiceAppearance.wallpaperError !== "", "Failed apply changed the saved wallpaper");
                until(() => thumb.status === Image.Ready, "Video thumbnail did not load");
                if (MOCK_VIDEO) {
                    check(ServiceAppearance.applyWallpaper(VIDEO_PATH), "Video apply did not start: " + (ServiceAppearance.videoComponent ? ServiceAppearance.videoComponent.errorString() : ServiceAppearance.wallpaperError));
                    until(() => !ServiceAppearance.wallpaperBusy, "Video did not start");
                    check(Config.wallpaperCurrent === VIDEO_PATH && playback.item, "Video was not committed after playback");
                    const player = findChild(playback.item, "wallpaperVideoPlayer");
                    check(player && player.activeAudioTrack === -1 && player.loops !== 1, "Video is not silent and looping");
                    ServiceLock.locked = true; until(() => player.playbackState === 2, "Locking did not pause video");
                    ServiceLock.locked = false; until(() => player.playbackState === 1, "Unlocking did not resume video");
                    if (MOCK_DECODER) {
                        ServiceAppearance.applyWallpaper(REJECT_PATH);
                        until(() => !ServiceAppearance.wallpaperBusy, "Failed video did not recover");
                        check(Config.wallpaperCurrent === VIDEO_PATH && ServiceAppearance.videoPath === VIDEO_PATH && ServiceAppearance.wallpaperError !== "", "Failed video did not restore the previous selection");
                    }
                    ServiceAppearance.applyWallpaper(PHOTO_TWO);
                    until(() => !ServiceAppearance.wallpaperBusy, "Switching back to a photo timed out");
                    check(ServiceAppearance.videoPath === "" && !playback.item, "Switching to a photo retained the video player");
                } else {
                    check(!ServiceAppearance.applyWallpaper(VIDEO_PATH) && Config.wallpaperCurrent === PHOTO_ONE && ServiceAppearance.wallpaperError !== "", "Missing video support changed the wallpaper or failed silently");
                }
                console.log("WALLPAPERS_PASSED", MOCK_VIDEO ? "playback lifecycle" : "optional dependency", "transitions, validation, previews, failure recovery"); Qt.quit();
            }
        }
        Timer { interval: 250; running: Config.initialized; onTriggered: { try { input.exercise(); } catch (error) { console.error("WALLPAPERS_FAILED", error); Qt.quit(); } } }
    }
}
'''
            for token, value in {"VIDEO_PATH": str(video), "REJECT_PATH": str(rejected), "PHOTO_TWO": str(second), "PHOTO_ONE": str(photo), "MOCK_VIDEO": mode != "missing", "MOCK_DECODER": mode == "mock"}.items():
                template = template.replace(token, json.dumps(value))
            (stage / "shell.qml").write_text(template)
            result = subprocess.run(["qs", "-p", str(stage), "--no-color"], env=qenv, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            print("Wallpaper renderer:", mode)
            print(output)
            assert result.returncode == 0 and "WALLPAPERS_PASSED" in output, output
            assert not re.search(r"WALLPAPERS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output
        calls = [json.loads(line) for line in (base / "calls").read_text().splitlines()]
        assert any("wave" in call for call in calls) and any("none" in call for call in calls)
    print("Wallpapers passed: real video posters, bounded private cache, all transition styles, safe paths, optional playback, lock pause, rollback and renderer cleanup.")

def desktop_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-desktop-blur-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "modules/services/ServiceAppearance.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property color accent: "#8ecbff"
    property bool wallpaperBusy: false
    property string videoPath: ""
    property Component videoComponent: Component { Rectangle { color: "red" } }
    function isVideo(path) { return path.endsWith(".mkv"); }
    function fileUrl(path) { return "file://" + path; }
}
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/desktop"
ShellRoot {
    Window {
        visible: true; width: 800; height: 600
        WallpaperLayer { id: a; anchors.fill: parent; outputName: "A" }
        WallpaperLayer { id: b; width: 400; height: 300; outputName: "B" }
        TestCase {
            id: events; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(test, message) { for(let i=0;i<120;i++) { if(test()) return; wait(20); } throw new Error(message); }
            function send(event) { ServiceCompositor.event(JSON.stringify(event)); }
            function exercise() {
                Config.set("wallpaperCurrent", Qt.resolvedUrl("fixture.png").toString().slice(7));
                const image = findChild(a, "wallpaperBlurImage");
                check(Config.desktopBlur === Enums.BlurDisabled && a.blurProgress === 0 && image.source.toString() === "", "Blur is not disabled by default");
                Config.set("desktopBlur", 3); Config.set("desktopBlur", -1);
                check(Config.desktopBlur === 0, "Invalid blur mode was accepted");
                Config.set("desktopBlur", Enums.BlurAlways);
                until(()=>a.blurProgress === 1 && b.blurProgress === 1, "Always mode did not load the wallpaper");
                send({WorkspacesChanged:{workspaces:[
                    {id:10,idx:1,output:"A",is_active:true,is_focused:true},
                    {id:11,idx:2,output:"A",is_active:false,is_focused:false},
                    {id:20,idx:1,output:"B",is_active:true,is_focused:false}
                ]}});
                send({WindowsChanged:{windows:[{id:1,workspace_id:11},{id:2,workspace_id:20}]}});
                Config.set("desktopBlur", Enums.BlurWindowPresented);
                check(a.blurProgress === 0 && b.blurProgress === 1, "Hidden workspace or other output triggered blur");
                send({WorkspaceActivated:{id:20,focused:true}});
                check(a.blurProgress === 0 && b.blurProgress === 1, "Global focus changed wallpaper blur");
                send({WindowOpenedOrChanged:{window:{id:3,workspace_id:10,is_floating:true}}});
                until(()=>a.blurProgress === 1, "Opening a floating window did not blur the wallpaper");
                send({WindowClosed:{id:3}});
                check(a.blurProgress === 0, "Closing the last window did not remove blur");
                send({WorkspaceActivated:{id:11,focused:true}});
                until(()=>a.blurProgress === 1, "Workspace switch did not restore blur");
                a.outputName = "missing";
                check(a.blurProgress === 0 && !ServiceCompositor.workspaceHasWindowsOnOutput("missing"), "Unknown output counted as occupied");
                a.outputName = "A";
                until(()=>a.blurProgress === 1, "Returning to an occupied output did not restore blur");
                Config.set("themeAnimations", 1);
                Config.set("desktopBlur", Enums.BlurDisabled);
                wait(60);
                check(a.blurProgress > 0 && a.blurProgress < 1, "Blur did not fade out");
                until(()=>a.blurProgress === 0 && image.source.toString() === "", "Disabled blur retained the wallpaper texture");
                Config.set("themeAnimations", 0);
                Config.set("desktopBlur", Enums.BlurAlways);
                until(()=>a.blurProgress === 1, "Blur did not recover after reloading the image");
                ServiceAppearance.wallpaperBusy = true;
                check(a.blurProgress === 0, "Blur hid the wallpaper transition");
                ServiceAppearance.wallpaperBusy = false;
                until(()=>a.blurProgress === 1 && !a.changing, "Blur did not return after the transition");
                ServiceAppearance.videoPath = "/fixture.mkv";
                until(()=>a.videoActive && a.blurProgress === 1, "Video wallpaper did not receive blur");
                Config.set("desktopBlur", Enums.BlurDisabled);
                check(a.videoActive && a.blurProgress === 0, "Disabling blur stopped video playback");
                ServiceAppearance.videoPath = "";
                check(!a.videoActive, "Static wallpaper retained video rendering");
                console.log("DESKTOP_BLUR_PASSED: modes, per-output workspaces, floating windows, animations, transitions and video");
                Qt.quit();
            }
        }
        Timer { interval: 120; running: Config.initialized; onTriggered: { try { events.exercise(); } catch(error) { console.error("DESKTOP_BLUR_FAILED", error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "DESKTOP_BLUR_PASSED" in output, output
        assert not re.search(r"DESKTOP_BLUR_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def picker_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-wallpaper-picker-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"))
        env.pop("WAYLAND_DISPLAY", None)
        for folder in ("home", "wallpapers", "other", "empty", "denied"):
            (base / folder).mkdir()
        for i in range(9):
            shutil.copyfile(base / "fixture.png", base / "wallpapers" / f"{i+1} wallpaper # fixture with a long name that must be truncated on compact screens.png")
        for i in range(2):
            shutil.copyfile(base / "fixture.png", base / "other" / f"{i+1}.png")
        images = sorted(str(path) for path in (base / "wallpapers").iterdir())
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0,
            wallpaperDirectory=str(base / "wallpapers"), wallpaperCurrent=images[4], shellLanguage="en")))
        resource = base / "scripts/lib/resources.py"
        resource.write_text(resource.read_text().replace('if args.action == "list":',
            'if args.action == "list":\n            if Path(args.path).name == "denied": raise ValueError("Fixture folder unavailable")'))
        (base / "modules/services/ServiceAppearance.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
import "../core"
Singleton {
    property string accent: "#8ecbff"
    property string wallpaperError: ""
    property bool wallpaperBusy: false
    property int applies: 0
    property string requested: ""
    signal wallpaperApplied()
    function isVideo(path) { return String(path).endsWith(".mp4"); }
    function fileUrl(path) { return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : ""; }
    function applyWallpaper(path) { applies++; requested=path; wallpaperBusy=true; wallpaperError=""; return true; }
    function finish(success) {
        wallpaperBusy=false;
        if (success) { Config.set("wallpaperCurrent",requested); wallpaperApplied(); }
        else wallpaperError="Fixture apply failed";
    }
}
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/wallpapers/components"

ShellRoot {
    Window {
        id:window; width:1100; height:700; visible:true
        WallpapersContent { id:picker; anchors.fill:parent }
        TestCase {
            id:events; name:"WallpaperPicker"; when:false; optional:true
            function check(ok,message) { if (!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<150 && !predicate();i++) wait(10); check(predicate(),message); }
            function card(i) { return findChild(picker,"wallpaperCard-"+i); }
            function click(item) { mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0); }
            function inspect() {
                const visible=[];
                const gallery=findChild(picker,"wallpaperGallery");
                for(let i=0;i<picker.images.length;i++) if(card(i).visible) visible.push(card(i));
                check(visible.length===Math.min(5,picker.images.length),"Picker does not show five items at rest");
                const bounds=item=>{
                    const points=[item.mapToItem(gallery,0,0),item.mapToItem(gallery,item.width,0),item.mapToItem(gallery,0,item.height),item.mapToItem(gallery,item.width,item.height)];
                    const left=Math.min(...points.map(p=>p.x)), top=Math.min(...points.map(p=>p.y));
                    return {x:left,y:top,width:Math.max(...points.map(p=>p.x))-left,height:Math.max(...points.map(p=>p.y))-top};
                };
                check(visible.every(item=>{const r=bounds(item); return r.x>=-0.1 && r.y>=0 && r.x+r.width<=gallery.width+0.1 && r.y+r.height<=gallery.height+0.1;}),"Wallpaper extends beyond the gallery");
                const selected=bounds(card(picker.index));
                check(visible.filter(item=>!item.selected).every(item=>bounds(item).width<selected.width*0.85),"Neighbour previews are not smaller");
                check(Math.abs(selected.x+selected.width/2-gallery.width/2)<0.1,"Selected wallpaper is not centred");
                check(!findChild(picker,"wallpaperPickerPanel"),"Picker still has a panel background");
                if(window.width>=1900 && picker.images.length>=5) check(picker.cardW>=600,"Large screen still has small previews");
                const title=findChild(picker,"wallpaperName");
                check(findChild(picker,"wallpaperCaptionBackground").color.a===1,"Title background is still translucent");
                check(!findChild(picker,"wallpaperRefresh"),"Refresh button was not removed");
                check(title.width>0 && title.elide===Text.ElideRight,"Filename is not bounded");
                if(window.width<=360) check(title.width<title.implicitWidth,"Long filename does not elide");
            }
            function exercise() {
                until(()=>!picker.loading && picker.images.length===9,"Wallpaper catalog did not load");
                const all=picker.images.slice(), folder=picker.folder;
                check(picker.index===4 && picker.selectedPath===Config.wallpaperCurrent,"Picker did not start at the current wallpaper");
                picker.apply(picker.index); check(ServiceAppearance.applies===0,"Current wallpaper can be reapplied");
                for(const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    for(const index of [0,4,8]) {
                        picker.select(index); wait(Theme.animationDurationMorph+60); inspect();
                        check(findChild(picker,"wallpaperPrevious").enabled && findChild(picker,"wallpaperNext").enabled,"Carousel stops browsing at an edge");
                    }
                }
                Config.set("themeAnimations",0);
                for(const size of [Qt.size(480,360),Qt.size(360,640),Qt.size(1920,1080)]) {
                    window.width=size.width; window.height=size.height;
                    picker.select(4); wait(30); inspect();
                }
                window.width=1100; window.height=700;
                for(const count of [1,2,3,4]) {
                    picker.images=all.slice(0,count); picker.select(0); wait(20); inspect();
                }
                picker.images=all; picker.select(4);
                mouseClick(card(5),card(5).width*0.85,card(5).height/2,Qt.LeftButton,Qt.NoModifier,0);
                check(picker.index===5 && ServiceAppearance.applies===0,"Selecting a preview also applies it");
                picker.forceActiveFocus(); keyClick(Qt.Key_Home); check(picker.index===0,"Home does not select the first image");
                keyClick(Qt.Key_End); check(picker.index===8,"End does not select the last image");
                keyClick(Qt.Key_Left); check(picker.index===7,"Keyboard browsing is broken");
                keyClick(Qt.Key_End); keyClick(Qt.Key_Right); check(picker.index===0,"Carousel does not wrap at the last wallpaper");
                keyClick(Qt.Key_Left); check(picker.index===8,"Carousel does not wrap at the first wallpaper");
                const selected=picker.selectedPath;
                picker.forceActiveFocus(); keyClick(Qt.Key_F5);
                until(()=>!picker.loading,"Refresh did not finish");
                check(picker.selectedPath===selected,"Refresh loses the browsed wallpaper");
                picker.select(4);
                const start=card(4).mapToItem(window.contentItem,card(4).width/2,card(4).height/2);
                mousePress(window.contentItem,start.x,start.y,Qt.LeftButton,Qt.NoModifier,0);
                mouseMove(window.contentItem,start.x-12,start.y,0);
                mouseMove(window.contentItem,start.x-picker.step*1.4,start.y,0);
                mouseRelease(window.contentItem,start.x-picker.step*1.4,start.y,Qt.LeftButton,Qt.NoModifier,0);
                check(!picker.dragging && picker.index===((Math.round(picker.pos)%all.length)+all.length)%all.length && ServiceAppearance.applies===0,"Dragging applies a wallpaper or does not settle");
                picker.select(3); OverlayState.show("wallpapers");
                click(card(3));
                check(ServiceAppearance.applies===1 && ServiceAppearance.wallpaperBusy,"Clicking the centred wallpaper does not apply it");
                picker.apply(3); picker.select(5);
                check(ServiceAppearance.applies===1 && picker.index===3 && !findChild(picker,"wallpaperNext").enabled,"Busy picker accepts another selection or apply");
                ServiceAppearance.finish(false);
                check(OverlayState.current==="wallpapers" && ServiceAppearance.wallpaperError!=="" && findChild(picker,"wallpaperNext").enabled,"Failed apply dismisses the picker or prevents retry");
                picker.apply(3); ServiceAppearance.finish(true);
                check(!OverlayState.active && Config.wallpaperCurrent===picker.selectedPath,"Successful apply does not close the picker or save the choice");
                picker.scanFolder(); Config.set("wallpaperDirectory",String(Qt.resolvedUrl("other")).slice(7));
                until(()=>!picker.loading && picker.images.length===2,"Folder change during refresh returns a stale catalog");
                check(picker.images.every(path=>path.includes("/other/")),"Stale wallpaper paths were accepted");
                Config.set("wallpaperDirectory",String(Qt.resolvedUrl("denied")).slice(7));
                until(()=>!picker.loading && picker.scanError!=="","Folder error was not shown");
                Config.set("wallpaperDirectory",String(Qt.resolvedUrl("empty")).slice(7));
                until(()=>!picker.loading && picker.images.length===0,"Empty folder did not finish loading");
                Config.set("wallpaperDirectory",folder);
                until(()=>!picker.loading && picker.images.length===9,"Catalog did not recover");
                Config.set("themeStyle",0); Config.set("shellLanguage","ru");
                picker.select(0); wait(100); inspect();
                picker.forceActiveFocus(); keyClick(Qt.Key_F5);
                until(()=>!picker.loading,"Refresh shortcut did not finish");
                window.contentItem.grabToImage(result=>{
                    result.saveToFile("/tmp/bloodyShell-wallpaper-picker-preview.png");
                    console.log("WALLPAPER_PICKER_PASSED five cover-flow previews, centred selection, no panel background, wraparound, all modes/sizes, click-to-apply, drag, keyboard, busy/retry, refresh, stale scans, empty state and localization");
                    Qt.quit();
                });
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("WALLPAPER_PICKER_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "WALLPAPER_PICKER_PASSED" in output, output
        assert not re.search(r"WALLPAPER_PICKER_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
    wallpaper_checks()
    desktop_checks()
    picker_checks()
