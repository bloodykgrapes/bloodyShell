#!/usr/bin/env python3

import json
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
        for folder in ("runtime", "setup", "tests", "tools"):
            (package / "scripts" / folder).mkdir(parents=True)
        (package / "scripts/runtime/screenshot").write_bytes((ROOT / "scripts/runtime/screenshot").read_bytes())
        (package / "scripts/runtime/screenshot").chmod(0o755)
        (package / "scripts/setup/greetd-keyring.awk").write_bytes((ROOT / "scripts/setup/greetd-keyring.awk").read_bytes())
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
                   XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
                   BLOODYSHELL_STATUS=str(base / "status"), TEST_RELEASE=str(archive), PATH=str(binary) + os.pathsep + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)

        def invoke(*args):
            return subprocess.run(["bash", str(ROOT / "setup"), *args], env=env, capture_output=True, text=True, timeout=10)

        result = invoke("update", "--tag", "v9.8.7")
        assert result.returncode == 0, result.stdout + result.stderr
        target = base / "config/quickshell/bloodyShell"
        assert (target / "shell.qml").read_text() == "release shell\n"
        assert not (target / "__pycache__").exists() and not (target / ".private").exists()
        assert (base / "status").read_text().strip() == "done 9.8.7"
        command = base / "commands/bloodyShell"
        assert command.is_file() and os.access(command, os.X_OK)
        assert (target / "scripts/bloodyShell").is_file(), "Older releases retain the command wrapper"
        assert (target / "scripts/setup/install-command").is_file(), "Command installation must support nested helpers"
        assert (target / "scripts/setup/greetd-keyring.awk").is_file()
        assert os.access(target / "scripts/runtime/screenshot", os.X_OK), "Runtime helpers must retain executable permissions"
        assert not (target / "scripts/tests").exists() and not (target / "scripts/tools").exists(), "Installed shells must exclude development tests and tools"
        assert "EXISTING_SETTING=kept" in (home / ".bashrc").read_text()
        assert list((home / "bloodyShell.bak").glob("*/launcher/bashrc"))
        assert invoke("update", "--tag", "v9.8.7").returncode == 0
        first_rc = (home / ".bashrc").read_text()
        assert invoke("update", "--tag", "v9.8.7", "--force").returncode == 0
        assert (home / ".bashrc").read_text() == first_rc, "PATH registration must be idempotent"
        info = subprocess.run([str(command), "path"], env=env, capture_output=True, text=True, timeout=5)
        assert info.returncode == 0 and info.stdout.strip() == str(target), info.stderr
        repair = base / "repair"
        source = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
        source = "\n".join('readonly PACKAGE="$TARGET"' if line.startswith("readonly PACKAGE=") else line for line in source.splitlines())
        repair.write_text(source + "\napply_shell\n")
        result = subprocess.run(["bash", str(repair)], env=env, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (target / "shell.qml").read_text() == "release shell\n", "Repairing an installed copy must not move its own source"
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
        for command in ("apply", "greeter", "keyring", "remove-sddm", "unknown"):
            assert invoke(command).returncode != 0, command
        for arguments in (("update", "--tag"), ("install", "unexpected"), ("greetd", "unexpected"), ("help", "unexpected")):
            assert invoke(*arguments).returncode != 0, arguments
        for command in ("install", "update", "doctor", "configs", "greetd", "help"):
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
