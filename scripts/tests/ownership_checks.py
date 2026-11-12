#!/usr/bin/env python3
"""Real CLI transactions against isolated XDG roots, with no desktop changes."""

import json
import os
from pathlib import Path
import signal
import shutil
import runpy
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-ownership-") as temporary:
        base = Path(temporary)
        for name in ("home", "config", "state", "cache", "runtime", "bin"):
            (base / name).mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_DATA_HOME=str(base / "data"),
                   XDG_RUNTIME_DIR=str(base / "runtime"), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        (base / "bin/niri").write_text("#!/bin/sh\nexit 0\n")
        (base / "bin/niri").chmod(0o700)
        (base / "bin/qs").write_text("#!/bin/sh\nprintf '[]\\n'\n")
        (base / "bin/qs").chmod(0o700)

        def cli(*args, success=True):
            result = subprocess.run([sys.executable, str(ROOT / "scripts/bloodyShell"), *args], env=env, text=True, capture_output=True, timeout=8)
            assert (result.returncode == 0) == success, result.stdout + result.stderr
            return result

        cli("footprint", "--json")
        assert not list((base / "state").iterdir()), "Inventory created persistent state"
        original = base / "config/niri/config.kdl"
        original.parent.mkdir()
        original.write_text("// user configuration\n")
        managed = original.parent / "bloodyShell/06-user-input.kdl"
        managed.parent.mkdir()
        managed.write_text("// original layout\n")
        cli("internal", "niri-config", "write", managed.name, "// updated layout")
        journal = base / "state/bloodyShell/changes.json"
        data = json.loads(journal.read_text())
        assert str(managed) in data["files"] and str(original) in data["files"]
        assert journal.stat().st_mode & 0o777 == 0o600
        unchanged = managed.read_bytes()
        before = journal.read_bytes()
        cli("restore")
        assert managed.read_bytes() == unchanged and journal.read_bytes() == before, "Preview changed files"
        managed.write_text("// user edited after bloodyShell\n")
        cli("restore", "--apply", success=False)
        assert managed.read_text() == "// user edited after bloodyShell\n"

        (base / "bin/niri").write_text("#!/bin/sh\nexit 1\n")
        cli("internal", "niri-config", "write", "07-user-output.kdl", "invalid", success=False)
        assert not (managed.parent / "07-user-output.kdl").exists()
        assert original.read_text() == "// user configuration\n", "Rejected compositor configuration was not rolled back"
        (base / "bin/niri").write_text("#!/bin/sh\nexit 0\n")
        assert original.read_text() == "// user configuration\n"
        # A later explicit edit starts from the user's latest configuration.
        cli("internal", "niri-config", "write", managed.name, "// another shell change")
        cli("restore", "--apply")
        assert managed.read_text() == "// user edited after bloodyShell\n"

        disposable = base / "cache/bloodyShell/keyboard"
        disposable.mkdir(parents=True)
        (disposable / "test.so").write_text("cache")
        settings = base / "config/bloodyShell/settings.json"
        settings.parent.mkdir()
        settings.write_text('{"personal":true}')
        marker = base / "cache/bloodyShell/last-version"
        marker.write_text("persistent marker")
        cli("cleanup")
        assert disposable.exists()
        cli("cleanup", "--apply")
        assert not disposable.exists() and settings.is_file() and marker.is_file() and journal.is_file()
        outside = base / "private"
        outside.mkdir()
        (outside / "keep").write_text("personal")
        disposable.symlink_to(outside, target_is_directory=True)
        cli("cleanup", "--apply", success=False)
        assert (outside / "keep").read_text() == "personal"
        disposable.unlink()

        # A running shell must prevent cleanup, even in another desktop session.
        (base / "bin/qs").write_text('#!/bin/sh\nprintf \'[{"id":"other","shell_id":"bloodyShell"}]\\n\'\n')
        cli("cleanup", "--apply", success=False)
        (base / "bin/qs").write_text("#!/bin/sh\nprintf '[]\\n'\n")

        # Supervisor termination removes its config and terminates its own child.
        cava = base / "bin/cava"
        cava.write_text("#!/usr/bin/env python3\nimport os, time\nfrom pathlib import Path\nPath(os.environ['TEST_CAVA_PID']).write_text(str(os.getpid()))\nwhile True: time.sleep(1)\n")
        cava.chmod(0o700)
        env["TEST_CAVA_PID"] = str(base / "cava.pid")
        process = subprocess.Popen([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", "visualizer", "28"], env=env)
        try:
            deadline = time.monotonic() + 4
            while not (base / "cava.pid").exists():
                assert process.poll() is None and time.monotonic() < deadline
                time.sleep(0.02)
            child_pid = int((base / "cava.pid").read_text())
            process.terminate()
            process.wait(timeout=5)
            assert not list((base / "runtime/bloodyShell").glob("visualizer-*"))
            assert not Path("/proc", str(child_pid)).exists(), "Visualizer child survived supervisor"
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
        assert cli("internal", "unknown", success=False).stderr

        # Sharing a login-screen theme must not imply consent to copy personal images.
        share = base / "shared"
        share.mkdir()
        image = base / "personal.png"
        image.write_bytes(b"private wallpaper")
        source = base / "source.json"
        source.write_text(json.dumps(dict(wallpaperCurrent=str(image))))
        resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
        resources["export"](source, share)
        assert "wallpaperCurrent" not in (share / "theme.conf").read_text()
        assert not list(share.glob("wallpaper.*"))
        source.write_text(json.dumps(dict(greeterSync=True, wallpaperCurrent=str(image))))
        resources["export"](source, share)
        assert (share / "wallpaper.png").read_bytes() == image.read_bytes()

        core = base / "core"
        core.mkdir()
        for name in ("Config", "Paths", "Enums"):
            shutil.copyfile(ROOT / "modules/core" / (name + ".qml"), core / (name + ".qml"))
        (core / "qmldir").write_text("\n".join(f"singleton {name} 1.0 {name}.qml" for name in ("Config", "Paths", "Enums")))
        settings.write_text(json.dumps(dict(themeScale=1.5, themeBorder=True, scrollSpeed=-10, barSide=99, dockPinned=[None, 42])))
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "core"
ShellRoot {
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            if (!Config.initialized) return;
            function check(ok) { if (!ok) throw new Error("Invalid configuration was accepted"); }
            try {
                check(Config.scrollSpeed === 2.5 && Config.barSide === 0 && Config.dockPinned.length === 0);
                check(!("themeScale" in Config) && !("themeBorder" in Config));
                check(!("themeScale" in Config.snapshot()) && !("themeBorder" in Config.snapshot()));
                check(!Config.greeterSync);
                Config.set("dockPinned", null);
                Config.set("scrollSpeed", -1);
                check(Config.dockPinned !== null && Config.scrollSpeed === 2.5);
                Config.set("scrollSpeed", 1.25);
                Config.set("barType", Enums.Islands);
                check(Config.scrollSpeed === 1.25 && Config.barType === Enums.Islands);
                console.log("CONFIG_OWNERSHIP_PASSED");
            } catch (error) { console.error(error); }
            Qt.quit();
        }
    }
}
''')
        result = subprocess.run([shutil.which("qs"), "-p", str(base), "--no-color"], env=dict(env, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software"), text=True, capture_output=True, timeout=8)
        assert "CONFIG_OWNERSHIP_PASSED" in result.stdout + result.stderr, result.stdout + result.stderr
    print("Ownership checks passed: read-only previews, tracked restoration, user edits, symlink refusal, cleanup boundaries, active sessions and child-process cleanup.")


if __name__ == "__main__":
    checks()
