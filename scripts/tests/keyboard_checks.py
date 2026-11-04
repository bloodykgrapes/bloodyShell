#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="bloodyshell-keyboard-") as temporary:
    base = Path(temporary)
    for name in ("runtime", "cache"):
        (base / name).mkdir(mode=0o700)
    env = dict(os.environ, XDG_CACHE_HOME=str(base / "cache"))
    url = subprocess.check_output(["python3", str(ROOT / "scripts/build-keyboard-monitor")], env=env, text=True).strip()
    wrapper = Path(unquote(urlparse(url).path))
    stamp = wrapper.stat().st_mtime_ns
    cached = subprocess.check_output(["python3", str(ROOT / "scripts/build-keyboard-monitor")], env=env, text=True).strip()
    assert cached == url and wrapper.stat().st_mtime_ns == stamp, "Unchanged keyboard monitor cache was rewritten"
    put = base / "shell.qml"
    put.write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot
{
    property int releases: 0
    Window
    {
        id: window
        visible: true
        width: 100
        height: 100
        Loader
        {
            id: monitor
            source: SOURCE
            onLoaded:
            {
                item.targetWindow = window;
                window.requestActivate();
                reopen.start();
            }
        }
        Timer
        {
            id: reopen
            interval: 100
            onTriggered: monitor.item.listening = true
        }
        Connections
        {
            target: monitor.item
            function onReleased()
            {
                monitor.item.listening = false;
                releases++;
                if (releases === 12)
                {
                    console.log("KEYBOARD_CHECKS_PASSED");
                    Qt.quit();
                }
                else reopen.start();
            }
        }
        Timer
        {
            interval: 4000
            running: true
            onTriggered: { console.error("KEYBOARD_CHECKS_FAILED missed release"); Qt.quit(); }
        }
    }
}
'''.replace("SOURCE", json.dumps(url)))
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=7)
    text = result.stdout + result.stderr
    print(text)
    assert "KEYBOARD_CHECKS_PASSED" in text and "KEYBOARD_CHECKS_FAILED" not in text
    assert "ReferenceError" not in text and "TypeError" not in text
print("Native keyboard monitor recovered 12 consecutive missed releases.")
