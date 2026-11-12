"""Private command registry. All UI and installer helpers enter here."""

import os
import runpy
import signal
import subprocess
import sys

MODULES = {
    "autostart": ("desktop.py", "autostart_main"),
    "niri-config": ("desktop.py", "niri_main"),
    "tray-menu": ("desktop.py", "tray_menu_main"),
    "build-keyboard-monitor": ("processes.py", "keyboard_main"),
    "build-virtual-keyboard": ("processes.py", "virtual_keyboard_main"),
    "visualizer": ("processes.py", "visualizer_main"),
    "dependencies": ("management.py", "dependencies_main"),
    "doctor": ("management.py", "doctor_main"),
    "install-command": ("management.py", "install_main"),
    "stage-runtime": ("management.py", "stage_main"),
    "extract-release": ("management.py", "release_main"),
    "uninstall": ("management.py", "uninstall_main"),
    "greeter-settings": ("resources.py", "greeter_main"),
    "resources": ("resources.py", "resources_main"),
    "wallpaper": ("resources.py", "wallpaper_main"),
    "network-auth": ("network.py", None),
    "screenshot": ("screenshot.py", None),
    "storage": ("storage.py", None),
    "appearance": ("appearance.sh", None),
}


def supervise(command, timeout=None):
    """Forward shutdown to an owned process group and reap it before cleanup."""
    child = subprocess.Popen(["setpriv", "--pdeathsig", "TERM", *command], start_new_session=True)
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    previous = {sig: signal.signal(sig, terminate) for sig in (signal.SIGTERM, signal.SIGHUP)}
    try:
        return child.wait(timeout=timeout)
    finally:
        try:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


def dispatch(args, root):
    domain, *arguments = args
    if domain not in MODULES:
        raise RuntimeError("Unknown internal command: " + domain)
    filename, entrypoint = MODULES[domain]
    module = root / "scripts/lib" / filename
    ownership = runpy.run_path(str(root / "scripts/lib/ownership.py"))
    with ownership["track"](domain, arguments):
        if module.suffix == ".sh":
            return supervise(["bash", str(module), *arguments], timeout=60)
        previous = sys.argv
        try:
            sys.argv = [str(module), *arguments]
            if entrypoint:
                api = runpy.run_path(str(module))
                handler = api.get(entrypoint)
                if handler is None:
                    raise RuntimeError("Incomplete backend module: " + filename)
                return handler()
            runpy.run_path(str(module), run_name="__main__")
        finally:
            sys.argv = previous
    return 0
