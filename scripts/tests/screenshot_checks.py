#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import runpy
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def png(width, height):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = b''.join(b'\0' + b''.join(bytes((220, 20, 40) if y < height // 2 and x < width // 2 else (20, 180, 40) if y < height // 2 else (20, 40, 220)) for x in range(width)) for y in range(height))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')


def pixels(path):
    data = path.read_bytes()
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    assert depth == 8 and color in (2, 6), (depth, color)
    encoded, offset = b'', 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b'IDAT': encoded += data[offset + 8:offset + 8 + length]
        offset += length + 12
    channels = 3 if color == 2 else 4
    size = width * channels
    raw, rows = zlib.decompress(encoded), []
    previous = bytearray(size)
    for y in range(height):
        kind = raw[y * (size + 1)]
        row = bytearray(raw[y * (size + 1) + 1:(y + 1) * (size + 1)])
        for x in range(size):
            a, b, c = (row[x - channels] if x >= channels else 0), previous[x], (previous[x - channels] if x >= channels else 0)
            if kind == 1: prediction = a
            elif kind == 2: prediction = b
            elif kind == 3: prediction = (a + b) // 2
            elif kind == 4:
                p = a + b - c
                prediction = min((a, b, c), key=lambda value: abs(p - value))
            else: prediction = 0
            row[x] = (row[x] + prediction) & 255
        rows.append(row)
        previous = row
    return width, height, lambda x, y: tuple(rows[y][x * channels:x * channels + 3])


def prepare(base):
    shutil.copytree(ROOT / 'modules', base / 'modules')
    shutil.copytree(ROOT / 'scripts', base / 'scripts', ignore=shutil.ignore_patterns('tests', 'tools', '__pycache__'))
    for name in ('assets', 'translations'):
        (base / name).symlink_to(ROOT / name)
    shutil.copy2(ROOT / 'version', base / 'version')
    for folder in ('bin', 'config/bloodyShell', 'runtime', 'cache', 'pictures'):
        (base / folder).mkdir(parents=True, mode=0o700)
    (base / 'fixture.png').write_bytes(png(800, 600))
    (base / 'config/bloodyShell/settings.json').write_text(json.dumps(dict(helperSeen=True, themeAnimations=0, osdEnabled=False)))
    fake = '''#!/usr/bin/env python3
import os, shutil, sys, time
from pathlib import Path
base = Path(os.environ['TEST_SCREENSHOT_BASE'])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
if name == 'grim':
    output = args[args.index('-o') + 1]
    counter = base / 'captures'
    count = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(count))
    if count == 4: time.sleep(0.3)
    if output == 'bad' or count == 7:
        print('Capture denied', file=sys.stderr); sys.exit(1)
    shutil.copyfile(base / 'fixture.png', args[-1])
elif name == 'wl-copy':
    assert args == ['--type', 'image/png'], args
    counter = base / 'copies'
    count = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(count))
    if count == 1:
        print('Clipboard unavailable', file=sys.stderr); sys.exit(1)
    (base / 'copied.png').write_bytes(sys.stdin.buffer.read())
elif name == 'xdg-user-dir': print(base / 'pictures')
'''
    for name in ('grim', 'wl-copy', 'xdg-user-dir', 'niri', 'awww', 'cava'):
        path = base / 'bin' / name
        path.write_text(fake)
        path.chmod(0o755)
    (base / 'modules/services/ServiceLock.qml').write_text('pragma Singleton\nimport Quickshell\nSingleton { property bool locked: false; function lock() { locked = true } }\n')
    (base / 'modules/ui/overlay/altTab/AltTabKeyboard.qml').write_text('import QtQuick\nItem {}\n')
    source = (ROOT / 'modules/ui/overlay/Overlay.qml').read_text().replace('PanelWindow\n{', 'Item\n{\n    property Item contentItem: parent', 1)
    source = source.replace('    screen: Quickshell', '    property var screen: Quickshell').replace('    mask: authenticating', '    property var mask: authenticating')
    source = re.sub(r'^    (?:WlrLayershell\.|BackgroundEffect\.|exclusionMode:|exclusiveZone:).*\n', '', source, flags=re.M)
    source = source.replace('    color: "transparent"\n', '').replace('    anchors { top: true; bottom: true; left: true; right: true }\n', '')
    source = re.sub(r'^    ShortcutInhibitor .*\n', '', source, flags=re.M)
    source = source.replace('PolkitAgent { id: authAgent }', 'QtObject { id: authAgent; property bool isActive: false; property var flow: null }')
    source = source.replace('    property string output:', '    readonly property alias testPage: page\n    property string output:')
    (base / 'modules/ui/overlay/OverlayFixture.qml').write_text(source)
    return dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'), XDG_RUNTIME_DIR=str(base / 'runtime'),
                PATH=str(base / 'bin') + os.pathsep + os.environ['PATH'], TEST_SCREENSHOT_BASE=str(base),
                DBUS_SESSION_BUS_ADDRESS='unix:path=/tmp/bloodyshell-test-no-session-bus', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/tmp/bloodyshell-test-no-system-bus', NIRI_SOCKET='/tmp/bloodyshell-test-no-niri')


def checks():
    with tempfile.TemporaryDirectory(prefix='bloodyshell-screenshot-') as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop('WAYLAND_DISPLAY', None)
        api = runpy.run_path(str(ROOT / 'scripts/runtime/screenshot'))
        with patch.dict(os.environ, WAYLAND_DISPLAY='wayland-current', XDG_RUNTIME_DIR=str(base / 'runtime')), patch('pathlib.Path.is_socket', return_value=True), patch('shutil.which', return_value='/usr/bin/wl-copy'), patch('subprocess.run') as command:
            command.return_value.returncode = 0
            api['copy_image'](base / 'fixture.png')
            arguments = command.call_args.args[0]
            assert '--service-type=forking' in arguments and '--setenv=WAYLAND_DISPLAY=wayland-current' in arguments
            assert '--setenv=XDG_RUNTIME_DIR=' + str(base / 'runtime') in arguments
        helper = [sys.executable, str(ROOT / 'scripts/runtime/screenshot')]
        result = subprocess.run(helper + ['capture', 'test', '800', '600'], env=env, capture_output=True, text=True, check=True)
        shot = json.loads(result.stdout)
        assert (shot['width'], shot['height']) == (800, 600)
        with patch.dict(os.environ, env), patch('shutil.which', return_value=None), patch('subprocess.run') as command:
            command.return_value.returncode = 0
            command.return_value.stdout = str(base / 'pictures')
            published = api['export'](shot['directory'], True, 0, 0, 800, 600)
            assert Path(published['path']).read_bytes() == (base / 'fixture.png').read_bytes()
            assert not any(call.args[0][0] == 'ffmpeg' for call in command.call_args_list), 'Full-screen export unnecessarily recoded the PNG'
        subprocess.run(helper + ['cleanup', shot['directory']], env=env, check=True)
        assert not Path(shot['directory']).exists()
        denied = subprocess.run(helper + ['cleanup', str(base / 'pictures')], env=env, capture_output=True)
        assert denied.returncode != 0 and (base / 'pictures').exists()
        (base / 'captures').unlink()
        (base / 'shell.qml').write_text(r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay"
ShellRoot
{
    id: tests
    property var savedPage: null
    property var savedInput: null
    property var paths: []
    property int completions: 0
    function check(ok, message) { if (!ok) throw new Error(message) }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const match = find(child, name); if (match) return match; }
        return null;
    }
    function shot() { return find(overlay, "screenshotView").item }
    function input(item) {
        if (item.cursorPosition !== undefined && item.text !== undefined) return item;
        for (const child of item.children || []) { const match = input(child); if (match) return match; }
        return null;
    }
    function restored() { check(!ServiceScreenshot.active && OverlayState.current === "settings" && overlay.testPage.item === savedPage, "Screenshot destroyed the previous settings page") }
    Connections { target: ServiceScreenshot; function onFinished(saved, path) { tests.completions++; if (saved) tests.paths = tests.paths.concat([path]); } }
    Window
    {
        id: window
        width: 800; height: 600; visible: true
        OverlayFixture { id: overlay; anchors.fill: parent }
        TestCase { id: events; name: "ScreenshotInput"; when: false; optional: true }
    }
    Timer
    {
        interval: 80; repeat: true; running: true
        property int step: 0
        property int waited: 0
        function waitFor(ok) { if (ok) { waited = 0; return false; } if (++waited > 60) throw new Error("Screenshot state timeout: " + ServiceScreenshot.phase); return true; }
        onTriggered:
        {
            if (!Config.initialized) return;
            try
            {
                switch (step)
                {
                    case 0: ServiceCompositor.focusedOutput = Quickshell.screens[0].name; OverlayState.show("settings"); break;
                    case 1:
                        if (waitFor(overlay.testPage.item !== null)) return;
                        tests.savedPage = overlay.testPage.item;
                        overlay.takeScreenshot();
                        tests.check(ServiceScreenshot.phase === "capturing" && !ServiceScreenshot.active && overlay.testPage.item === tests.savedPage, "Settings hidden before capture completed"); break;
                    case 2:
                        if (waitFor(ServiceScreenshot.phase === "ready" && tests.shot() && tests.shot().ready)) return;
                        tests.check(OverlayState.current === "settings" && overlay.testPage.item === tests.savedPage && !overlay.activeFor("settings"), "Settings was replaced instead of suspended");
                        const modes = tests.find(tests.shot(), "screenshotModes"), destination = tests.find(tests.shot(), "screenshotDestination");
                        modes.selected(Enums.ScreenshotScreen); destination.selected(true);
                        tests.check(Config.screenshotMode === Enums.ScreenshotScreen && Config.screenshotSave === true && tests.shot().selectionItem.region.width === 800, "Screenshot selectors do not persist or update geometry");
                        modes.selected(Enums.ScreenshotArea);
                        const pointer = tests.find(tests.shot(), "screenshotPointer");
                        events.mousePress(pointer, 100, 120, Qt.LeftButton, Qt.NoModifier, 0);
                        events.mouseMove(pointer, 300, 240, 0);
                        events.mouseRelease(pointer, 300, 240, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(tests.shot().selectionItem.region.width === 200 && tests.shot().selectionItem.region.height === 120, "Area selection is incorrect");
                        events.mousePress(pointer, 150, 150, Qt.LeftButton, Qt.NoModifier, 0);
                        events.mouseMove(pointer, 170, 160, 0);
                        events.mouseRelease(pointer, 170, 160, Qt.LeftButton, Qt.NoModifier, 0);
                        events.mousePress(pointer, 320, 250, Qt.LeftButton, Qt.NoModifier, 0);
                        events.mouseMove(pointer, 340, 270, 0);
                        events.mouseRelease(pointer, 340, 270, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(tests.shot().selectionItem.region.x === 120 && tests.shot().selectionItem.region.y === 130 && tests.shot().selectionItem.region.width === 220 && tests.shot().selectionItem.region.height === 140, "Area move or resize is incorrect");
                        events.keyClick(Qt.Key_Right, Qt.ShiftModifier);
                        events.keyClick(Qt.Key_Down, Qt.ControlModifier);
                        tests.check(tests.shot().selectionItem.region.x === 130 && tests.shot().selectionItem.region.height === 141, "Keyboard move or resize failed after dragging");
                        events.keyClick(Qt.Key_Left, Qt.ShiftModifier);
                        events.keyClick(Qt.Key_Up, Qt.ControlModifier);
                        modes.selected(Enums.ScreenshotScreen);
                        modes.selected(Enums.ScreenshotArea);
                        tests.check(tests.shot().selectionItem.region.x === 120 && tests.shot().selectionItem.region.width === 220 && tests.shot().selectionItem.region.height === 140, "Mode switch lost the selected area");
                        const panel = tests.find(tests.shot(), "screenshotModePanel");
                        events.mouseClick(panel, 2, 2, Qt.LeftButton, Qt.NoModifier, 0);
                        tests.check(tests.shot().selectionItem.region.x === 120 && tests.shot().selectionItem.region.width === 220, "Toolbar padding changed selection");
                        tests.shot().selectionItem.nudge(-1000, -1000, false);
                        tests.check(tests.shot().selectionItem.region.x === 0 && tests.shot().selectionItem.region.y === 0, "Keyboard move escaped screen bounds");
                        tests.shot().selectionItem.nudge(120, 130, false);
                        tests.shot().submit(); break;
                    case 3:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.restored(); tests.check(tests.paths.length === 1, "Area export failed");
                        overlay.takeScreenshot(Enums.ScreenshotScreen); break;
                    case 4:
                        if (waitFor(ServiceScreenshot.phase === "ready" && tests.shot() && tests.shot().ready)) return;
                        tests.find(tests.shot(), "screenshotDestination").selected(false);
                        tests.shot().submit(); break;
                    case 5:
                        if (waitFor(ServiceScreenshot.phase === "ready" && ServiceScreenshot.error !== "")) return;
                        tests.check(ServiceScreenshot.active, "Copy failure closed the screenshot");
                        tests.find(tests.shot(), "screenshotDestination").selected(true);
                        tests.shot().submit(); break;
                    case 6:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.restored(); tests.check(tests.paths.length === 2, "Retry save failed");
                        overlay.takeScreenshot(Enums.ScreenshotScreen); break;
                    case 7:
                        if (waitFor(ServiceScreenshot.phase === "ready" && tests.shot() && tests.shot().ready)) return;
                        tests.find(tests.shot(), "screenshotDestination").selected(false);
                        tests.shot().submit(); break;
                    case 8:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.restored(); tests.check(tests.completions === 3, "Copy completion was not reported");
                        overlay.takeScreenshot(); ServiceScreenshot.cancel(); break;
                    case 9:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.restored(); Config.set("screenshotMode", 1); overlay.takeScreenshot(); break;
                    case 10:
                        if (waitFor(ServiceScreenshot.phase === "ready" && tests.shot() && tests.shot().ready)) return;
                        const choices = tests.find(tests.shot(), "screenshotModes");
                        tests.check(choices.options.length === 2 && choices.current === Enums.ScreenshotArea && tests.shot().selectionItem.mode === Enums.ScreenshotArea, "Unsupported saved mode did not fall back to Area");
                        choices.selected(Enums.ScreenshotArea);
                        events.keyClick(Qt.Key_Escape); break;
                    case 11:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.restored(); overlay.takeScreenshot(); break;
                    case 12:
                        if (waitFor(ServiceScreenshot.phase === "ready")) return;
                        ServiceLock.locked = true; break;
                    case 13:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        ServiceLock.locked = false; OverlayState.show("settings"); overlay.takeScreenshot(); break;
                    case 14:
                        if (waitFor(ServiceScreenshot.phase === "idle" && ServiceScreenshot.error !== "")) return;
                        tests.check(!ServiceScreenshot.active && OverlayState.current === "settings", "Capture failure changed the previous page");
                        OverlayState.show("launcher"); break;
                    case 15:
                        if (waitFor(overlay.testPage.item && overlay.testPage.item.name === "launcher")) return;
                        tests.savedPage = overlay.testPage.item;
                        tests.savedInput = tests.input(tests.savedPage);
                        tests.check(tests.savedInput !== null, "Launcher input is missing");
                        window.requestActivate();
                        tests.savedInput.text = "screenshot state";
                        tests.savedInput.forceActiveFocus(); break;
                    case 16: overlay.takeScreenshot(); break;
                    case 17:
                        if (waitFor(ServiceScreenshot.phase === "ready" && tests.shot() && tests.shot().ready)) return;
                        tests.check(overlay.testPage.item === tests.savedPage && tests.savedInput.text === "screenshot state", "Capturing reset the launcher search");
                        ServiceScreenshot.cancel(); break;
                    case 18:
                        if (waitFor(ServiceScreenshot.phase === "idle")) return;
                        tests.check(overlay.testPage.item === tests.savedPage && OverlayState.current === "launcher", "Launcher was not restored");
                        events.keyClick(Qt.Key_X);
                        tests.check(tests.savedInput.text === "screenshot statex", "Keyboard focus did not return to the launcher input");
                        console.log("SCREENSHOT_PATHS", JSON.stringify(tests.paths));
                        console.log("SCREENSHOTS_PASSED"); Qt.quit(); break;
                }
                step++;
            }
            catch (error) { console.error("SCREENSHOTS_FAILED", step, error); Qt.quit() }
        }
    }
}
''')
        result = subprocess.run(['qs', '-p', str(base), '--no-color'], env=dict(env, QT_SCALE_FACTOR='1.25'), capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and 'SCREENSHOTS_PASSED' in output, output
        assert not re.search(r'SCREENSHOTS_FAILED|ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign', output), output
        paths = json.loads(re.search(r'SCREENSHOT_PATHS (\[.*\])', output).group(1))
        width, height, pixel = pixels(Path(paths[0]))
        assert (width, height) == (220, 140), (width, height)
        assert pixel(0, 0) == (220, 20, 40) and pixel(width - 1, height - 1) == (220, 20, 40), 'Area pixels were rescaled or include overlay controls'
        width, height, pixel = pixels(Path(paths[1]))
        assert (width, height) == (800, 600), (width, height)
        assert pixel(400, 40) == (20, 180, 40) and pixel(400, 565) == (20, 40, 220), 'Screen export contains screenshot controls'
        assert (base / 'copied.png').read_bytes() == Path(paths[1]).read_bytes(), 'Copy differs from the saved frozen image'
        assert int((base / 'captures').read_text()) == 8, 'Selection or export recaptured the desktop'
        assert not list((base / 'runtime').glob('bloodyShell-captures-*/capture-*')), 'Screenshot sessions leaked'
        settings = json.loads((base / 'config/bloodyShell/settings.json').read_text())
        assert isinstance(settings['screenshotMode'], int) and isinstance(settings['screenshotSave'], bool)
    print('Frozen capture, scale-correct crops, clipboard/save retry, mode selection, preserved pages, cancellation and cleanup passed.')


if __name__ == '__main__':
    checks()
