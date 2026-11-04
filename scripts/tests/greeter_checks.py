#!/usr/bin/env python3

import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def run(base, qml, env):
    (base / "shell.qml").write_text(qml)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=8)
    text = result.stdout + result.stderr
    print(text)
    assert result.returncode == 0 and "GREETER_PASSED" in text, text
    assert not any(message in text for message in ("GREETER_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign"))


def checks():
    api = runpy.run_path(str(ROOT / "greeter/session-data"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-greeter-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "state", "sessions"):
            (base / name).mkdir(mode=0o700)
        shutil.copytree(ROOT / "greeter", base / "greeter")
        export = runpy.run_path(str(ROOT / "greeter/export-settings"))["export"]
        wallpaper = base / "wallpaper with spaces.png"
        wallpaper.write_bytes(b"test")
        source = base / "source.json"
        source.write_text(json.dumps(dict(themeStyle=0, shellLanguage="ru", wallpaperCurrent=str(wallpaper), privateValue="not exported", themeAnimations=2, themeAccent=True, barWidgetClock24=False)))
        export(source, base / "state")
        data = json.loads((base / "state/settings.json").read_text())
        assert "privateValue" not in data and Path(data["wallpaperCurrent"]).read_bytes() == b"test"
        assert data["animationLevel"] == 2 and data["accentShell"] and not data["widgetClock24"]
        source.write_text('{"themeStyle": 1}')
        export(source, base / "state")
        assert "wallpaperCurrent" not in json.loads((base / "state/settings.json").read_text())
        session = base / "sessions/test.desktop"
        session.write_text('[Desktop Entry]\nName=Niri\nExec=niri-session "argument with spaces"\nDesktopNames=niri;\n')
        with patch("shutil.which", return_value="/usr/bin/test"):
            found = api["sessions"](base / "sessions")
            assert found[0]["command"] == ["niri-session", "argument with spaces"]
            session.write_text("[Desktop Entry]\nName=Hidden\nHidden=true\nExec=niri-session\n")
            assert not any(item["name"] == "Hidden" for item in api["sessions"](base / "sessions"))

        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), BLOODYSHELL_CONFIG=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        env.pop("GREETD_SOCK", None)
        env.pop("BLOODYSHELL_GREETER_PREVIEW", None)
        original = (base / "greeter/shell.qml").read_text()
        original = original.replace('import QtQuick\n', 'import QtQuick\nimport "greeter"\n', 1).replace('Qt.resolvedUrl("session-data")', 'Qt.resolvedUrl("greeter/session-data")')
        auth = original[:original.index("    FloatingWindow")].replace('property var authenticator: Greetd', 'property var authenticator: fake')
        fake = '''
    QtObject {
        id: fake
        property bool available: true
        property int state: 0
        property var replies: []
        property var launched: []
        signal authMessage(string message, bool error, bool responseRequired, bool echoResponse)
        signal authFailure(string message)
        signal error(string error)
        signal readyToLaunch()
        function createSession(user) { state=1; }
        function respond(value) { replies=replies.concat([value]); }
        function cancelSession() { state=0; }
        function launch(command, environment, quit) { launched=command; }
    }
    function check(ok, message) { if(!ok) throw new Error(message); }
    Timer {interval:100;running:true;onTriggered:{
        try {
            Theme.animationLevel=0;
            root.users=[{name:"tester",fullName:"Tester",home:"/nonexistent"}];
            root.sessions=[{id:"niri",name:"Niri",desktop:"niri",command:["niri-session","argument with spaces","quote'argument"]}];
            root.submit("test-secret");
            check(root.busy && root.pending==="test-secret","begin");
            fake.authMessage("Password:",false,true,false);
            check(root.pending==="" && fake.replies[0]==="test-secret","password clearing");
            fake.authMessage("Verification code:",false,true,true);
            check(root.awaitingResponse && !root.busy && root.echoResponse,"second prompt");
            root.submit("123456");
            check(fake.replies[1]==="123456","second response");
            root.sessionIndex=4;
            fake.readyToLaunch();
            verify.start();
        } catch(error) {console.error("GREETER_FAILED "+error);Qt.quit();}
    }}
    Timer {id:verify;interval:50;onTriggered:{
        try {
            check(fake.launched.includes("'argument with spaces'"),"argument quoting");
            check(root.leaving,"launch");
            fake.authFailure("Rejected");
            check(!root.busy && !root.authenticating && root.failed && !root.pending,"failure reset");
            fake.state=0;
            root.submit("retry-secret");
            root.cancelAuthentication();
            check(!root.authenticating && fake.state===0 && !root.pending,"cancel");
            fake.available=false;
            root.submit("preview");
            check(!root.authenticating && !root.busy,"preview must not authenticate");
            console.log("GREETER_PASSED authentication");
        }catch(error){console.error("GREETER_FAILED "+error);}
        Qt.quit();
    }}
}'''
        run(base, auth + fake, env)
        env["BLOODYSHELL_GREETER_PREVIEW"] = "1"
        preview = original.replace("import QtQuick\n", "import QtQuick\nimport QtQuick.Window\n", 1)
        preview = preview.replace("    FloatingWindow\n    {", "    Window\n    {\n        id: previewWindow\n        visible: true", 1)
        preview = preview.replace("        fullscreen: !root.preview\n", "").replace("implicitWidth: 1280", "width: 1280").replace("implicitHeight: 800", "height: 800")
        preview = preview.rstrip()[:-1] + '''
    Timer {interval:1500;running:true;onTriggered:previewWindow.contentItem.grabToImage(result=>{
        result.saveToFile("/tmp/bloodyshell-greeter-preview.png");console.log("GREETER_PASSED preview");Qt.quit();
    })}
}
'''
        run(base, preview, env)
    print("Replacement greeter authentication, prompt handling, session quoting, export, and UI checks passed.")


if __name__ == "__main__":
    checks()
