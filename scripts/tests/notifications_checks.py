#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


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
    with tempfile.TemporaryDirectory(prefix="bloodyshell-sidebar-notifications-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        (base / "home").mkdir()
        env.pop("WAYLAND_DISPLAY", None)
        source = base / "modules/services/ServiceNotifications.qml"
        text = source.read_text()
        start = text.index("    NotificationServer\n")
        end = text.index("    function received(n)", start)
        text = text[:start] + '''    property var fixtureNotifications: []
    QtObject { id: server; property var trackedNotifications: ({values:serviceNotifications.fixtureNotifications}) }

''' + text[end:]
        source.write_text(text)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/sidebars/right"

ShellRoot {
    id: tests
    property int activations: 0
    function check(ok,message) { if(!ok)throw new Error(message); }
    function find(item,name) { if(item.objectName===name)return item;for(const child of item.children||[]) {const found=find(child,name);if(found)return found;}return null; }
    function group(item) { if(typeof item.requestToggle==="function")return item;for(const child of item.children||[]){const found=group(child);if(found)return found;}return null; }
    function notificationRow(item) { if(item.n && typeof item.activate==="function")return item;for(const child of item.children||[]){const found=notificationRow(child);if(found)return found;}return null; }
    function click(item) { events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0); }
    function swipe(item, y, direction) {
        const start=item.mapToItem(window.contentItem,direction<0 ? item.width*0.8 : item.width*0.2,y);
        events.mousePress(window.contentItem,start.x,start.y,Qt.LeftButton);
        for(let step=1;step<=6;step++) events.mouseMove(window.contentItem,start.x+direction*item.width*step/12,start.y,20);
        events.mouseRelease(window.contentItem,start.x+direction*item.width/2,start.y,Qt.LeftButton);
    }
    function fill(count) {
        const list=[];
        for(let i=0;i<count;i++) {
            const note={id:i,desktopEntry:"fixture.app"+(i%5),appName:"Application "+(i%5+1),summary:"Notification "+(i+1),body:"A notification with enough detail to check wrapping and scrolling.",appIcon:"",image:"",urgency:1,tracked:true};
            note.actions=[{identifier:"default",text:"Open",invoke:()=>tests.activations++}];
            note.dismiss=()=>{note.tracked=false;ServiceNotifications.fixtureNotifications=ServiceNotifications.fixtureNotifications.filter(item=>item!==note);};
            list.push(note);
        }
        ServiceNotifications.fixtureNotifications=list;
    }
    function capture(path) {
        let saved=false;
        window.contentItem.grabToImage(result=>{result.saveToFile(path);saved=true;});
        for(let i=0;!saved&&i<20;i++)events.wait(25);
        check(saved,"Screenshot did not complete");
    }
    Window {
        id:window;visible:true;width:460;height:720
        Rectangle { anchors.fill:parent;color:Theme.colorSolid }
        RightSidebar {id:sidebar;anchors.fill:parent;screen:Quickshell.screens[0];barSide:Enums.EdgeTop;barThickness:44}
        TestCase {id:events;name:"SidebarTabs";when:false;optional:true}
    }
    Timer {interval:200;running:true;onTriggered:{try {
        for(const mode of [0,1,2]) {
            Config.set("themeAnimations",mode);Config.set("shellLanguage",mode===1?"ru":"en");Config.set("themeStyle",mode===1?0:1);
            sidebar.currentTab="controls";tests.fill(20);ServiceNotifications.unreadCounter=3;
            SidebarState.toggle("right",Quickshell.screens[0].name);events.wait(550);
            const tabs=tests.find(sidebar,"rightSidebarTabs");
            check(tabs && tabs.selectedIndex===0 && ServiceNotifications.unreadCounter===3,"Opening Control Center marked notifications read");
            check(tests.find(tabs,"tab-notifications").count===3,"Unread badge is missing");
            if(mode===0)tests.capture("/tmp/bloodyShell-control-center-tabs.png");
            tests.click(tests.find(tabs,"tab-notifications"));events.wait(550);
            let view=tests.find(sidebar,"sidebarNotifications");
            check(view && tabs.selectedIndex===1 && ServiceNotifications.unreadCounter===0,"Notification tab did not load or mark history read");
            ServiceNotifications.unreadCounter=2;
            check(ServiceNotifications.unreadCounter===0,"Visible notification history leaves new arrivals unread");
            const headerY=tabs.mapToItem(window.contentItem,0,0).y;
            check(sidebar.scrollView.contentHeight>sidebar.scrollView.height,"Long history does not scroll");
            sidebar.scrollView.contentY=100;events.wait(30);
            check(tabs.mapToItem(window.contentItem,0,0).y===headerY,"Tabs scroll away with history");
            sidebar.scrollView.contentY=0;
            const duration=tests.find(view,"notificationsDndDuration"),dnd=tests.find(view,"notificationsDnd");
            check(!duration.visible,"DND duration is visible while disabled");
            dnd.toggled(true);events.wait(30);
            check(duration.visible,"Enabling DND did not reveal duration");
            duration.toggle();events.wait(50);
            const durationPanel=tests.find(duration,"inlineMenuDropdownPanel");
            check(durationPanel&&durationPanel.height>0&&durationPanel.width===duration.width&&duration.alternatives.length===3,
                "DND durations did not expand within the sidebar");
            duration.choose(0);
            check(!duration.open&&!OverlayState.settingsPopup&&ServiceNotifications.dndMinutes===30,"DND selection did not close or apply");
            for(const minutes of [30,60,120,0]) {
                tests.find(view,"notificationsDndDuration").selected(minutes);
                check(ServiceNotifications.dnd && ServiceNotifications.dndMinutes===minutes,"DND duration did not apply");
            }
            ServiceNotifications.setDnd(false);
            const stack=tests.group(view);check(stack && stack.total===4,"History lost notification grouping");
            const groupToggle=tests.find(stack,"notificationGroupToggle");
            check(groupToggle.text===Tr.tr("notifications.showMore"),"Collapsed group is missing Show more");
            tests.click(groupToggle);check(stack.expanded && groupToggle.text===Tr.tr("notifications.showLess"),"Show more did not expand the group");
            if(mode===0)tests.capture("/tmp/bloodyShell-notification-tabs.png");
            events.wait(Theme.animationDurationControl+40);
            tests.click(groupToggle);check(!stack.expanded,"Show less did not collapse the group");
            events.wait(Theme.animationDurationControl+40);
            if(mode!==1) {
                const key=stack.model.key;
                const count=ServiceNotifications.count-stack.total;
                if(mode===2) {
                    tests.click(groupToggle);
                    events.wait(Theme.animationDurationControl+40);
                    tests.swipe(stack,22,1);
                } else tests.swipe(tests.notificationRow(stack),20,-1);
                events.wait(Theme.animationDurationClose+280);
                check(ServiceNotifications.count===count && ServiceNotifications.groups.every(group=>group.key!==key),
                    "Sideways swipe did not dismiss exactly one application's notifications");
            }
            tests.click(tests.find(tabs,"tab-controls"));events.wait(50);
            check(!tests.find(sidebar,"sidebarNotifications") && sidebar.scrollView.contentY===0,"Switching tabs kept inactive history or old scroll offset");
            check(!tabs.visualFocus,"Pointer tab selection kept keyboard hover styling");
            events.keyClick(Qt.Key_Right);events.wait(30);
            check(sidebar.currentTab==="notifications" && tabs.visualFocus,"Arrow navigation or keyboard focus failed");
            events.keyClick(Qt.Key_Home);events.wait(30);check(sidebar.currentTab==="controls","Home key did not select the first tab");
            events.keyClick(Qt.Key_End);events.wait(30);check(sidebar.currentTab==="notifications","End key did not select the last tab");
            view=tests.find(sidebar,"sidebarNotifications");
            tests.notificationRow(view).activate();events.wait(550);
            check(tests.activations===mode+1 && !SidebarState.active,"Notification action failed");
            check(!tests.find(sidebar,"sidebarNotifications"),"Closed sidebar retained notification views");
            sidebar.currentTab="notifications";SidebarState.toggle("right",Quickshell.screens[0].name);events.wait(550);
            view=tests.find(sidebar,"sidebarNotifications");tests.click(tests.find(view,"notificationsClearAll"));
            sidebar.currentTab="controls";events.wait(30);
            check(ServiceNotifications.count===0,"Switching tabs interrupted Clear All");
            sidebar.currentTab="notifications";events.wait(550);
            check(!tests.group(tests.find(sidebar,"sidebarNotifications")),"Empty notification history kept old groups");
            if(mode===1)tests.capture("/tmp/bloodyShell-notification-tabs-light-ru.png");
            SidebarState.close();events.wait(550);
        }
        console.log("SIDEBAR_NOTIFICATIONS_PASSED pointer/keyboard tabs, unread badge/read lifecycle, fixed header, scrolling, groups, DND, activation, clear-on-tab-switch, cleanup, animation modes and localization");Qt.quit();
    }catch(error){console.error("SIDEBAR_NOTIFICATIONS_FAILED",error);Qt.quit();}}}
    Timer {interval:20000;running:true;onTriggered:{console.error("SIDEBAR_NOTIFICATIONS_FAILED timeout");Qt.quit();}}
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "SIDEBAR_NOTIFICATIONS_PASSED" in output, output
        assert not re.search(r"SIDEBAR_NOTIFICATIONS_FAILED|TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def activation_checks():
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
                            'testActions = testActions.concat([{args:args, sidebarActive:SidebarState.active}])')
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
            actions:action?[{identifier:"default",text:"Open",invoke:()=>{check(!SidebarState.active,"Default action ran before sidebar closed");invocations++;}}]:[],
            dismiss:()=>{dismissals++;}};
    }
    function activate(notification, keyboard) {
        row.n=notification;
        SidebarState.current="right";
        if(keyboard) {row.forceActiveFocus();events.keyClick(Qt.Key_Return);}
        else events.mouseClick(row,row.width/2,row.height/2,Qt.LeftButton,Qt.NoModifier,0);
        check(!SidebarState.active,"Activation kept the sidebar open");
    }
    function expectWindow(id, message) {
        const actions=ServiceCompositor.backend.testActions;
        check(actions.length===1 && JSON.stringify(actions[0].args)===JSON.stringify(["focus-window","--id",String(id)]) && !actions[0].sidebarActive,message);
        ServiceCompositor.backend.testActions=[];
    }
    Window {
        id: window; visible:true; width:420; height:180
        NotificationRow {id:row;anchors.centerIn:parent;width:380}
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
