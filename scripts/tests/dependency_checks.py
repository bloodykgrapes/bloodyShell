#!/usr/bin/env python3

import json
from pathlib import Path
import runpy
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    entries = api["catalog"]()
    assert len(entries) > 20 and len({entry["tool"] for entry in entries}) == len(entries)
    assert next(entry for entry in entries if entry["tool"] == "bluetoothd")["arch"] == "bluez"
    with patch("shutil.which", side_effect=lambda tool: None if tool == "lsblk" else "/usr/bin/" + tool):
        assert not api["available"]("findmnt"), "A partial utility installation was accepted"
    with patch("shutil.which", return_value=None), patch("pathlib.Path.is_file", return_value=False):
        assert not api["available"]("bluetoothd")
    with patch("shutil.which", return_value=None), patch("pathlib.Path.is_file", autospec=True, side_effect=lambda path: str(path) == "/usr/lib/bluetooth/bluetoothd"):
        assert api["available"]("bluetoothd"), "BlueZ daemon outside PATH was not detected"
    plan = api["plan"]
    setup = runpy.run_path(str(ROOT / "scripts/lib/setup.py"))
    for family in ("arch", "fedora", "debian"):
        groups = api["installer_packages"](family)
        assert groups["audio"] == ["playerctl"]
        assert groups["brightness"] == ["brightnessctl"]
        assert set(groups["printer"]) == {"cups", "system-config-printer"}
        assert "cava" not in groups["audio"] and "wlsunset" not in groups["brightness"]
        minimal = setup["make_plan"]([], family=family)
        keyboard = setup["make_plan"](["input"], family=family)
        login = setup["make_plan"](["login"], family=family)
        assert keyboard["selected"] == ["input"]
        assert login["selected"] == ["input", "login"]
        assert set(groups["input"]) <= set(keyboard["packages"])
        assert set(minimal["packages"]) <= set(keyboard["packages"])
        assert "base-devel" not in minimal["packages"]
    data = api["package_data"]()
    with tempfile.TemporaryDirectory(prefix="bloodyShell-catalog-") as temporary:
        root = Path(temporary)
        (root / "assets").mkdir()
        path = root / "assets/packages.json"
        path.write_text(json.dumps(data))
        assert api["package_data"](root) == data
        data["installer"]["options"][0]["packages"]["arch"].append("$(touch forbidden)")
        path.write_text(json.dumps(data))
        try:
            api["package_data"](root)
            raise AssertionError("Unsafe package metadata was accepted")
        except ValueError:
            pass
    assert next(entry for entry in entries if entry["tool"] == "easyeffects")["kind"] == "optional"
    for language in ("en", "ru"):
        strings = json.loads((ROOT / "translations" / (language + ".json")).read_text())["strings"]
        for entry in entries:
            if entry["kind"] == "optional":
                assert strings["settings.packages." + entry["tool"]].strip(), "Optional package lacks a description"
    with patch.dict(api["dependencies_status"].__globals__, family=lambda: "arch", available=lambda tool: False, terminal=lambda: []):
        status = api["dependencies_status"]()["entries"]
        calls = []
        with patch.dict(api["dependencies_status"].__globals__, available=lambda tool: calls.append(tool) or False):
            optional = api["dependencies_status"]("optional")["entries"]
            assert all(not entry["required"] for entry in optional)
            assert set(calls) == {entry["tool"] for entry in optional}, "Optional checks probe required dependencies"
        assert all(entry["feature"] for entry in status), "Dependency metadata lost feature descriptions"
        assert all(not entry["removable"] for entry in status if entry["required"]), "Required dependencies can be removed"
    with patch("shutil.which", side_effect=lambda tool: "/usr/bin/quickshell" if tool == "quickshell" else None):
        assert api["available"]("qs"), "Diagnostics rejected the supported quickshell executable name"
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
