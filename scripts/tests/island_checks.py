#!/usr/bin/env python3

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

with tempfile.TemporaryDirectory(prefix="bloodyshell-island-") as temporary:
    base = Path(temporary)
    for folder in ("core", "services", "runtime", "cache"):
        (base / folder).mkdir(mode=0o700)
    shutil.copy2(ROOT / "modules/services/ServiceIsland.qml", base / "services/ServiceIsland.qml")
    stub(base, "core", "Config", 'property bool notificationsEnabled: true\nproperty int notificationsDuration: 100')
    stub(base, "core", "Icon", 'property string bell: ""')
    stub(base, "services", "ServiceLock", 'property bool locked: false')
    stub(base, "services", "ServiceMedia", 'property bool playing: false\nproperty string title: "Track"\nproperty string artist: "Artist"\nproperty string art: ""')
    stub(base, "services", "ServiceCompositor", 'property string focusedOutput: "A"; property var fullscreenOutputs: []; function fullscreenOnOutput(name) { return fullscreenOutputs.includes(name); }')
    stub(base, "services", "ServiceOSD", '''
    property bool active: false
    property string text: "72%"
    property string detail: ""
    property string context: "Volume"
    property string icon: ""
    property real value: 0.72
    property bool dim: false
    property int presentationRevision: 0
    function show() { presentationRevision++; active = true }
    function hide() { active = false }
''')
    stub(base, "services", "ServiceNotifications", '''
    property bool dnd: false
    property var dismissed: []
    property var activated: []
    signal notificationReceived(var notification)
    function dismiss(n) { dismissed = dismissed.concat([n]); n.closed() }
    function activate(n) { activated = activated.concat([n]); n.closed() }
''')
    module(base, "core")
    module(base, "services")
    put(base, "shell.qml", r'''import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "core"
import "services"

ShellRoot
{
    id: tests
    function check(ok, message) { if (!ok) throw new Error(message) }
    component Notice: QtObject
    {
        signal closed()
        property string summary: "Notice"
        property string body: "Body"
        property string appName: "Test app"
        property int urgency: NotificationUrgency.Normal
        property real expireTimeout: 0.18
    }
    QtObject { id: mediaMenu; property string output: "A" }
    Notice { id: a; summary: "First" }
    Notice { id: b; summary: "Second" }
    Notice { id: critical; urgency: NotificationUrgency.Critical }
    Component { id: factory; Notice {} }
    Timer
    {
        property int step: 0
        interval: 50; repeat: true; running: true
        onTriggered:
        {
            try
            {
                switch (step)
                {
                    case 0:
                        tests.check(ServiceIsland.view("A").kind === "", "Idle island was visible");
                        ServiceMedia.playing = true;
                        tests.check(ServiceIsland.view("A").kind === "media", "Playing media missing");
                        ServiceCompositor.fullscreenOutputs = ["A"];
                        tests.check(ServiceIsland.view("A").kind === "" && ServiceIsland.view("B").kind === "media", "Fullscreen did not suppress only its own music widget");
                        ServiceOSD.show();
                        tests.check(ServiceIsland.view("A").kind === "osd" && ServiceIsland.view("B").kind === "media", "Value event routing or priority failed");
                        ServiceNotifications.notificationReceived(a); ServiceNotifications.notificationReceived(b);
                        tests.check(ServiceIsland.queue.length === 1, "Burst notification was lost");
                        break;
                    case 6:
                        tests.check(ServiceIsland.notice.notification === a, "Hidden notification expired behind a value event");
                        ServiceOSD.hide();
                        tests.check(ServiceIsland.view("A").kind === "notification", "Notification did not resume after OSD");
                        ServiceCompositor.fullscreenOutputs = [];
                        break;
                    case 11: tests.check(ServiceIsland.notice && ServiceIsland.notice.notification === b, "Notification queue did not advance"); break;
                    case 15:
                        tests.check(!ServiceIsland.notice && ServiceIsland.view("A").kind === "media", "Island did not restore media");
                        ServiceNotifications.dnd = true;
                        ServiceNotifications.notificationReceived(a);
                        tests.check(!ServiceIsland.notice, "DND admitted a normal notification");
                        ServiceNotifications.notificationReceived(critical);
                        tests.check(ServiceIsland.notice.notification === critical, "DND suppressed a critical notification");
                        Config.notificationsEnabled = false;
                        tests.check(!ServiceIsland.notice && ServiceIsland.queue.length === 0, "Disabling notifications kept a popup alive");
                        ServiceNotifications.dnd = false; Config.notificationsEnabled = true;
                        break;
                    case 16:
                        ServiceNotifications.notificationReceived(a); ServiceNotifications.notificationReceived(b);
                        a.closed();
                        tests.check(ServiceIsland.notice.notification === b, "Closed notification left a stale presentation");
                        ServiceIsland.activate();
                        tests.check(!ServiceIsland.notice && ServiceNotifications.activated[0] === b, "Notification action targeted the wrong item");
                        ServiceNotifications.notificationReceived(a);
                        ServiceIsland.dismiss();
                        tests.check(ServiceNotifications.dismissed[0] === a, "Dismissal targeted the wrong notification");
                        break;
                    case 17:
                        ServiceNotifications.notificationReceived(a); ServiceIsland.setMediaMenu(mediaMenu, true); break;
                    case 22:
                        tests.check(ServiceIsland.notice && ServiceIsland.notice.notification === a, "Notification expired behind an open media menu");
                        ServiceIsland.setMediaMenu(mediaMenu, false); ServiceIsland.clear(); break;
                    case 24:
                        ServiceNotifications.notificationReceived(a); ServiceOSD.show();
                        ServiceLock.locked = true;
                        tests.check(!ServiceIsland.notice && !ServiceOSD.active && ServiceIsland.view("A").kind === "", "Lock leaked a transient");
                        ServiceLock.locked = false;
                        tests.check(ServiceIsland.view("A").kind === "media", "Unlock did not restore media");
                        break;
                    case 25:
                        for (let i = 0; i < 20; i++) ServiceNotifications.notificationReceived(factory.createObject(tests, {summary: "Burst " + i}));
                        tests.check(ServiceIsland.queue.length <= 8, "Notification queue is unbounded");
                        ServiceIsland.clear(); ServiceMedia.playing = false;
                        tests.check(ServiceIsland.view("A").kind === "", "Idle island did not disappear");
                        console.log("ISLAND_CHECKS_PASSED"); Qt.quit();
                        break;
                }
                step++;
            }
            catch (error) { console.error("ISLAND_CHECKS_FAILED", step, error); Qt.quit() }
        }
    }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=10)
    print(result.stdout)
    assert result.returncode == 0 and "ISLAND_CHECKS_PASSED" in result.stdout, "Island arbitration checks failed"
    assert not re.search(r"ISLAND_CHECKS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", result.stdout), "Island QML error"
print("Island priority, output routing, queued notifications, DND, locking, and media restoration passed.")
