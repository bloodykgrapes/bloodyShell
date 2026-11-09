#!/usr/bin/env python3

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def put(base, path, text):
    target = base / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)


def stub(base, folder, name, body):
    put(base, f"{folder}/{name}.qml", "pragma Singleton\n\nimport QtQuick\nimport Quickshell\n\nSingleton\n{\n" + body + "\n}\n")


def module(base, folder):
    names = sorted(p.stem for p in (base / folder).glob("*.qml"))
    put(base, f"{folder}/qmldir", "\n".join(f"singleton {name} 1.0 {name}.qml" for name in names) + "\n")


def check_sources():
    qml_files = [ROOT / "shell.qml", *ROOT.glob("modules/**/*.qml")]
    for path in qml_files:
        source = path.read_text()
        for relative in re.findall(r'^import "([^"\n]+)"', source, re.M):
            if path.name == "Monitor.qml" and relative == "plugin":
                continue
            assert (path.parent / relative).exists(), f"{path}: missing import {relative}"
        for relative in re.findall(r'Qt\.resolvedUrl\("([^"\n]+)"', source):
            assert (path.parent / relative).exists(), f"{path}: missing resource {relative}"
    def unique_entries(pairs):
        entries = dict(pairs)
        assert len(entries) == len(pairs), "Duplicate translation keys"
        return entries

    english = json.loads((ROOT / "translations/en.json").read_text(), object_pairs_hook=unique_entries)["strings"]
    russian = json.loads((ROOT / "translations/ru.json").read_text(), object_pairs_hook=unique_entries)["strings"]
    assert english.keys() == russian.keys(), "Translation dictionaries differ"
    for key, text in english.items():
        assert isinstance(text, str) and text.strip() and isinstance(russian[key], str) and russian[key].strip(), f"Empty translation: {key}"
        assert sorted(re.findall(r"%\d+", text)) == sorted(re.findall(r"%\d+", russian[key])), f"Translation placeholders differ: {key}"
    for path in ROOT.glob("modules/**/*.qml"):
        for key in re.findall(r'Tr\.tr\("([^"\n]+)"\)', path.read_text()):
            assert key in english, f"{path}: missing translation {key}"
    enums = (ROOT / "modules/core/Enums.qml").read_text()
    enum_names = set(re.findall(r"\b([A-Z]\w+)\s*=\s*\d+", enums))
    for path in ROOT.glob("modules/**/*.qml"):
        text = path.read_text()
        assert not re.search(r"\bLoad\.", text), f"{path}: obsolete Load owner"
        assert not re.search(r"ServiceLock\.(user|userFullName|userAvatar)\b", text), f"{path}: account data belongs to ServiceUser"
        assert not re.search(r"ServiceApplications\.(focusWindow|closeWindow)\(", text), f"{path}: duplicate compositor API"
        for name in re.findall(r"Enums\.(\w+)", text):
            assert name in enum_names, f"{path}: unknown enum {name}"
    for folder in ("core", "services"):
        for line in (ROOT / f"modules/{folder}/qmldir").read_text().splitlines():
            if line.startswith("singleton "):
                _, _, _, file = line.split()
                assert (ROOT / f"modules/{folder}" / file).is_file(), file
    shell_scripts = [ROOT / "setup"] + sorted(
        path for path in (ROOT / "scripts").rglob("*")
        if path.is_file() and path.read_bytes().startswith(b"#!/usr/bin/env bash")
    )
    for path in shell_scripts:
        subprocess.run(["bash", "-n", str(path)], cwd=ROOT, check=True)


def run_user_editor(base):
    base.mkdir()
    for folder in ("core", "services", "common", "bin", "account", "home", "runtime", "cache", "config"):
        (base / folder).mkdir(mode=0o700)
    for name in ("Paths",):
        put(base, f"core/{name}.qml", (ROOT / f"modules/core/{name}.qml").read_text())
    stub(base, "core", "Tr", "function tr(key) { return key }")
    source = (ROOT / "modules/services/ServiceUser.qml").read_text()
    for file in ("passwd", "group", "shells"):
        source = source.replace(f'"/etc/{file}"', json.dumps(str(base / "account" / file)))
    put(base, "services/ServiceUser.qml", source)
    put(base, "common/CommandProcess.qml", (ROOT / "modules/common/CommandProcess.qml").read_text())
    username = os.environ.get("USER", "user")
    put(base, "account/passwd", f"{username}:x:2000:2000:Tester,Room:{base / 'home'}:/bin/sh\noccupied:x:3000:2000:Other:/home/other:/bin/sh\n")
    put(base, "account/group", "users:x:2000:\nwheel:x:10:\naudio:x:20:\n")
    put(base, "account/shells", "/bin/sh\n/bin/bash\n")
    put(base, "account/memberships", "users wheel")
    put(base, "home/.face", "old-avatar")
    put(base, "home/new.png", "new-avatar")
    tool = f"#!{sys.executable}\nBASE = {str(base)!r}\n" + r'''
import json
import os
from pathlib import Path
import sys
base = Path(BASE)
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "id":
    print((base / "account/memberships").read_text())
elif name == "pkexec":
    with (base / "calls.jsonl").open("a") as log:
        log.write(json.dumps(args) + "\n")
    if "--comment" in args and args[args.index("--comment") + 1].split(",")[0] == "Denied":
        sys.exit(126)
    assert args[0] == str(base / "bin/usermod")
    os.execv(args[0], args)
elif name == "usermod":
    lines = (base / "account/passwd").read_text().splitlines()
    fields = lines[0].split(":")
    columns = {"--login": 0, "--uid": 2, "--gid": 3, "--comment": 4, "--home": 5, "--shell": 6}
    for flag, column in columns.items():
        if flag in args:
            fields[column] = args[args.index(flag) + 1]
    if "--groups" in args:
        memberships = args[args.index("--groups") + 1].replace(",", " ")
        (base / "account/memberships").write_text("users " + memberships)
    lines[0] = ":".join(fields)
    (base / "account/passwd").write_text("\n".join(lines) + "\n")
else:
    raise AssertionError(name)
'''
    for name in ("pkexec", "usermod", "id"):
        put(base, "bin/" + name, tool)
        (base / "bin" / name).chmod(0o700)
    module(base, "core")
    module(base, "services")
    shutil.copyfile(ROOT / "scripts/tests/UserRegression.qml", base / "shell.qml")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", PATH=str(base / "bin") + os.pathsep + os.environ["PATH"],
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"),
               BLOODYSHELL_TEST_HOME=str(base / "home"), BLOODYSHELL_TEST_BIN=str(base / "bin"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], cwd=base, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
    print(result.stdout)
    assert result.returncode == 0 and "REGRESSIONS_PASSED user editor" in result.stdout, "User editor regression failed"
    assert not re.search(r"REGRESSION_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", result.stdout), "User editor QML error"
    calls = [json.loads(line) for line in (base / "calls.jsonl").read_text().splitlines()]
    assert len(calls) == 3, "Only confirmed changes may invoke authorization"
    assert calls[0][calls[0].index("--comment") + 1] == 'New "$(touch should-not-exist)",Room', "Keep literal arguments and other GECOS fields"
    assert not (base / "should-not-exist").exists(), "Shell interpolation is forbidden"
    assert (base / "home/.face").read_text() == "new-avatar", "Avatar copied only on successful confirmation"
    assert (base / "account/passwd").read_text().splitlines()[0].split(":")[4] == "Partial,Room", "Refresh partial success accurately"


def run_storage(base):
    base.mkdir()
    for folder in ("core", "services", "common", "bin", "runtime", "cache", "config", "scripts"):
        (base / folder).mkdir(mode=0o700)
    for name in ("Paths",):
        put(base, f"core/{name}.qml", (ROOT / f"modules/core/{name}.qml").read_text())
    stub(base, "core", "Tr", "function tr(key) { return key }")
    source = (ROOT / "modules/services/ServiceStorage.qml").read_text().replace('"/etc/fstab"', json.dumps(str(base / "fstab")))
    put(base, "services/ServiceStorage.qml", source)
    put(base, "src/Clients.js", (ROOT / "modules/src/Clients.js").read_text())
    put(base, "src/ModelSync.js", (ROOT / "modules/src/ModelSync.js").read_text())
    put(base, "common/CommandProcess.qml", (ROOT / "modules/common/CommandProcess.qml").read_text())
    put(base, "scripts/runtime/storage", (ROOT / "scripts/runtime/storage").read_text())
    put(base, "fstab", "")
    put(base, "mounts.json", "{}")
    tool = f"#!{sys.executable}\nBASE = {str(base)!r}\n" + r'''
import json
from pathlib import Path
import sys
base = Path(BASE)
name = Path(sys.argv[0]).name
args = sys.argv[1:]
mounts = json.loads((base / "mounts.json").read_text())
if name == "lsblk":
    def device(path, uuid, ro=False):
        return {"name": path, "type": "part", "fstype": "ext4", "label": "Data", "uuid": uuid,
                "size": 1000, "mountpoints": [mounts[path]] if path in mounts else [], "ro": ro}
    items = [dict(device("/dev/test-root", "ROOT"), mountpoints=["/"]),
             {"name": "/dev/test-disk", "type": "disk", "model": "Test disk", "children": [device("/dev/test-data", "DATA", True), device("/dev/test-persistent", "PERSISTENT"), device("/dev/test-fail", "FAIL")]},
             device("/dev/test-data", "DATA", True),
             {"name": "/dev/test-swap", "type": "part", "fstype": "swap"},
             {"name": "/dev/test-locked", "type": "part", "fstype": "crypto_LUKS"}]
    print(json.dumps({"blockdevices": items}))
elif name == "findmnt":
    items = [{"source": "tmpfs", "fstype": "tmpfs", "size": 1000, "target": "/tmp"},
             {"source": "/dev/test-other", "fstype": "ext4", "size": 1000, "used": 200, "avail": 800, "target": "/mnt/With Spaces"},
             {"source": "/dev/test-root", "fstype": "ext4", "size": 1000, "used": 500 + 100 * len(mounts), "avail": 500 - 100 * len(mounts), "target": "/"}]
    for path, target in mounts.items():
        items.append({"source": path, "fstype": "ext4", "size": 1000, "used": 200, "avail": 800, "target": target})
    print(json.dumps({"filesystems": items}))
elif name in ("udisksctl", "pkexec"):
    with (base / "calls.jsonl").open("a") as output:
        output.write(json.dumps({"tool": name, "args": args}) + "\n")
    if name == "udisksctl":
        assert args[:2] == ["mount", "--block-device"]
        assert args[2] == "/dev/test-data" and args[3:] == ["--options", "ro"]
        mounts[args[2]] = "/run/media/test/Data"
    else:
        assert args[0] == str(base / "scripts/runtime/storage")
        assert args[1] == "mount"
        if args[-1] == "/mnt/Denied":
            sys.exit(126)
        assert args[2:5] == ["/dev/test-persistent", "PERSISTENT", "ext4"]
        assert args[5] == "/mnt/Persistent Data"
        mounts[args[2]] = args[5]
    (base / "mounts.json").write_text(json.dumps(mounts))
    print("Mounted test device")
else:
    raise AssertionError(name)
'''
    for name in ("lsblk", "findmnt", "udisksctl", "pkexec"):
        put(base, "bin/" + name, tool)
        (base / "bin" / name).chmod(0o700)
    module(base, "core")
    module(base, "services")
    shutil.copyfile(ROOT / "scripts/tests/StorageRegression.qml", base / "shell.qml")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", PATH=str(base / "bin") + os.pathsep + os.environ["PATH"],
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"),
               BLOODYSHELL_TEST_BIN=str(base / "bin"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], cwd=base, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
    print(result.stdout)
    assert result.returncode == 0 and "REGRESSIONS_PASSED storage" in result.stdout, "Storage regression failed"
    assert not re.search(r"REGRESSION_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", result.stdout), "Storage QML error"
    calls = [json.loads(line) for line in (base / "calls.jsonl").read_text().splitlines()]
    assert [call["tool"] for call in calls] == ["udisksctl", "pkexec", "pkexec"], "Only confirmed operations may run"


def run_media(base):
    base.mkdir()
    for folder in ("core", "services", "common", "runtime", "cache", "config"):
        (base / folder).mkdir(mode=0o700)
    stub(base, "core", "Config", "property bool animationsEnabled: true\nproperty int equalizerStyle: 0")
    put(base, "core/Enums.qml", (ROOT / "modules/core/Enums.qml").read_text())
    stub(base, "core", "Mpris", "property var players: ({ values: [] })")
    stub(base, "services", "ServiceLock", "property bool locked: false")
    source = (ROOT / "modules/services/ServiceMedia.qml").read_text().replace("import Quickshell.Services.Mpris\n", "")
    put(base, "services/ServiceMedia.qml", source)
    put(base, "common/RenderActivity.qml", (ROOT / "modules/common/RenderActivity.qml").read_text())
    put(base, "common/Equalizer.qml", (ROOT / "modules/common/Equalizer.qml").read_text())
    stub(base, "core", "Theme", "property bool accentShell: true\nfunction accentAlpha(alpha) { return Qt.rgba(1, 1, 1, alpha) }\nfunction inkAlpha(alpha) { return Qt.rgba(0, 0, 0, alpha) }")
    put(base, "src/Clients.js", (ROOT / "modules/src/Clients.js").read_text())
    put(base, "src/Visualizer.js", (ROOT / "modules/src/Visualizer.js").read_text())
    module(base, "core")
    module(base, "services")
    shutil.copyfile(ROOT / "scripts/tests/MediaRegression.qml", base / "shell.qml")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=10)
    print(result.stdout)
    assert result.returncode == 0 and "REGRESSIONS_PASSED media activity" in result.stdout, "Media activity regression failed"
    assert not re.search(r"REGRESSION_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", result.stdout), "Media QML error"


def main():
    check_sources()
    with tempfile.TemporaryDirectory(prefix="bloodyShell-tests-") as temporary:
        base = Path(temporary)
        copies = {
            "core": ["OverlayState", "MenuState", "Paths", "Enums"],
            "services": ["ServiceApplications", "ServiceWindowActions", "ServiceDock"],
            "common": ["CommandProcess"],
        }
        for folder, names in copies.items():
            for name in names:
                put(base, f"{folder}/{name}.qml", (ROOT / f"modules/{folder}/{name}.qml").read_text())
        put(base, "src/Clients.js", (ROOT / "modules/src/Clients.js").read_text())
        put(base, "src/ModelSync.js", (ROOT / "modules/src/ModelSync.js").read_text())
        put(base, "src/AppIdentity.js", (ROOT / "modules/src/AppIdentity.js").read_text())
        stub(base, "core", "Config", '''
    property bool debug: false
    property bool launcherEnabled: true
    property bool dockMerge: true
    property var dockPinned: []
    function set(key, value) { this[key] = value }
''')
        stub(base, "core", "Registry", 'readonly property var windows: ["launcher", "power", "settings", "wallpapers"]')
        stub(base, "services", "ServiceCompositor", '''
    property var windowList: []
    property var focusedWindowId: null
    property var lastWindowId: null
    property var focusedWorkspaceId: null
    property bool overviewOpen: false
    property var focusedCalls: []
    property var closedCalls: []
    function focusWindow(id) { focusedCalls = focusedCalls.concat([id]) }
    function closeWindow(id) { closedCalls = closedCalls.concat([id]) }
''')
        stub(base, "services", "ServiceAppearance", 'function iconPath(name) { return "file:///icons/" + name + ".svg" }')
        stub(base, "services", "ServiceNotifications", 'property var history: []\nproperty var receivedAt: ({})')
        module(base, "core")
        module(base, "services")
        shutil.copyfile(ROOT / "scripts/tests/Regression.qml", base / "shell.qml")
        for path in ("runtime", "cache", "config"):
            (base / path).mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
        print(result.stdout)
        assert result.returncode == 0, "Quickshell failed"
        assert "REGRESSIONS_PASSED" in result.stdout, "Regression run did not finish"
        assert not re.search(r"REGRESSION_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign", result.stdout), "QML runtime error"
        run_user_editor(base / "user-editor")
        run_storage(base / "storage")
        run_media(base / "media")
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/runtime_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/storage_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/installer_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/command_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/program_choices_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/dependency_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/update_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/network_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/notifications_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/screenshot_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/battery_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/autostart_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/helper_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/greeter_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/lock_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/greeter_install_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/alt_tab_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/surface_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/menu_geometry_checks.py")], check=True)
        subprocess.run([sys.executable, str(ROOT / "scripts/tests/island_checks.py")], check=True)
    print("Source checks and isolated QML regressions passed.")


if __name__ == "__main__":
    main()
