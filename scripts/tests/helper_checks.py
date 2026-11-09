#!/usr/bin/env python3

import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-helper-") as temporary:
        base = Path(temporary)
        for folder in ("core", "services", "ui/overlay/helper", "runtime", "cache"):
            (base / folder).mkdir(parents=True, mode=0o700)
        for name in ("Config", "Enums", "Paths", "OverlayState"):
            shutil.copyfile(ROOT / f"modules/core/{name}.qml", base / f"core/{name}.qml")
        shutil.copyfile(ROOT / "modules/ui/overlay/helper/HelperStartup.qml", base / "ui/overlay/helper/HelperStartup.qml")
        helpers["stub"](base, "core", "Registry", 'property var windows: ["helper", "settings"]')
        helpers["stub"](base, "core", "MenuState", 'function close() {}')
        helpers["stub"](base, "core", "Theme", 'property int animationDurationClose: 100')
        helpers["stub"](base, "services", "ServiceLock", 'property bool locked: true')
        helpers["module"](base, "core")
        helpers["module"](base, "services")
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "core"
import "services"
import "ui/overlay/helper"
ShellRoot {
    HelperStartup {}
    property bool second: Quickshell.env("TEST_HELPER_SECOND") === "1"
    Component.onCompleted: if (second) ServiceLock.locked = false
    Timer {
        interval: 800; running: true
        onTriggered: {
            if (Config.helperSeen !== parent.second || (OverlayState.current === "helper")) {
                console.error("HELPER_FAILED persistence or lock guard"); Qt.quit(); return;
            }
            if (!parent.second) {
                OverlayState.show("settings");
                ServiceLock.locked = false;
            }
            verify.start();
        }
    }
    Timer {
        id: verify; interval: 700
        onTriggered: {
            if ((OverlayState.current === "helper")) { console.error("HELPER_FAILED other overlay guard"); Qt.quit(); return; }
            OverlayState.hide("settings"); finish.start();
        }
    }
    Timer {
        id: finish; interval: 1100
        onTriggered: {
            if (!Config.helperSeen || (OverlayState.current === "helper") === parent.second) {
                console.error("HELPER_FAILED first-run behavior"); Qt.quit(); return;
            }
            OverlayState.hide("helper"); checkClosed.start();
        }
    }
    Timer {
        id: checkClosed; interval: 700
        onTriggered: {
            if ((OverlayState.current === "helper")) console.error("HELPER_FAILED reopened automatically");
            else console.log("HELPER_PASSED first run, lock, other overlay, persistence");
            Qt.quit();
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(base / "config"),
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        for second in ("0", "1"):
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, TEST_HELPER_SECOND=second),
                                    capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            assert result.returncode == 0 and "HELPER_PASSED" in output and "HELPER_FAILED" not in output, output
        print("Helper first-run and persistence checks passed across two shell launches.")


if __name__ == "__main__":
    run_checks()
