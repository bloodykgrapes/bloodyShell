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
        archive = base / "release.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="release")
        binary = base / "bin"
        binary.mkdir()
        curl = binary / "curl"
        curl.write_text("#!/usr/bin/env python3\nimport os, shutil, sys\nshutil.copyfile(os.environ['TEST_RELEASE'], sys.argv[sys.argv.index('-o') + 1])\n")
        curl.chmod(0o700)
        env = dict(os.environ, XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
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
        assert invoke("update", "--tag", "v9.8.7").returncode == 0
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
        print("Installer commands, Doctor menu position, diagnostics, and isolated release update passed.")


if __name__ == "__main__":
    run_checks()
