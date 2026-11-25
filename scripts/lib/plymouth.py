"""Read installed Plymouth themes and apply one with the system theme tool."""

import argparse
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys


THEMES = Path("/usr/share/plymouth/themes")
THEME_ID = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*")
PREVIEWS = runpy.run_path(str(Path(__file__).with_name("plymouth_preview.py")))


def system_tool(name):
    for directory in ("/usr/bin", "/usr/sbin", "/bin", "/sbin"):
        path = Path(directory) / name
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    return ""


def run(command, timeout=None):
    result = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                            errors="replace", env=dict(os.environ, LC_ALL="C"), timeout=timeout)
    if result.returncode:
        details = (result.stderr.strip() or result.stdout.strip()).splitlines()
        raise RuntimeError(details[-1] if details else f"{Path(command[0]).name} exited with status {result.returncode}")
    return result.stdout.strip()


def installed_themes(selector):
    names = run([selector, "--list"], timeout=10).splitlines()
    return dict.fromkeys(name for name in map(str.strip, names) if THEME_ID.fullmatch(name))


def alternatives_themes(alternatives, directory):
    current, themes = "", {}
    if alternatives and (directory / "default.plymouth").is_symlink():
        output = run([alternatives, "--query", "default.plymouth"], timeout=10)
        for line in output.splitlines():
            key, _, value = line.partition(": ")
            path = Path(value)
            if key == "Value":
                current = path.stem
            elif key == "Alternative" and path.suffix == ".plymouth" and path.is_file() and path.resolve().is_relative_to(directory.resolve()):
                themes[path.stem] = path
    return current, themes


def settings(action, choice=None, directory=THEMES):
    selector = system_tool("plymouth-set-default-theme")
    auth = system_tool("pkexec")
    installed = bool(selector or system_tool("plymouth"))
    alternatives, rebuild = "", []
    current, paths = "", {}
    if selector:
        paths = {name: directory / name / (name + ".plymouth") for name in installed_themes(selector)}
        current = run([selector], timeout=10)
    elif installed:
        alternatives = system_tool("update-alternatives")
        current, paths = alternatives_themes(alternatives, directory)
        if initramfs := system_tool("update-initramfs"):
            rebuild = [initramfs, "-u", "-k", "all"]
        elif dracut := system_tool("dracut"):
            rebuild = [dracut, "--regenerate-all", "--force"]

    can_apply = bool(auth and (selector or (alternatives and rebuild)))
    if action == "apply":
        if not can_apply:
            raise ValueError("Plymouth, administrator authorization and an initramfs tool are required.")
        if choice not in paths:
            raise ValueError("Choose an installed Plymouth theme.")
        if selector:
            run([auth, selector, "--rebuild-initrd", choice])
            current = run([selector], timeout=10)
        else:
            run([auth, alternatives, "--set", "default.plymouth", str(paths[choice])])
            run([auth, *rebuild])
            current, _ = alternatives_themes(alternatives, directory)
        if current != choice:
            raise RuntimeError("Plymouth did not report the selected theme as active.")

    system = PREVIEWS["distribution"]()
    themes = [PREVIEWS["theme_info"](name, path, system) for name, path in paths.items()]
    return {"installed": installed, "canApply": can_apply, "current": current,
            "themes": sorted(themes, key=lambda theme: (theme["name"].casefold(), theme["id"]))}


def main():
    parser = argparse.ArgumentParser(description="Plymouth boot theme settings")
    parser.add_argument("action", choices=("status", "apply"))
    parser.add_argument("theme", nargs="?")
    args = parser.parse_args()
    try:
        print(json.dumps(settings(args.action, args.theme)))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
