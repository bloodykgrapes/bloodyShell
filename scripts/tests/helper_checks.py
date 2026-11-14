#!/usr/bin/env python3

import os
import json
import re
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
        (base / "src").mkdir()
        shutil.copyfile(ROOT / "modules/src/Clients.js", base / "src/Clients.js")
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
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        for second in ("0", "1"):
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, TEST_HELPER_SECOND=second),
                                    capture_output=True, text=True, timeout=8)
            output = result.stdout + result.stderr
            assert result.returncode == 0 and "HELPER_PASSED" in output and "HELPER_FAILED" not in output, output
        print("Helper first-run and persistence checks passed across two shell launches.")


def ui_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-helper-ui-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        (base / "home").mkdir()
        (base / "config/niri/bloodyShell").mkdir(parents=True)
        (base / "config/niri/config.kdl").write_text('include "bloodyShell/06-user-input.kdl"\n')
        input_file = base / "config/niri/bloodyShell/06-user-input.kdl"
        input_file.write_text('''// Personal input settings
input {
    keyboard { xkb { layout "us"; options "compose:menu"; }; }
    mouse { scroll-factor horizontal=-2.1 vertical=1.0; }
    touchpad { tap; }
}
''')
        (base / "config/niri/bloodyShell/07-user-output.kdl").write_text("")
        niri = base / "bin/niri"
        niri.write_text("#!/usr/bin/env python3\nimport json,sys\nif sys.argv[1:] == ['msg','-j','outputs']:\n    print(json.dumps({'A':dict(name='A',make='Test',model='Display',modes=[dict(width=1920,height=1080,refresh_rate=60000,is_preferred=True),dict(width=1280,height=720,refresh_rate=60000,is_preferred=False)],current_mode=0,logical=dict(x=0,y=0,width=1920,height=1080,scale=1,transform='Normal'),vrr_supported=False,vrr_enabled=False)}))\n")
        niri.chmod(0o700)
        (base / "modules/services/ServiceAppearance.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property color accent: "#8ecbff" }\n')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/helper"

ShellRoot {
    Window {
        id:window; visible:true; width:800; height:640
        property int finishes:0
        HelperContent { id:helper; anchors.fill:parent; onFinished:window.finishes++ }
        TestCase {
            id:events; name:"HelperUi"; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function find(name) { return findChild(helper,name); }
            function click(item) { mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0); }
            function until(predicate,message) { for(let i=0;i<250 && !predicate();i++) wait(10); check(predicate(),message); }
            function reveal(item) {
                const view=find("helperContentScroll"), p=item.mapToItem(view.contentItem,0,0);
                view.contentY=Math.max(0,Math.min(view.contentHeight-view.height,p.y-(view.height-item.height)/2));
                wait(30);
            }
            function inspect() {
                const view=find("helperContentScroll");
                check(view.height>0 && view.width>0,"Helper has no room for page content");
                check(helper.pageReveal===1,"Page fade did not settle");
                for(const name of ["helperBack","helperNext","helperClose","helperStep-0","helperStep-5"]) {
                    const item=find(name), p=item.mapToItem(helper,0,0);
                    check(p.x>=0 && p.y>=0 && p.x+item.width<=helper.width+0.1 && p.y+item.height<=helper.height+0.1,"Helper navigation exceeds the window: "+name);
                    check(item.Accessible.name!=="","Navigation has no accessible name");
                }
                for(const name of ["helperAnimation-0","helperAnimation-1","helperAnimation-2"]) {
                    const item=find(name);
                    if(!item.visible) continue;
                    const p=item.mapToItem(view,0,0);
                    check(p.x>=0 && p.x+item.width<=view.width+0.1,"Animation previews overflow the helper");
                }
            }
            function exercise() {
                window.requestActivate();
                check(helper.steps.length===6,"Helper does not have the six requested steps");
                check(!find("helperBack").enabled,"Welcome page allows going backwards");
                check(ServiceDevices.mouseWatchers===0 && ServiceDevices.watchers===0,"Helper watches devices before opening Input");
                until(()=>ServiceKeyboard.loaded,"Keyboard settings did not load");
                ServiceKeyboard.parse(`// input { keyboard { xkb { layout "bad"; }; }; }
/- input { keyboard { xkb { layout "bad"; }; }; }
input {
    /- keyboard { xkb { layout "bad"; }; }
    keyboard {
        /- xkb { layout "bad"; }
        xkb { layout r#"de,us"#; variant "nodeadkeys,"; options "grp:win_space_toggle,compose:menu"; }
        repeat-rate 37; numlock;
    }
}`);
                check(ServiceKeyboard.layouts.length===2 && ServiceKeyboard.layouts[0].layout==="de" && ServiceKeyboard.layouts[0].variant==="nodeadkeys","Inline/raw or disabled layout statements were parsed incorrectly");
                check(ServiceKeyboard.otherOptions.includes("compose:menu") && ServiceKeyboard.repeatRate===37 && ServiceKeyboard.numlock,"Keyboard reader dropped existing options");
                ServiceKeyboard.parse(`input { keyboard { /* options "bad"; */ xkb { layout #"fr"#; options "compose:menu"; }; /- numlock; }; }`);
                check(ServiceKeyboard.layouts[0].layout==="fr" && ServiceKeyboard.otherOptions.includes("compose:menu") && !ServiceKeyboard.numlock,"Keyboard reader accepts commented/disabled nodes or loses inline values");
                ServiceKeyboard.refresh(); until(()=>ServiceKeyboard.layouts[0].layout==="us","Keyboard file did not reload");
                click(find("helperWelcome-1"));check(helper.currentPage===1,"Display is not the first setup step");
                until(()=>ServiceDisplay.loaded&&find("helperDisplay")&&find("helperDisplay").selected==="A","Display settings did not load");
                const monitor=find("helperDisplay"), resolution=find("displayResolution"), scale=find("displayScale");
                check(resolution.options.length===2,"Display resolutions were not discovered");
                scale.edited(1.25);until(()=>!ServiceDisplay.busy,"Display scale did not save");
                check(Config.displays.A.scale===1.25,"Display scale was not saved");
                resolution.selected("1280x720");until(()=>ServiceDisplay.confirming&&find("displayConfirmation").opened,"Resolution has no recovery popup");
                find("displayConfirmation").accepted();until(()=>!ServiceDisplay.busy,"Resolution did not save");
                check(Config.displays.A.mode==="1280x720@60.000","Confirmed resolution did not save");
                resolution.selected("1920x1080");until(()=>ServiceDisplay.confirming,"Resolution change was not staged");
                helper.go(0);check(!ServiceDisplay.confirming&&Config.displays.A.mode==="1280x720@60.000","Leaving Display committed an unconfirmed mode");
                wait(50);reveal(find("helperWelcome-3"));click(find("helperWelcome-3")); check(helper.currentPage===3,"Welcome shortcut opens the wrong step"); wait(40);
                const view=find("helperContentScroll");
                for(const prefix of ["bar","dock"]) {
                    const enabled=find("helper-"+prefix+"-enabled"), position=find("helper-"+prefix+"-position");
                    reveal(enabled); click(enabled);
                    check(!Config[prefix+"Enabled"] && !position.enabled,"Disabled component keeps its controls enabled");
                    click(enabled); check(Config[prefix+"Enabled"] && position.enabled,"Component toggle did not save");
                    position.selected(prefix==="bar" ? Enums.EdgeRight : Enums.EdgeLeft);
                    check(Config[prefix+"Side"]===(prefix==="bar" ? Enums.EdgeRight : Enums.EdgeLeft),"Component position did not save");
                    const style=prefix==="bar" ? Enums.Filled : Enums.Islands;
                    const card=find("helper-"+prefix+"-style-"+style); reveal(card); click(card);
                    check(Config[prefix+"Type"]===style,"Component style did not save");
                }
                check(!find("helperIsland") && Config.islandEnabled,"Helper changes an unrequested dynamic-island setting");
                click(find("helperStep-2")); check(helper.currentPage===2,"Step buttons do not navigate"); wait(40);
                const theme=find("helperTheme"); theme.forceActiveFocus();
                keyClick(Qt.Key_Home); check(Config.themeStyle===Enums.ThemeLight && helper.currentPage===2,"Theme keyboard input navigates the wizard instead");
                keyClick(Qt.Key_End); check(Config.themeStyle===Enums.ThemeDark && helper.currentPage===2,"Theme selection did not save");
                const accent=Config.themeAccent; click(find("helperAccent")); check(Config.themeAccent!==accent,"Accent toggle did not save");
                for(const mode of [0,1,2]) {
                    const card=find("helperAnimation-"+mode); reveal(card); click(card);
                    check(Config.themeAnimations===mode,"Animation preview cannot be selected");
                }
                helper.go(4);
                until(()=>ServiceKeyboard.loaded && ServiceKeyboard.catalog.some(layout=>layout.code==="de") && ServiceDevices.mouseLoaded && ServiceDevices.mouseAvailable,"Input settings did not load");
                check(ServiceDevices.mouseWatchers===1 && ServiceDevices.watchers===0,"Input watches unrelated devices or owns duplicate mouse watchers");
                Config.set("themeAnimations",0); wait(40);
                find("helperLayoutChoice").selected("de");
                const add=find("helperLayoutAdd"); reveal(add); click(add);
                check(ServiceKeyboard.layouts.some(layout=>layout.layout==="de"),"Adding a keyboard layout failed");
                const primary=find("helperLayoutPrimary-1"); reveal(primary); click(primary);
                check(ServiceKeyboard.layouts[0].layout==="de","Primary keyboard layout was not changed");
                find("helperLayoutShortcut").selected("grp:win_space_toggle");
                find("helperMousePointerSpeed").moved(0.45);
                find("helperMouseAcceleration").selected("flat");
                const natural=find("helperMouseNaturalScroll"); reveal(natural); click(natural);
                find("helperMouseVerticalScrollSpeed").edited(2.5);
                helper.go(5);
                check(ServiceDevices.mouseWatchers===0 && ServiceDevices.watchers===0,"Leaving Input kept watching devices");
                check(helper.saving && !find("helperNext").enabled,"Ready does not wait for pending input changes");
                helper.advance(); check(window.finishes===0,"Enter finishes before pending input changes save");
                until(()=>!helper.saving,"Input saves did not finish");
                check(helper.saveError==="","Input save failed: "+helper.saveError);
                check(ServiceDevices.mouse.speed===0.45 && ServiceDevices.mouse.profile==="flat" && ServiceDevices.mouse.naturalScroll && ServiceDevices.mouse.scrollVertical===2.5,"Mouse controls did not save");
                check(find("helperDisplaySummary-A").valueText.includes("1280x720")&&find("helperDisplaySummary-A").valueText.includes("1.25"),"Ready omits saved display choices");
                check(find("helperBarSummary").valueText.includes(Tr.tr("common.right")) && find("helperDockSummary").valueText.includes(Tr.tr("common.left")),"Ready does not summarize selected positions");
                check(find("helperMouseSummary").description.includes("45%") && find("helperMouseSummary").description.includes("2.5"),"Ready omits the saved mouse settings");
                helper.go(4); until(()=>find("helperLayoutRemove-1"),"Input did not reopen");
                const remove=find("helperLayoutRemove-1"); reveal(remove); click(remove);
                check(ServiceKeyboard.layouts.length===1 && !find("helperLayoutRemove-0").enabled,"Last keyboard layout can be removed");
                helper.go(3); check(helper.pageReveal===1,"Disabled animations still fade pages");
                Config.set("themeAnimations",2); helper.go(2); check(helper.pageReveal<1,"Page change has no entrance animation");
                Config.set("themeAnimations",0); check(helper.pageReveal===1,"Disabling animations leaves a partial page fade");
                for(const scenario of [{w:800,h:640,language:"en",theme:1,animation:2},{w:520,h:480,language:"ru",theme:0,animation:1},{w:360,h:420,language:"ru",theme:1,animation:0}]) {
                    window.width=scenario.w; window.height=scenario.h;
                    Config.set("shellLanguage",scenario.language); Config.set("themeStyle",scenario.theme); Config.set("themeAnimations",scenario.animation);
                    for(let page=0;page<6;page++) { helper.go(page); wait(Theme.animationDurationControl+50); inspect(); }
                }
                Config.set("scrollSpeed",1); view.contentY=0;
                mouseWheel(view,view.width/2,view.height/2,0,-120,Qt.NoButton,Qt.NoModifier,0);
                check(view.contentY>0,"Compact helper cannot scroll"); const normal=view.contentY;
                Config.set("scrollSpeed",3); view.contentY=0;
                mouseWheel(view,view.width/2,view.height/2,0,-120,Qt.NoButton,Qt.NoModifier,0);
                check(view.contentY>normal,"Helper ignores configured scroll speed");
                Config.set("themeAnimations",2); view.contentY=0;
                mouseWheel(view,view.width/2,view.height/2,0,-120,Qt.NoButton,Qt.NoModifier,0); wait(20);
                helper.go(3); wait(400); check(view.contentY===0,"Old page scrolling continues after changing steps");
                helper.forceActiveFocus(); keyClick(Qt.Key_Home); check(helper.currentPage===0,"Home does not return to the first step");
                keyClick(Qt.Key_End); check(helper.currentPage===5,"End does not open Ready");
                keyClick(Qt.Key_Left); check(helper.currentPage===4,"Keyboard step navigation is broken");
                find("helperStep-2").forceActiveFocus(); keyClick(Qt.Key_Space); check(helper.currentPage===2,"Step button cannot be used with the keyboard");
                Config.set("themeAnimations",0); helper.forceActiveFocus();
                keyClick(Qt.Key_Return); check(helper.currentPage===3,"Enter does not advance");
                keyClick(Qt.Key_Return); keyClick(Qt.Key_Return); until(()=>!helper.saving,"Input stayed busy"); keyClick(Qt.Key_Return);
                check(window.finishes===1,"Finish does not close the helper once");
                click(find("helperClose")); keyClick(Qt.Key_Escape); check(window.finishes===3,"Close or Escape does not finish");
                check(ServiceDevices.mouseWatchers===0 && ServiceDevices.watchers===0,"Helper retained an input watcher");
                window.width=800; window.height=640; Config.set("shellLanguage","en"); helper.go(0); wait(100);
                window.contentItem.grabToImage(result=>{
                    result.saveToFile("/tmp/bloodyShell-helper-preview.png");
                    console.log("HELPER_UI_PASSED six requested steps, shared display controls and recovery, bar/dock enable-position-style, appearance, real input saves, primary/add/remove layouts, mouse controls, Ready summaries/save guards, watcher cleanup and compact localized layouts");
                    Qt.quit();
                });
            }
        }
        Timer { interval:150; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("HELPER_UI_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "HELPER_UI_PASSED" in output, output
        assert not re.search(r"HELPER_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output
        saved = json.loads((base / "config/bloodyShell/settings.json").read_text())
        assert saved["barEnabled"] is True and saved["dockEnabled"] is True and saved["islandEnabled"] is True
        assert saved["barSide"] == 3 and saved["barType"] == 2 and saved["dockSide"] == 2 and saved["dockType"] == 3
        stored_input = input_file.read_text()
        assert 'layout "de"' in stored_input and 'grp:win_space_toggle' in stored_input and 'compose:menu' in stored_input
        assert 'horizontal=-2.1' in stored_input and 'vertical=2.5' in stored_input and 'touchpad { tap; }' in stored_input


if __name__ == "__main__":
    run_checks()
    ui_checks()
