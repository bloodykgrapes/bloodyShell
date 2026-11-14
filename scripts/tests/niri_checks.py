#!/usr/bin/env python3
"""Managed niri imports refresh defaults and preserve personal user files."""

import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def checks():
    resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
    desktop = runpy.run_path(str(ROOT / "scripts/lib/compositors/niri.py"))
    managed, user = desktop["NIRI_MANAGED"], desktop["NIRI_USER"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-niri-") as temporary:
        base = Path(temporary)
        source = base / "source"
        shutil.copytree(ROOT / "dots/niri", source)
        env = dict(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"))
        with patch.dict(os.environ, env):
            result = resources["import_config"](source, "niri")
            target = Path(result["destination"])
            fragments = target / "bloodyShell"
            assert sorted(path.name for path in fragments.iterdir()) == sorted((*managed, *user))
            assert "eDP-1" not in (fragments / "07-user-output.kdl").read_text(), "Import installed machine-specific display settings"
            personal = {
                "05-user.kdl": '// personal\nlayout { gaps 29; }\ninclude "../../external.kdl"\n',
                "06-user-input.kdl": 'input { keyboard { xkb { layout "de"; }; }; }\ncursor { xcursor-theme "Adwaita"; xcursor-size 31; }\n',
                "07-user-output.kdl": 'output "Personal display" { scale 2.0; }\n',
            }
            for name, text in personal.items():
                (fragments / name).write_text(text)
                (fragments / name).chmod(0o600)
            # Personal includes belong in the preserved user fragment.
            external = target.parent / "external.kdl"
            external.write_text('// outside the niri directory\n')
            (target / "config.kdl").write_text("// a managed loader will be refreshed\n")
            (fragments / "extra.kdl").write_text('// unrelated file\n')
            before = {name: ((fragments / name).read_bytes(), (fragments / name).stat().st_mtime_ns) for name in user}
            (source / "bloodyShell/01-layout.kdl").write_text((source / "bloodyShell/01-layout.kdl").read_text().replace("gaps 10", "gaps 17"))
            for repeat in range(2):
                imported = resources["import_config"](source, "niri")
                assert Path(imported["backup"]).is_dir()
                for name, (contents, modified) in before.items():
                    assert (fragments / name).read_bytes() == contents
                    assert (fragments / name).stat().st_mtime_ns == modified
                    assert (fragments / name).stat().st_mode & 0o777 == 0o600
                assert "gaps 17" in (fragments / "01-layout.kdl").read_text()
                assert (fragments / "extra.kdl").is_file()
                loader = (target / "config.kdl").read_text()
                assert loader == (ROOT / "dots/niri/config.kdl").read_text()
            # A protected symlink remains a link, and import never writes its target.
            shared = target / "shared-input.kdl"
            shared.write_text('input { keyboard { xkb { layout "fr"; }; }; }\n')
            input_file = fragments / "06-user-input.kdl"
            input_file.unlink()
            input_file.symlink_to("../shared-input.kdl")
            resources["import_config"](source, "niri")
            assert input_file.is_symlink() and os.readlink(input_file) == "../shared-input.kdl"
            assert shared.read_text() == 'input { keyboard { xkb { layout "fr"; }; }; }\n'
            # Invalid imports must never replace the current tree.
            snapshot = {str(path.relative_to(target)): path.read_bytes() for path in target.rglob("*") if path.is_file()}
            with patch("subprocess.run", return_value=SimpleNamespace(returncode=1, stderr="rejected")), patch("shutil.which", return_value="/fake/niri"):
                try:
                    resources["import_config"](source, "niri")
                except ValueError:
                    pass
                else:
                    raise AssertionError("Invalid niri configuration imported")
            assert snapshot == {str(path.relative_to(target)): path.read_bytes() for path in target.rglob("*") if path.is_file()}
            assert not list(target.parent.glob(".bloodyShell-config-*"))

            # Neither the helper nor UI services may write managed layout/window files.
            original = (fragments / "01-layout.kdl").read_bytes()
            for name in managed:
                try:
                    desktop["niri_write"](name, "invalid")
                except ValueError:
                    pass
                else:
                    raise AssertionError("Managed niri fragment was writable: " + name)
            assert (fragments / "01-layout.kdl").read_bytes() == original
            original_input = input_file.read_text()
            cursor = desktop["cursor_config"](original_input, 'New "cursor"', 28)
            assert original_input.strip() in cursor and cursor.count("xcursor-size") == 1
            assert 'xcursor-theme "New \\"cursor\\""' in cursor
            tricky = '// cursor { fake }\ninput { keyboard { xkb { options r#"{ cursor }"#; }; }; }\ncursor {\n    hide-when-typing\n    xcursor-theme "Old"\n    xcursor-size 20\n}\n'
            updated = desktop["cursor_config"](tricky, "Adwaita", 24)
            assert 'options r#"{ cursor }"#' in updated and "hide-when-typing" in updated
            assert updated.count("xcursor-size") == 1 and "xcursor-size 24" in updated
            changed = subprocess.run([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", "compositor", "config", "niri", "cursor", "Adwaita", "32"], capture_output=True, text=True, timeout=8)
            assert changed.returncode == 0, changed.stdout + changed.stderr
            text = (fragments / "06-user-input.kdl").read_text()
            assert original_input.strip() in text and "xcursor-size 32" in text
            resources["import_config"](source, "niri")
            assert (fragments / "06-user-input.kdl").read_text() == text
    assert not (ROOT / "modules/ui/overlay/settings/pages/PageCompositor.qml").exists()
    registry = (ROOT / "modules/core/Registry.qml").read_text()
    assert 'id: "compositor"' not in registry
    print("Niri checks passed: managed refresh, preserved user files/symlinks/metadata, repeat imports, user includes, staged rejection, cursor edits and no compositor customization.")


def mouse_checks():
    import json
    api = runpy.run_path(str(ROOT / 'scripts/lib/compositors/niri.py'))
    mouse_config, mouse_settings = api['mouse_config'], api['mouse_settings']
    text = '''// input { mouse { fake } }
input {
    keyboard { xkb { layout "de"; options "compose:menu"; }; }
    mouse {
        // accel-speed 1.0
        /- left-handed
        accel-speed -0.25 // keep this comment
        accel-profile r#"flat"#
        scroll-factor horizontal=-2.0 vertical=0.6
        scroll-method "on-button-down"
        scroll-button 274
    }
    touchpad { tap; accel-speed 0.2; }
}
cursor { xcursor-theme "Adwaita"; xcursor-size 24; }
'''
    assert mouse_settings(text) == dict(speed=-0.25, profile='flat', naturalScroll=False, leftHanded=False, scrollHorizontal=-2.0, scrollVertical=0.6, middleEmulation=False)
    changed = mouse_config(text, dict(speed=0.6, naturalScroll=True, leftHanded=True, scrollVertical=1.5, middleEmulation=True))
    assert mouse_settings(changed)['scrollHorizontal'] == -2 and mouse_settings(changed)['scrollVertical'] == 1.5
    for preserved in ('// keep this comment', '// accel-speed 1.0', '/- left-handed', 'touchpad { tap; accel-speed 0.2; }', 'scroll-method "on-button-down"', 'scroll-button 274', 'keyboard { xkb { layout "de"; options "compose:menu"; }; }', 'cursor { xcursor-theme "Adwaita"; xcursor-size 24; }'):
        assert preserved in changed, preserved
    assert mouse_config(changed, dict(speed=0.6, naturalScroll=True, leftHanded=True, scrollVertical=1.5, middleEmulation=True)) == changed
    disabled = mouse_config(changed, dict(naturalScroll=False, leftHanded=False, middleEmulation=False))
    assert not any(mouse_settings(disabled)[key] for key in ('naturalScroll','leftHanded','middleEmulation'))
    for source in ('', 'input {}', 'input { mouse { accel-speed 0.1; natural-scroll; }; touchpad { tap; }; }', '/- input { mouse { accel-speed 0.9; }; }'):
        edited = mouse_config(source, dict(speed=-0.5, profile='adaptive', naturalScroll=False))
        assert mouse_settings(edited)['speed'] == -0.5
        assert mouse_config(edited, dict(speed=-0.5, profile='adaptive', naturalScroll=False)) == edited
    for invalid in ({'off':True}, {'speed':2}, {'speed':True}, {'speed':float('nan')}, {'profile':'flat"; off;'}, {'naturalScroll':'true'}, {'scrollVertical':float('inf')}):
        try: mouse_config(text, invalid)
        except ValueError: pass
        else: raise AssertionError('Invalid mouse settings accepted: ' + str(invalid))
    keyboard = api['keyboard_config'](changed, 'keyboard {\n    xkb { layout "fr"; }\n    repeat-rate 40\n}')
    assert mouse_settings(keyboard) == mouse_settings(changed) and 'layout "fr"' in keyboard
    with tempfile.TemporaryDirectory(prefix='bloodyShell-mouse-config-') as temporary:
        base = Path(temporary)
        config = base / 'config/niri'
        fragments = config / 'bloodyShell'
        fragments.mkdir(parents=True)
        (config / 'config.kdl').write_text('include "bloodyShell/06-user-input.kdl"\n')
        shared = base / 'shared-input.kdl'
        shared.write_text((ROOT / 'dots/niri/bloodyShell/06-user-input.kdl').read_text())
        shared.chmod(0o600)
        (fragments / '06-user-input.kdl').symlink_to(shared)
        (base / 'bin').mkdir()
        (base / 'bin/qs').write_text("#!/bin/sh\nprintf '[]\\n'\n")
        (base / 'bin/qs').chmod(0o700)
        validator = base / 'bin/niri'
        validator.write_text('#!/bin/sh\n[ ! -f "' + str(base / 'deny') + '" ] || exit 1\nexec /usr/bin/niri "$@"\n')
        validator.chmod(0o700)
        env = dict(os.environ, HOME=str(base / 'home'), XDG_CONFIG_HOME=str(base / 'config'), XDG_STATE_HOME=str(base / 'state'), PATH=str(base / 'bin') + os.pathsep + os.environ['PATH'])
        cli = [sys.executable, str(ROOT / 'scripts/bloodyShell'), 'internal','compositor','config','niri']
        read = subprocess.run(cli + ['mouse-read'],env=env,capture_output=True,text=True,check=True)
        assert json.loads(read.stdout)['available'] and not (base / 'state').exists(), 'Reading mouse settings wrote state'
        result = subprocess.run(cli + ['mouse', json.dumps(dict(speed=0.4,scrollVertical=1.7,naturalScroll=True))],env=env,capture_output=True,text=True,check=True)
        assert json.loads(result.stdout)['mouse']['speed'] == 0.4
        assert not (base / 'state/bloodyShell/changes.json').exists(), 'Mouse changes created a tracking journal'
        assert (fragments / '06-user-input.kdl').is_symlink() and shared.stat().st_mode & 0o777 == 0o600
        subprocess.run(cli + ['keyboard','keyboard {\n    xkb { layout "fr"; }\n    repeat-rate 40\n}'],env=env,capture_output=True,text=True,check=True)
        assert mouse_settings(shared.read_text())['speed'] == 0.4 and 'repeat-rate 40' in shared.read_text()
        subprocess.run(cli + ['mouse',json.dumps({'leftHanded':True})],env=env,capture_output=True,text=True,check=True)
        assert 'repeat-rate 40' in shared.read_text()
        before = shared.read_bytes()
        (base / 'deny').touch()
        failed = subprocess.run(cli + ['mouse',json.dumps({'speed':0.9})],env=env,capture_output=True,text=True)
        assert failed.returncode != 0 and shared.read_bytes() == before, 'Rejected mouse configuration was not rolled back'
        subprocess.run(['niri','validate','-c',str(config / 'config.kdl')],capture_output=True,text=True,check=True)
        assert shared.read_bytes() == before and (fragments / '06-user-input.kdl').is_symlink(), 'Rejected edits changed the user configuration'
    print('Mouse configuration passed: real niri validation, defaults, flags, signed scroll axes, comments, disabled nodes, inline KDL, idempotence, concurrent keyboard edits, symlinks, permissions and rollback.')


def mouse_ui_checks():
    import json
    import re
    prepare = runpy.run_path(str(ROOT / 'scripts/tests/screenshot_checks.py'))['prepare']
    with tempfile.TemporaryDirectory(prefix='bloodyShell-mouse-ui-') as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / 'home').mkdir()
        env.update(HOME=str(base / 'home'), XDG_STATE_HOME=str(base / 'state'))
        env.pop('WAYLAND_DISPLAY', None)
        config = base / 'config/niri'
        directory = config / 'bloodyShell'
        directory.mkdir(parents=True)
        (config / 'config.kdl').write_text('include "bloodyShell/06-user-input.kdl"\n')
        initial = (ROOT / 'dots/niri/bloodyShell/06-user-input.kdl').read_text().replace('scroll-factor 1.0','scroll-factor horizontal=-1.2 vertical=0.8')
        path = directory / '06-user-input.kdl'
        path.write_text(initial)
        (base / 'bin/niri').write_text('#!/bin/sh\n[ "$1" = validate ] || exit 1\n[ ! -s "' + str(base / 'deny') + '" ] || { echo denied >&2; exit 1; }\nexec /usr/bin/niri "$@"\n')
        (base / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
ShellRoot {
    FileView { id: inputFile; path: ServiceCompositor.configFiles.input; watchChanges: true; onFileChanged: reload() }
    FileView { id: deny; path: DENY_PATH; printErrors: false }
    Window {
        visible: true; width: 900; height: 900
        PageDevices { id: page; anchors.fill: parent }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function until(predicate, message) { for(let i=0;i<180;i++) { if(predicate()) return; wait(20); } throw new Error(message); }
            function exercise() {
                until(() => ServiceDevices.mouseLoaded && ServiceDevices.mouseAvailable, "Mouse settings did not load: " + ServiceDevices.mouseError);
                const speed = findChild(page,"mousePointerSpeed"), acceleration = findChild(page,"mouseAcceleration"), primary = findChild(page,"mousePrimaryButton");
                const natural = findChild(page,"mouseNaturalScroll"), middle = findChild(page,"mouseMiddleEmulation");
                const horizontal = findChild(page,"mouseHorizontalScrollSpeed"), vertical = findChild(page,"mouseVerticalScrollSpeed");
                check(speed && acceleration && primary && natural && middle && horizontal && vertical && speed.enabled, "Mouse controls are missing or disabled");
                check(speed.value === 0 && acceleration.current === "flat" && horizontal.value === 1.2 && vertical.value === 0.8, "Mouse controls did not reflect the input configuration");
                speed.moved(0.6); acceleration.selected("adaptive"); primary.selected(true); natural.toggled(true); middle.toggled(true);
                horizontal.edited(2.1); vertical.edited(1.7);
                ServiceKeyboard.set("repeatRate",40);
                until(() => !ServiceDevices.mouseBusy && inputFile.text().includes("repeat-rate 40") && inputFile.text().includes("scroll-factor horizontal=-2.1 vertical=1.7"), "Mouse and keyboard saves lost a concurrent edit: " + ServiceDevices.mouseError + " " + ServiceKeyboard.error);
                check(ServiceDevices.mouse.speed === 0.6 && ServiceDevices.mouse.leftHanded && ServiceDevices.mouse.middleEmulation && ServiceDevices.mouse.naturalScroll && ServiceDevices.mouse.profile === "adaptive", "Saved mouse controls lost their values");
                inputFile.setText(inputFile.text().replace("accel-speed 0.6","accel-speed 0.25"));
                until(() => ServiceDevices.mouse.speed === 0.25 && speed.value === 0.25, "External input changes were not reflected in settings");
                deny.setText("deny");
                speed.moved(0.9);
                until(() => !ServiceDevices.mouseBusy && ServiceDevices.mouseError !== "" && ServiceDevices.mouse.speed === 0.25, "Rejected configuration did not restore the saved mouse state");
                check(inputFile.text().includes("accel-speed 0.25") && !inputFile.text().includes("accel-speed 0.9"), "Rejected mouse settings changed the file");
                deny.setText("");
                speed.moved(0.3);
                until(() => !ServiceDevices.mouseBusy && inputFile.text().includes("accel-speed 0.3"), "Mouse settings did not recover after a failed save");
                check(ServiceDevices.mouseError === "", "Successful retry retained an error");
                Config.set("shellLanguage","ru");
                page.visible = false;
                until(() => ServiceDevices.watchers === 0, "Hidden device settings retained hardware watchers");
                console.log("MOUSE_UI_PASSED controls, signed scroll axes, batched changes, concurrent keyboard writes, external edits, rollback, recovery and watcher cleanup"); Qt.quit();
            }
        }
        Timer { interval: 200; running: Config.initialized; onTriggered: { try { input.exercise(); } catch(error) { console.error("MOUSE_UI_FAILED",error); Qt.quit(); } } }
    }
}
'''.replace('DENY_PATH', json.dumps(str(base / 'deny'))))
        result = subprocess.run(['qs','-p',str(base),'--no-color'],env=env,capture_output=True,text=True,timeout=16)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and 'MOUSE_UI_PASSED' in output, output
        assert not re.search(r'MOUSE_UI_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration',output), output
        final = path.read_text()
        assert 'repeat-rate 40' in final and 'scroll-factor horizontal=-2.1 vertical=1.7' in final and 'accel-speed 0.3' in final
        api = runpy.run_path(str(ROOT / 'scripts/lib/compositors/niri.py'))
        for name in ('touchpad','cursor'):
            old_span = api['kdl_block'](initial,name,api['kdl_block'](initial,'input') if name == 'touchpad' else None)
            new_span = api['kdl_block'](final,name,api['kdl_block'](final,'input') if name == 'touchpad' else None)
            assert initial[old_span[0]:old_span[2]] == final[new_span[0]:new_span[2]], name + ' changed while editing mouse settings'


def concurrent_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-niri-concurrent-") as temporary:
        base = Path(temporary)
        directory = base / "config/niri/bloodyShell"
        directory.mkdir(parents=True)
        (directory.parent / "config.kdl").write_text('include "bloodyShell/06-user-input.kdl"\n')
        path = directory / "06-user-input.kdl"
        path.write_text('input { keyboard { xkb { layout "us"; }; }; mouse { accel-speed 0.0; }; touchpad { tap; }; }\n')
        binary = base / "bin"
        binary.mkdir()
        niri = binary / "niri"
        niri.write_text("#!/usr/bin/env python3\nimport time\ntime.sleep(0.03)\n")
        niri.chmod(0o700)
        env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_STATE_HOME=str(base / "state"), PATH=str(binary) + os.pathsep + os.environ["PATH"])
        requests = [
            ["keyboard", 'keyboard { xkb { layout "de,us"; }; repeat-rate 42; }'],
            ["mouse", '{"speed":0.45,"profile":"flat"}'],
            ["cursor", "Adwaita", "32"],
            ["write", "07-user-output.kdl", 'output "Test" { scale 1.25; }']
        ]
        processes = [subprocess.Popen([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", "compositor", "config", "niri", *args],
                                      env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                     for args in requests * 3]
        try:
            for process in processes:
                output, errors = process.communicate(timeout=10)
                assert process.returncode == 0, output + errors
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill(); process.communicate(timeout=3)
        text = path.read_text()
        assert 'layout "de,us"' in text and 'repeat-rate 42' in text, text
        assert 'accel-speed 0.45' in text and 'accel-profile "flat"' in text and 'xcursor-size 32' in text, text
        assert 'touchpad { tap; }' in text and 'scale 1.25' in (directory / "07-user-output.kdl").read_text(), text
        assert set(item.name for item in directory.iterdir()) == {"06-user-input.kdl", "07-user-output.kdl"}, "Input saving left lock or staging files"
    print("Concurrent niri writes passed: keyboard, mouse, cursor and output changes are kept without lock files.")


if __name__ == "__main__":
    checks()
    mouse_checks()
    mouse_ui_checks()
    concurrent_checks()
