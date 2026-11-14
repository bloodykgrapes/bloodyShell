"""Compositor backend selection and configuration commands."""

from pathlib import Path
import json
import os
import runpy
import sys

BACKENDS = {"niri": "niri.py"}
DEFAULT = "niri"


def load(name=DEFAULT):
    if name not in BACKENDS:
        raise ValueError("Unsupported compositor: " + name)
    return runpy.run_path(str(Path(__file__).parent / BACKENDS[name]))


def detect():
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":")
    return "niri" if os.environ.get("NIRI_SOCKET") or "niri" in desktop else ""


def main():
    args = sys.argv[1:]
    if args and args[0] == "info" and len(args) <= 2:
        print(json.dumps(load(args[1] if len(args) == 2 else detect())["INFO"]))
        return 0
    if len(args) >= 3 and args[0] == "config":
        backend = load(args[1])
        sys.argv = [sys.argv[0], *args[2:]]
        return backend["configuration_main"]()
    if len(args) == 3 and args[0] == "cursor":
        name = detect()
        if not name:
            return 0
        backend = load(name)
        config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        if (config / backend["INFO"]["config"] / "bloodyShell").is_dir():
            sys.argv = [sys.argv[0], *args]
            return backend["configuration_main"]()
        return 0
    raise ValueError("Usage: compositor info [name] | config <name> <operation> [arguments] | cursor <theme> <size>")
