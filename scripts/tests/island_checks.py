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
    island_source = base / "services/ServiceIsland.qml"
    island_source.write_text(island_source.read_text().replace("id: island", 'id: island\n    property int testRemovals: 0\n    property var testScreens: [{name:"A"},{name:"B"}]', 1)
                            .replace("primaryOutputFor(Quickshell.screens, Config.barScreens)", "primaryOutputFor(testScreens, Config.barScreens)")
                            .replace("function remove(notification)\n    {", "function remove(notification)\n    {\n        island.testRemovals++;"))
    recording = (ROOT / "modules/services/ServiceRecording.qml").read_text()
    put(base, "services/ServiceRecording.qml", recording.replace(
        "    readonly property var streams:", "    property var testLinks: []\n    readonly property var streams:",
        1).replace("(Pipewire.links?.values ?? [])", "testLinks"))
    stub(base, "core", "Config", 'property bool notificationsEnabled: true\nproperty int notificationsDuration: 100\nproperty var barScreens: ["A"]\nproperty bool islandRecordingIndicator: true\nproperty bool islandCameraIndicator: false\nproperty bool islandMedia: true')
    stub(base, "core", "Icon", 'property string bell: ""; property string recording: ""')
    stub(base, "core", "Tr", 'function tr(key) { return key + " %1"; }')
    stub(base, "services", "ServiceLock", 'property bool locked: false')
    stub(base, "services", "ServiceMedia", 'property bool playing: false\nproperty string title: "Track"\nproperty string artist: "Artist"\nproperty string art: ""')
    stub(base, "services", "ServiceCompositor", 'property string focusedOutput: "A"; property var fullscreenOutputs: []; property var captureStreams: []; function fullscreenOnOutput(name) { return fullscreenOutputs.includes(name); }')
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
import Quickshell.Services.Pipewire
import "core"
import "services"

ShellRoot
{
    id: tests
    property int retainedWatchers: 0
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
                        Config.islandCameraIndicator = true;
                        const source = {type: PwNodeType.Video, name: "v4l2_input.fixture", isStream: false, isSink: false};
                        const target = {isStream: true};
                        ServiceRecording.testLinks = [{state: PwLinkState.Paused, source, target}];
                        tests.check(!ServiceIsland.cameraActive, "Paused camera link set the indicator");
                        ServiceRecording.testLinks = [{state: PwLinkState.Active, source, target}];
                        tests.check(ServiceIsland.cameraActive && ServiceIsland.view("A").kind === "", "Camera took over the clock");
                        Config.islandCameraIndicator = false;
                        tests.check(!ServiceIsland.cameraActive, "Camera indicator ignored its setting");
                        Config.islandCameraIndicator = true;
                        ServiceRecording.testLinks = [{state: PwLinkState.Active, source: Object.assign({}, source, {name: "niri-screen-cast"}), target}];
                        tests.check(!ServiceIsland.cameraActive, "Screen casting was reported as camera use");
                        ServiceRecording.testLinks = [];
                        ServiceCompositor.captureStreams = [{id:1, active:false, output:"A"}];
                        tests.check(!ServiceRecording.active, "Paused recording is marked active");
                        ServiceCompositor.captureStreams = [{id:1, active:true, output:"A"}];
                        ServiceCompositor.fullscreenOutputs = ["A"];
                        ServiceNotifications.dnd = true;
                        tests.check(ServiceRecording.active && ServiceIsland.recordingActive && ServiceIsland.view("A").kind === "",
                            "Recording replaced the clock instead of setting the capture flag");
                        Config.islandRecordingIndicator = false;
                        tests.check(ServiceRecording.active && !ServiceIsland.active && ServiceIsland.view("A").kind === "", "Disabling the indicator kept the island visible or changed capture detection");
                        ServiceOSD.show();
                        tests.check(ServiceIsland.view("A").kind === "osd", "Disabling recording indication hid value changes");
                        ServiceOSD.hide();
                        Config.islandRecordingIndicator = true;
                        tests.check(ServiceIsland.active && ServiceIsland.recordingActive, "Re-enabling indication did not restore an active capture");
                        Config.barScreens = ["B"];
                        tests.check(ServiceIsland.primaryOutput === "B" && ServiceIsland.recordingActive, "Changing primary lost capture state");
                        Config.barScreens = ["A"];
                        ServiceIsland.testScreens = [{name:"B"}];
                        tests.check(ServiceIsland.primaryOutput === "B" && ServiceIsland.recordingActive, "Disconnected primary has no fallback");
                        ServiceIsland.testScreens = [{name:"A"},{name:"B"}];
                        tests.check(ServiceIsland.primaryOutput === "A", "Reconnecting the preferred display did not restore primary");
                        ServiceLock.locked = true;
                        tests.check(!ServiceIsland.active && ServiceIsland.view("A").kind === "", "Recording leaked through the lock screen");
                        ServiceLock.locked = false;
                        ServiceNotifications.dnd = false;
                        ServiceCompositor.captureStreams = [];
                        ServiceCompositor.fullscreenOutputs = [];
                        tests.check(!ServiceRecording.active && ServiceIsland.view("A").kind === "", "Stopped recording left its indicator behind");
                        ServiceMedia.playing = true;
                        tests.check(ServiceIsland.view("A").kind === "media", "Playing media missing");
                        Config.islandMedia = false;
                        tests.check(ServiceMedia.playing && !ServiceIsland.active && ServiceIsland.view("A").kind === "", "Disabling island media changed playback or left media visible");
                        Config.islandMedia = true;
                        tests.check(ServiceIsland.active && ServiceIsland.view("A").kind === "media", "Re-enabling island media did not restore playback status");
                        ServiceCompositor.fullscreenOutputs = ["A"];
                        tests.check(ServiceIsland.view("A").kind === "" && ServiceIsland.view("B").kind === "", "Fullscreen music leaked onto another screen");
                        ServiceCompositor.focusedOutput = "B";
                        ServiceOSD.show();
                        tests.check(ServiceIsland.view("A").kind === "osd" && ServiceIsland.view("B").kind === "", "Secondary focus routed a value event away from primary");
                        ServiceNotifications.notificationReceived(a); ServiceNotifications.notificationReceived(b);
                        tests.check(ServiceIsland.queue.length === 1, "Burst notification was lost");
                        break;
                    case 6:
                        tests.check(ServiceIsland.notice.notification === a, "Hidden notification expired behind a value event");
                        ServiceOSD.hide();
                        tests.check(ServiceIsland.view("A").kind === "notification" && ServiceIsland.view("B").kind === "", "Notification did not resume only on primary");
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
                        const updated = factory.createObject(tests, {summary:"Updating notification"});
                        for (let i = 0; i < 40; i++) {
                            updated.body = "Progress " + i;
                            ServiceNotifications.notificationReceived(updated);
                        }
                        tests.check(ServiceIsland.queue.filter(item => item.notification === updated).length === 1, "Updating a queued notification duplicates it");
                        tests.check(ServiceIsland.queue.find(item => item.notification === updated).body === "Progress 39", "Queued notification lost its latest update");
                        ServiceIsland.testRemovals = 0;
                        updated.closed();
                        tests.check(ServiceIsland.testRemovals === 1, "Notification updates attach duplicate close handlers");
                        ServiceIsland.clear(); ServiceMedia.playing = false;
                        tests.check(ServiceIsland.view("A").kind === "", "Idle island did not disappear");
                        retainedWatchers = ServiceIsland.notificationWatchers.length;
                        break;
                    default:
                        if (step < 26) break;
                        tests.check(ServiceIsland.notificationWatchers.length === retainedWatchers, "Destroyed notifications retained lifecycle watchers");
                        tests.check(!ServiceIsland.notice && ServiceIsland.queue.length === 0, "Destroyed notifications left stale island content");
                        if (step === 66) {
                            console.log("ISLAND_CHECKS_PASSED notification lifetime and garbage collection"); Qt.quit(); break;
                        }
                        for (let i = 0; i < 32; i++) {
                            const note = factory.createObject(tests, {summary: "Lifetime " + step + "-" + i});
                            ServiceNotifications.notificationReceived(note);
                            if (step < 46 || i % 2 === 0) note.closed();
                            note.destroy();
                        }
                        gc();
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
    assert not re.search(r"ISLAND_CHECKS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign", result.stdout), "Island QML error"
print("Island priority, output routing, queued notifications, DND, locking, media restoration, and notification destruction/garbage collection passed.")
