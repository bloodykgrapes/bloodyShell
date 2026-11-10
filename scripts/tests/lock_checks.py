#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def service_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-lock-service-") as temporary:
        base = Path(temporary)
        for folder in ("modules/core", "modules/services", "modules/common", "modules/test", "bin", "runtime"):
            (base / folder).mkdir(parents=True, mode=0o700)

        def put(name, body):
            (base / name).write_text(body)

        def stub(name, body):
            put(f"modules/core/{name}.qml", "pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n" + body + "\n}\n")

        stub("Config", "property bool animationsEnabled: true; property bool animationsFluid: true")
        stub("MenuState", "function close() {}")
        stub("Tr", "function tr(key) { return key; }")
        stub("TestLock", "property bool secure: false; property var pam: null; property var view: null")
        put("modules/core/qmldir", "\n".join(f"singleton {name} 1.0 {name}.qml" for name in ("Config", "MenuState", "Tr", "TestLock")))
        put("modules/services/qmldir", "singleton ServiceLock 1.0 ServiceLock.qml\nsingleton ServicePower 1.0 ServicePower.qml\n")
        for name in ("ServiceLock", "ServicePower"):
            source = (ROOT / f"modules/services/{name}.qml").read_text()
            if name == "ServiceLock":
                source = source.replace('import "../ui/lock"', 'import "../test"')
                source = source.replace("PamContext\n", "FakePam\n").replace("WlSessionLockSurface", "FakeLockSurface").replace("WlSessionLock\n", "FakeSessionLock\n")
                source = source.replace("            Lock\n", "            Item\n")
                source = source.replace("                anchors.fill: parent\n", "                Component.onCompleted: TestLock.view = this\n                anchors.fill: parent\n")
            put(f"modules/services/{name}.qml", source)
        shutil.copyfile(ROOT / "modules/common/CommandProcess.qml", base / "modules/common/CommandProcess.qml")
        put("modules/test/FakeSessionLock.qml", '''import QtQuick
import "../core"
QtObject
{
    default property list<QtObject> data
    property bool locked: false
    readonly property bool secure: TestLock.secure
}
''')
        put("modules/test/FakeLockSurface.qml", 'import QtQuick\nItem { property color color: "black" }\n')
        put("modules/test/FakePam.qml", '''import QtQuick
import Quickshell.Services.Pam
import "../core"
QtObject
{
    property string config: ""
    property bool responseRequired: false
    property bool active: false
    property int aborts: 0
    signal completed(int result)
    signal error(int error)
    function start() { active = true; return true; }
    function respond(password) {}
    function abort() { active = false; aborts++; }
    function success() { active = false; completed(PamResult.Success); }
    Component.onCompleted: TestLock.pam = this
}
''')
        put("control.json", "[]")
        put("calls", "")
        put("reject-suspend", "0")
        tool = f"#!{sys.executable}\nBASE = {str(base)!r}\n" + '''
import json
import os
from pathlib import Path
import subprocess
import sys
import time
base = Path(BASE)
name = Path(sys.argv[0]).name
def log(event):
    with (base / "calls").open("a") as stream:
        stream.write(event + "\\n")
if name == "gdbus":
    assert os.environ["LC_ALL"] == "C"
    log("monitor+")
    print("The name org.freedesktop.login1 is owned by :1.2", flush=True)
    cursor = int((base / "cursor").read_text()) if (base / "cursor").exists() else 0
    while True:
        try:
            events = json.loads((base / "control.json").read_text())
        except (ValueError, FileNotFoundError):
            events = []
        for event in events[cursor:]:
            cursor += 1
            (base / "cursor").write_text(str(cursor))
            if event == "disconnect":
                sys.exit(1)
            print(event, flush=True)
        time.sleep(0.02)
elif name == "systemd-inhibit":
    assert "--what=sleep" in sys.argv and "--mode=delay" in sys.argv
    log("delay+")
    code = subprocess.call(sys.argv[sys.argv.index("sh"):])
    log("delay-")
    sys.exit(code)
elif name == "systemctl":
    assert sys.argv[1:] == ["suspend"]
    log("suspend")
    if (base / "reject-suspend").read_text() == "1": sys.exit(1)
else:
    raise AssertionError(name)
'''
        for name in ("gdbus", "systemd-inhibit", "systemctl"):
            put(f"bin/{name}", tool)
            (base / f"bin/{name}").chmod(0o700)
        put("shell.qml", '''import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
ShellRoot
{
    id: tests
    property var events: []
    FileView { id: control; path: Quickshell.env("BLOODYSHELL_LOCK_TEST") + "/control.json"; blockLoading: true }
    FileView { id: calls; path: Quickshell.env("BLOODYSHELL_LOCK_TEST") + "/calls"; blockLoading: true }
    FileView { id: rejectSuspend; path: Quickshell.env("BLOODYSHELL_LOCK_TEST") + "/reject-suspend"; blockLoading: true }
    function count(event) { calls.reload(); calls.waitForJob(); return calls.text().split("\\n").filter(line => line === event).length; }
    function send(line) { events = events.concat([line]); control.waitForJob(); control.setText(JSON.stringify(events)); }
    function sleep(value) { send("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (" + value + ",)"); }
    function check(ok, message) { if (!ok) throw new Error(message); }
    TestCase
    {
        id: input
        when: false
        optional: true
        function until(predicate, message)
        {
            for (let i = 0; i < 200 && !predicate(); i++) wait(20);
            tests.check(predicate(), message);
        }
        function exercise()
        {
            until(() => ServiceLock.sleepMonitorReady && tests.count("delay+") === 1, "Sleep delay did not arm");
            ServiceLock.sleepEvent("unrelated PrepareForSleep (true,)");
            tests.check(!ServiceLock.locked, "Unrelated signal locked the session");
            tests.sleep(true);
            until(() => ServiceLock.preparingForSleep && ServiceLock.locked, "gdbus tuple did not lock before sleep");
            tests.check(!TestLock.view.visible, "Sleep exposed the normal lock UI instead of the black lock surface");
            wait(400);
            tests.check(tests.count("delay-") === 0, "Sleep delay released before compositor confirmation");
            ServiceLock.submit("test password");
            tests.check(!ServiceLock.checking && ServiceLock.pending === "", "Authentication started during sleep");
            TestLock.secure = true;
            until(() => tests.count("delay-") === 1, "Secure lock did not release sleep delay");
            tests.sleep(false);
            until(() => !ServiceLock.preparingForSleep && tests.count("delay+") === 2, "Wake did not rearm sleep delay");
            tests.check(ServiceLock.locked, "Wake unlocked the session");
            tests.check(TestLock.view.visible, "Wake did not restore the lock UI");

            ServiceLock.submit("test password");
            TestLock.pam.success();
            tests.check(ServiceLock.leaving, "Authentication did not begin unlock animation");
            wait(60);
            tests.sleep(true);
            until(() => ServiceLock.preparingForSleep, "Second sleep was missed");
            tests.check(!ServiceLock.leaving, "Sleep did not cancel pending unlock");
            wait(450);
            tests.check(ServiceLock.locked, "Unlock timer unlocked a sleeping session");
            TestLock.pam.success();
            tests.check(!ServiceLock.leaving, "Late authentication unlocked a sleeping session");
            tests.sleep(false);
            until(() => !ServiceLock.preparingForSleep && tests.count("delay+") === 3, "Second wake did not rearm");

            ServiceLock.submit("test password");
            const aborts = TestLock.pam.aborts;
            tests.sleep(true);
            until(() => ServiceLock.preparingForSleep, "Sleep during authentication was missed");
            tests.check(!ServiceLock.checking && ServiceLock.pending === "" && TestLock.pam.aborts > aborts, "Sleep did not cancel authentication");
            tests.sleep(false);
            until(() => !ServiceLock.preparingForSleep && tests.count("delay+") === 4, "Third wake did not rearm");
            tests.send("disconnect");
            until(() => !ServiceLock.sleepMonitorReady, "Failed monitor was not detected");
            until(() => ServiceLock.sleepMonitorReady && tests.count("monitor+") === 2 && tests.count("delay+") === 5, "Sleep monitor did not recover");
            tests.send("The name org.freedesktop.login1 does not have an owner");
            until(() => !ServiceLock.sleepMonitorReady && tests.count("delay-") === 5, "Lost logind owner retained sleep delay");
            tests.send("The name org.freedesktop.login1 is owned by :1.3");
            until(() => ServiceLock.sleepMonitorReady && tests.count("delay+") === 6, "New logind owner did not rearm");

            ServiceLock.submit("test password");
            TestLock.pam.success();
            Config.animationsEnabled = false;
            until(() => !ServiceLock.locked, "Disabling animations did not finish unlock");
            ServicePower.run("suspend");
            tests.check(ServiceLock.locked, "Shell suspend did not request a lock first");
            tests.check(!TestLock.view.visible, "Shell suspend flashes the lock UI before the sleep signal");
            until(() => tests.count("suspend") === 1 && ServicePower.pendingAction === "", "Shell suspend action did not complete");
            tests.check(TestLock.view.visible && ServiceLock.locked, "Completed suspend without a sleep signal left the lock UI black");
            rejectSuspend.setText("1"); rejectSuspend.waitForJob();
            ServicePower.run("suspend");
            tests.check(!TestLock.view.visible, "Pending suspend shows the lock UI");
            until(() => tests.count("suspend") === 2 && ServicePower.pendingAction === "", "Failed suspend did not finish");
            tests.check(TestLock.view.visible && ServiceLock.locked, "Failed suspend did not restore a usable locked screen");
            console.log("LOCK_SERVICE_PASSED sleep signals, black handoff, secure delay, wake, failed suspend, authentication races, and monitor recovery");
            Qt.quit();
        }
    }
    Timer
    {
        interval: 40; running: true
        onTriggered: { try { input.exercise(); } catch (error) { console.error("LOCK_SERVICE_FAILED", error); Qt.quit(); } }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   PATH=str(base / "bin") + os.pathsep + os.environ["PATH"], BLOODYSHELL_LOCK_TEST=str(base),
                   XDG_RUNTIME_DIR=str(base / "runtime"), DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus",
                   DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "LOCK_SERVICE_PASSED" in output, output
        assert not re.search(r"LOCK_SERVICE_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-lock-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules", base / "modules")
        for name in ("assets", "translations"):
            (base / name).symlink_to(ROOT / name)
        for name in ("runtime", "config/bloodyShell", "cache"):
            (base / name).mkdir(parents=True, mode=0o700)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps({"themeAnimations": 0, "lockNotificationsContent": False, "helperSeen": True}))

        def stub(name, body):
            (base / f"modules/services/{name}.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton\n{\n" + body + "\n}\n")

        stub("ServiceLock", 'property bool checking: false; property bool failed: false; property bool leaving: false; property bool preparingForSleep: false; property int failures: 0; readonly property int unlockDuration: !Config.animationsEnabled ? 0 : Config.animationsFluid ? 380 : 220; function submit(password) {}')
        lock_stub = base / "modules/services/ServiceLock.qml"
        lock_stub.write_text(lock_stub.read_text().replace("import Quickshell\n", 'import Quickshell\nimport "../core"\n'))
        stub("ServiceUser", 'property string avatar: ""; property string user: "tester"; property string fullName: "A long account name"')
        stub("ServicePower", 'function run(action) {}')
        stub("ServiceAppearance", 'property color accent: "#8ecbff"; function iconPath(name) { return ""; }')
        stub("ServiceNotifications", '''
    property var history: [
        {appName:"Messages",summary:"Private title",body:"Private message",image:"sensitive-image",appIcon:""},
        {appName:"Calendar",summary:"Private event",body:"Private details",image:"",appIcon:""},
        {appName:"Mail",summary:"Private mail",body:"Private body",image:"",appIcon:""}
    ]
    readonly property int count: history.length
    function age(notification, now) { return "Now"; }
''')
        stub("ServiceMedia", '''
    property var player: ({canGoPrevious:true,canGoNext:true,canTogglePlaying:true})
    property bool available: true
    property bool playing: true
    property string title: "A longer track title for a small screen"
    property string artist: "Artist"
    property string album: "Album"
    property string app: "Player"
    property string art: ""
    property real position: 30
    property real length: 180
    property var positionClients: []
    function setPositionActive(client, active) { positionClients = positionClients.filter(item => item !== client); if (active) positionClients = positionClients.concat([client]); }
    function time(value) { return "0:30"; }
    function next() {}
    function previous() {}
    function toggle() { playing = !playing; }
''')
        icon = base / "modules/core/Icon.qml"
        names = set(re.findall(r"Icon\.(\w+)", "\n".join(path.read_text() for path in (ROOT / "modules/ui/lock").rglob("*.qml"))))
        icon.write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n' + '\n'.join(f'    readonly property string {name}: ""' for name in names) + '\n}\n')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/lock"
ShellRoot
{
    Window
    {
        id: window
        visible: true
        width: 1024; height: 768; color: "black"
        Lock { id: lock; anchors.fill: parent }
        Loader { id: animatedLock; anchors.fill: parent; active: false; sourceComponent: Component { Lock {} } }
        function all(item, name) {
            let result = item.objectName === name ? [item] : [];
            for (const child of item.children || []) result = result.concat(all(child, name));
            return result;
        }
        function check(ok, message) { if (!ok) throw new Error(message); }
        TestCase
        {
            id: animations
            when: false
            optional: true
            function settled(item, name, value)
            {
                for (let i = 0; i < 75 && item[name] !== value; i++) wait(20);
                window.check(item[name] === value, "Animation did not settle: " + name);
            }
            function exercise()
            {
                lock.visible = false;
                for (const mode of [1, 2])
                {
                    Config.set("themeAnimations", mode);
                    animatedLock.active = true;
                    window.check(animatedLock.item !== null, "Lock did not load");
                    const view = animatedLock.item;
                    const clock = window.all(view, "lockClockReveal")[0];
                    const field = window.all(view, "lockPasswordReveal")[0];
                    const input = window.all(view, "lockPasswordInput")[0];
                    wait(140);
                    window.check(clock.progress > field.progress && clock.progress > 0 && clock.progress < 1, "Lock entrance did not stagger");
                    settled(field, "progress", 1);
                    settled(view, "introBack", 1);
                    window.check(view.introBack === 1, "Wallpaper entrance did not finish");
                    input.text = "temporary password";
                    ServiceLock.leaving = true;
                    window.check(input.text === "", "Unlock retained the typed password");
                    wait(70);
                    window.check(field.opacity > 0 && field.opacity < 1, "Unlock did not animate");
                    Config.set("themeAnimations", 0);
                    window.check(field.opacity === 0, "Animations-off left an unfinished unlock");
                    ServiceLock.leaving = false;
                    window.check(field.opacity === 1, "Cancelled unlock did not restore content");
                    input.text = "another password";
                    ServiceLock.preparingForSleep = true;
                    window.check(input.text === "", "Suspend retained the typed password");
                    window.check(input.readOnly, "Password input stayed editable during suspend");
                    ServiceLock.preparingForSleep = false;
                    animatedLock.active = false;
                    wait(20);
                }
                console.log("LOCK_PASSED responsive layout, privacy, fades, media lifecycle, and animation modes");
                Qt.quit();
            }
        }
        Timer
        {
            interval: 180; repeat: true; running: Config.initialized
            property int step: 0
            property var sizes: [Qt.size(1024,768), Qt.size(800,600), Qt.size(683,512), Qt.size(533,400)]
            onTriggered:
            {
                try
                {
                    const content = window.all(lock, "lockContent")[0];
                    const footer = window.all(lock, "lockFooter")[0];
                    const a = content.mapToItem(lock, 0, 0), b = content.mapToItem(lock, content.width, content.height);
                    window.check(a.x >= 20 && a.y >= 20 && b.x <= lock.width - 20 && b.y <= footer.y - 20, "Lock content clips: " + lock.width + "x" + lock.height);
                    if (step === 0)
                    {
                        const summaries = window.all(lock, "lockNotificationSummary");
                        const bodies = window.all(lock, "lockNotificationBody");
                        window.check(summaries.length === 3 && summaries.every(item => !item.label.includes("Private")), "Private notification titles leaked");
                        window.check(bodies.every(item => item.label === "" && !item.visible), "Private notification bodies leaked");
                        window.check(window.all(lock, "lockNotificationImage").every(item => String(item.source) === ""), "Private image previews leaked");
                        const cards = summaries.map(item => item.parent.parent);
                        window.check(cards[0].opacity === 1 && cards[1].opacity === 0.75 && cards[2].opacity === 0.5, "Notification fade was lost");
                        window.check(ServiceMedia.positionClients.length === 1, "Media timing did not subscribe");
                        Config.set("lockNotificationsContent", true);
                    }
                    if (step === 1)
                    {
                        window.check(window.all(lock, "lockNotificationSummary")[0].label === "Private title", "Content toggle did not restore titles");
                        window.check(window.all(lock, "lockNotificationBody")[0].label === "Private message", "Content toggle did not restore body");
                        Config.set("lockNotificationsContent", false);
                    }
                    if (step >= 2 && step < 6)
                    {
                        window.width = sizes[step - 2].width; window.height = sizes[step - 2].height;
                        Config.set("themeScale", step % 2 ? 1.5 : 1);
                    }
                    if (step === 6) lock.visible = false;
                    if (step === 7)
                    {
                        window.check(ServiceMedia.positionClients.length === 0, "Hidden lock screen kept polling media");
                        lock.visible = true;
                        Config.set("themeScale", 1);
                        window.width = 1024; window.height = 768;
                    }
                    if (step === 8)
                    {
                        window.contentItem.grabToImage(result => { result.saveToFile("/tmp/bloodyshell-lock-preview.png"); try { animations.exercise(); } catch (error) { console.error("LOCK_FAILED", error); Qt.quit(); } });
                        stop();
                    }
                    step++;
                }
                catch (error) { console.error("LOCK_FAILED", step, error); Qt.quit(); }
            }
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "LOCK_PASSED" in output, (result.returncode, output)
        assert not re.search(r"LOCK_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    service_checks()
    checks()
