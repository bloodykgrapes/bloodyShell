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
    env = dict(os.environ, XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
    url = subprocess.check_output(["python3", str(ROOT / "scripts/bloodyShell"), "internal", "build-keyboard-monitor"], env=env, text=True).strip()
    wrapper = Path(unquote(urlparse(url).path))
    stamp = wrapper.stat().st_mtime_ns
    cached = subprocess.check_output(["python3", str(ROOT / "scripts/bloodyShell"), "internal", "build-keyboard-monitor"], env=env, text=True).strip()
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
    put.write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
ShellRoot {
    id:tests
    property int releases:0
    Window { id:other; visible:false; width:100; height:100 }
    Window {
        id:window; visible:true; width:100; height:100
        Loader { id:monitor; source:SOURCE; onLoaded: { item.targetWindow=window; begin.start(); } }
        Connections { target:monitor.item; function onReleased() { tests.releases++; monitor.item.listening=false; } }
        TestCase {
            id:events; name:"KeyboardFocusHandoff"; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function exercise() {
                window.requestActivate(); wait(40);
                check(window.active,"Test window did not gain focus");
                keyPress(Qt.Key_Alt,Qt.AltModifier);
                monitor.item.listening=true;
                wait(160);
                check(tests.releases===0,"Held Alt was treated as released");
                other.visible=true; other.requestActivate(); wait(100);
                check(!window.active && tests.releases===0,"Temporary focus loss was treated as Alt release");
                window.requestActivate(); keyPress(Qt.Key_Alt,Qt.AltModifier); wait(160);
                check(window.active && tests.releases===0,"Focus handoff ended a held shortcut");
                keyRelease(Qt.Key_Alt); wait(140);
                check(tests.releases===1,"Real Alt release was missed or emitted more than once");
                keyPress(Qt.Key_Alt,Qt.AltModifier); monitor.item.listening=true; wait(40);
                other.requestActivate(); wait(40);
                keyRelease(Qt.Key_Alt); wait(100);
                check(tests.releases===1,"An inactive window confirmed a switch");
                window.requestActivate(); wait(140);
                check(tests.releases===2,"Alt release during focus handoff was not recovered");
                console.log("KEYBOARD_FOCUS_PASSED held Alt, temporary focus loss, focus recovery and release while unfocused");
                Qt.quit();
            }
        }
        Timer { id:begin; interval:100; onTriggered:{ try { events.exercise(); } catch(error) { console.error("KEYBOARD_FOCUS_FAILED",error); Qt.quit(); } } }
    }
}
'''.replace("SOURCE", json.dumps(url)))
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=5)
    text = result.stdout + result.stderr
    print(text)
    assert "KEYBOARD_FOCUS_PASSED" in text and "KEYBOARD_FOCUS_FAILED" not in text, text
    assert "ReferenceError" not in text and "TypeError" not in text, text
print("Native keyboard monitor preserved held shortcuts through focus handoffs and recovered 12 consecutive missed releases.")
