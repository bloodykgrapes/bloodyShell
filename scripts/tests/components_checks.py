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
                const entry=Registry.settings.findIndex(page=>page.id==="components");
                check(entry>=0,"Components page is missing");
                OverlayState.settingsPage=entry; OverlayState.show("settings");
                until(()=>overlay.testPage.item && findChild(overlay.testPage.item,"loginWallpaperPreview") && ServiceGreeter.installed && !ServiceGreeter.wallpaperBusy,"Components did not load login settings");
                const original=overlay.testPage.item;
                const screenshots=findChild(original,"screenshotOptions"), login=findChild(original,"loginOptions");
                screenshots.expanded=true; login.expanded=true; wait(20);
                const path=findChild(original,"screenshotsPath"), action=findChild(original,"screenshotsAction"), instant=findChild(original,"screenshotsInstantly");
                check(Config.screenshotsAction==="copy" && !Config.screenshotsInstantly,"Screenshot defaults are incorrect");
                check(path.text===Config.screenshotsDefault() && path.text.endsWith("/Screenshots"),"Screenshot field does not contain its default directory");
                path.text=""; path.editingFinished();
                check(path.text===Config.screenshotsDefault() && Config.screenshotsPath===path.text,"Clearing the screenshot field did not restore its default");
                path.text="~/Pictures/My captures"; path.editingFinished(); action.selected("save"); instant.toggled(true);
                check(Config.screenshotsPath==="~/Pictures/My captures" && Config.screenshotsAction==="save" && Config.screenshotsInstantly,"Screenshot settings did not apply");
                Config.set("screenshotsAction","invalid"); Config.set("screenshotsPath","relative/path");
                check(Config.screenshotsAction==="save" && Config.screenshotsPath==="~/Pictures/My captures","Invalid screenshot defaults were accepted");
                const preview=findChild(original,"loginWallpaperPreview"), desktop=Config.wallpaperCurrent;
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
                check(overlay.testPage.item===original && screenshots.expanded && login.expanded,"Components state was lost");
                console.log("COMPONENTS_PASSED screenshot defaults, validation, shared login picker, desktop independence, cancellation, retry and preserved settings"); Qt.quit();
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


if __name__ == "__main__":
    checks()
