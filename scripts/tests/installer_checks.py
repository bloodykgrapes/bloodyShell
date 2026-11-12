#!/usr/bin/env python3

import json
import io
import signal
import time
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-installer-") as temporary:
        base = Path(temporary)
        package = base / "release"
        package.mkdir()
        (package / "version").write_text("9.8.7\n")
        (package / "shell.qml").write_text("release shell\n")
        (package / "setup").write_text("#!/bin/sh\nexit 99\n")
        (package / "__pycache__").mkdir()
        (package / "__pycache__/private.pyc").write_text("generated cache")
        (package / ".private").write_text("local state")
        (package / "local-notes.txt").write_text("private checkout notes")
        import shutil
        shutil.copytree(ROOT / "scripts/lib", package / "scripts/lib")
        shutil.copy2(ROOT / "scripts/bloodyShell", package / "scripts/bloodyShell")
        for folder in ("tests", "tools"):
            (package / "scripts" / folder).mkdir(parents=True)
        for folder, name in (("dots/wallpapers", "new.png"), ("dots/kitty", "kitty.conf"), ("dots/sddm", "Main.qml")):
            (package / folder).mkdir(parents=True)
            (package / folder / name).write_text("optional repository file")
        (package / "scripts/tests/development-check.py").write_text("development test\n")
        (package / "scripts/tools/icons-dark").write_text("development tool\n")
        archive = base / "release.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        binary = base / "bin"
        binary.mkdir()
        curl = binary / "curl"
        curl.write_text("#!/usr/bin/env python3\nimport os, shutil, sys\nshutil.copyfile(os.environ['TEST_RELEASE'], sys.argv[sys.argv.index('-o') + 1])\n")
        curl.chmod(0o700)
        home = base / "home"
        home.mkdir()
        (home / ".bashrc").write_text("export EXISTING_SETTING=kept\n")
        env = dict(os.environ, HOME=str(home), SHELL="/bin/bash", XDG_BIN_HOME=str(base / "commands"),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_DATA_HOME=str(base / "data"),
                   BLOODYSHELL_STATUS=str(base / "status"), TEST_RELEASE=str(archive), PATH=str(binary) + os.pathsep + os.environ["PATH"])
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

        def invoke(*args):
            return subprocess.run(["bash", str(ROOT / "setup"), *args], env=env, capture_output=True, text=True, timeout=10)

        result = invoke("update", "--tag", "v9.8.7")
        assert result.returncode == 0, result.stdout + result.stderr
        assert (target / "shell.qml").read_text() == "release shell\n"
        assert not (target / "dots/wallpapers").exists() and not (target / "dots").exists()
        assert (pictures / "personal.png").read_bytes() == b"personal wallpaper"
        assert settings.read_bytes() == original_settings, "Updates must preserve shell settings"
        assert not (pictures / "new.png").exists(), "Updates must not import newly bundled wallpapers"
        untouched = {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in pictures.iterdir()}
        assert not (target / "__pycache__").exists() and not (target / ".private").exists()
        assert not (target / "local-notes.txt").exists(), "Only declared runtime roots may be installed"
        assert (base / "status").read_text().strip() == "done 9.8.7"
        command = base / "commands/bloodyShell"
        assert command.is_file() and os.access(command, os.X_OK)
        assert not (base / "data/applications/bloodyShell.desktop").exists()
        assert (target / "scripts/bloodyShell").is_file()
        assert (target / "scripts/lib/management.py").is_file(), "Command installation must package the management module"
        assert (target / "scripts/lib/screenshot.py").is_file(), "Backend modules must be packaged"
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
        source = "\n".join('readonly PACKAGE="$TARGET"' if line.startswith("readonly PACKAGE=") else line for line in source.splitlines())
        repair.write_text(source + "\napply_shell\n")
        result = subprocess.run(["bash", str(repair)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (target / "shell.qml").read_text() == "release shell\n", "Repairing an installed copy must not move its own source"
        (target / "preserved.marker").write_text("previous installation")
        installed_launcher = (base / "commands/bloodyShell").read_bytes()
        manager = package / "scripts/lib/management.py"
        original_manager = manager.read_text()
        manager.write_text("def install_main():\n    return 1\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        failed_install = invoke("update", "--tag", "v9.8.7", "--force")
        assert failed_install.returncode != 0
        assert (target / "preserved.marker").read_text() == "previous installation", "Installation failure did not restore the previous shell"
        assert (base / "commands/bloodyShell").read_bytes() == installed_launcher
        assert not list((base / "config/quickshell").glob(".bloodyShell.new.*"))
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
            assert not list((base / "config/quickshell").glob(".bloodyShell.new.*"))
        # A fresh installation must also roll back when command registration fails.
        fresh_env = dict(env, HOME=str(base / "fresh home"), XDG_CONFIG_HOME=str(base / "fresh config"),
                         XDG_STATE_HOME=str(base / "fresh state"), XDG_CACHE_HOME=str(base / "fresh cache"), XDG_BIN_HOME=str(base / "fresh bin"))
        manager.write_text("def install_main():\n    return 1\n")
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        failed = subprocess.run(["bash", str(ROOT / "setup"), "update", "--tag", "v9.8.7"], env=fresh_env, capture_output=True, text=True, timeout=10)
        assert failed.returncode != 0 and not (base / "fresh config/quickshell/bloodyShell").exists()
        assert not list((base / "fresh config/quickshell").glob(".bloodyShell.new.*"))
        manager.write_text(original_manager)
        # Interrupt staging in its own process group, without touching a desktop.
        marker = base / "staging-started"
        python = binary / "python3"
        python.write_text("#!/usr/bin/python3\nimport os, sys, time\nfrom pathlib import Path\nif 'stage-runtime' in sys.argv:\n    Path(os.environ['TEST_STAGE_MARKER']).touch()\n    time.sleep(30)\nelse:\n    os.execv('/usr/bin/python3', ['/usr/bin/python3', *sys.argv[1:]])\n")
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
            assert not list((base / "config/quickshell").glob(".bloodyShell.new.*"))
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
        menu_script = base / "menu-check"
        menu_source = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
        menu_script.write_text(menu_source + '\nbanner() { :; }\nchoose() { CHOICE=3; }\ncmd_doctor() { echo DOCTOR_SELECTED; }\nmenu\n')
        selected = subprocess.run(["bash", str(menu_script)], env=env, capture_output=True, text=True, timeout=10)
        assert selected.returncode == 0 and "DOCTOR_SELECTED" in selected.stdout
        print("Installer commands, Doctor menu, diagnostics, updates, repair, invalid releases and temporary-file cleanup passed.")


if __name__ == "__main__":
    run_checks()
