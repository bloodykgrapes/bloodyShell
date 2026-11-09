#!/usr/bin/env python3

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
        helpers["stub"](base, "services", "ServiceApplications", 'function notificationFrom(notification, app) { return false }')
        helpers["module"](base, "core")
        helpers["module"](base, "services")
        settings = base / "config/bloodyShell/settings.json"
        settings.write_text(json.dumps({"notificationsRememberDnd": False, "notificationsDnd": False}))
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "core"
import "services"

ShellRoot
{
    id: tests
    property int stage: parseInt(Quickshell.env("TEST_NOTIFICATIONS_STAGE"), 10)
    function check(ok, message) { if (!ok) throw new Error(message) }
    Component.onCompleted: if (stage !== 3) void ServiceNotifications.dnd
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
                    ServiceNotifications.dnd = true;
                    tests.check(!Config.notificationsDnd, "Session-only DND was saved");
                    Config.set("notificationsRememberDnd", true);
                    tests.check(Config.notificationsDnd, "Enabling persistence lost the current state");
                }
                else if (tests.stage === 1)
                {
                    tests.check(ServiceNotifications.dnd, "DND did not survive restart");
                    ServiceNotifications.dnd = false;
                    tests.check(!Config.notificationsDnd, "Turning DND off was not saved");
                    ServiceNotifications.dnd = true;
                    Config.set("notificationsRememberDnd", false);
                    tests.check(ServiceNotifications.dnd && !Config.notificationsDnd, "Disabling persistence changed the session or kept a stale saved state");
                }
                else if (tests.stage === 2)
                {
                    tests.check(!ServiceNotifications.dnd, "DND survived after disabling persistence");
                    Config.set("notificationsRememberDnd", true);
                    tests.check(!Config.notificationsDnd, "Enabling persistence resurrected stale DND");
                    ServiceNotifications.dnd = true;
                    ServiceNotifications.dnd = false;
                }
                else tests.check(!ServiceNotifications.dnd && Config.notificationsRememberDnd, "Saved off state was not restored by a late-loaded service");
                finish.start();
            }
            catch (error) { console.error("NOTIFICATIONS_FAILED", error); Qt.quit() }
        }
    }
    Timer { id: finish; interval: 500; onTriggered: { console.log("NOTIFICATIONS_PASSED", tests.stage); Qt.quit() } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(base / "config"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-session-bus")
        env.pop("WAYLAND_DISPLAY", None)
        for stage, (remember, dnd) in enumerate(((True, True), (False, False), (True, False), (True, False))):
            result = subprocess.run(["qs", "-p", str(base), "--no-color"],
                                    env=dict(env, TEST_NOTIFICATIONS_STAGE=str(stage)), capture_output=True, text=True, timeout=5)
            output = result.stdout + result.stderr
            assert result.returncode == 0 and "NOTIFICATIONS_PASSED" in output, output
            assert not re.search(r"NOTIFICATIONS_FAILED|ReferenceError|TypeError|Binding loop|Unable to assign", output), output
            saved = json.loads(settings.read_text())
            assert (saved["notificationsRememberDnd"], saved["notificationsDnd"]) == (remember, dnd), saved
    print("DND opt-in, state changes, restart restoration, disabling persistence, and late service startup passed.")


if __name__ == "__main__":
    checks()
