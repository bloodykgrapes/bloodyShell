#!/usr/bin/env python3

import json
import os
from pathlib import Path
import runpy
import re
import shutil
import shlex
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def startup_import_checks():
    """Compile the real startup dependency graph without instantiating services."""
    with tempfile.TemporaryDirectory(prefix="bloodyShell-startup-imports-") as temporary:
        base = Path(temporary)
        for name in ("runtime", "cache", "config", "state"):
            (base / name).mkdir(mode=0o700)
        for name in ("modules", "assets", "scripts", "translations"):
            (base / name).symlink_to(ROOT / name, target_is_directory=True)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "modules/common" as Common
import "modules/ui/desktop" as Desktop
ShellRoot {
    Component { id: probe; Common.Equalizer {} }
    Component { Desktop.WallpaperLayer { outputName: "" } }
    Timer { interval:10; running:true; onTriggered: { console.log("STARTUP_IMPORTS_PASSED",probe.status); Qt.quit(); } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=8)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "STARTUP_IMPORTS_PASSED 1" in output, output


def native_ui_checks(check_protocol=True):
    with tempfile.TemporaryDirectory(prefix="bloodyShell-virtual-keyboard-") as temporary:
        base = Path(temporary)
        (base / "runtime").mkdir(mode=0o700)
        env = dict(os.environ, XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        env.pop("WAYLAND_DISPLAY", None)
        command = ["python3", str(ROOT / "scripts/bloodyShell"), "internal", "build-virtual-keyboard"]
        url = subprocess.check_output(command, env=env, text=True).strip()
        assert subprocess.check_output(command, env=env, text=True).strip() == url
        rebuilt = base / "rebuilt"
        shutil.copytree(ROOT / "modules/src/virtualKeyboard", rebuilt / "modules/src/virtualKeyboard")
        builder = rebuilt / "scripts/lib/processes.py"
        builder.parent.mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/lib/processes.py", builder)
        source = rebuilt / "modules/src/virtualKeyboard/VirtualKeyboard.cpp"
        source.write_text(source.read_text() + "\n// Simulate a rebuilt keyboard plugin during a shell reload.\n")
        rebuilt_url = subprocess.check_output(["python3", "-c", "import runpy; runpy.run_path(" + repr(str(builder)) + ")['virtual_keyboard_main']()"], env=env, text=True).strip()
        assert rebuilt_url != url, "Native source change did not invalidate the build cache"
        (base / "keyboard").symlink_to(ROOT / "modules/common/keyboard", target_is_directory=True)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "keyboard"

ShellRoot {
    Window {
        id: window; visible: true; width: 920; height: 500; color: "#08080a"
        property int submissions: 0
        function check(ok, message) { if (!ok) throw new Error(message); }
        function find(item, name) {
            if (item.objectName === name) return item;
            for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
            return null;
        }
        TextInput {
            id: field; x: 40; y: 25; width: 840; height: 44; color: "white"; font.pixelSize: 22
            focus: true; inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            onAccepted: window.submissions++
        }
        Loader { id: native; source: ENGINE; onLoaded: { item.local = true; begin.start(); } }
        Loader { id: rebuilt; active: false; source: REBUILT_ENGINE }
        Keyboard {
            id: keyboard; x: 40; y: 110; width: 840; height: implicitHeight
            engine: native.item; animations: false
            layouts: [{layout:"us",variant:""},{layout:"ru",variant:""},{layout:"de",variant:""}]
            onLayoutSelected: index => layoutIndex = index
            onDismissed: visible = false
        }
        TestCase {
            id: input; when: false; optional: true
            function click(name) { wait(20); const key = window.find(keyboard, name); window.check(key !== null, "Missing " + name); mouseClick(key, key.width / 2, key.height / 2); wait(20); }
            function exercise() {
                window.requestActivate(); field.forceActiveFocus(); wait(30);
                const engine = native.item;
                window.check(engine.ready && engine.rows.length === 4, "Local keyboard not ready");
                const letter = window.find(keyboard, "virtualKey30"), hover = window.find(letter, "virtualKeyHover");
                for (const mode of [0,1,2]) {
                    keyboard.animations=mode>0; keyboard.fluid=mode===2;
                    mouseMove(window.contentItem,10,470); wait(180);
                    window.check(hover.opacity===0,"Hover stayed visible after leaving");
                    mouseMove(letter,letter.width/2,letter.height/2); wait(35);
                    window.check(mode===0 ? hover.opacity===1 : hover.opacity>0 && hover.opacity<1,"Hover did not fade in");
                    window.check(letter.color.a===1,"Hover made the key surface translucent");
                    wait(160); window.check(hover.opacity===1,"Hover fade did not finish");
                    mouseMove(window.contentItem,10,470); wait(35);
                    window.check(mode===0 ? hover.opacity===0 : hover.opacity>0 && hover.opacity<1,"Hover did not fade out");
                    mouseMove(letter,letter.width/2,letter.height/2); wait(180);
                    window.check(hover.opacity===1,"Reversing the hover fade left a stale highlight");
                }
                keyboard.animations=false;
                click("virtualKey30"); window.check(field.text === "a" && field.activeFocus, "Typing stole focus or failed");
                keyboard.shifted = true; click("virtualKey30"); window.check(field.text === "aA" && !keyboard.shifted, "One-shot Shift failed");
                keyboard.caps = true; click("virtualKey30"); keyboard.caps = false;
                window.check(field.text === "aAA", "Caps Lock failed");
                field.select(0, field.text.length); click("virtualKey16"); window.check(field.text === "q", "Selected text was not replaced");
                click("virtualKeyboardLayout"); click("virtualKey30"); window.check(field.text === "qф", "Russian layout mismatch");
                click("virtualKeyboardLayout"); window.check(engine.label(21,false,false) === "z", "German XKB positions ignored: " + engine.layout + "/" + keyboard.layoutIndex);
                click("virtualKeyboardSymbols"); click("virtualKey3Shift"); window.check(field.text.endsWith("@"), "Symbol page used wrong keymap");
                click("virtualKeyboardSymbols"); window.check(engine.layout === "de" && !engine.symbols, "Symbol mode lost layout");
                keyboard.layoutIndex = 0; engine.variant = "dvorak";
                window.check(engine.label(16,false,false) === "'", "XKB variants ignored"); engine.variant = "";
                field.text = "aaaaaaa"; field.cursorPosition = field.text.length;
                wait(30);
                const back = window.find(keyboard,"virtualKey14"); mousePress(back,back.width/2,back.height/2); wait(550); mouseRelease(back,back.width/2,back.height/2);
                window.check(field.text.length < 6, "Backspace did not repeat");
                const releasedLength = field.text.length; wait(120); window.check(field.text.length === releasedLength, "Repeat continued after release");
                click("virtualKey28"); window.check(window.submissions === 1,"Enter did not submit");
                field.text=""; engine.layout="fr"; engine.variant="";
                window.check(engine.tap(26) && field.text === "", "Dead key committed prematurely"); engine.tap(18);
                window.check(field.text === "ê", "Local dead-key composition failed: " + field.text);
                engine.layout="us";
                for (const width of [320,480,840]) {
                    keyboard.width=width; wait(30);
                    const allKeys=[];
                    function walk(item) { if (item.objectName && item.objectName.startsWith("virtualKey")) allKeys.push(item); for(const child of item.children || []) walk(child); }
                    walk(keyboard);
                    for(const key of allKeys) { const pos=key.mapToItem(keyboard,0,0); window.check(key.width>0 && pos.x>=0 && pos.x+key.width<=width+1, "Keyboard overflow at " + width); }
                }
                const loadedHeight=keyboard.implicitHeight;
                keyboard.engine=null; wait(30);
                window.check(!keyboard.hasLayout && keyboard.rows.length===0 && window.find(keyboard,"virtualKey14")===null,"Missing backend stretched action buttons across the rows");
                window.check(window.find(keyboard,"virtualKeyboardStatus").visible && keyboard.implicitHeight===loadedHeight,"Loading state was hidden or changed keyboard size");
                keyboard.status="Could not load the on-screen keyboard."; wait(20);
                window.check(window.find(keyboard,"virtualKeyboardStatus").children[0].text===keyboard.status,"Backend failure was hidden");
                keyboard.status="";
                rebuilt.active=true; tryCompare(rebuilt,"status",Loader.Ready,2000); rebuilt.item.local=true;
                keyboard.engine=rebuilt.item; keyboard.width=840; field.text=""; wait(30);
                window.check(keyboard.hasLayout && !window.find(keyboard,"virtualKeyboardStatus").visible,"Rebuilt plugin did not restore character keys");
                click("virtualKey30"); window.check(field.text==="a","Rebuilt plugin could not type alongside the previous loaded module");
                keyboard.width=840; field.text="bloodyShell"; wait(30);
                window.contentItem.grabToImage(result => result.saveToFile("/tmp/bloodyShell-keyboard-preview.png")); wait(80);
                keyboard.shifted=true; keyboard.caps=true; keyboard.visible=false;
                window.check(!keyboard.shifted && !keyboard.caps && !keyboard.symbols, "Hidden keyboard retained modifiers");
                engine.local=false; engine.connectDisplay(); window.check(!engine.ready && engine.error!=="", "Missing Wayland backend was not reported");
                console.log("VIRTUAL_KEYBOARD_NATIVE_PASSED concurrent rebuilt plugins, loading/error layout and recovery, button fades, focus, selection, layouts/variants, Shift/Caps, symbols, repeat, Enter, dead keys, narrow layouts, and unavailable backend");
            }
        }
        Timer { id: begin; interval: 40; onTriggered: { try { input.exercise(); } catch(error) { console.error("VIRTUAL_KEYBOARD_FAILED",error); } Qt.quit(); } }
    }
}
'''.replace("REBUILT_ENGINE", json.dumps(rebuilt_url)).replace("ENGINE", json.dumps(url)))
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "VIRTUAL_KEYBOARD_NATIVE_PASSED" in output, output
        assert not any(message in output for message in ("VIRTUAL_KEYBOARD_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output
        if check_protocol:
            protocol_checks(base, url, env)
        shell_checks(base, url, env)


def shell_checks(parent, url, parent_env):
    base = parent / "integration"
    base.mkdir()
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    env = prepare(base)
    env["XDG_CACHE_HOME"] = parent_env["XDG_CACHE_HOME"]
    env.pop("WAYLAND_DISPLAY", None)
    shutil.copytree(ROOT / "dots/sddm", base / "greeter")
    panel = (base / "modules/ui/keyboard/VirtualKeyboard.qml").read_text().replace("PanelWindow\n{", "Item\n{", 1)
    assert "exclusiveZone: 0" in panel and "exclusionMode: ExclusionMode.Ignore" in panel, "Keyboard must float without reserving application space"
    panel = panel.replace("    screen: Quickshell", "    property var screen: Quickshell").replace("    mask: Region", "    property var mask: Region")
    panel = re.sub(r'^    (?:WlrLayershell\.|color:|anchors \{|exclusionMode:|exclusiveZone:).*\n', '', panel, flags=re.M)
    (base / "modules/ui/keyboard/VirtualKeyboardFixture.qml").write_text(panel)
    (base / "modules/services/ServiceLock.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool locked:true; property bool checking:false; property bool failed:false; property bool leaving:false
    property bool preparingForSleep:false; property int failures:0; property int unlockDuration:0
    property var submissions:[]
    function submit(password) { submissions=submissions.concat([password]); }
}
''')
    (base / "modules/services/ServiceScreenshot.qml").write_text('pragma Singleton\nimport Quickshell\nSingleton { property bool active:false }\n')
    (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/keyboard"
import "modules/ui/lock"
import "greeter" as Greeter

ShellRoot {
    Window {
        id:window; visible:true; width:1024; height:768; color:"#08080a"
        function check(ok,message) { if(!ok) throw new Error(message); }
        function find(item,name) { if(item.objectName===name) return item; for(const child of item.children || []) { const found=find(child,name); if(found) return found; } return null; }
        Lock { id:lock; anchors.fill:parent; visible:ServiceLock.locked && !greeter.visible }
        TextInput { id:desktopField; x:20; y:20; width:500; height:40; color:"white"; visible:!ServiceLock.locked }
        KeyboardContent { id:desktop; anchors { horizontalCenter:parent.horizontalCenter; bottom:parent.bottom } width:840; height:implicitHeight; visible:!ServiceLock.locked && ServiceVirtualKeyboard.visible }
        Loader { id:engine; source:ENGINE; onLoaded:item.local=true }
        Greeter.Main { id:greeter; anchors.fill:parent; visible:false; keyboardEngine:engine.item }
        TestCase {
            id:input; when:false; optional:true
            function click(parent,name) { wait(25); const key=window.find(parent,name); window.check(key!==null,"Missing " + name); mouseClick(key,key.width/2,key.height/2); wait(25); }
            function exercise() {
                tryVerify(()=>Config.initialized,2000); window.requestActivate();
                const panel=Qt.createComponent(Qt.resolvedUrl("modules/ui/keyboard/VirtualKeyboardFixture.qml"));
                window.check(panel.status===Component.Ready,"Keyboard panel does not compile: " + panel.errorString());
                Config.set("virtualKeyboardEnabled",true); ServiceKeyboard.layouts=[{layout:"us",variant:""},{layout:"ru",variant:""}];
                click(lock,"lockKeyboardButton"); tryVerify(()=>ServiceVirtualKeyboard.ready,8000); wait(60);
                window.check(ServiceVirtualKeyboard.visible && lock.keyboardOpened,"Lock keyboard did not open");
                const field=window.find(lock,"lockPasswordInput"); field.forceActiveFocus();
                click(lock,"virtualKey30"); window.check(field.text==="a" && field.activeFocus,"Lock typing failed or stole focus");
                click(lock,"virtualKey28"); window.check(ServiceLock.submissions[0]==="a","Lock Enter did not reach authentication");
                for(const size of [Qt.size(1024,768),Qt.size(640,480),Qt.size(480,800)]) {
                    window.width=size.width; window.height=size.height; wait(30);
                    const keyboard=window.find(lock,"virtualKeyboard"), footer=window.find(lock,"lockFooter");
                    const top=keyboard.mapToItem(lock,0,0);
                    window.check(top.y>=0 && top.y+keyboard.height<=window.height+1 && footer.y+footer.height<=top.y,"Lock keyboard overlaps actions or leaves screen");
                }
                window.width=1024;window.height=768;
                ServiceScreenshot.active=true; window.check(!ServiceVirtualKeyboard.visible,"Screenshot did not hide keyboard");
                ServiceVirtualKeyboard.show(); window.check(!ServiceVirtualKeyboard.visible,"Keyboard opened over screenshot"); ServiceScreenshot.active=false;
                ServiceLock.locked=false; ServiceVirtualKeyboard.show(); ServiceVirtualKeyboard.engine.local=true; wait(30);
                desktopField.forceActiveFocus(); click(desktop,"virtualKey30"); window.check(desktopField.text==="a" && desktopField.activeFocus,"Shell input failed");
                Config.set("virtualKeyboardEnabled",false); window.check(!ServiceVirtualKeyboard.visible,"Disabling left keyboard open");
                Greeter.Theme.configuration={keyboardSource:KEYBOARD_SOURCE,keyboardLayouts:JSON.stringify([{layout:"us",variant:""},{layout:"ru",variant:""}])};
                greeter.visible=true; wait(30); click(greeter,"greeterKeyboardButton"); wait(60);
                window.check(greeter.keyboardVisible && window.find(greeter,"virtualKeyboard")!==null,"Login keyboard did not load");
                const loginField=window.find(greeter,"greeterPasswordInput"); loginField.forceActiveFocus();
                click(greeter,"virtualKey30"); window.check(loginField.text==="a" && loginField.activeFocus,"Login typing failed");
                click(greeter,"virtualKeyboardLayout"); click(greeter,"virtualKey30"); window.check(loginField.text==="aф","Login configured layouts ignored");
                for(const size of [Qt.size(1024,768),Qt.size(640,480),Qt.size(480,800)]) {
                    window.width=size.width; window.height=size.height; wait(30);
                    const keyboard=window.find(greeter,"virtualKeyboard"), footer=window.find(greeter,"greeterFooter");
                    const top=keyboard.mapToItem(greeter,0,0);
                    window.check(top.y>=0 && top.y+keyboard.height<=window.height+1 && footer.y+footer.height<=top.y,"Login keyboard overlaps actions or leaves screen");
                }
                click(greeter,"virtualKeyboardClose"); window.check(!greeter.keyboardVisible,"Login keyboard failed to close");
                console.log("VIRTUAL_KEYBOARD_SHELL_PASSED lock and login typing/layouts, focus, responsive placement, shell input, screenshot ordering, and disabling");
            }
        }
        Timer { interval:100; running:true; onTriggered: { try { input.exercise(); } catch(error) { console.error("VIRTUAL_KEYBOARD_FAILED",error); } Qt.quit(); } }
    }
}
'''.replace("ENGINE", json.dumps(url)).replace("KEYBOARD_SOURCE", json.dumps((ROOT / "modules/common/keyboard/Keyboard.qml").as_uri())))
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=16)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "VIRTUAL_KEYBOARD_SHELL_PASSED" in output, output
    assert not any(message in output for message in ("VIRTUAL_KEYBOARD_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output


def protocol_checks(base, url, env):
    """Decode real Wayland requests in an isolated compositor connection."""
    protocol = ROOT / "modules/src/virtualKeyboard/virtual-keyboard.xml"
    subprocess.run(["wayland-scanner", "server-header", str(protocol), str(base / "server-protocol.h")], check=True)
    subprocess.run(["wayland-scanner", "private-code", str(protocol), str(base / "server-protocol.c")], check=True)
    subprocess.run(["cc", "-fPIC", "-c", str(base / "server-protocol.c"), "-o", str(base / "protocol.o")], check=True)
    (base / "server.cpp").write_text(r'''
#include <wayland-server.h>
#include <xkbcommon/xkbcommon.h>
#include <cstdio>
#include <cstdlib>
#include <sys/mman.h>
#include <unistd.h>
#include "server-protocol.h"
static xkb_context *context;
static xkb_keymap *map;
static xkb_state *state;
static void keymap(wl_client *, wl_resource *, uint32_t format, int32_t fd, uint32_t size) {
    if(format != 1) std::abort();
    char *data=static_cast<char *>(mmap(nullptr,size,PROT_READ,MAP_PRIVATE,fd,0));
    if(data==MAP_FAILED || !size || data[size-1]) std::abort();
    if(state) xkb_state_unref(state); if(map) xkb_keymap_unref(map);
    map=xkb_keymap_new_from_string(context,data,XKB_KEYMAP_FORMAT_TEXT_V1,XKB_KEYMAP_COMPILE_NO_FLAGS);
    if(!map) std::abort(); state=xkb_state_new(map); munmap(data,size); close(fd);
}
static void key(wl_client *, wl_resource *, uint32_t, uint32_t code, uint32_t pressed) {
    if(!state) std::abort();
    std::printf("KEY %u %u\n",pressed,xkb_state_key_get_utf32(state,code+8)); std::fflush(stdout);
}
static void modifiers(wl_client *, wl_resource *, uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
    xkb_state_update_mask(state,depressed,latched,locked,0,0,group);
    std::printf("MOD %u %u %u\n",depressed,latched,locked); std::fflush(stdout);
}
static void destroy(wl_client *,wl_resource *resource) { wl_resource_destroy(resource); }
static void create(wl_client *client,wl_resource *,wl_resource *,uint32_t id) {
    static const struct zwp_virtual_keyboard_v1_interface implementation={keymap,key,modifiers,destroy};
    auto *resource=wl_resource_create(client,&zwp_virtual_keyboard_v1_interface,1,id);
    wl_resource_set_implementation(resource,&implementation,nullptr,nullptr);
}
static void bindManager(wl_client *client,void *,uint32_t,uint32_t id) {
    static const struct zwp_virtual_keyboard_manager_v1_interface implementation={create};
    auto *resource=wl_resource_create(client,&zwp_virtual_keyboard_manager_v1_interface,1,id);
    wl_resource_set_implementation(resource,&implementation,nullptr,nullptr);
}
static void bindSeat(wl_client *client,void *,uint32_t,uint32_t id) {
    auto *resource=wl_resource_create(client,&wl_seat_interface,1,id);
    wl_seat_send_capabilities(resource,WL_SEAT_CAPABILITY_KEYBOARD);
}
int main(int argc,char **argv) {
    context=xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    auto *display=wl_display_create();
    wl_global_create(display,&wl_seat_interface,1,nullptr,bindSeat);
    wl_global_create(display,&zwp_virtual_keyboard_manager_v1_interface,1,nullptr,bindManager);
    if(!wl_client_create(display,std::atoi(argv[1]))) { std::perror("wl_client_create"); return 1; }
    wl_display_run(display); return 0;
}
''')
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-server", "xkbcommon"], text=True))
    subprocess.run(["c++", "-std=c++17", str(base / "server.cpp"), str(base / "protocol.o"), "-o", str(base / "server"), *flags], check=True)
    server_socket, client_socket = socket.socketpair()
    log = base / "protocol.log"
    with log.open("w") as stream:
        server = subprocess.Popen([str(base / "server"), str(server_socket.fileno())], pass_fds=(server_socket.fileno(),), stdout=stream, stderr=subprocess.PIPE, env=env)
        server_socket.close()
        try:
            (base / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    Loader { id:native; source:ENGINE; onLoaded:begin.start() }
    Timer { id:begin; interval:30; onTriggered: {
        const engine=native.item; engine.connectDisplay();
        if(!engine.ready) { console.error("PROTOCOL_FAILED",engine.error); Qt.quit(); return; }
        engine.tap(30); engine.tap(30,true); engine.tap(30,false,true);
        engine.layout="ru"; engine.tap(30);
        engine.layout="de"; engine.tap(21);
        engine.symbols=true; engine.tap(3,true);
        done.start();
    } }
    Timer { id:done; interval:120; onTriggered: { native.item.disconnectDisplay(); console.log("PROTOCOL_PASSED"); Qt.quit(); } }
}
'''.replace("ENGINE", json.dumps(url)))
            try:
                result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, WAYLAND_SOCKET=str(client_socket.fileno())), pass_fds=(client_socket.fileno(),), capture_output=True, text=True, timeout=7)
            except subprocess.TimeoutExpired as error:
                print(error.stdout, error.stderr, "server:", server.poll(), log.read_text())
                raise
            output = result.stdout + result.stderr
            assert result.returncode == 0 and "PROTOCOL_PASSED" in output, output
        finally:
            client_socket.close()
            server.terminate()
            _, errors = server.communicate(timeout=3)
            if errors:
                print(errors.decode())
    events = log.read_text().splitlines()
    down = [int(line.split()[2]) for line in events if line.startswith("KEY 1 ")]
    up = [int(line.split()[2]) for line in events if line.startswith("KEY 0 ")]
    assert down == up == list(map(ord, "aAAфz@")), events
    assert events[-1] == "MOD 0 0 0", events
    print("VIRTUAL_KEYBOARD_PROTOCOL_PASSED real keymaps, UTF-8 layouts, modifiers, releases, and teardown")


if __name__ == "__main__":
    startup_import_checks()
    native_ui_checks()
