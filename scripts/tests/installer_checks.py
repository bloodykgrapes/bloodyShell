#!/usr/bin/env python3

import json
import io
import signal
import time
import os
from pathlib import Path
import runpy
import subprocess
import tarfile
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-installer-") as temporary:
        base = Path(temporary)
        package = base / "release"
        package.mkdir()
        (package / "version").write_text("9.8.7\n")
        (package / "shell.qml").write_text("release shell\n")
        (package / "CHANGELOG.md").write_text("## [9.8.7] - 2026-11-15\n\nBundled release notes.\n")
        (package / "setup").write_text("#!/bin/sh\nexit 99\n")
        (package / "__pycache__").mkdir()
        (package / "__pycache__/private.pyc").write_text("generated cache")
        (package / ".private").write_text("local state")
        (package / "local-notes.txt").write_text("private checkout notes")
        import shutil
        shutil.copytree(ROOT / "scripts/lib", package / "scripts/lib")
        shutil.copy2(ROOT / "scripts/bloodyShell", package / "scripts/bloodyShell")
        shutil.copytree(ROOT / "dots/niri", package / "dots/niri")
        greeter = package / "scripts/lib/system.sh"
        greeter.write_text(greeter.read_text() + "\nrefresh_greeter() { return 0; }\n")
        (package / "assets").mkdir()
        shutil.copy2(ROOT / "assets/packages.json", package / "assets/packages.json")
        for folder in ("tests", "tools"):
            (package / "scripts" / folder).mkdir(parents=True)
        for folder, name in (("images", "new.png"), ("dots/config/kitty", "kitty.conf"), ("dots/sddm", "Main.qml")):
            (package / folder).mkdir(parents=True)
            (package / folder / name).write_text("optional repository file")
        (package / "scripts/tests/development-check.py").write_text("development test\n")
        (package / "scripts/lib/README.md").write_text("Development documentation\n")
        (package / "scripts/tools/icons-dark").write_text("development tool\n")
        archive = base / "release.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        binary = base / "bin"
        binary.mkdir()
        curl = binary / "curl"
        curl.write_text("#!/usr/bin/env python3\nimport os, shutil, sys\nif '-o' in sys.argv: shutil.copyfile(os.environ['TEST_RELEASE'], sys.argv[sys.argv.index('-o') + 1])\nelse: print(os.environ['TEST_RELEASES'])\n")
        curl.chmod(0o700)
        home = base / "home"
        home.mkdir()
        (home / ".bashrc").write_text("export EXISTING_SETTING=kept\n")
        env = dict(os.environ, HOME=str(home), SHELL="/bin/bash", XDG_BIN_HOME=str(base / "commands"),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_DATA_HOME=str(base / "data"),
                   BLOODYSHELL_STATUS=str(base / "status"), TEST_RELEASE=str(archive), TEST_RELEASES=json.dumps([
                       dict(tag_name="v100.0.0", draft=True, prerelease=False),
                       dict(tag_name="v10.0.0-beta.1", draft=False, prerelease=True),
                       dict(tag_name="nightly", draft=False, prerelease=False),
                       dict(tag_name="v9.8.7", draft=False, prerelease=False),
                       dict(tag_name="v8.0.0", draft=False, prerelease=False)]),
                   PATH=str(binary) + os.pathsep + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)
        target = base / "config/quickshell/bloodyShell"
        target.mkdir(parents=True)
        (target / "shell.qml").write_text("previous shell\n")
        pictures = home / "Pictures/Wallpapers"
        pictures.mkdir(parents=True)
        (pictures / "personal.png").write_bytes(b"personal wallpaper")
        settings = base / "config/bloodyShell/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text(json.dumps(dict(wallpaperDirectory=str(pictures), wallpaperCurrent=str(pictures / "personal.png"))))
        original_settings = settings.read_bytes()
        fragments = base / "config/niri/bloodyShell"
        fragments.mkdir(parents=True)
        old_input = 'input { keyboard { xkb { layout "de"; }; }; }\n'
        old_output = 'output "Personal display" { scale 2.0; }\n'
        old_user = '// personal override\nlayout { gaps 27; }\n'
        for name, content in (("06-user-input.kdl", old_input), ("07-user-output.kdl", old_output), ("05-user.kdl", old_user)):
            (fragments / name).write_text(content)
        (fragments.parent / "config.kdl").write_text('include "bloodyShell/05-user.kdl"\n')

        def invoke(*args):
            return subprocess.run(["bash", str(ROOT / "setup"), *args], env=env, capture_output=True, text=True, timeout=10)

        result = invoke("update")
        assert result.returncode == 0, result.stdout + result.stderr
        assert (target / "shell.qml").read_text() == "release shell\n"
        assert not (target / "CHANGELOG.md").exists(), "Changelog is fetched from GitHub, not installed"
        assert not (target / "scripts/lib/README.md").exists(), "Runtime includes unrelated documentation"
        assert not (target / "images").exists() and not (target / "dots").exists()
        assert (pictures / "personal.png").read_bytes() == b"personal wallpaper"
        assert settings.read_bytes() == original_settings, "Updates must preserve shell settings"
        niri_settings = (fragments / "08-settings.kdl").read_text()
        assert old_input in niri_settings and old_output in niri_settings
        assert (fragments / "09-user.kdl").read_text() == old_user
        assert (fragments / "07-binds.kdl").read_bytes() == (ROOT / "dots/niri/bloodyShell/07-binds.kdl").read_bytes()
        assert not (pictures / "new.png").exists(), "Updates must not import wallpapers without an explicit request"
        untouched = {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in pictures.iterdir()}
        assert not (target / "__pycache__").exists() and not (target / ".private").exists()
        assert not (target / "local-notes.txt").exists(), "Only declared runtime roots may be installed"
        assert (base / "status").read_text().strip() == "done 9.8.7"
        command = base / "commands/bloodyShell"
        assert command.is_file() and os.access(command, os.X_OK)
        assert not (base / "data/applications/bloodyShell.desktop").exists()
        assert (target / "scripts/bloodyShell").is_file()
        assert not (target / "setup").exists(), "The installer must not be shipped with the runtime"
        assert not (target / "source.json").exists(), "Installed imports must not retain a checkout fallback"
        assert (target / "scripts/lib/management.py").is_file(), "Command installation must package the management module"
        assert (target / "scripts/lib/screenshot.py").is_file(), "Backend modules must be packaged"
        beta = invoke("update", "--beta")
        assert beta.returncode != 0 and "Downloading 10.0.0-beta.1" in beta.stdout and "does not match" in beta.stderr
        assert (target / "version").read_text().strip() == "9.8.7", "Rejected beta archives must preserve the runtime"
        assert invoke("update").returncode == 0
        assert not (target / "scripts/tests").exists() and not (target / "scripts/tools").exists(), "Installed shells must exclude development tests and tools"
        assert "EXISTING_SETTING=kept" in (home / ".bashrc").read_text()
        assert not list(home.glob(".local/state/bloodyShell/backups/*/launcher/bashrc"))
        assert invoke("update", "--tag", "v9.8.7").returncode == 0
        first_rc = (home / ".bashrc").read_text()
        assert invoke("update", "--tag", "v9.8.7", "--force").returncode == 0
        assert untouched == {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in pictures.iterdir()}, "Later updates must leave personal wallpapers untouched"
        assert (home / ".bashrc").read_text() == first_rc, "Updates must preserve startup files"
        info = subprocess.run([str(command), "path"], env=env, capture_output=True, text=True, timeout=5)
        assert info.returncode == 0 and info.stdout.strip() == str(target), info.stderr
        repair = base / "repair"
        source = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
        source = "\n".join('readonly PACKAGE="$CONFIG_HOME/quickshell/$NAME"' if line.startswith("readonly PACKAGE=") else line for line in source.splitlines())
        repair.write_text(source + "\napply_shell\n")
        result = subprocess.run(["bash", str(repair)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (target / "shell.qml").read_text() == "release shell\n", "Repairing an installed copy must not move its own source"
        (target / "preserved.marker").write_text("previous installation")
        installed_launcher = (base / "commands/bloodyShell").read_bytes()
        # A new runtime that cannot start restores both the old files and CLI,
        # reports failure, and leaves user settings unchanged.
        qs = binary / "qs"
        qs.write_text('''#!/usr/bin/env python3
import pathlib, sys
if sys.argv[1] == 'list': print('[]')
elif '--daemonize' in sys.argv:
    root = pathlib.Path(sys.argv[sys.argv.index('--path') + 1])
    sys.exit(0 if (root / 'preserved.marker').is_file() else 1)
''')
        qs.chmod(0o700)
        release_cli = package / "scripts/bloodyShell"
        original_cli = release_cli.read_bytes()
        broken_cli = original_cli.replace(b"def stop(command, path, quiet=False):\n", b'def stop(command, path, quiet=False):\n    raise RuntimeError("Broken updated CLI")\n', 1)
        assert broken_cli != original_cli
        release_cli.write_bytes(broken_cli)
        (fragments / "04-layout.kdl").write_text("// previous managed config\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        env["WAYLAND_DISPLAY"] = "fixture-startup-check"
        failed_start = invoke("update", "--tag", "v9.8.7", "--force")
        assert failed_start.returncode != 0, failed_start.stdout + failed_start.stderr
        assert "restored version 9.8.7" in failed_start.stderr, failed_start.stdout + failed_start.stderr
        assert (target / "preserved.marker").read_text() == "previous installation"
        assert (base / "commands/bloodyShell").read_bytes() == installed_launcher
        assert settings.read_bytes() == original_settings
        assert (fragments / "04-layout.kdl").read_text() == "// previous managed config\n"
        assert (fragments / "08-settings.kdl").read_text() == niri_settings
        assert (base / "status").read_text().startswith("failed Update failed; restored version")
        recovery = json.loads((base / "cache/bloodyShell/update-recovery.json").read_text())
        assert recovery == dict(tag="v9.8.7", version="9.8.7", error="Update failed; restored version 9.8.7")
        assert not list(target.parent.glob(".bloodyShell-*")), "Recovery left temporary runtime folders"
        env.pop("WAYLAND_DISPLAY")
        qs.unlink()
        release_cli.write_bytes(original_cli)
        manager = package / "scripts/lib/management.py"
        original_manager = manager.read_text()
        manager.write_text("def install_main():\n    return 1\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        failed_install = invoke("update", "--tag", "v9.8.7", "--force")
        assert failed_install.returncode != 0
        assert (target / "preserved.marker").read_text() == "previous installation", "Installation failure did not restore the previous shell"
        assert (base / "commands/bloodyShell").read_bytes() == installed_launcher
        assert not list((base / "config/quickshell").glob(".bloodyShell-*"))
        assert not list((base / "state").rglob("failed-shell")), "Failed runtime copies must be cleaned up"
        manager.write_text(original_manager)
        temporary_download = base / "download's folder"
        temporary_download.mkdir()
        env["TMPDIR"] = str(temporary_download)
        (package / "version").write_text("wrong-version\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        failed = invoke("update", "--tag", "v9.8.7", "--force")
        assert failed.returncode != 0
        assert (target / "version").read_text().strip() == "9.8.7", "Rejected releases must keep the current installation"
        assert not list(temporary_download.iterdir()), "Clean downloads even when TMPDIR contains an apostrophe"
        (package / "version").write_text("9.8.7\n")
        # Unsafe archives are rejected in the download directory, before the
        # installed runtime or any user configuration is changed.
        for name, kind, link in (("release/../../outside", tarfile.REGTYPE, ""),
                                 ("release/escape", tarfile.SYMTYPE, str(base / "outside")),
                                 ("release/pipe", tarfile.FIFOTYPE, "")):
            with tarfile.open(archive, "w:gz") as tar:
                entry = tarfile.TarInfo(name)
                entry.type, entry.linkname = kind, link
                data = b"unsafe archive"
                entry.size = len(data) if kind == tarfile.REGTYPE else 0
                tar.addfile(entry, io.BytesIO(data) if kind == tarfile.REGTYPE else None)
            rejected = invoke("update", "--tag", "v9.8.7", "--force")
            assert rejected.returncode != 0 and not (base / "outside").exists()
            assert (target / "preserved.marker").read_text() == "previous installation"
            assert not list(temporary_download.iterdir())
        # Invalid Python and links outside the payload are caught before backup.
        for invalid in ("syntax", "link"):
            if invalid == "syntax":
                (package / "scripts/lib/broken.py").write_text("def broken(:\n")
            else:
                (package / "scripts/lib/escape").symlink_to(home / ".bashrc")
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(package, arcname="release")
            rejected = invoke("update", "--tag", "v9.8.7", "--force")
            assert rejected.returncode != 0 and (target / "preserved.marker").is_file()
            (package / ("scripts/lib/broken.py" if invalid == "syntax" else "scripts/lib/escape")).unlink()
            assert not list((base / "config/quickshell").glob(".bloodyShell-*"))
        # A fresh installation must also roll back when command registration fails.
        fresh_env = dict(env, HOME=str(base / "fresh home"), XDG_CONFIG_HOME=str(base / "fresh config"),
                         XDG_STATE_HOME=str(base / "fresh state"), XDG_CACHE_HOME=str(base / "fresh cache"), XDG_BIN_HOME=str(base / "fresh bin"))
        manager.write_text("def install_main():\n    return 1\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        failed = subprocess.run(["bash", str(ROOT / "setup"), "update", "--tag", "v9.8.7"], env=fresh_env, capture_output=True, text=True, timeout=10)
        assert failed.returncode != 0 and not (base / "fresh config/quickshell/bloodyShell").exists()
        assert not list((base / "fresh config/quickshell").glob(".bloodyShell-*"))
        manager.write_text(original_manager)
        # Interrupt staging in its own process group, without touching a desktop.
        marker = base / "staging-started"
        python = binary / "python3"
        python.write_text("#!/usr/bin/python3\nimport os, sys, time\nfrom pathlib import Path\nif 'install-runtime' in sys.argv:\n    Path(os.environ['TEST_STAGE_MARKER']).touch()\n    time.sleep(30)\nelse:\n    os.execv('/usr/bin/python3', ['/usr/bin/python3', *sys.argv[1:]])\n")
        python.chmod(0o755)
        interrupted_script = base / "interrupted-install"
        content = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
        content = "\n".join('readonly PACKAGE="' + str(ROOT) + '"' if line.startswith("readonly PACKAGE=") else line for line in content.splitlines())
        interrupted_script.write_text(content + '\napply_shell "' + str(package) + '"\n')
        process = subprocess.Popen(["bash", str(interrupted_script)], env=dict(env, TEST_STAGE_MARKER=str(marker)), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            assert marker.exists(), "Staging did not start"
            os.killpg(process.pid, signal.SIGTERM)
            process.communicate(timeout=5)
            assert process.returncode != 0 and (target / "preserved.marker").is_file()
            assert not list((base / "config/quickshell").glob(".bloodyShell-*"))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)
            python.unlink()
        for command in ("apply", "greeter", "keyring", "remove-sddm", "unknown"):
            assert invoke(command).returncode != 0, command
        for arguments in (("update", "--tag"), ("install", "unexpected"), ("sddm", "unexpected"), ("help", "unexpected")):
            assert invoke(*arguments).returncode != 0, arguments
        for command in ("install", "update", "doctor", "configs", "sddm", "help"):
            for flag in ("-y", "--yes"):
                assert invoke(command, flag).returncode != 0, (command, flag)
        assert invoke("help").returncode == 0
        doctor = invoke("doctor", "--json")
        report = json.loads(doctor.stdout)
        assert report and all("ok" in item and "required" in item for item in report)
        assert invoke("doctor", "--invalid").returncode != 0
        print("Installer commands, diagnostics, CLI updates without an installed setup, repair, invalid releases and temporary-file cleanup passed.")


def installation_flow_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-install-entry-") as temporary:
        base = Path(temporary)
        env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"))
        result = subprocess.run(["bash", str(ROOT / "setup"), "install"], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode != 0 and "terminal" in result.stderr
        assert not (base / "config").exists() and not (base / "state").exists(), "Noninteractive install bypassed the review screen"
    print("Repository installer uses the reviewed wizard and refuses noninteractive installation without changing files.")


def runtime_transaction_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    scope = api["install_runtime"].__globals__
    replace = os.replace
    with tempfile.TemporaryDirectory(prefix="bloodyShell-runtime-rollback-") as temporary:
        base = Path(temporary)
        for existing, boundary in ((True, "save"), (True, "replace"), (True, "command"), (False, "replace"), (False, "command")):
            case = base / (str(existing) + "-" + boundary)
            target, source, binary, backup = (case / name for name in ("runtime", "source", "bin", "backup"))
            source.mkdir(parents=True)
            if existing:
                target.mkdir()
                (target / "personal").write_text("original runtime")
                inode = target.stat().st_ino
            interrupted = False

            def stage(package, destination, commands):
                (destination / "shell.qml").write_text("replacement")

            def interrupt(previous, destination):
                nonlocal interrupted
                result = replace(previous, destination)
                if not interrupted and (boundary == "save" and Path(previous) == target or boundary == "replace" and Path(destination) == target):
                    interrupted = True
                    raise SystemExit(143)
                return result

            def register(*args, **kwargs):
                assert boundary == "command"
                raise SystemExit(143)

            with patch.dict(scope, stage_runtime=stage), patch("os.replace", side_effect=interrupt), patch("subprocess.run", side_effect=register):
                try:
                    api["install_runtime"](source, target, binary, backup)
                except SystemExit as error:
                    assert error.code == 143
                else:
                    raise AssertionError("Interrupted runtime installation succeeded")
            if existing:
                assert target.stat().st_ino == inode and (target / "personal").read_text() == "original runtime"
            else:
                assert not target.exists(), "Interrupted fresh installation left a partial runtime"
            assert not list(case.glob(".bloodyShell-*")) and not (backup / "shell").exists()
    print("Runtime replacement restores original folders when interrupted immediately after either rename or during command registration.")


def startup_health_checks():
    """Exercise the readiness handshake through Quickshell's actual IPC transport."""
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    cli = runpy.run_path(str(ROOT / "scripts/bloodyShell"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-startup-") as temporary:
        base = Path(temporary)
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        (base / "version").write_text("1.2.3\n")
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    property bool initialized: false
    Timer { interval: 200; running: true; onTriggered: initialized = true }
    IpcHandler {
        target: "health"
        function status(): string { return JSON.stringify({ready: initialized, version: "1.2.3"}); }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(runtime))
        env.pop("WAYLAND_DISPLAY", None)
        with patch.dict(os.environ, env, clear=True), (base / "shell.log").open("w+") as log:
            process = subprocess.Popen([cli["quickshell"](), "-p", str(base), "--no-color"], env=env, stdout=log, stderr=log)
            try:
                assert api["verify_runtime"](cli, cli["quickshell"](), base, set(), timeout=5, stable=0.2), "New shell did not answer its readiness check"
                existing = {entry["id"] for entry in cli["instances"](cli["quickshell"](), base)}
                assert existing
                assert not api["verify_runtime"](cli, cli["quickshell"](), base, existing, timeout=0.5, stable=0.1), "Old running instance was accepted as the updated shell"
                (base / "version").write_text("1.2.4\n")
                assert not api["verify_runtime"](cli, cli["quickshell"](), base, set(), timeout=0.5, stable=0.1), "Wrong version passed the startup check"
            finally:
                process.terminate()
                process.wait(timeout=5)
                log.seek(0)
                print(log.read())
    print("Startup IPC verifies readiness, rejects preexisting instances and checks the running version.")


def unstable_startup_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    verify = api["verify_runtime"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-startup-policy-") as temporary:
        base = Path(temporary)
        (base / "version").write_text("1.2.3\n")
        for mode in ("stable", "crash", "not-ready", "crash-loop", "invalid", "timeout"):
            tick = [0.0]
            clock = lambda: tick[0]
            def sleep(delay): tick[0] += delay
            def instances(command, target):
                if mode == "crash" and tick[0] > 0.2:
                    return []
                return [dict(id=str(int(tick[0] * 10)) if mode == "crash-loop" else "fresh")]
            def reply(*args, **kwargs):
                if mode == "timeout":
                    raise subprocess.TimeoutExpired("qs ipc", 1)
                return subprocess.CompletedProcess([], 0, "invalid" if mode == "invalid" else json.dumps(dict(ready=mode != "not-ready", version="1.2.3")), "")
            with patch.dict(verify.__globals__["FILES"], run=reply), patch("time.monotonic", side_effect=clock), patch("time.sleep", side_effect=sleep):
                result = verify(dict(instances=instances), "qs", base, set(), timeout=1.2, stable=0.5)
            assert result == (mode == "stable"), mode
    print("Startup verification rejects short-lived/crash-looping instances, incomplete startup, malformed IPC and timeouts.")


def recovery_transaction_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    restore = api["restore_runtime"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-recovery-") as temporary:
        for boundary in ("success", "first-rename", "second-rename", "launcher", "stop"):
            base = Path(temporary) / boundary
            target, binary, backup = base / "shell", base / "bin", base / "backup"
            for folder in (target, binary, backup / "shell", backup / "launcher"):
                folder.mkdir(parents=True)
            (target / "marker").write_text("rejected release")
            (backup / "shell/marker").write_text("working release")
            (binary / "bloodyShell").write_text("rejected launcher")
            (backup / "launcher/command").write_text("working launcher")
            original_replace = os.replace
            interrupted = [False]
            def replace(source, destination):
                original_replace(source, destination)
                match = boundary == "first-rename" and Path(source) == target or boundary == "second-rename" and Path(destination) == target
                if match and not interrupted[0]:
                    interrupted[0] = True
                    raise SystemExit(143)
            def write(*args):
                if boundary == "launcher":
                    raise OSError("Launcher write failed")
                api["write_command"](*args)
            def stop(command, path, quiet):
                assert path == target and quiet
                if boundary == "stop":
                    raise RuntimeError("Stop failed")
            with patch("runpy.run_path", return_value=dict(stop=stop, quickshell=lambda: "qs")), patch("os.replace", side_effect=replace), patch.dict(restore.__globals__, write_command=write):
                try:
                    restore(target, binary, backup)
                except (SystemExit, OSError, RuntimeError):
                    assert boundary != "success", boundary
                else:
                    assert boundary == "success", boundary
            assert (target / "marker").read_text() == ("working release" if boundary == "success" else "rejected release"), boundary
            assert (backup / "shell/marker").read_text() == "working release"
            assert (binary / "bloodyShell").read_text() == ("working launcher" if boundary == "success" else "rejected launcher")
            assert not list(base.glob(".bloodyShell-*")), boundary
    print("Recovery keeps the previous backup and installed files safe across stop failures, interrupted renames and launcher errors.")


if __name__ == "__main__":
    run_checks()
    installation_flow_checks()
    runtime_transaction_checks()
    unstable_startup_checks()
    recovery_transaction_checks()
    startup_health_checks()
