#!/usr/bin/env python3

from pathlib import Path
import runpy
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    entries = api["catalog"]()
    assert len(entries) > 20 and len({entry["tool"] for entry in entries}) == len(entries)
    plan = api["plan"]
    assert next(entry for entry in entries if entry["tool"] == "easyeffects")["kind"] == "optional"
    for distro in ("arch", "fedora", "debian"):
        for entry in entries:
            if entry["kind"] == "required" or entry["tool"] == "python3":
                try:
                    plan("remove", entry["tool"], distro)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Required dependency removal was permitted")
    assert plan("install", "cava", "debian") == [["sudo", "apt-get", "install", "cava"]]
    assert plan("remove", "cava", "debian") == [["sudo", "apt-get", "remove", "cava"]]
    assert plan("install", "qs", "fedora") == [["sudo", "dnf", "copr", "enable", "errornointernet/quickshell"], ["sudo", "dnf", "install", "quickshell"]]
    assert plan("remove", "cava", "arch") == [["sudo", "pacman", "-R", "cava"]]
    with patch("subprocess.run") as run:
        run.return_value.returncode = 0
        assert plan("install", "cava", "arch") == [["sudo", "pacman", "-S", "--needed", "cava"]]
        assert run.call_args.args[0] == ["pacman", "-Si", "cava"]
    for action, tool, distro in (("install", "$(touch forbidden)", "debian"), ("remove", "unknown", "arch"), ("install", "awww", "fedora"), ("invalid", "cava", "debian")):
        try:
            plan(action, tool, distro)
        except ValueError:
            pass
        else:
            raise AssertionError((action, tool, distro))
    print("Dependency catalog and package operation checks passed without changing packages.")


if __name__ == "__main__":
    run_checks()
