#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def unix_sockets_available():
    probe = Path(tempfile.gettempdir()) / ("bloodyShell-notification-socket-probe-" + str(os.getpid()))
    try:
        server = socket.socket(socket.AF_UNIX)
        server.bind(str(probe))
        server.close()
        probe.unlink()
        return True
    except OSError:
        return False


def checks():
    helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyshell-notifications-") as temporary:
        base = Path(temporary)
        for folder in ("core", "services", "runtime", "cache", "config/bloodyShell"):
            (base / folder).mkdir(parents=True, mode=0o700)
        for name in ("Config", "Enums", "Paths"):
            shutil.copy2(ROOT / f"modules/core/{name}.qml", base / f"core/{name}.qml")
        shutil.copy2(ROOT / "modules/services/ServiceNotifications.qml", base / "services/ServiceNotifications.qml")
        helpers["stub"](base, "core", "Tr", 'function tr(key) { return key }')
        helpers["stub"](base, "services", "ServiceCompositor", 'property var windowList: []')
        helpers["stub"](base, "services", "ServiceApplications", '''property var applications: [
            {id: "org.example.Music", name: "Music"},
            {id: "org.other.Music", name: "Other Music"},
            {id: "one.Terminal", name: "Terminal"},
            {id: "two.Terminal", name: "Terminal"}]
            function notificationFrom(notification, app) { return false }''')
        helpers["module"](base, "core")
        helpers["module"](base, "services")
        settings = base / "config/bloodyShell/settings.json"
        settings.write_text(json.dumps({"notificationsRememberDnd": True, "notificationsDnd": True, "notificationsDndUntil": int(time.time() * 1000) + 3600000}))
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "core"
import "services"

ShellRoot
{
    id: tests
    property int stage: parseInt(Quickshell.env("TEST_NOTIFICATIONS_STAGE"), 10)
    function check(ok, message) { if (!ok) throw new Error(message) }
    Component.onCompleted: void ServiceNotifications.dnd
    Timer
    {
        interval: 80
        running: true
        repeat: true
        onTriggered:
        {
            if (!Config.initialized) return;
            stop();
            try
            {
                if (tests.stage === 0)
                {
                    tests.check(!ServiceNotifications.dnd, "Fresh session restored DND without permission");
                    ServiceNotifications.setEnabledFor("org.example.Music.desktop", false);
                    tests.check(!ServiceNotifications.enabledFor("org.example.Music") && ServiceNotifications.enabledFor("org.other.Music"), "App preference used a shared suffix");
                    tests.check(ServiceNotifications.blockedNotification({desktopEntry: "ORG.EXAMPLE.MUSIC.desktop"}), "Desktop ID was not normalized");
                    tests.check(ServiceNotifications.blockedNotification({appName: "Music"}), "Exact name fallback failed");
                    tests.check(!ServiceNotifications.blockedNotification({desktopEntry: "org.other.Music", appName: "Music"}), "Name fallback overrode an explicit desktop ID");
                    ServiceNotifications.setEnabledFor("one.Terminal", false);
                    tests.check(!ServiceNotifications.blockedNotification({appName: "Terminal"}), "Ambiguous names blocked another application");
                    const blocked = {id: 99, desktopEntry: "org.example.Music", tracked: false, dismissed: false, dismiss: function() { this.dismissed = true; }};
                    const unread = ServiceNotifications.unreadCounter;
                    ServiceNotifications.received(blocked);
                    tests.check(blocked.dismissed && !blocked.tracked && ServiceNotifications.unreadCounter === unread && !ServiceNotifications.receivedAt[99], "Blocked notification was tracked or counted");
                    ServiceNotifications.setDnd(true, 30);
                    tests.check(ServiceNotifications.dnd && ServiceNotifications.dndMinutes === 30 && ServiceNotifications.dndUntil > Date.now() + 1799000, "Timed DND did not set a deadline");
                }
                else if (tests.stage === 1)
                {
                    tests.check(!ServiceNotifications.dnd && ServiceNotifications.dndUntil === 0, "Timed DND survived restart");
                    tests.check(!ServiceNotifications.enabledFor("org.example.Music") && !ServiceNotifications.enabledFor("one.Terminal"), "App preferences did not survive restart");
                    ServiceNotifications.setEnabledFor("org.example.Music", true);
                    tests.check(ServiceNotifications.enabledFor("org.example.Music") && !ServiceNotifications.enabledFor("one.Terminal"), "Enabling one app changed another app's preference");
                    ServiceNotifications.setDnd(true, 60);
                    ServiceNotifications.expireDnd(ServiceNotifications.dndUntil);
                    tests.check(!ServiceNotifications.dnd && ServiceNotifications.dndUntil === 0, "Timed DND did not expire");
                    ServiceNotifications.setDnd(true);
                    tests.check(ServiceNotifications.dnd && ServiceNotifications.dndUntil === 0, "Indefinite DND kept an old deadline");
                }
                else
                {
                    tests.check(!ServiceNotifications.dnd && ServiceNotifications.dndUntil === 0, "Indefinite DND survived restart");
                    ServiceNotifications.setDnd(true, 120);
                    const deadline=ServiceNotifications.dndUntil;
                    for(const duration of [-1, NaN, Infinity]) ServiceNotifications.setDnd(true,duration);
                    tests.check(ServiceNotifications.dndUntil===deadline,"Invalid duration changed DND");
                    ServiceNotifications.setDnd(false);
                    tests.check(!ServiceNotifications.dnd && ServiceNotifications.dndUntil===0,"Disabling DND left a pending deadline");
                    ServiceNotifications.setDnd(true, 0.002);
                }
                finish.start();
            }
            catch (error) { console.error("NOTIFICATIONS_FAILED", error); Qt.quit() }
        }
    }
    Timer { id: finish; interval: tests.stage === 2 ? 1500 : 500; onTriggered: {
        if (tests.stage === 2 && ServiceNotifications.dnd) { console.error("NOTIFICATIONS_FAILED timer did not expire"); Qt.quit(); return; }
        console.log("NOTIFICATIONS_PASSED", tests.stage); Qt.quit();
    } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(base / "config"),
                   XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus")
        env.pop("WAYLAND_DISPLAY", None)
        for stage in range(3):
            result = subprocess.run(["qs", "-p", str(base), "--no-color"],
                                    env=dict(env, TEST_NOTIFICATIONS_STAGE=str(stage)), capture_output=True, text=True, timeout=5)
            output = result.stdout + result.stderr
            assert result.returncode == 0 and "NOTIFICATIONS_PASSED" in output, output
            assert not re.search(r"NOTIFICATIONS_FAILED|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
            saved = json.loads(settings.read_text())
            assert not any(key in saved for key in ("notificationsRememberDnd", "notificationsDnd", "notificationsDndUntil")), saved
    print("Session-only timed/indefinite DND, automatic expiry, restart reset, removed persistence, invalid durations, and per-app preferences passed.")

def ui_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-island-notifications-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        (base / "home").mkdir()
        brightness = base / "fixture-brightness"
        brightness.mkdir()
        (brightness / "max_brightness").write_text("100\n")
        (brightness / "brightness").write_text("55\n")
        env.pop("WAYLAND_DISPLAY", None)
        source = base / "modules/services/ServiceNotifications.qml"
        text = source.read_text()
        start = text.index("    NotificationServer\n")
        end = text.index("    function received(n)", start)
        text = text[:start] + '''    property var fixtureNotifications: []
    QtObject { id: server; property var trackedNotifications: ({values:serviceNotifications.fixtureNotifications}) }

''' + text[end:]
        source.write_text(text)
        (base / "modules/services/ServiceMedia.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool playing: false
    property string art: ""
    property string title: "A song"
    property string artist: "An artist"
    readonly property var player: ({canTogglePlaying: true})
    function toggle() { playing = !playing }
}
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/bar/menus"

ShellRoot {
    id: tests

    property int activations: 0
    function check(ok, message) { if (!ok) throw new Error(message); }

    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    function card(item) {
        if (item.n && typeof item.activate === "function") return item;
        for (const child of item.children || []) {
            const result = card(child);
            if (result) return result;
        }
        return null;
    }

    function notification(id, app) {
        const note = {id, desktopEntry:"fixture.app" + app, appName:"Application " + app,
            summary:"Notification " + id, body:"Message body", appIcon:"", image:"", urgency:1, tracked:true};
        note.actions = [{identifier:"default", text:"Open", invoke:() => { tests.activations++; }}];
        note.dismiss = () => {
            note.tracked = false;
            ServiceNotifications.fixtureNotifications = ServiceNotifications.fixtureNotifications.filter(item => item !== note);
        };
        return note;
    }
    function fill() {
        ServiceNotifications.fixtureNotifications = [notification(1, 1), notification(2, 1), notification(3, 1), notification(4, 2)];
    }
    function click(item) {
        events.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0);
    }
    function reveal(item) {
        const scroll = find(menu, "islandPageScroll");
        const middle = item.mapToItem(scroll.contentItem, 0, item.height / 2).y;
        if (middle < scroll.contentY || middle > scroll.contentY + scroll.height)
            scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, middle - scroll.height / 2));
        events.wait(32);
    }
    function swipe(item, direction) {
        const start = item.mapToItem(window.contentItem, direction < 0 ? item.width * 0.8 : item.width * 0.2, item.height / 2);
        events.mousePress(window.contentItem, start.x, start.y, Qt.LeftButton);
        for (let step = 1; step <= 6; step++)
            events.mouseMove(window.contentItem, start.x + direction * item.width * step / 12, start.y, 20);
        events.mouseRelease(window.contentItem, start.x + direction * item.width / 2, start.y, Qt.LeftButton);
    }
    function until(test, message) {
        for (let i = 0; i < 85 && !test(); i++) events.wait(20);
        check(test(), message);
    }

    function exercise() {
        const element = name => tests.find(menu, name);
        const y = item => item.mapToItem(menu, 0, 0).y;
        Config.set("motionStyle", Enums.MotionDirect);
        check(menu.tabs.map(tab => tab.value).join(",") === "controls,calendar,weather,system,shelf", "Island tabs are out of order");
        menu.selectTab("weather");
        until(() => element("islandEmptyPage")?.pageTitle === Tr.tr("settings.island.weather"), "Weather tab did not load");
        menu.selectTab("shelf");
        until(() => element("islandEmptyPage")?.pageTitle === Tr.tr("settings.island.shelf"), "Shelf did not replace the previous tab");
        check(element("islandEmptyPage").pageText === Tr.tr("settings.island.shelfEmpty"), "Shelf shows another tab's content");
        menu.selectTab("controls");
        until(() => element("islandBrightness"), "Control Center did not load");
        check(!element("islandMediaCard") && !element("islandNotifications") && !element("islandBrightness").visible,
            "Empty Control Center shows inactive sections");
        const wallpaper = element("islandWallpaper"), user = element("islandUser");
        const launcher = element("islandLauncher"), settings = element("islandAction-settings");
        const lock = element("islandAction-lock"), power = element("islandAction-power");
        check(y(wallpaper) === y(user) && y(launcher) === y(settings) && y(settings) === y(lock) && y(lock) === y(power),
            "Profile and quick actions do not share their respective rows");
        check(!launcher.iconOnly && settings.iconOnly && lock.iconOnly && power.iconOnly, "Quick action labels do not match the layout");
        click(lock);
        check(ServiceLock.locked, "The Lock action did not lock the session");
        ServiceLock.locked = false;

        ServiceDisplay.brightnessDevice = Quickshell.env("TEST_SCREENSHOT_BASE") + "/fixture-brightness";
        ServiceDisplay.brightnessMax = 100;
        ServiceMedia.playing = true;
        fill();
        until(() => element("islandMediaCard") && element("islandNotifications"), "Media or notifications did not load");
        const ordered = ["islandWallpaper", "islandLauncher", "islandWifi", "islandVolume", "islandBrightness", "islandMediaCard", "islandNotifications"];
        until(() => ordered.slice(1).every((name, index) => y(element(name)) > y(element(ordered[index]))),
            "Control Center rows are out of order");
        click(element("islandMediaPause"));
        until(() => !element("islandMediaCard"), "Pausing did not hide the media card");

        for (const mode of [Enums.MotionDirect, Enums.MotionFluid, Enums.MotionGlide]) {
            Config.set("motionStyle", mode);
            Config.set("shellLanguage", mode === Enums.MotionFluid ? "ru" : "en");
            menu.selectTab("calendar");
            until(() => !element("islandNotifications"), "Switching tabs retained the inactive stack");
            menu.selectTab("controls");
            until(() => element("notificationStack"), "Notification stack did not return");
            fill();
            const view = element("islandNotifications");
            const stack = () => descendants(view).find(item => item.objectName === "notificationStack" && item.model?.key === "fixture.app1");
            until(() => stack()?.total === 3, "App grouping did not keep all three notifications");
            const group = stack();
            events.wait(Theme.animationDurationControl + 32);
            const first = card(group);
            check(find(group, "notificationStackLayer") && first.n.id === 3, "The stack did not show its next cards behind the newest one");
            const toggle = find(group, "notificationGroupToggle");
            check(toggle.text === Tr.tr("notifications.showMore"), "Collapsed stack lost Show more");
            reveal(toggle);
            click(toggle);
            check(group.expanded && toggle.text === Tr.tr("notifications.showLess"), "Show more did not expand the app stack in mode " + mode);
            until(() => descendants(group).filter(item => item.n && typeof item.activate === "function").length === 3,
                "Expanded stack did not render each notification");
            events.wait(Theme.animationDurationControl + 32);
            reveal(first);
            swipe(first, -1);
            until(() => ServiceNotifications.count === 3 && stack()?.total === 2, "Single swipe dismissed the wrong number of notifications");
            check(stack() === group && group.expanded && !ServiceNotifications.history.some(note => note.id === 3),
                "Single swipe did not preserve the stack: " + JSON.stringify({
                    reused: stack() === group, expanded: stack().expanded, remaining: ServiceNotifications.history.map(note => note.id)
                }));
            reveal(toggle);
            click(toggle);
            check(!group.expanded, "Show less did not collapse the app stack");
            const header = find(group, "notificationGroupSwipeArea");
            reveal(header);
            swipe(header, 1);
            until(() => ServiceNotifications.count === 1 && ServiceNotifications.history[0].id === 4, "Header swipe did not clear only that app");
        }

        fill();
        until(() => element("notificationsClearAll"), "Clear all control did not load");
        const top = card(element("islandNotifications"));
        top.activate();
        check(activations === 1, "Notification activation did not invoke its default action");
        const clear = element("notificationsClearAll");
        reveal(clear);
        click(clear);
        until(() => !element("islandNotifications"), "Empty notification history kept its section visible");
    }

    function descendants(item) {
        let result = [item];
        for (const child of item.children || []) result = result.concat(descendants(child));
        return result;
    }

    Window {
        id: window; width: 460; height: 880; visible: true; color: Theme.frameColor
        MenuIsland { id: menu; width: 430; height: implicitHeight; maximumHeight: window.height }
        TestCase { id: events; when: false; optional: true }
    }
    Timer {
        interval: 300; running: Config.initialized
        onTriggered: {
            try { tests.exercise(); console.log("ISLAND_NOTIFICATIONS_PASSED layout, optional sections, media, app grouping, individual swipe, app swipe, and actions"); }
            catch (error) { console.error("ISLAND_NOTIFICATIONS_FAILED", error); }
            Qt.quit();
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "ISLAND_NOTIFICATIONS_PASSED" in output, output
        assert not re.search(r"ISLAND_NOTIFICATIONS_FAILED|TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def activation_checks():
    if not unix_sockets_available():
        print("SKIP notification activation: UNIX domain sockets are unavailable in this environment")
        return
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-notification-focus-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        (base / "home").mkdir()
        env.pop("WAYLAND_DISPLAY", None)
        source = base / "modules/compositors/Niri.qml"
        text = source.read_text().replace("    id: niri", "    id: niri\n    property var testActions: []", 1)
        text = text.replace('Quickshell.execDetached(["niri", "msg", "action"].concat(args))',
                            'testActions = testActions.concat([{args:args, menuActive:MenuState.menuActive}])')
        source.write_text(text)
        source = base / "modules/services/ServiceApplications.qml"
        text = source.read_text().replace("readonly property var applications: DesktopEntries.applications.values || []", "property var applications: []")
        text = text.replace("DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)",
                            "applications.find(entry => entry.id === appId || entry.startupClass === appId) || null")
        source.write_text(text)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/common"

ShellRoot {
    id: tests
    property int invocations: 0
    property int dismissals: 0
    function check(ok,message) { if(!ok)throw new Error(message); }
    function note(desktop, appName, action) {
        return {id:1, desktopEntry:desktop, appName:appName, summary:"New message", body:"Open the application", appIcon:"", image:"", urgency:1, tracked:true,
            actions:action?[{identifier:"default",text:"Open",invoke:()=>{check(!MenuState.menuActive,"Default action ran before menu closed");invocations++;}}]:[],
            dismiss:()=>{dismissals++;}};
    }
    function activate(notification, keyboard) {
        row.n=notification;
        MenuState.menuActive=true;
        if(keyboard) {row.forceActiveFocus();events.keyClick(Qt.Key_Return);}
        else events.mouseClick(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,0);
        check(!MenuState.menuActive,"Activation kept the menu open");
    }
    function expectWindow(id, message) {
        const actions=ServiceCompositor.backend.testActions;
        check(actions.length===1 && JSON.stringify(actions[0].args)===JSON.stringify(["focus-window","--id",String(id)]) && !actions[0].menuActive,message);
        ServiceCompositor.backend.testActions=[];
    }
    Window {
        id: window; visible:true; width:420; height:180
        NotificationRow {id:row;anchors.centerIn:parent;width:380;onActivated:MenuState.close()}
        TestCase {id:events;name:"NotificationActivation";when:false;optional:true}
    }
    Timer {interval:250;running:true;onTriggered:{try {
        const backend=ServiceCompositor.backend;
        check(backend!==null,"Missing compositor adapter");
        ServiceApplications.applications=[{id:"org.example.Chat",name:"Chat",startupClass:"Chat-client"}];
        void ServiceWindowActions.lastFocused;
        backend.windowsApply([
            {id:11,app_id:"org.example.Chat",title:"First chat",workspace_id:1,is_focused:false},
            {id:12,app_id:"org.example.Chat",title:"Recent chat",workspace_id:2,is_focused:true},
            {id:13,app_id:"org.other.Chat",title:"Other app",workspace_id:3,is_focused:false},
            {id:99,app_id:"org.example.Editor",title:"Editor",workspace_id:4,is_focused:false}]);
        backend.windowFocus(13);backend.windowFocus(99);
        activate(note("org.example.Chat.desktop","Chat",true),false);
        expectWindow(12,"Pointer activation did not focus the recent exact application window");
        check(invocations===1 && dismissals===0,"Default action changed its dismissal behavior");
        activate(note("org.example.Chat.desktop","Chat",false),true);
        expectWindow(12,"Keyboard activation without a default action did not focus the window");
        check(invocations===1 && dismissals===1,"Action-less notification was not dismissed");
        activate(note("Chat-client","",true),false);
        expectWindow(12,"Startup class alias did not match the application");
        activate(note("","Chat",true),false);
        expectWindow(12,"Application name fallback did not match the application");
        activate(note("org.example.Missing","Missing",true),false);
        check(backend.testActions.length===0 && invocations===4,"Unmatched notification focused an unrelated window or lost its action");
        activate(note("org.example.Missing","Missing",false),true);
        check(backend.testActions.length===0 && dismissals===2,"Unmatched action-less notification was not dismissed safely");
        backend.windowRemove(12);
        activate(note("org.example.Chat.desktop","Chat",false),false);
        expectWindow(11,"Closed recent window prevented focusing the remaining application window");
        console.log("NOTIFICATION_ACTIVATION_PASSED pointer/keyboard, default actions, MRU, exact IDs, startup classes, names, closed windows and unmatched notifications");Qt.quit();
    }catch(error){console.error("NOTIFICATION_ACTIVATION_FAILED",error);Qt.quit();}}}
    Timer {interval:5000;running:true;onTriggered:{console.error("NOTIFICATION_ACTIVATION_FAILED timeout");Qt.quit();}}
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=8)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "NOTIFICATION_ACTIVATION_PASSED" in output, output
        assert not re.search(r"NOTIFICATION_ACTIVATION_FAILED|TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
    ui_checks()
    activation_checks()
