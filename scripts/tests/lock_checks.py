#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
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

            tests.check(!ServiceLock.promptVisible,"Wake opened the password prompt");
            ServiceLock.submit("test password");
            tests.check(!ServiceLock.checking,"Overview accepted a password without opening the prompt");
            ServiceLock.showPrompt();
            tests.check(ServiceLock.promptVisible,"Prompt did not open after wake");
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

            tests.check(!ServiceLock.promptVisible,"Wake opened the password prompt");
            ServiceLock.submit("test password");
            tests.check(!ServiceLock.checking,"Overview accepted a password without opening the prompt");
            ServiceLock.showPrompt();
            tests.check(ServiceLock.promptVisible,"Prompt did not open after wake");
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
        wallpaper = base / "wallpaper #.png"
        wallpaper.write_bytes(runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["png"](200, 120))
        (base / "config/bloodyShell/settings.json").write_text(json.dumps({"themeAnimations": 0, "lockNotificationsContent": False, "helperSeen": True, "wallpaperCurrent": str(wallpaper)}))

        def stub(name, body):
            (base / f"modules/services/{name}.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton\n{\n" + body + "\n}\n")

        stub("ServiceLock", 'property bool locked: true; property bool promptVisible: false; function showPrompt() { if (!preparingForSleep && !leaving) promptVisible = true; } function hidePrompt() { if (!checking && !leaving && !preparingForSleep) { promptVisible = false; failed = false; } } property bool checking: false; property bool failed: false; property bool leaving: false; property bool preparingForSleep: false; property int failures: 0; readonly property int unlockDuration: !Config.animationsEnabled ? 0 : Config.animationsFluid ? 380 : 220; property var submissions: []; function submit(password) { if (promptVisible) submissions = submissions.concat([password]); }')
        lock_stub = base / "modules/services/ServiceLock.qml"
        lock_stub.write_text(lock_stub.read_text().replace("import Quickshell\n", 'import Quickshell\nimport "../core"\n'))
        stub("ServiceUser", 'property string avatar: ""; property string user: "tester"; property string fullName: "An account name long enough to wrap without covering the password field"')
        stub("ServicePower", 'function run(action) {}')
        stub("ServiceAppearance", 'property color accent: "#8ecbff"; property string wallpaperImage: Config.wallpaperCurrent; function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""; } function iconPath(name) { return ""; }')
        appearance = base / "modules/services/ServiceAppearance.qml"
        appearance.write_text(appearance.read_text().replace("import Quickshell\n", 'import Quickshell\nimport "../core"\n'))
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
        Loader { id: view; anchors.fill: parent; active: false; sourceComponent: Lock {} }
        TestCase
        {
            id: events; when: false; optional: true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<250 && !predicate();i++) wait(10); check(predicate(),message); }
            function all(item,name) {
                let result=item.objectName===name ? [item] : [];
                for(const child of item.children || []) result=result.concat(all(child,name));
                return result;
            }
            function bounds(item,bottom,message) {
                const a=item.mapToItem(view.item,0,0), b=item.mapToItem(view.item,item.width,item.height);
                check(a.x>=20 && a.y>=20 && b.x<=window.width-20 && b.y<=bottom,message+" at "+window.width+"x"+window.height);
            }
            function overview(lock) {
                ServiceLock.hidePrompt(); until(()=>lock.promptReveal===0,"Clock view did not return");
            }
            function exercise()
            {
                until(()=>Config.initialized,"Settings did not load"); window.requestActivate();
                for(const mode of [0,1,2])
                {
                    ServiceLock.checking=false; ServiceLock.leaving=false; ServiceLock.preparingForSleep=false; ServiceLock.promptVisible=false;
                    Config.set("themeAnimations",mode); view.active=true;
                    check(view.item!==null,"Lock view did not load");
                    const lock=view.item, clock=findChild(lock,"lockClockReveal"), prompt=findChild(lock,"lockPrompt"), info=findChild(lock,"lockOverview");
                    const field=findChild(lock,"lockPasswordField"), input=findChild(lock,"lockPasswordInput"), footer=findChild(lock,"lockFooter"), wallpaper=findChild(lock,"lockWallpaper");
                    check(!ServiceLock.promptVisible && !prompt.visible && input.readOnly && input.text==="","Lock did not start with a noneditable overview");
                    const backdrop=findChild(lock,"lockBackdrop"), wallpaperLayer=findChild(lock,"lockWallpaperLayer");
                    check(backdrop.blurAmount===0 && wallpaperLayer.scale===1,"Overview wallpaper started blurred or zoomed");
                    check(wallpaper.status===Image.Ready && wallpaper.opacity===1 && !wallpaper.asynchronous,"Wallpaper appeared late or faded in");
                    if(mode) {
                        wait(140);
                        check(clock.progress>0 && prompt.opacity===0,"Password appeared during the first clock entrance");
                        until(()=>clock.progress===1,"Clock did not finish entering");
                    }
                    until(()=>ServiceMedia.positionClients.length===1,"Overview media did not subscribe");
                    const summaries=all(lock,"lockNotificationSummary"), bodies=all(lock,"lockNotificationBody");
                    check(summaries.length===3 && summaries.every(item=>!item.label.includes("Private")),"Private titles leaked");
                    check(bodies.every(item=>item.label==="" && !item.visible),"Private message bodies leaked");
                    check(all(lock,"lockNotificationImage").every(item=>String(item.source)===""),"Private images leaked");
                    Config.set("lockNotificationsContent",true);
                    check(summaries[0].label==="Private title" && bodies[0].label==="Private message","Notification content toggle did not apply");
                    Config.set("lockNotificationsContent",false);
                    if(mode===0) {
                        for(const size of [Qt.size(1024,768),Qt.size(800,600),Qt.size(683,512),Qt.size(533,400),Qt.size(480,800)]) {
                            window.width=size.width; window.height=size.height; wait(25);
                            bounds(findChild(lock,"lockOverviewContent"),window.height-40,"Overview clips");
                            lock.showPrompt();
                            bounds(findChild(lock,"lockContent"),footer.y-20,"Sign-in content clips");
                            overview(lock);
                        }
                        window.width=1024; window.height=768; wait(25);
                        window.contentItem.grabToImage(result=>result.saveToFile("/tmp/bloodyShell-lock-overview.png")); wait(80);
                    }
                    mouseClick(findChild(lock,"lockWakeArea"),8,8,mode===2 ? Qt.RightButton : Qt.LeftButton);
                    check(ServiceLock.promptVisible && prompt.enabled,"Click did not reveal sign-in");
                    if(mode) {
                        wait(70);
                        check(lock.promptReveal>0 && lock.promptReveal<1 && info.opacity>0 && prompt.opacity>0,"Switching views did not animate");
                        check(backdrop.blurAmount>0 && backdrop.blurAmount<0.8 && wallpaperLayer.scale>1 && wallpaperLayer.scale<1.035,"Wallpaper blur and zoom did not animate with sign-in");
                    }
                    until(()=>lock.promptReveal===1,"Sign-in entrance did not finish");
                    check(backdrop.blurAmount===0.8 && Math.abs(wallpaperLayer.scale-1.035)<0.0001,"Sign-in wallpaper did not finish blurring and zooming");
                    check(!info.visible && footer.visible && !input.readOnly && input.activeFocus,"Sign-in controls or password focus are missing");
                    until(()=>ServiceMedia.positionClients.length===0,"Hidden information kept media polling");
                    input.text="discard this password";
                    keyClick(Qt.Key_Escape);
                    until(()=>lock.promptReveal===0,"Escape did not return to the clock");
                    check(input.text==="" && input.readOnly,"Returning retained a hidden password");
                    check(backdrop.blurAmount===0 && wallpaperLayer.scale===1,"Returning to the clock retained blur or zoom");
                    keyClick(Qt.Key_A);
                    check(ServiceLock.promptVisible && input.text==="a","Typing did not preserve the first password character");
                    until(()=>lock.promptReveal===1,"Typing did not finish revealing sign-in");
                    keyClick(Qt.Key_Return);
                    check(ServiceLock.submissions[ServiceLock.submissions.length-1]==="a","Password did not submit from sign-in");
                    ServiceLock.checking=true; keyClick(Qt.Key_Escape);
                    check(ServiceLock.promptVisible,"Escape hid an active password check"); ServiceLock.checking=false;
                    input.text="temporary password"; ServiceLock.preparingForSleep=true;
                    check(input.text==="" && input.readOnly,"Suspend retained or allowed editing a password"); ServiceLock.preparingForSleep=false;
                    check(!input.readOnly,"Password field did not restore after suspend");
                    input.text="temporary password"; ServiceLock.leaving=true;
                    check(input.text==="","Unlock retained the password");
                    if(mode) { wait(70); check(prompt.opacity>0 && prompt.opacity<1,"Unlock did not animate"); }
                    Config.set("themeAnimations",0);
                    check(prompt.opacity===0,"Disabling animations left an unfinished unlock");
                    ServiceLock.leaving=false; check(prompt.opacity===1,"Cancelled unlock did not restore sign-in");
                    if(mode===0) { window.contentItem.grabToImage(result=>result.saveToFile("/tmp/bloodyShell-lock-prompt.png")); wait(80); }
                    Config.set("themeAnimations",mode);
                    lock.visible=false; ServiceLock.hidePrompt(); wait(20); lock.visible=true; wait(20);
                    check(lock.promptReveal===0 && input.text==="" && input.readOnly,"Reopening the same lock view retained sign-in or a password");
                    if(mode) {
                        lock.showPrompt(); wait(45); keyClick(Qt.Key_Escape); wait(20); lock.showPrompt();
                        until(()=>lock.promptReveal===1,"Rapid prompt reversal did not settle");
                        check(input.activeFocus && backdrop.blurAmount===0.8,"Rapid reversal lost focus or wallpaper effects");
                    }
                    ServiceLock.hidePrompt(); view.active=false; wait(30);
                    check(ServiceMedia.positionClients.length===0,"Unmounted lock retained media polling");
                }
                console.log("LOCK_PASSED two stages, click/typing/Escape, first character, immediate wallpaper, responsive layout, privacy, focus, password clearing and animation modes"); Qt.quit();
            }
        }
        Timer { interval:100; running:true; onTriggered:{try{events.exercise();}catch(error){console.error("LOCK_FAILED",error);Qt.quit();}} }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
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
