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
        for folder in ("animations", "core", "services", "ui/overlay/helper", "runtime", "cache"):
            (base / folder).mkdir(parents=True, mode=0o700)
        for name in ("Config", "Enums", "Paths", "OverlayState"):
            shutil.copyfile(ROOT / f"modules/core/{name}.qml", base / f"core/{name}.qml")
        shutil.copyfile(ROOT / "modules/animations/OverlayMotion.js", base / "animations/OverlayMotion.js")
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
        (base / "config/niri/config.kdl").write_text('include "bloodyShell/08-settings.kdl"\n')
        input_file = base / "config/niri/bloodyShell/08-settings.kdl"
        input_file.write_text('''// Personal input settings
input {
    keyboard { xkb { layout "us"; options "compose:menu"; }; }
    mouse { scroll-factor horizontal=-2.1 vertical=1.0; }
    touchpad { tap; }
}
''')
        (base / "modules/services/ServiceAppearance.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property color accent: "#8ecbff"; property int effectiveThemeStyle: 1 }\n')
        (base / "modules/services/ServiceRegion.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property string locale: "en_US.UTF-8"
    property string timezone: "Europe/London"
    property var locales: ["en_US.UTF-8", "ru_RU.UTF-8"]
    property var timezones: ["Europe/London", "Europe/Moscow"]
    property string error: ""
    property string notice: ""
    property bool busy: false
    function refresh() {}
    function setLocale(value) { locale=value; busy=true; finish.restart(); }
    function setTimezone(value) { timezone=value; busy=true; finish.restart(); }
    Timer {id:finish;interval:150;onTriggered:parent.busy=false}
}
''')
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
            function capture(path) {
                let saved=false;
                window.contentItem.grabToImage(result=>{result.saveToFile(path);saved=true;});
                until(()=>saved,"Helper capture did not finish");
            }
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
                for(const name of ["helperShellLanguage","helperSystemLanguage","helperTimezone","helperTheme","helperAnimations","helper-bar-position","helper-dock-position"]) {
                    const item=find(name);
                    if(!item || !item.visible)continue;
                    const position=item.mapToItem(view,0,0);
                    check(position.x>=0 && position.x+item.width<=view.width+1,"Helper control overflows narrow content: "+name);
                }
            }
            function exercise() {
                window.requestActivate();
                ServiceCompositor.backend.outputs = [{name:"A", make:"Test", model:"Display", current_mode:0,
                    modes:[{width:1920,height:1080,refresh_rate:60000,is_preferred:true},
                           {width:1280,height:720,refresh_rate:60000,is_preferred:false}],
                    logical:{x:0,y:0,width:1920,height:1080,scale:1,transform:"Normal"},vrr_supported:false,vrr_enabled:false}];
                ServiceCompositor.backend.outputsLoaded = true;
                check(helper.steps.length===6 && !find("helperBack").enabled,"Wizard steps or initial navigation are wrong");
                check(!find("helperWelcome-1") && !find("helperInputLoader"),"Removed welcome cards or Input step remain");
                helper.go(1);until(()=>find("helperTimezone"),"Time and language did not load");
                const shellLanguage=find("helperShellLanguage");
                wait(Theme.animationDurationControl+50);
                click(shellLanguage);wait(100);
                let panel=findChild(helper.popupLayer,"settingsDropdownPanel");
                check(panel && panel.height>shellLanguage.height && panel.width>=shellLanguage.width,"Helper dropdown is squeezed into its field");
                let popupPosition=panel.mapToItem(helper,0,0);
                check(popupPosition.x>=0 && popupPosition.y>=0 && popupPosition.x+panel.width<=helper.width && popupPosition.y+panel.height<=helper.height,"Helper dropdown exceeds its popup layer");
                capture("/tmp/bloodyShell-helper-dropdown.png");
                keyClick(Qt.Key_Escape);check(!shellLanguage.open,"Escape did not close helper dropdown");
                click(shellLanguage);wait(30);keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);
                check(!shellLanguage.open && Config.shellLanguage!=="system","Dropdown keyboard selection did not apply");
                click(shellLanguage);helper.go(2);wait(30);
                check(!OverlayState.settingsPopup,"Changing helper step retained a modal dropdown");
                helper.go(1);until(()=>find("helperShellLanguage"),"Regional controls did not reopen");
                find("helperShellLanguage").selected("ru");check(Config.shellLanguage==="ru","Shell language did not save");
                find("helperShellLanguage").selected("en");
                find("helperSystemLanguage").selected("ru_RU.UTF-8");until(()=>!ServiceRegion.busy,"Locale save did not finish");
                find("helperTimezone").selected("Europe/Moscow");until(()=>!ServiceRegion.busy,"Timezone save did not finish");
                check(ServiceRegion.locale==="ru_RU.UTF-8" && ServiceRegion.timezone==="Europe/Moscow","Regional settings did not apply");
                helper.go(2);
                until(()=>ServiceDisplay.loaded&&find("helperDisplay")&&find("helperDisplay").selected==="A","Display controls did not load");
                const resolution=find("displayResolution"),scale=find("displayScale");
                check(resolution.options.length===2,"Display resolutions are missing");
                scale.edited(1.25);until(()=>!ServiceDisplay.busy,"Scale did not save");
                check(Config.displays.A.scale===1.25,"Scale was not retained");
                resolution.selected("1280x720");until(()=>ServiceDisplay.confirming&&find("displayConfirmation").opened,"Display confirmation is missing");
                find("displayConfirmation").accepted();until(()=>!ServiceDisplay.busy,"Resolution did not save");
                resolution.selected("1920x1080");until(()=>ServiceDisplay.confirming,"Resolution was not staged");
                helper.go(0);check(!ServiceDisplay.confirming&&Config.displays.A.mode==="1280x720@60.000","Leaving Display committed an unconfirmed change");
                helper.go(3);wait(50);
                const theme=find("helperTheme");theme.forceActiveFocus();
                keyClick(Qt.Key_Home);check(Config.themeStyle===Enums.ThemeLight&&helper.currentPage===3,"Theme key navigated the wizard");
                keyClick(Qt.Key_End);check(Config.themeStyle===Enums.ThemeAuto && theme.current===Enums.ThemeAuto,"Auto theme did not save or stay selected");
                keyClick(Qt.Key_Left);check(Config.themeStyle===Enums.ThemeDark,"Dark theme did not save");
                const accent=Config.themeAccent;click(find("helperAccent"));check(Config.themeAccent!==accent,"Automatic color did not save");
                for(const mode of [0,1,2]) {find("helperAnimations").selected(mode);check(Config.themeAnimations===mode,"Animation segment did not save");}
                Config.set("themeAnimations",0);helper.go(4);
                for(const prefix of ["bar","dock"]) {
                    const enabled=find("helper-"+prefix+"-enabled"),position=find("helper-"+prefix+"-position");
                    reveal(enabled);click(enabled);check(!Config[prefix+"Enabled"]&&!position.enabled,"Disabled layout keeps its position enabled");
                    click(enabled);position.selected(prefix==="bar"?Enums.EdgeRight:Enums.EdgeLeft);
                    check(Config[prefix+"Enabled"]&&Config[prefix+"Side"]===(prefix==="bar"?Enums.EdgeRight:Enums.EdgeLeft),"Layout controls did not apply");
                }
                check(!find("helper-bar-style-0"),"Layout still offers style previews");
                ServiceRegion.setTimezone("Europe/London");helper.go(5);
                check(helper.saving&&!find("helperNext").enabled,"Ready ignores pending saves");
                helper.advance();check(window.finishes===0,"Ready closed before settings saved");
                until(()=>!helper.saving,"Region stayed busy");
                check(!find("helperBarSummary")&&!find("helperMouseSummary"),"Ready contains old summaries");
                Config.set("themeAnimations",2);helper.go(3);check(helper.pageReveal<1,"Page change has no animation");
                Config.set("themeAnimations",0);check(helper.pageReveal===1,"Disabling animations leaves a partial fade");
                for(const scenario of [{w:800,h:640,language:"en",theme:1,animation:2},{w:520,h:480,language:"ru",theme:0,animation:1},{w:360,h:420,language:"ru",theme:1,animation:0}]) {
                    window.width=scenario.w;window.height=scenario.h;
                    Config.set("shellLanguage",scenario.language);Config.set("themeStyle",scenario.theme);Config.set("themeAnimations",scenario.animation);
                    for(let page=0;page<6;page++){helper.go(page);wait(Theme.animationDurationControl+50);inspect();}
                }
                helper.go(4);wait(50);const view=find("helperContentScroll");
                Config.set("scrollSpeed",1);view.contentY=0;mouseWheel(view,view.width/2,view.height/2,0,-120,Qt.NoButton,Qt.NoModifier,0);
                check(view.contentY>0,"Compact layout cannot scroll");const normal=view.contentY;
                Config.set("scrollSpeed",3);view.contentY=0;mouseWheel(view,view.width/2,view.height/2,0,-120,Qt.NoButton,Qt.NoModifier,0);
                check(view.contentY>normal,"Helper ignores scroll speed");
                helper.go(3);wait(100);check(view.contentY===0,"Old scroll offset survives navigation");
                helper.forceActiveFocus();keyClick(Qt.Key_Home);check(helper.currentPage===0,"Home navigation failed");
                keyClick(Qt.Key_End);check(helper.currentPage===5,"End navigation failed");
                keyClick(Qt.Key_Left);check(helper.currentPage===4,"Left navigation failed");
                find("helperStep-3").forceActiveFocus();keyClick(Qt.Key_Space);check(helper.currentPage===3,"Step keyboard activation failed");
                helper.forceActiveFocus();keyClick(Qt.Key_Return);keyClick(Qt.Key_Return);keyClick(Qt.Key_Return);
                check(window.finishes===1,"Finish did not close exactly once");
                click(find("helperClose"));keyClick(Qt.Key_Escape);check(window.finishes===3,"Close or Escape did not finish");
                check(ServiceDevices.mouseWatchers===0&&ServiceDevices.watchers===0,"Helper starts unrelated device watchers");
                window.width=800;window.height=640;Config.set("shellLanguage","en");helper.go(0);wait(150);
                capture("/tmp/bloodyShell-helper-welcome.png");
                helper.go(5);wait(100);capture("/tmp/bloodyShell-helper-ready.png");
                helper.go(1);wait(100);capture("/tmp/bloodyShell-helper-preview.png");
                console.log("HELPER_UI_PASSED six steps, dropdown placement/selection/cleanup, visual welcome/ready, regional controls, display recovery, segmented appearance, layout toggles, save guards, keyboard navigation and compact/localized layouts");Qt.quit();
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
        assert saved["barSide"] == 3 and saved["barType"] == 0 and saved["dockSide"] == 2 and saved["dockType"] == 0
        stored_input = input_file.read_text()
        assert 'layout "us"' in stored_input and 'compose:menu' in stored_input
        assert 'horizontal=-2.1' in stored_input and 'vertical=1.0' in stored_input and 'touchpad { tap; }' in stored_input


if __name__ == "__main__":
    run_checks()
    ui_checks()
