#!/usr/bin/env python3

from pathlib import Path
import os
import re
import resource
import runpy
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-overlay-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "Probe.qml").write_text('import QtQuick\nItem {}\n')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay"
import "modules/ui/overlay/settings/components"

ShellRoot
{
    id: tests
    property var timings: []
    property double requested: 0
    property string pending: ""
    function check(ok, message) { if (!ok) throw new Error(message); }
    QtObject
    {
        id: probeHost
        function activeFor(name) { return true; }
        function revealFor(name) { return 0.5; }
        function dismiss(name) {}
    }
    Component { id: viewProbe; OverlayView { host: probeHost; name: "probe" } }
    Window
    {
        id: window
        visible: true; width: 1024; height: 768
        OverlayFixture { id: overlay; anchors.fill: parent }
        SettingsPageSlot { id: slot; visible: false }
    }
    Connections
    {
        target: overlay.testPage
        function onLoaded()
        {
            if (tests.pending === "") return;
            tests.timings = tests.timings.concat([{ name: tests.pending, mode: Config.themeAnimations, milliseconds: Date.now() - tests.requested }]);
            tests.pending = "";
        }
    }
    Timer
    {
        interval: 35; repeat: true; running: true
        property int step: 0
        property int waits: 0
        property int index: 0
        property int mode: 0
        property int prepared: 0
        property double since: 0
        readonly property var names: ["settings", "launcher", "wallpapers", "helper", "power", "desktopMenu"]
        onTriggered:
        {
            if (!Config.initialized) return;
            try
            {
                tests.check(++waits < 400, "Overlay checks did not finish");
                switch (step)
                {
                    case 0:
                        const probe = viewProbe.createObject(window.contentItem);
                        tests.check(probe.ready, "Overlay entrance waits for another event-loop turn");
                        probe.arrival = 0.5;
                        tests.check(probe.reveal === 0.5, "Host and view entrances multiply their fades");
                        probe.destroy();
                        Config.set("themeAnimations", 2);
                        slot.enter(Qt.resolvedUrl("Probe.qml"), 0);
                        tests.check(slot.opacity === 1 && slot.shift === 0, "First settings page has an extra entrance delay");
                        slot.leave(0); Config.set("themeAnimations", 0);
                        prepared = overlay.preparedComponents.length;
                        OverlayState.show("launcher");
                        since = Date.now(); step = 1; break;
                    case 1:
                        if (Date.now() - since < 350) return;
                        tests.check(overlay.preparedComponents.length === prepared, "Background preparation ran while an overlay was active");
                        OverlayState.close(); step = 2; break;
                    case 2:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        ServiceLock.locked = true;
                        prepared = overlay.preparedComponents.length;
                        since = Date.now(); step = 3; break;
                    case 3:
                        if (Date.now() - since < 350) return;
                        tests.check(overlay.preparedComponents.length === prepared, "Background preparation ran while locked");
                        ServiceLock.locked = false; step = 4; break;
                    case 4:
                        tests.check(!overlay.preparedComponents.some(component => component.status === Component.Error), "An overlay failed to prepare: " + overlay.preparedComponents.filter(component => component.status === Component.Error).map(component => component.errorString()).join("\n"));
                        if (overlay.preparedComponents.length < overlay.preparationOrder.length || overlay.preparedComponents.some(component => component.status === Component.Loading)) return;
                        tests.check(overlay.testPage.item === null && !OverlayState.active, "Preparing components created a live overlay");
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Background preparation subscribed hidden views");
                        step = 5; break;
                    case 5:
                        Config.set("themeAnimations", mode);
                        tests.pending = names[index]; tests.requested = Date.now();
                        OverlayState.show(names[index]);
                        step = 6; break;
                    case 6:
                        if (!overlay.testPage.item || overlay.testPage.item.name !== names[index]) return;
                        tests.check(overlay.testPage.item.ready && overlay.testPage.item.active, "Prepared overlay is not ready for input");
                        OverlayState.close(); step = 7; break;
                    case 7:
                        if (overlay.testPage.item || OverlayState.mounted !== "") return;
                        index++;
                        if (index >= names.length) { index = 0; mode++; }
                        if (mode < 3) { step = 5; break; }
                        tests.check(ServiceApplications.autostartClients.length === 0 && ServiceMedia.positionUsers === 0 && ServiceMedia.visualizerUsers === 0, "Closing overlays retained resource subscriptions");
                        console.log("OVERLAY_TIMINGS", JSON.stringify(tests.timings));
                        console.log("OVERLAYS_PASSED single entrance, first settings page, background preparation, modal/lock guards, opening and cleanup in every animation mode");
                        Qt.quit(); break;
                }
            }
            catch (error) { console.error("OVERLAYS_FAILED", step, error); Qt.quit(); }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "OVERLAYS_PASSED" in output, output
        assert not re.search(r"OVERLAYS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def desktop_menu_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-desktop-menu-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/ui/overlay"

ShellRoot {
    Window {
        id: window; width:800; height:600; visible:true
        OverlayFixture { id:overlay; anchors.fill:parent }
        TestCase {
            id:events; name:"DesktopMenu"; when:false; optional:true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(predicate, message) {
                for (let i=0; i<100 && !predicate(); i++) wait(10);
                check(predicate(), message);
            }
            function openAt(point) {
                OverlayState.showDesktopMenu(Quickshell.screens[0].name,point.x,point.y);
                until(()=>overlay.testPage.item && overlay.testPage.item.name === "desktopMenu", "Menu did not load");
                return overlay.testPage.item;
            }
            function closed() { until(()=>!overlay.testPage.item && !OverlayState.active, "Menu did not finish closing"); }
            function exercise() {
                window.requestActivate();
                for (const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    for (const point of [Qt.point(20,20),Qt.point(780,20),Qt.point(20,580),Qt.point(780,580)]) {
                        const menu = openAt(point), card = findChild(menu,"desktopMenuCard");
                        wait(25);
                        check(card && menu.selected === -1, "Opening retained the previous selection");
                        if (mode === 0) check(card.opacity === 1 && card.zoom === 1, "Disabled animations still animate");
                        else check(card.opacity > 0 && card.opacity < 1 && card.zoom < 1, "Context menu has no entrance fade or zoom");
                        const left = card.mapToItem(window.contentItem,0,0), right = card.mapToItem(window.contentItem,card.width,card.height);
                        check(left.x >= 8 && left.y >= 8 && right.x <= window.width-8 && right.y <= window.height-8, "Animation moves the menu beyond a screen edge");
                        const scale = findChild(card,"desktopMenuScale");
                        check(scale.origin.x === Math.max(0,Math.min(card.width,point.x-card.x)) && scale.origin.y === Math.max(0,Math.min(card.height,point.y-card.y)), "Menu expands from the wrong origin");
                        wait(Theme.animationDurationControl+40);
                        check(card.opacity === 1 && card.zoom === 1, "Entrance did not settle");
                        keyClick(Qt.Key_Down); check(menu.selected === 0, "Menu did not receive keyboard focus");
                        keyClick(Qt.Key_Escape);
                        if (mode !== 0) {
                            wait(25);
                            check(card.opacity > 0 && card.opacity < 1, "Context menu has no exit fade");
                        }
                        closed();
                    }
                    const menu = openAt(Qt.point(300,200));
                    wait(Theme.animationDurationControl+40);
                    keyClick(Qt.Key_Down); keyClick(Qt.Key_Down);
                    OverlayState.close();
                    if (mode !== 0) wait(30);
                    const reopened = openAt(Qt.point(600,400));
                    check(reopened.selected === -1, "Reopening did not reset keyboard selection");
                    wait(Theme.animationDurationControl+40);
                    const card = findChild(reopened,"desktopMenuCard");
                    check(card.opacity === 1, "Interrupted exit did not reopen");
                    mouseClick(window.contentItem,2,2,Qt.RightButton,Qt.NoModifier,0);
                    closed();
                }
                Config.set("themeAnimations",2);
                const menu = openAt(Qt.point(300,200)); wait(25);
                Config.set("themeAnimations",0);
                check(findChild(menu,"desktopMenuCard").opacity === 1, "Disabling animations leaves a partial fade");
                keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
                until(()=>overlay.testPage.item && overlay.testPage.item.name === "settings", "Keyboard action did not open settings");
                OverlayState.close(); closed();
                console.log("DESKTOP_MENU_PASSED entrance/exit, all screen corners, pointer origin, keyboard focus/actions, interrupted close, outside click and every animation mode");
                Qt.quit();
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("DESKTOP_MENU_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "DESKTOP_MENU_PASSED" in output, output
        assert not re.search(r"DESKTOP_MENU_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def wallpaper_dismiss_checks():
    import json
    import shutil

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-wallpaper-dismiss-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "wallpapers").mkdir()
        for index in range(9):
            shutil.copyfile(base / "fixture.png", base / "wallpapers" / f"{index}.png")
        current = str(base / "wallpapers/4.png")
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True,
            themeAnimations=0, wallpaperDirectory=str(base / "wallpapers"), wallpaperCurrent=current)))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/ui/overlay"

ShellRoot {
    Window {
        id:window; width:900; height:650; visible:true
        OverlayFixture { id:overlay; anchors.fill:parent }
        TestCase {
            id:events; name:"WallpaperDismiss"; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<200 && !predicate();i++) wait(10); check(predicate(),message); }
            function picker() { return overlay.testPage.item ? findChild(overlay.testPage.item,"wallpapersContent") : null; }
            function open() {
                OverlayState.show("wallpapers");
                until(()=>picker() && !picker().loading && picker().images.length===9 && picker().rise===1,"Wallpaper picker did not open");
                return picker();
            }
            function closed() { until(()=>!OverlayState.active && !overlay.testPage.item,"Empty-space click did not dismiss the overlay"); }
            function exercise() {
                const initial=Config.wallpaperCurrent;
                for(const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    let content=open();
                    mouseClick(window.contentItem,4,4,Qt.LeftButton,Qt.NoModifier,0); closed();
                    content=open();
                    mouseClick(window.contentItem,window.width-4,window.height-4,Qt.RightButton,Qt.NoModifier,0); closed();
                    content=open();
                    const next=findChild(content,"wallpaperNext");
                    mouseClick(next,next.width/2,next.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && content.index===5,"Navigation also dismisses the picker");
                    wait(Theme.animationDurationMorph+40);
                    const side=findChild(content,"wallpaperCard-6");
                    mouseClick(side,side.width*0.85,side.height/2,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && content.index===6,"Side preview selection also dismisses the picker");
                    mousePress(window.contentItem,450,30,Qt.LeftButton,Qt.NoModifier,0);
                    mouseMove(window.contentItem,430,30,0);
                    mouseMove(window.contentItem,330,30,0);
                    mouseRelease(window.contentItem,330,30,Qt.LeftButton,Qt.NoModifier,0);
                    check(OverlayState.current==="wallpapers" && !content.dragging,"Dragging through empty space dismisses the picker");
                    mouseClick(window.contentItem,450,30,Qt.LeftButton,Qt.NoModifier,0); closed();
                    check(Config.wallpaperCurrent===initial,"Empty-space interaction changed the wallpaper");
                }
                console.log("WALLPAPER_DISMISS_PASSED left/right empty-space taps, drag cancellation, arrows and side previews in every animation mode");
                Qt.quit();
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("WALLPAPER_DISMISS_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "WALLPAPER_DISMISS_PASSED" in output, output
        assert not re.search(r"WALLPAPER_DISMISS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def wayland_checks():
    display = os.environ.get("WAYLAND_DISPLAY")
    if not display:
        print("SKIP native overlay check: a Wayland session with two outputs is required")
        return
    socket = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    source = (ROOT / "modules/ui/overlay/Overlay.qml").read_text()
    inhibitor = next(line.strip() for line in source.splitlines() if line.strip().startswith("ShortcutInhibitor {"))
    inhibitor = inhibitor.replace("ShortcutInhibitor {", "ShortcutInhibitor { id: shortcuts;", 1)
    with tempfile.TemporaryDirectory(prefix="bloodyshell-overlay-wayland-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "config", "home"):
            (base / name).mkdir(mode=0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: tests
    property int phase: 0
    property int round: 0
    property int ticks: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    PanelWindow {
        id: overlay
        property bool modal: true
        // The test never takes focus or pointer input from the user's applications.
        implicitWidth: 8; implicitHeight: 8
        visible: false; color: "transparent"
        anchors { top: true; left: true }
        screen: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bloodyShell:test-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        INHIBITOR
    }
    Timer {
        interval: 80; repeat: true; running: true
        onTriggered: {
            try {
                tests.check(Quickshell.screens.length >= 2, "Two connected Wayland outputs are required");
                tests.check(++tests.ticks < 160, "Native surface check timed out");
                switch (tests.phase) {
                    case 0:
                        tests.check(!shortcuts.enabled, "Hidden surface retained its shortcut inhibitor");
                        overlay.screen = Quickshell.screens[tests.round % Quickshell.screens.length];
                        overlay.visible = true; tests.phase = 1; break;
                    case 1:
                        if (!overlay.backingWindowVisible) return;
                        tests.check(shortcuts.enabled, "Visible modal surface lost shortcut inhibition");
                        overlay.screen = Quickshell.screens[(tests.round + 1) % Quickshell.screens.length];
                        tests.phase = 2; break;
                    case 2:
                        if (!overlay.backingWindowVisible) return;
                        tests.check(shortcuts.enabled, "Moving the surface did not restore shortcut inhibition");
                        overlay.modal = false;
                        tests.check(!shortcuts.enabled, "Closing the modal retained shortcut inhibition");
                        overlay.modal = true;
                        overlay.visible = false; tests.phase = 3; break;
                    case 3:
                        tests.check(!overlay.backingWindowVisible && !shortcuts.enabled, "Destroying the surface retained its inhibitor");
                        if (++tests.round < Quickshell.screens.length * 6) { tests.phase = 0; break; }
                        console.log("OVERLAY_WAYLAND_PASSED", tests.round, "hidden/visible moves, native surface recreation and inhibitor cleanup");
                        Qt.quit(); break;
                }
            } catch (error) { console.error("OVERLAY_WAYLAND_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
}
'''.replace("INHIBITOR", inhibitor))
        env = dict(os.environ, QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY=socket, QS_DISABLE_CRASH_HANDLER="1",
                   HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_CONFIG_HOME=str(base / "config"), DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus")
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True,
                                timeout=18, preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "OVERLAY_WAYLAND_PASSED" in output, output
        assert not re.search(r"OVERLAY_WAYLAND_FAILED|FATAL|ReferenceError|TypeError|Binding loop|Failed to load configuration", output), output


if __name__ == "__main__":
    if "--wayland" in sys.argv:
        wayland_checks()
    else:
        checks()
        desktop_menu_checks()
        wallpaper_dismiss_checks()
