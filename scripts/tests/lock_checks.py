#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


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

        stub("ServiceLock", 'property bool checking: false; property bool failed: false; property bool leaving: false; property int failures: 0; function submit(password) {}')
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
        function all(item, name) {
            let result = item.objectName === name ? [item] : [];
            for (const child of item.children || []) result = result.concat(all(child, name));
            return result;
        }
        function check(ok, message) { if (!ok) throw new Error(message); }
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
                        window.contentItem.grabToImage(result => { result.saveToFile("/tmp/bloodyshell-lock-preview.png"); console.log("LOCK_PASSED responsive layout, privacy, fades, and media lifecycle"); Qt.quit(); });
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
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "LOCK_PASSED" in output
        assert not re.search(r"LOCK_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
