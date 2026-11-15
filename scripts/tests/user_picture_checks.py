#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    screenshot = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-user-picture-") as temporary:
        base = Path(temporary)
        env = screenshot["prepare"](base)
        env.pop("WAYLAND_DISPLAY", None)
        home = base / "home"
        home.mkdir()
        env.update(HOME=str(home), USER="avatar-test")
        original = screenshot["png"](100, 80)
        chosen = screenshot["png"](120, 90)
        (home / ".face").write_bytes(original)
        for name in ("new.png", "special #21%.png", "Angel & Aki - matching #.jpg", "new.jfif"):
            (home / name).write_bytes(chosen)
        (base / "passwd").write_text(f"avatar-test:x:1000:1000:Tester:{home}:/bin/bash\n")
        (base / "group").write_text("users:x:1000:\n")
        (base / "shells").write_text("/bin/bash\n")
        service = base / "modules/services/ServiceUser.qml"
        source = service.read_text()
        for name in ("passwd", "group", "shells"):
            source = source.replace('"/etc/' + name + '"', json.dumps(str(base / name)))
        service.write_text(source)
        (base / "modules/services/ServiceGreeter.qml").write_text("pragma Singleton\nimport Quickshell\nSingleton {}\n")
        for name, body in (("id", "echo users"), ("pkexec", "exit 126"), ("usermod", "exit 1")):
            command = base / "bin" / name
            command.write_text("#!/bin/sh\n" + body + "\n")
            command.chmod(0o755)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay"

ShellRoot {
    Window {
        id: window; visible:true; width:1024; height:768
        OverlayFixture { id: overlay; anchors.fill:parent }
        TestCase {
            id: events; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<250 && !predicate();i++) wait(10); check(predicate(),message); }
            function pick(choose,dialog,name,cancel) {
                wait(250);
                mouseClick(choose,choose.width/2,choose.height/2);
                until(()=>dialog.visible,"Picture picker did not open");
                const list=findChild(window.contentItem,"fileDialogListView");
                until(()=>list && list.count===4,"Image filter excluded a supported picture");
                let item=null;
                until(()=>{
                    for(let i=0;i<list.count;i++) {
                        const candidate=list.itemAtIndex(i);
                        if(candidate && candidate.fileName===name) { item=candidate; return true; }
                    }
                    return false;
                },"Picture is missing from the picker: "+name);
                if(cancel) { mouseClick(item,item.width/2,item.height/2); dialog.reject(); }
                else mouseDoubleClickSequence(item,item.width/2,item.height/2);
                until(()=>!dialog.visible,"Picker did not accept the selected image");
            }
            function exercise() {
                until(()=>Config.initialized && ServiceUser.loaded && !ServiceUser.busy,"User account did not load");
                OverlayState.settingsPage=Registry.settings.findIndex(page=>page.id==="user"); OverlayState.show("settings");
                until(()=>overlay.testPage.item && findChild(overlay.testPage.item,"chooseUserPicture"),"User page did not load");
                const page=overlay.testPage.item, choose=findChild(page,"chooseUserPicture"), dialog=findChild(page,"userPictureDialog"), face=findChild(page,"userPicturePreview");
                const original=ServiceUser.avatar;
                pick(choose,dialog,"new.png",true);
                check(!ServiceUser.hasChanges && ServiceUser.avatar===original,"Cancelling the picker changed the picture");
                for(const name of ["new.png","special #21%.png","Angel & Aki - matching #.jpg","new.jfif"]) {
                    ServiceUser.resetDraft(); pick(choose,dialog,name,false);
                    until(()=>face.status===Image.Ready && face.sourceSize.width>0,"Selected image preview could not load: "+name);
                    check(ServiceUser.avatarPreview===Quickshell.env("HOME")+"/"+name && ServiceUser.hasChanges && ServiceUser.error==="","Selecting a picture did not update the draft: "+name);
                    check(ServiceUser.avatar===original && !ServiceUser.applying,"Choosing a picture saved it without confirmation");
                }
                const apply=findChild(page,"applyUserChanges"); apply.clicked();
                const confirmation=findChild(page,"accountConfirmation");
                until(()=>confirmation.opened,"Apply did not open confirmation");
                check(ServiceUser.confirmationChanges.length===1,"Picture-only change included account edits");
                const accept=findChild(confirmation.contentItem,"acceptConfirmation");
                mouseClick(accept,accept.width/2,accept.height/2);
                until(()=>!ServiceUser.busy && !ServiceUser.hasChanges && ServiceUser.draft.avatarAction==="keep","Selected picture did not save and refresh: "+ServiceUser.error);
                until(()=>face.status===Image.Ready,"Saved profile picture did not render");
                check(ServiceUser.avatar===Quickshell.env("HOME")+"/.face","Saved avatar path is incorrect");
                console.log("USER_PICTURE_PASSED real picker selection, cancellation, JFIF, encoded filenames, previews and confirmed saving"); Qt.quit();
            }
        }
        Timer { interval:100; running:true; onTriggered:{try{events.exercise();}catch(error){console.error("USER_PICTURE_FAILED",error);Qt.quit();}} }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "USER_PICTURE_PASSED" in output, output
        assert not re.search(r"USER_PICTURE_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Cannot open:", output), output
        assert (home / ".face").read_bytes() == chosen, "Confirmed picture was not saved"


if __name__ == "__main__":
    checks()
