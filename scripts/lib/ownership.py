"""Conservative inventory and disposal of explicitly owned, disposable data.

User settings, backups, imported files and system integrations are never removed.
No paths supplied by the caller are accepted for cleanup.
"""

import argparse
import base64
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile


def atomic(path, data, mode=0o600):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def snapshot(path):
    target = path.resolve()
    if not target.exists():
        return dict(target=str(target), data=None, mode=0o600)
    if not target.is_file() or target.stat().st_size > 4 * 1024 * 1024:
        raise RuntimeError("Cannot safely track configuration: " + str(path))
    return dict(target=str(target), data=base64.b64encode(target.read_bytes()).decode(), mode=stat.S_IMODE(target.stat().st_mode))


def integration_paths(domain):
    r = roots()
    config = r["config"]
    if domain == "autostart":
        return list((config / "autostart").glob("*.desktop"))
    paths = [config / name for name in (
        "gtk-3.0/settings.ini", "gtk-4.0/settings.ini", "qt6ct/qt6ct.conf",
        "niri/config.kdl",
    )]
    paths += list((config / "niri/bloodyShell").glob("*.kdl"))
    paths += [config / "niri/bloodyShell" / name for name in ("05-user.kdl", "06-user-input.kdl", "07-user-output.kdl")]
    portal_names = [name.lower() + "-portals.conf" for name in os.environ.get("XDG_CURRENT_DESKTOP", "").split(":") if name and all(c.isalnum() or c in "_.-" for c in name)]
    paths += [config / "xdg-desktop-portal" / name for name in ["portals.conf", *portal_names]]
    paths.append(Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "icons/default/index.theme")
    return list(dict.fromkeys(paths))


def settings_snapshot():
    values = {}
    for key in ("color-scheme", "icon-theme", "cursor-theme", "cursor-size", "font-name"):
        result = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key], capture_output=True, text=True, timeout=3)
        if result.returncode == 0:
            values[key] = result.stdout.strip()
    return values


@contextmanager
def journal(write=True):
    directory = roots()["state"] / "bloodyShell"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not safe(directory) or directory.stat().st_uid != os.getuid():
        raise RuntimeError("Unsafe ownership state directory")
    directory.chmod(0o700)
    lock_fd = os.open(directory / "changes.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = directory / "changes.json"
        if path.is_symlink():
            raise RuntimeError("Unsafe ownership journal")
        changes = json.loads(path.read_text()) if path.exists() else {"files": {}, "settings": {}}
        try:
            yield changes
        finally:
            if write:
                atomic(path, (json.dumps(changes, indent=2) + "\n").encode())


@contextmanager
def track(domain, arguments):
    """Record only explicit writes; read-only startup does not create a journal."""
    mutation = bool(arguments) and (
        domain == "appearance" and arguments[0] in ("set", "apply") or
        domain == "niri-config" and arguments[0] in ("write", "cursor", "mouse", "keyboard") or
        domain == "autostart" and arguments[0] in ("add", "set", "remove")
    )
    if not mutation:
        yield
        return
    with journal() as changes:
        paths = integration_paths(domain)
        before = {str(path): snapshot(path) for path in paths}
        settings = settings_snapshot() if domain == "appearance" and shutil.which("gsettings") else {}
        try:
            yield
        finally:
            for path in set(paths + integration_paths(domain)):
                name = str(path)
                old = before.get(name, dict(target=str(path.resolve()), data=None, mode=0o600))
                new = snapshot(path)
                if old == new:
                    continue
                previous = changes["files"].get(name)
                original = previous["before"] if previous and previous["after"] == old else old
                changes["files"][name] = dict(before=original, after=new)
            after_settings = settings_snapshot() if settings else {}
            for key, old in settings.items():
                new = after_settings.get(key)
                if new is not None and old != new:
                    previous = changes["settings"].get(key)
                    original = previous["before"] if previous and previous["after"] == old else old
                    changes["settings"][key] = dict(before=original, after=new)


def restore(args):
    parser = argparse.ArgumentParser(description="Restore tracked integrations only when they have not been edited since")
    parser.add_argument("--apply", action="store_true")
    options = parser.parse_args(args)
    path = roots()["state"] / "bloodyShell/changes.json"
    if not path.exists():
        print("No tracked integrations to restore.")
        return 0
    conflicts = False
    with journal(write=options.apply) as changes:
        for name, entry in list(changes["files"].items()):
            target = Path(name)
            if snapshot(target) != entry["after"]:
                print("Preserved edited file: " + name)
                conflicts = True
                continue
            print("Restore: " + name)
            if options.apply:
                original = entry["before"]
                if original["target"] != str(target.resolve()):
                    print("Preserved changed symlink: " + name)
                    conflicts = True
                    continue
                if original["data"] is None:
                    target.resolve().unlink(missing_ok=True)
                else:
                    atomic(target.resolve(), base64.b64decode(original["data"]), original["mode"])
                del changes["files"][name]
        current = settings_snapshot() if changes["settings"] and shutil.which("gsettings") else {}
        for key, entry in list(changes["settings"].items()):
            if current.get(key) != entry["after"]:
                print("Preserved edited setting: " + key)
                conflicts = True
                continue
            print("Restore setting: " + key)
            if options.apply:
                subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, entry["before"]], check=True)
                del changes["settings"][key]
    if not options.apply:
        print("Preview only. Use restore --apply to restore unchanged tracked integrations.")
    return int(conflicts)


def roots():
    home = Path.home()
    return {
        "config": Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config"),
        "cache": Path(os.environ.get("XDG_CACHE_HOME") or home / ".cache"),
        "state": Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state"),
        "runtime": Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()),
    }


def private_runtime():
    root = roots()["runtime"] / ("bloodyShell" if os.environ.get("XDG_RUNTIME_DIR") else "bloodyShell-" + str(os.getuid()))
    if root.is_symlink():
        raise ValueError("Refusing a symlink for runtime storage")
    root.mkdir(mode=0o700, exist_ok=True)
    info = root.stat()
    if info.st_uid != os.getuid() or not stat.S_ISDIR(info.st_mode):
        raise ValueError("Runtime storage is not owned by this user")
    root.chmod(0o700)
    return root


def safe(path):
    """Reject links anywhere in the path, including XDG directory overrides."""
    return path.is_absolute() and all(not item.is_symlink() for item in (path, *path.parents))


def inventory():
    r = roots()
    runtime = r["runtime"] / ("bloodyShell" if os.environ.get("XDG_RUNTIME_DIR") else "bloodyShell-" + str(os.getuid()))
    disposable = [runtime, r["cache"] / "bloodyShell/keyboard", r["cache"] / "bloodyShell/virtual-keyboard"]
    cache = r["cache"] / "bloodyShell"
    disposable += [cache / "update.log", cache / "update.status"]
    if safe(cache) and cache.is_dir():
        disposable += sorted(cache.glob("update-*.status"))
    rows = [dict(path=str(path), kind="disposable", exists=path.exists() or path.is_symlink(), safe=safe(path)) for path in disposable]
    for path, kind in [
        (r["config"] / "bloodyShell", "settings"),
        (r["cache"] / "bloodyShell", "cache and persistent update markers"),
        (Path(os.environ.get("XDG_BIN_HOME") or Path.home() / ".local/bin") / "bloodyShell", "launcher"),
        (r["config"] / "quickshell/bloodyShell", "installation"),
        (r["state"] / "bloodyShell", "state and backups"),
        (r["config"] / "niri/bloodyShell", "compositor integration"),
        (r["config"] / "environment.d/90-bloodyShell-qt.conf", "Qt environment integration"),
        (r["config"] / "environment.d/90-bloodyShell-path.conf", "user service PATH"),
        (r["config"] / "fish/conf.d/bloodyShell-path.fish", "Fish PATH"),
        (Path("/var/lib/bloodyShell"), "shared greeter images and settings"),
        (Path("/usr/share/sddm/themes/bloodyShell"), "system greeter"),
        (Path("/etc/sddm.conf.d/zz-bloodyShell.conf"), "SDDM integration"),
    ]:
        rows.append(dict(path=str(path), kind=kind, exists=path.exists() or path.is_symlink(), safe=False))
    return rows


def main(action, args):
    parser = argparse.ArgumentParser(description="Inspect owned data; cleanup preserves settings, backups and integrations")
    parser.add_argument("--json", action="store_true")
    if action == "cleanup":
        parser.add_argument("--apply", action="store_true", help="remove the listed disposable data after stopping the shell")
    options = parser.parse_args(args)
    rows = [row for row in inventory() if row["exists"] and (action != "cleanup" or row["kind"] == "disposable")]
    if action == "cleanup" and options.apply:
        cleanup_owned(rows)
    if options.json:
        print(json.dumps(rows, indent=2))
    else:
        for row in rows:
            print(row["kind"] + ": " + row["path"])
        if action == "cleanup":
            print("Disposable data removed." if options.apply else "Preview only. Stop bloodyShell, then use cleanup --apply to remove these paths.")
        else:
            print("External appearance settings, autostart entries, imported configs, saved screenshots, PAM, fstab and sddm changes are preserved.")
    return 0


def cleanup_owned(rows=None):
    if rows is None:
        rows = [row for row in inventory() if row["exists"] and row["kind"] == "disposable"]
    if any(not row["safe"] for row in rows):
        raise RuntimeError("Cleanup refused: a disposable path contains a symlink")
    for row in rows:
        path = Path(row["path"])
        if path.stat().st_uid != os.getuid():
            raise RuntimeError("Cleanup refused: data belongs to another user: " + str(path))
    for row in rows:
        path = Path(row["path"])
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
