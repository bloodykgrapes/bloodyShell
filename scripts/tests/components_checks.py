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
    screenshot = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-components-") as temporary:
        base = Path(temporary)
        env = screenshot["prepare"](base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "home").mkdir()
        env["HOME"] = str(base / "home")
        state = base / "login"
        state.mkdir()
        (state / "theme.conf").write_text("[General]\nanimationLevel=1\n")
        (state / ".appearance.lock").touch()
        wallpapers = base / "wallpapers"
        wallpapers.mkdir()
        for name in ("a.png", "b.png"):
            (wallpapers / name).write_bytes(screenshot["png"](100 if name == "a.png" else 120, 80))
        (wallpapers / "video.mp4").write_bytes(b"video excluded from login picker")
        (base / "deny-terminal").write_text("no")
        terminal = base / "bin/kitty"
        terminal.write_text("#!/usr/bin/env python3\nimport os, sys\nfrom pathlib import Path\n"
                            "base = Path(os.environ['TEST_SCREENSHOT_BASE'])\n"
                            "if (base / 'deny-terminal').read_text() == 'yes': sys.exit(0)\n"
                            "os.execvp(sys.argv[1], sys.argv[1:])\n")
        terminal.chmod(0o755)
        resource = base / "scripts/lib/resources.py"
        resource.write_text(resource.read_text().replace('GREETER_STATE = Path("/var/lib/bloodyShell")', 'GREETER_STATE = Path(' + repr(str(state)) + ')').replace('writable=os.access(directory, os.W_OK)', 'writable=False'))
        service = base / "modules/services/ServiceGreeter.qml"
        service.write_text(service.read_text().replace('"/var/lib/bloodyShell"', json.dumps(str(state))))
        themes = base / "boot splash"
        for name in ("current", "aurora"):
            folder = themes / name
            folder.mkdir(parents=True)
            module = "details" if name == "current" else "script"
            (folder / (name + ".plymouth")).write_text(f"[Plymouth Theme]\nName={name.title()}\nModuleName={module}\n")
        (themes / "aurora/preview.png").write_bytes(screenshot["png"](160, 90))
        (base / "boot-theme").write_text("current")
        selector = base / "bin/plymouth-set-default-theme"
        selector.write_text('#!/bin/sh\ncase "$1" in\n'
                            '  --list) printf "current\\naurora\\n";;\n'
                            '  --rebuild-initrd)\n'
                            '    printf "%s" "$2" > "$TEST_SCREENSHOT_BASE/boot-theme"\n'
                            '    if [ "$(cat "$TEST_SCREENSHOT_BASE/deny-terminal")" = rebuild ]; then\n'
                            '      echo "Rebuild failed" >&2; exit 1\n'
                            '    fi;;\n'
                            '  "") cat "$TEST_SCREENSHOT_BASE/boot-theme";;\n'
                            '  *) exit 1;;\nesac\n')
        auth = base / "bin/pkexec"
        auth.write_text('#!/bin/sh\n[ "$(cat "$TEST_SCREENSHOT_BASE/deny-terminal")" != yes ] || { echo "Authorization denied" >&2; exit 126; }\nexec "$@"\n')
        for binary in (selector, auth):
            binary.chmod(0o755)
        plymouth = base / "scripts/lib/plymouth.py"
        plymouth.write_text(plymouth.read_text().replace('Path("/usr/share/plymouth/themes")', f'Path({str(themes)!r})')
                            .replace('("/usr/bin", "/usr/sbin", "/bin", "/sbin")', f'({str(base / "bin")!r},)'))
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0,
            wallpaperDirectory=str(wallpapers), wallpaperCurrent=str(wallpapers / "a.png"))))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
import "modules/ui/overlay"

ShellRoot {
    FileView { id: deny; path: Quickshell.env("TEST_SCREENSHOT_BASE") + "/deny-terminal"; blockWrites: true }
    FileView { id: configuredTheme; path: Quickshell.env("TEST_SCREENSHOT_BASE") + "/boot-theme"; blockLoading: true; blockWrites: true }
    Window {
        id: window; visible:true; width:1024; height:768
        OverlayFixture { id: overlay; anchors.fill:parent }
        TestCase {
            id: events; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<400 && !predicate();i++) wait(10); check(predicate(),message); }
            function picker() { const layer=findChild(overlay,"stackedOverlayPage"); return layer && layer.item ? findChild(layer.item,"wallpapersContent") : null; }
            function exercise() {
                until(()=>Config.initialized,"Settings did not load");
                OverlayState.show("settings");
                function selectPage(id, control) {
                    const index=Registry.settings.findIndex(page=>page.id===id);
                    check(index>=0,"Missing settings page "+id);
                    OverlayState.settingsPage=index;
                    until(()=>overlay.testPage.item && findChild(overlay.testPage.item,control),"Page did not load: "+id);
                    return findChild(overlay.testPage.item,control);
                }
                const keyboard=selectPage("devices", "virtualKeyboardOptions");
                const mode=findChild(keyboard,"virtualKeyboardMode");
                check(keyboard && mode && mode.options.length===2,"Virtual keyboard does not have a segmented mode row");
                keyboard.expanded=true;
                mode.selected(false);
                check(!Config.virtualKeyboardEnabled,"Disabled mode did not save");
                const visualizer=selectPage("desktop", "visualizerOptions");
                check(visualizer && visualizer.title===Tr.tr("settings.components.visualizer"),"Visualizer foldout is missing");
                visualizer.expanded=true;
                findChild(visualizer,"equalizerStyle-"+Enums.EqualizerWaves).clicked();
                findChild(visualizer,"visualizerOpacity").moved(0.4);
                check(Config.equalizerStyle===Enums.EqualizerWaves && Config.desktopEqualizerOpacity===0.4,"Visualizer controls did not save");
                const boot=selectPage("login", "plymouthSection");
                until(()=>ServiceGreeter.installed && !ServiceGreeter.wallpaperBusy,"Login settings did not load");
                boot.expanded=true;
                until(()=>!ServicePlymouth.busy && findChild(boot,"plymouthTheme-aurora"),"Plymouth theme cards did not load");
                const currentTheme=findChild(boot,"plymouthTheme-current"), aurora=findChild(boot,"plymouthTheme-aurora");
                const applyBoot=findChild(aurora.parent,"applyPlymouthTheme");
                const currentMark=findChild(currentTheme,"plymouthCurrentTheme"), auroraMark=findChild(aurora,"plymouthCurrentTheme");
                check(currentTheme.selected && !aurora.selected && !applyBoot.visible,"Current boot theme was not selected");
                check(currentMark.visible && !auroraMark.visible,"Current theme was not marked");
                check(findChild(currentTheme,"plymouthPreview").textTheme,"A text-only Plymouth theme did not get a preview");
                until(()=>findChild(aurora,"plymouthThemeImage").status===Image.Ready,"Plymouth preview did not load before selection");
                const art=findChild(aurora,"plymouthPreview"), title=findChild(aurora,"plymouthThemeTitle");
                check(art.height>0 && title.label==="Aurora" && title.mapToItem(aurora,0,0).y>=art.mapToItem(aurora,0,art.height).y,"Theme title is not below its preview");
                let viewport=aurora.parent;
                while(viewport && typeof viewport.revealItem!=="function") viewport=viewport.parent;
                check(viewport!==null,"Plymouth cards are outside the settings viewport");
                window.height=540; wait(30);
                check(applyBoot.mapToItem(viewport,0,0).y+applyBoot.height>viewport.height,"Apply fixture is already in view");
                aurora.clicked();
                check(aurora.selected && !currentTheme.selected && ServicePlymouth.state.current==="current" && applyBoot.visible && applyBoot.enabled,"Theme card did not show its Apply button");
                check(currentMark.visible && !auroraMark.visible,"Pending selection moved the current theme mark");
                until(()=>{
                    const top=applyBoot.mapToItem(viewport,0,0).y;
                    return top>=viewport.headerHeight && top+applyBoot.height<=viewport.height;
                },"Apply button was clipped after selection");
                deny.setText("yes"); deny.waitForJob(); mouseClick(applyBoot,applyBoot.width/2,applyBoot.height/2);
                until(()=>!ServicePlymouth.busy && ServicePlymouth.applyError==="Authorization denied","Plymouth authorization failure was hidden");
                check(currentMark.visible && !auroraMark.visible,"Authorization failure moved the current theme mark");
                deny.setText("rebuild"); deny.waitForJob(); applyBoot.clicked();
                until(()=>!ServicePlymouth.busy && ServicePlymouth.state.current==="aurora" && ServicePlymouth.applyError==="Rebuild failed","Plymouth did not refresh the configured theme after a rebuild failure");
                check(auroraMark.visible && applyBoot.visible,"Configured theme lost its mark or retry after a rebuild failure");
                deny.setText("no"); deny.waitForJob(); applyBoot.clicked();
                until(()=>!ServicePlymouth.busy && ServicePlymouth.applied,"Plymouth theme did not apply");
                check(aurora.selected && auroraMark.visible && !applyBoot.visible,"Applied Plymouth theme did not become current");
                configuredTheme.reload(); configuredTheme.waitForJob();
                check(configuredTheme.text()==="aurora","Theme fixture did not persist the applied theme");
                configuredTheme.setText("current"); configuredTheme.waitForJob(); ServicePlymouth.refresh();
                until(()=>!ServicePlymouth.busy && ServicePlymouth.state.current==="current","External theme change was not detected");
                check(currentTheme.selected && currentMark.visible && !aurora.selected && !auroraMark.visible && !applyBoot.visible,"Picker kept a stale selection after an external change");
                configuredTheme.setText("missing"); configuredTheme.waitForJob(); ServicePlymouth.refresh();
                until(()=>!ServicePlymouth.busy && ServicePlymouth.state.current==="missing","Unavailable configured theme was not detected");
                check(!currentTheme.selected && !currentMark.visible && !aurora.selected && !auroraMark.visible,"Picker marked a fallback theme as current");
                window.height=768;
                boot.expanded=false;
                const screenshots=selectPage("capture","screenshotOptions");
                screenshots.expanded=true; wait(20);
                const path=findChild(screenshots,"screenshotsPath"), action=findChild(screenshots,"screenshotsAction"), instant=findChild(screenshots,"screenshotsInstantly");
                check(Config.screenshotsAction==="copy" && !Config.screenshotsInstantly,"Screenshot defaults are incorrect");
                check(path.text===Config.screenshotsDefault() && path.text.endsWith("/Screenshots"),"Screenshot field does not contain its default directory");
                path.text=""; path.editingFinished();
                check(path.text===Config.screenshotsDefault() && Config.screenshotsPath===path.text,"Clearing the screenshot field did not restore its default");
                path.text="~/Pictures/My captures"; path.editingFinished(); action.selected("save"); instant.toggled(true);
                check(Config.screenshotsPath==="~/Pictures/My captures" && Config.screenshotsAction==="save" && Config.screenshotsInstantly,"Screenshot settings did not apply");
                Config.set("screenshotsAction","invalid"); Config.set("screenshotsPath","relative/path");
                check(Config.screenshotsAction==="save" && Config.screenshotsPath==="~/Pictures/My captures","Invalid screenshot defaults were accepted");
                const login=selectPage("login","loginOptions");
                login.expanded=true; wait(30);
                const original=overlay.testPage.item;
                const preview=findChild(login,"loginWallpaperPreview"), desktop=Config.wallpaperCurrent;
                preview.clicked();
                until(()=>picker() && !picker().loading && picker().images.length===2,"Login picker did not exclude videos");
                check(picker().loginWallpaper && OverlayState.wallpaperTarget==="login","Picker is not targeting the login screen");
                const selected=picker().images[1]; picker().apply(1);
                until(()=>OverlayState.current==="settings" && OverlayState.stacked==="" && !ServiceGreeter.wallpaperBusy,"Login wallpaper did not apply and return to settings: "+ServiceGreeter.wallpaperError);
                check(ServiceGreeter.selection===selected && Config.wallpaperCurrent===desktop && overlay.testPage.item===original,"Changing login wallpaper changed desktop settings or replaced the page");
                Config.set("wallpaperCurrent",selected); wait(1100);
                ServiceGreeter.refresh(); until(()=>!ServiceGreeter.wallpaperBusy,"Login refresh did not finish");
                check(ServiceGreeter.selection===selected,"Automatic appearance sharing replaced login wallpaper");
                preview.clicked(); until(()=>picker() && !picker().loading,"Second picker did not open");
                deny.setText("yes"); deny.waitForJob(); picker().apply(0);
                until(()=>!ServiceGreeter.wallpaperBusy && ServiceGreeter.wallpaperError!=="","Cancelled terminal was falsely reported as success");
                check(OverlayState.current==="wallpapers" && ServiceGreeter.selection===selected,"Cancelled apply changed login wallpaper or closed the picker");
                deny.setText("no"); deny.waitForJob(); ServiceGreeter.writable=true; picker().apply(0);
                until(()=>OverlayState.current==="settings" && OverlayState.stacked==="","Login wallpaper retry failed");
                check(Config.wallpaperCurrent===selected && ServiceGreeter.selection.endsWith("a.png"),"Retry changed the desktop wallpaper");
                check(overlay.testPage.item===original && login.expanded,"Components state was lost");
                console.log("COMPONENTS_PASSED Plymouth preview, authorization and apply, screenshot defaults, and shared login wallpaper"); Qt.quit();
            }
        }
        Timer { interval:100; running:true; onTriggered:{try{events.exercise();}catch(error){console.error("COMPONENTS_FAILED",error);Qt.quit();}} }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "COMPONENTS_PASSED" in output, output
        assert not re.search(r"COMPONENTS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), output
        api = runpy.run_path(str(resource))
        status = api["greeter_wallpaper_status"](state, str(wallpapers / "a.png"))
        assert status["matches"] and Path(status["wallpaper"]).read_bytes() == (wallpapers / "a.png").read_bytes()
        assert len(list(state.glob("wallpaper-*"))) == 1, "Login wallpaper replacement leaked files"


def time_language_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-time-language-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "home").mkdir()
        env["HOME"] = str(base / "home")
        (base / "modules/services/ServiceKeyboard.qml").write_text('''pragma Singleton
import Quickshell
Singleton {
    property bool busy: false
    property string error: ""
    property string switchOption: ""
    property var layouts: [{layout:"us",variant:""}]
    property var catalog: [{code:"us",name:"English"},{code:"ru",name:"Russian"}]
    property var variants: ({ru:[{code:"phonetic",name:"Phonetic"}]})
    function refresh() {}
    function title(entry) { return entry.layout; }
    function set(key,value) { this[key]=value; }
    function addLayout(layout,variant) { layouts=layouts.concat([{layout:layout,variant:variant}]); }
    function moveLayout(index,delta) {}
    function removeLayout(index) {}
}
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
ShellRoot {
    Window { id: window; visible:true; width:720; height:760; PageTimeLanguage {id: page;anchors.fill:parent} }
    TestCase {
        id: events; when:false; optional:true
        function check(ok,message) { if(!ok) throw new Error(message); }
        function exercise() {
            const language=findChild(page,"languageSettings"), dateTime=findChild(page,"dateTimeSettings"), keyboard=findChild(page,"keyboardSettings");
            check(language.y<dateTime.y && dateTime.y<keyboard.y,"Time and Language groups are out of order");
            const popup=findChild(page,"keyboardLayoutPicker"), add=findChild(page,"addKeyboardLayout");
            const layout=findChild(popup,"newKeyboardLayout"), variant=findChild(popup,"newKeyboardVariant"), confirm=findChild(popup,"confirmKeyboardLayout");
            add.clicked(); wait(50);
            check(popup.opened && !confirm.enabled,"Layout picker did not open with an empty selection");
            layout.selected("ru");variant.selected("phonetic");
            check(confirm.enabled,"Valid layout cannot be added");confirm.clicked();wait(100);
            check(!popup.visible && ServiceKeyboard.layouts.length===2 && ServiceKeyboard.layouts[1].variant==="phonetic","Layout and variant did not save");
            add.clicked();wait(50);
            check(popup.layout==="" && popup.variant==="","Reopening the picker kept an unfinished selection");
            layout.selected("ru");variant.selected("phonetic");check(!confirm.enabled,"Duplicate layout can be added");
            popup.close();wait(100);
            add.clicked();wait(50);layout.selected("us");
            check(!confirm.enabled,"Existing default layout can be added twice");
            popup.close();wait(100);
            check(ServiceKeyboard.layouts.length===2,"Cancelling changed the layout list");
            window.width=400;add.clicked();wait(50);
            check(popup.width<=window.width-32 && popup.height<window.height,"Layout picker does not fit a compact window");
            page.visible=false;wait(100);check(!popup.visible,"Leaving the page kept the picker open");
            console.log("TIME_LANGUAGE_PASSED ordering, add popup, variants, duplicates, cancellation, compact size and page cleanup");Qt.quit();
        }
    }
    Timer {interval:200;running:Config.initialized;onTriggered:{try{events.exercise();}catch(error){console.error("TIME_LANGUAGE_FAILED",error);Qt.quit();}}}
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "TIME_LANGUAGE_PASSED" in output, output
        assert not re.search(r"TIME_LANGUAGE_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output
        print("Time and Language grouping and layout popup checks passed without system changes.")


if __name__ == "__main__":
    checks()
    time_language_checks()
