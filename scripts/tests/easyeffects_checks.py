#!/usr/bin/env python3

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def backend_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/processes.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyshell-effects-backend-") as temporary:
        base = Path(temporary)
        commands = []
        server = dict(running=True, bypass=False, current={"output": "Shared", "input": "Shared"})

        class Connection:
            buffer = b""

            def __enter__(self): return self
            def __exit__(self, *args): pass
            def settimeout(self, value): assert 0 < value <= 1
            def connect(self, path):
                assert path == str(base / "runtime/EasyEffectsServer")
                if not server["running"]: raise FileNotFoundError(path)
            def sendall(self, data):
                message = data.decode("utf-8")
                commands.append(message)
                assert message.endswith("\n") and message.count("\n") == 1
                if message == "get_global_bypass\n": self.buffer = b"1" if server["bypass"] else b"2"
                elif message.startswith("get_last_loaded_preset:"):
                    self.buffer = (server["current"][message.strip().split(":")[1]] + "\n").encode("utf-8")
                elif message.startswith("global_bypass:"): server["bypass"] = message.strip().endswith(":1")
                elif message.startswith("load_preset:"):
                    _, pipeline, name = message.rstrip("\n").split(":", 2)
                    if not server.get("reject"): server["current"][pipeline] = name
                else: raise AssertionError(message)
            def recv(self, size):
                if server.get("timeout"): raise TimeoutError()
                # Split even UTF-8 names across reads, as a real socket can.
                result, self.buffer = self.buffer[:1], self.buffer[1:]
                return result

        def invoke(*args):
            output = io.StringIO()
            with patch("sys.argv", ["effects", *args]), redirect_stdout(output):
                api["easyeffects_main"]()
            return json.loads(output.getvalue())

        env = dict(HOME=str(base / "home"), XDG_DATA_HOME=str(base / "data"), XDG_RUNTIME_DIR=str(base / "runtime"))
        with patch.dict(os.environ, env), patch("shutil.which", return_value=None), patch("socket.socket") as transport:
            assert not invoke("status")["installed"]
            transport.assert_not_called()
            assert not list(base.iterdir()), "Detection created settings or runtime folders"
        names = ["Shared", "Music: $(touch owned)", "Голос", "-leading-option"]
        for pipeline in ("input", "output"):
            folder = base / "data/easyeffects" / pipeline
            folder.mkdir(parents=True)
            for name in names + ["bad\nname", "x" * 101]:
                (folder / (name + ".json")).write_text("{}")
        before = {path: path.read_bytes() for path in base.rglob("*.json")}
        with patch.dict(os.environ, env), patch("shutil.which", return_value="/usr/bin/easyeffects"), patch("socket.socket", side_effect=lambda *args: Connection()):
            state = invoke("status")
            assert state["installed"] and state["running"] and not state["bypass"]
            assert set(state["presets"]["output"]) == set(names)
            assert not any(not message.startswith("get_") for message in commands), "Status changed EasyEffects"
            for name in names:
                state = invoke("preset", "output", name)
                assert state["current"] == dict(output=name, input="Shared"), "Output selection changed microphone preset"
            state = invoke("preset", "input", "Голос")
            assert state["current"] == dict(output=names[-1], input="Голос")
            assert invoke("effects", "false")["bypass"] is True
            assert invoke("effects", "true")["bypass"] is False
            server["reject"] = True
            try: invoke("preset", "input", "Shared")
            except RuntimeError as error: assert "could not load" in str(error)
            else: raise AssertionError("Rejected preset was reported as applied")
            for args in [("preset", "other", "Shared"), ("preset", "input", "../Shared"),
                         ("preset", "input", "bad\nname"), ("effects", "yes"), ("preset", "input", "missing")]:
                previous = len(commands)
                try: invoke(*args)
                except ValueError: pass
                else: raise AssertionError(args)
                assert len(commands) == previous, "Invalid action reached EasyEffects"
            server["timeout"] = True
            state = invoke("status")
            assert state["installed"] and state["command"] and "did not respond" in state["error"]
            server.pop("timeout")
            server["running"] = False
            state = invoke("status")
            assert state["installed"] and not state["running"] and state["bypass"] is None
            try: invoke("effects", "true")
            except RuntimeError as error: assert "Start EasyEffects" in str(error)
            else: raise AssertionError("Stopped EasyEffects accepted an action")
        assert all(path.read_bytes() == data for path, data in before.items()), "Integration rewrote presets"
        assert not (base / "owned").exists()
    print("EASYEFFECTS_BACKEND_PASSED missing/stopped/running, independent pipelines, literal names, fragmented replies, bypass, timeout and rejected changes")


def ui_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-effects-ui-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        registry = base / "scripts/lib/backend.py"
        registry.write_text(registry.read_text().replace('("processes.py", "easyeffects_main")', '("effects_fixture.py", "effects_main")'))
        (base / "scripts/lib/effects_fixture.py").write_text('''import json, os, sys
from pathlib import Path
def effects_main():
    base = Path(os.environ["TEST_SCREENSHOT_BASE"])
    path = base / "effects.json"
    args = sys.argv[1:]
    if args[0] == "fixture": path.write_text(args[1]); return
    calls = base / "effects-calls.jsonl"
    if args == ["count"]:
        print(sum(1 for line in calls.read_text().splitlines() if json.loads(line) == ["status"]) if calls.exists() else 0); return
    with calls.open("a") as output: output.write(json.dumps(args) + "\\n")
    state = json.loads(path.read_text())
    if args[0] != "status" and state.get("reject"):
        print("Fixture rejected action", file=sys.stderr); return 1
    if args[0] == "effects": state["bypass"] = args[1] == "false"
    elif args[0] == "preset": state["current"][args[1]] = args[2]
    path.write_text(json.dumps(state))
    print(json.dumps(state))
''')
        (base / "effects.json").write_text(json.dumps(dict(installed=False, running=False, bypass=None, command=[],
                                                          presets=dict(output=[], input=[]), current=dict(output="", input=""))))
        executable = base / "bin/easyeffects"
        executable.write_text('#!/bin/sh\nprintf opened > "$TEST_SCREENSHOT_BASE/opened"\n')
        executable.chmod(0o700)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "modules/common"
import "modules/core"
import "modules/ui/overlay/settings"

ShellRoot {
    Window {
        id: window; visible: true; width: 1080; height: 720
        SettingsContent { id: settings; anchors.fill: parent }
        CommandProcess { id: control; stdout: StdioCollector { id: controlResult } }
        TestCase {
            id: input; when: false; optional: true
            property var section
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(test, message) { for (let i=0;i<150;i++) { if (test()) return; wait(20); } throw new Error(message); }
            function find(item, name) {
                if (item.objectName === name) return item;
                for (const child of item.children || []) { const result=find(child,name); if (result) return result; }
                return null;
            }
            function configure(state) {
                until(()=>!section.busy,"UI did not settle");
                control.run(Paths.commandFor("easyeffects",["fixture",JSON.stringify(state)]));
                until(()=>!control.busy,"Fixture change did not finish");
                section.refresh();until(()=>!section.busy,"Refresh did not finish");
            }
            function count() {
                control.run(Paths.commandFor("easyeffects",["count"]));
                until(()=>!control.busy,"Count did not finish");return Number(controlResult.text);
            }
            function exercise() {
                OverlayState.show("settings");
                OverlayState.settingsPage=Registry.settings.findIndex(page=>page.id==="sound");
                until(()=>find(settings,"easyEffectsSection")!==null,"Sound page has no EasyEffects section");
                section=find(settings,"easyEffectsSection");until(()=>section.scanned&&!section.busy,"Detection did not finish");
                check(!section.expanded&&!section.state.installed,"Optional section did not start collapsed");
                section.expanded=true;wait(30);
                check(find(section,"easyEffectsDependencies").visible,"Missing app has no dependency shortcut");
                const state={installed:true,running:false,bypass:null,command:[Quickshell.env("TEST_SCREENSHOT_BASE")+"/bin/easyeffects"],
                    presets:{output:["Shared","Music: $(touch owned)"],input:["Shared","Voice"]},current:{output:"Shared",input:"Shared"}};
                configure(state);
                const output=find(section,"easyEffectsPreset-output"), microphone=find(section,"easyEffectsPreset-input"), toggle=find(section,"easyEffectsEnabled");
                check(!output.enabled&&!microphone.enabled&&!toggle.enabled&&find(section,"openEasyEffects").enabled,"Stopped controls are incorrect");
                state.running=true;state.bypass=false;configure(state);
                check(toggle.checked&&output.enabled&&microphone.enabled,"Running controls are unavailable");
                output.selected("Music: $(touch owned)");until(()=>!section.busy,"Output preset did not finish");
                check(section.state.current.output==="Music: $(touch owned)"&&section.state.current.input==="Shared","Preset selections are coupled");
                microphone.selected("Voice");until(()=>!section.busy,"Microphone preset did not finish");
                check(section.state.current.input==="Voice"&&section.state.current.output==="Music: $(touch owned)","Microphone changed output preset");
                toggle.toggled(false);until(()=>!section.busy,"Effects toggle did not finish");
                check(section.state.bypass&&!toggle.checked,"Effects toggle does not invert bypass");
                state.reject=true;configure(state);output.selected("Music: $(touch owned)");until(()=>!section.busy,"Rejected change did not finish");
                check(section.error!==""&&!output.enabled,"Rejected change was reported as successful");
                delete state.reject;configure(state);check(section.error===""&&output.enabled,"Refresh did not recover controls");
                state.error="EasyEffects did not respond";configure(state);
                check(section.error!==""&&find(section,"openEasyEffects").enabled&&!toggle.enabled,"Unresponsive app lost its Open button");
                delete state.error;state.presets={output:[],input:[]};configure(state);
                check(!output.enabled&&!microphone.enabled,"Empty presets are selectable");
                Config.set("shellLanguage","ru");Config.set("themeStyle",Enums.ThemeLight);wait(60);
                check(section.summary!==""&&section.width>0,"Localized section has invalid layout");
                section.expanded=false;wait(60);const collapsed=count();wait(2700);
                check(count()===collapsed,"Collapsed section retained polling");
                section.expanded=true;until(()=>!section.busy,"Expanded refresh did not finish");window.visible=false;wait(60);
                const hidden=count();wait(2700);check(count()===hidden,"Hidden Sound page retained polling");
                window.visible=true;until(()=>!section.busy,"Returning to Sound did not finish refreshing");
                Config.set("shellLanguage","en");Config.set("themeStyle",Enums.ThemeDark);
                state.presets={output:["Shared","Music"],input:["Shared","Voice"]};configure(state);
                for (let item=section.parent;item;item=item.parent) {
                    if (typeof item.resetScroll!=="function") continue;
                    item.contentY=Math.max(0,Math.min(item.contentHeight-item.height,section.mapToItem(item.contentItem,0,0).y-40));break;
                }
                wait(80);
                find(section,"openEasyEffects").clicked();wait(100);
                check(!OverlayState.active,"Opening EasyEffects left Settings in front");
                settings.grabToImage(result=>{
                    result.saveToFile("/tmp/bloodyShell-easyeffects-preview.png");
                    console.log("EASYEFFECTS_UI_PASSED collapsed optional section, stopped/running states, independent presets, bypass, failures/recovery, empty lists, localization and polling cleanup");Qt.quit();
                });
            }
        }
        Timer {interval:150;running:Config.initialized;onTriggered:{try{input.exercise();}catch(error){console.error("EASYEFFECTS_UI_FAILED",error);Qt.quit();}}}
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=22)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "EASYEFFECTS_UI_PASSED" in output, output
        assert not re.search(r"EASYEFFECTS_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output
        calls = [json.loads(line) for line in (base / "effects-calls.jsonl").read_text().splitlines()]
        assert ["preset", "output", "Music: $(touch owned)"] in calls and ["preset", "input", "Voice"] in calls
        assert (base / "opened").read_text() == "opened" and not (base / "owned").exists()


if __name__ == "__main__":
    backend_checks()
    ui_checks()
