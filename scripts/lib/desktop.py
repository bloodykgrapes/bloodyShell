"""Desktop integration: application shortcuts, autostart, niri and tray menus."""

from pathlib import Path
import ctypes
import errno
import json
import os
import re
import runpy
import select
import shutil
import signal
import stat
import subprocess
import sys


FILES = runpy.run_path(str(Path(__file__).with_name("files.py")))


def base_path(name, fallback):
    value = os.environ.get(name, "")
    return Path(value) if value and Path(value).is_absolute() else fallback


def path_list(name, fallback):
    values = os.environ.get(name) or fallback
    paths = list(dict.fromkeys(Path(value) for value in values.split(":") if value and Path(value).is_absolute()))
    return paths or [Path(value) for value in fallback.split(":")]


def config_paths():
    home = base_path("XDG_CONFIG_HOME", Path.home() / ".config")
    return list(dict.fromkeys([home / "autostart", *(path / "autostart" for path in path_list("XDG_CONFIG_DIRS", "/etc/xdg"))]))


def application_paths():
    home = base_path("XDG_DATA_HOME", Path.home() / ".local/share")
    return list(dict.fromkeys([home / "applications", *(path / "applications" for path in path_list("XDG_DATA_DIRS", "/usr/local/share:/usr/share"))]))


def desktop_name(value):
    if not value or "/" in value or "\\" in value or any(ord(char) < 32 or ord(char) == 127 for char in value) or not value.endswith(".desktop") or value == ".desktop":
        raise ValueError("Invalid desktop entry ID")
    return value


def fields(text):
    result = {}
    section = ""
    for line in text.lstrip("\ufeff").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section == "Desktop Entry" and line and not line.startswith("#"):
            key, separator, value = line.partition("=")
            if separator:
                result[key.strip()] = value.strip()
    return result


def edit(text, changes):
    lines = text.lstrip("\ufeff").splitlines(keepends=True)
    output = []
    section = ""
    pending = dict(changes)
    found = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if section == "Desktop Entry":
                if output and not output[-1].endswith("\n"):
                    output[-1] += "\n"
                output.extend(f"{key}={value}\n" for key, value in pending.items() if value is not None)
                pending.clear()
            section = stripped[1:-1]
            found = found or section == "Desktop Entry"
        if section == "Desktop Entry" and "=" in line and not stripped.startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in changes:
                value = pending.pop(key, None)
                if value is not None:
                    output.append(f"{key}={value}\n")
                continue
        output.append(line)
    if not found:
        raise ValueError("Missing Desktop Entry section")
    if pending:
        if output and not output[-1].endswith("\n"):
            output[-1] += "\n"
        output.extend(f"{key}={value}\n" for key, value in pending.items() if value is not None)
    return "".join(output)


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    mode = stat.S_IMODE(path.stat().st_mode) if path.is_file() and not path.is_symlink() else 0o644
    FILES["atomic_write"](path, text.encode(), mode)


def candidates():
    result = {}
    for directory in config_paths():
        if directory.is_dir():
            for path in sorted(directory.glob("*.desktop")):
                result.setdefault(path.name, []).append(path)
    return result


def unescape(value):
    escapes = {"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}
    return re.sub(r"\\([sntr\\])", lambda match: escapes[match[1]], value)


def localized(values, key):
    language = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG", "")
    language = re.sub(r"\.[^@]+", "", language)
    locale, _, modifier = language.partition("@")
    short = locale.split("_", 1)[0]
    locales = [language, locale, short + "@" + modifier if modifier else short, short]
    return unescape(next((values[f"{key}[{name}]"] for name in locales if f"{key}[{name}]" in values), values.get(key, "")))


def executable(value):
    value = unescape(value)
    return bool(shutil.which(value))


def entry(name, paths):
    user = config_paths()[0] / name
    system = next((path for path in paths if path.parent != user.parent), None)
    try:
        values = fields(read(paths[0]))
        try:
            fallback = fields(read(system)) if system else {}
        except (OSError, UnicodeError):
            fallback = {}
        masked = values.get("Hidden", "false").lower() == "true" and not values.get("Exec") and system is not None
        effective = dict(fallback, **values) if masked else values
        valid = effective.get("Type") == "Application" and bool(effective.get("Exec"))
        reason = "" if valid else "invalid"
        desktops = set(filter(None, os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")))
        only = set(filter(None, effective.get("OnlyShowIn", "").split(";")))
        excluded = set(filter(None, effective.get("NotShowIn", "").split(";")))
        if valid and ((only and not desktops.intersection(only)) or desktops.intersection(excluded)):
            reason = "desktop"
        elif valid and effective.get("TryExec") and not executable(effective["TryExec"]):
            reason = "executable"
        elif valid and effective.get("X-systemd-skip", "").lower() == "true":
            reason = "session"
        enabled = values.get("Hidden", "false").lower() != "true" and values.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
        return dict(id=name, appId=values.get("X-BloodyShell-AppId", name.removesuffix(".desktop")),
                    name=localized(values, "Name") or localized(fallback, "Name") or name.removesuffix(".desktop"),
                    icon=unescape(values.get("Icon", fallback.get("Icon", ""))),
                    command=values.get("Exec", fallback.get("Exec", "")), enabled=enabled, valid=valid, reason=reason,
                    system=system is not None, removable=paths[0].parent == user.parent and system is None)
    except (OSError, UnicodeError) as error:
        return dict(id=name, appId=name.removesuffix(".desktop"), name=name.removesuffix(".desktop"), icon="", command="",
                    enabled=False, valid=False, reason="invalid", system=system is not None,
                    removable=paths[0].parent == user.parent and system is None)


def session_status():
    if not shutil.which("systemctl"):
        return "unavailable"
    try:
        result = subprocess.run(["systemctl", "--user", "show", "xdg-desktop-autostart.target", "--property=ActiveState", "--value"],
                                capture_output=True, text=True, timeout=2)
        state = result.stdout.strip()
        if result.returncode == 0 and state in ("active", "activating", "inactive", "failed"):
            return "active" if state in ("active", "activating") else "inactive"
    except (OSError, subprocess.SubprocessError):
        pass
    return "unknown"


def status():
    entries = [entry(name, paths) for name, paths in candidates().items()]
    entries.sort(key=lambda item: (item["name"].casefold(), item["id"]))
    return dict(entries=entries, session=session_status())


def add(app_id):
    name = desktop_name(app_id if app_id.endswith(".desktop") else app_id + ".desktop")
    if name in candidates():
        raise ValueError("This application already has an autostart entry")
    source = None
    for directory in application_paths():
        direct = directory / name
        if direct.is_file():
            source = direct
            break
        if directory.is_dir():
            source = next((path for path in sorted(directory.rglob("*.desktop")) if path.is_file() and "-".join(path.relative_to(directory).parts) == name), None)
            if source:
                break
    if source is None:
        raise ValueError("The installed application desktop entry was not found")
    text = read(source)
    values = fields(text)
    if values.get("Type") != "Application" or not values.get("Exec") or values.get("Hidden", "false").lower() == "true":
        raise ValueError("This desktop entry cannot be added to autostart")
    text = edit(text, {"Hidden": "false", "X-GNOME-Autostart-enabled": "true", "X-BloodyShell-AppId": name.removesuffix(".desktop")})
    write(config_paths()[0] / name, text)


def set_enabled(name, enabled):
    name = desktop_name(name)
    paths = candidates().get(name, [])
    if not paths:
        raise ValueError("The autostart entry no longer exists")
    text = read(paths[0])
    values = fields(text)
    if enabled and not values.get("Exec"):
        system = next((path for path in paths if path.parent != config_paths()[0]), None)
        if system is not None:
            text = edit(read(system), values)
    if enabled and (fields(text).get("Type") != "Application" or not fields(text).get("Exec")):
        raise ValueError("This desktop entry cannot be enabled")
    changes = {"Hidden": "false" if enabled else "true"}
    if "X-GNOME-Autostart-enabled" in fields(text):
        changes["X-GNOME-Autostart-enabled"] = "true" if enabled else "false"
    write(config_paths()[0] / name, edit(text, changes))


def remove(name):
    name = desktop_name(name)
    paths = candidates().get(name, [])
    if not paths or not entry(name, paths)["removable"]:
        raise ValueError("Only user autostart entries without a system default can be removed")
    (config_paths()[0] / name).unlink()


def watch_paths():
    paths = set()
    for directory in config_paths():
        parent = directory
        while not parent.exists() and parent != parent.parent:
            parent = parent.parent
        paths.add(parent)
        if directory.is_dir():
            for path in directory.glob("*.desktop"):
                if path.is_symlink():
                    try:
                        target = path.resolve()
                    except (OSError, RuntimeError):
                        continue
                    if target.exists():
                        paths.add(target)
                    parent = target.parent
                    while not parent.exists() and parent != parent.parent:
                        parent = parent.parent
                    paths.add(parent)
    return paths


def watch():
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    ready = False
    while True:
        descriptor = libc.inotify_init1(os.O_CLOEXEC | os.O_NONBLOCK)
        if descriptor < 0:
            raise OSError(ctypes.get_errno(), "Could not watch autostart files")
        try:
            watching = 0
            for path in watch_paths():
                if libc.inotify_add_watch(descriptor, os.fsencode(path), 0x00000FCC) >= 0:
                    watching += 1
            if not watching:
                raise OSError(errno.ENOENT, "No autostart directories can be watched")
            if not ready:
                print("ready", flush=True)
                ready = True
            select.select([descriptor], [], [])
            os.read(descriptor, 65536)
            print("changed", flush=True)
        finally:
            os.close(descriptor)


def autostart_main():
    args = sys.argv[1:]
    if args == ["watch"]:
        watch()
        return
    if args == ["list"]:
        pass
    elif len(args) == 2 and args[0] == "add":
        add(args[1])
    elif len(args) == 3 and args[0] == "set" and args[2] in ("true", "false"):
        set_enabled(args[1], args[2] == "true")
    elif len(args) == 2 and args[0] == "remove":
        remove(args[1])
    else:
        raise ValueError("Usage: autostart list | add <application-id> | set <entry-id> true/false | remove <entry-id> | watch")
    print(json.dumps(status()))

DEFAULT_APPLICATION_TYPES = {
    "browser": ("x-scheme-handler/http", "x-scheme-handler/https"),
    "file-manager": ("inode/directory",),
    "terminal": (),
}
DEFAULT_APPLICATION_SETTINGS = {"browser": "applicationBrowser", "file-manager": "applicationFileManager", "terminal": "applicationTerminal"}


def application_libraries():
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        raise RuntimeError("Install the Python GObject bindings to manage applications") from None
    return Gio, GLib


def default_applications(Gio):
    groups = {role: [] for role in DEFAULT_APPLICATION_TYPES}
    for app in Gio.AppInfo.get_all():
        if not app.should_show() or not app.get_id():
            continue
        categories = set((app.get_categories() or "").split(";")) if hasattr(app, "get_categories") else set()
        types = set(app.get_supported_types() or [])
        if "WebBrowser" in categories or types.intersection(DEFAULT_APPLICATION_TYPES["browser"]):
            groups["browser"].append(app)
        if "FileManager" in categories:
            groups["file-manager"].append(app)
        if "TerminalEmulator" in categories:
            groups["terminal"].append(app)
    for apps in groups.values():
        apps.sort(key=lambda app: (app.get_display_name().casefold(), app.get_id()))
    config = base_path("XDG_CONFIG_HOME", Path.home() / ".config") / "bloodyShell/settings.json"
    settings = json.loads(config.read_text()) if config.is_file() else {}
    if not isinstance(settings, dict):
        raise ValueError("Shell settings must contain a JSON object")
    selected = {}
    for role, apps in groups.items():
        current = Gio.AppInfo.get_default_for_type(DEFAULT_APPLICATION_TYPES[role][0], False) if role != "terminal" else None
        app_id = settings.get(DEFAULT_APPLICATION_SETTINGS[role], "") or (current.get_id() if current else "")
        selected[role] = next((app.get_id() for app in apps if app.get_id() == app_id), apps[0].get_id() if apps else "")
    return groups, selected


def applications_action(Gio):
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "removal":
        plan = application_removal(Gio, args[1])
        management = runpy.run_path(str(Path(__file__).with_name("management.py")))
        plan["terminal"] = management["terminal"]()
        if not plan["terminal"]:
            raise RuntimeError("Install a terminal to uninstall applications")
        print(json.dumps(plan))
        return 0
    if len(args) == 3 and args[0] == "remove":
        try:
            plan = application_removal(Gio, args[1])
            if plan["target"] != args[2]:
                raise RuntimeError("The application's package changed. Open its Delete dialog again")
            return subprocess.run(plan["command"]).returncode
        finally:
            if sys.stdin.isatty():
                try:
                    input("\nPress Enter to close…")
                except (EOFError, KeyboardInterrupt):
                    pass
    if args != ["status"] and not (len(args) == 2 and args[0] == "launch" and args[1] in DEFAULT_APPLICATION_TYPES):
        raise ValueError("Usage: applications status | launch <role> | removal <app-id> | remove <app-id> <target>")
    groups, selected = default_applications(Gio)
    if args[0] == "launch":
        role = args[1]
        app = next((app for app in groups[role] if app.get_id() == selected[role]), None)
        if app is None:
            raise RuntimeError("No installed application found for " + role)
        files = [Gio.File.new_for_path(str(Path.home()))] if role == "file-manager" else []
        if not app.launch(files, None):
            raise RuntimeError("Could not launch " + app.get_display_name())
        return 0
    print(json.dumps(dict(applications={role: [dict(id=app.get_id(), name=app.get_display_name()) for app in apps]
                                        for role, apps in groups.items()}, current=selected)))
    return 0


def application_removal(Gio, app_id):
    name = desktop_name(app_id if app_id.endswith(".desktop") else app_id + ".desktop")
    app = Gio.DesktopAppInfo.new(name)
    if app is None or not app.get_filename():
        raise ValueError("The application is no longer installed")
    path = Path(app.get_filename())
    flatpak_id = fields(read(path)).get("X-Flatpak", "")
    if flatpak_id and re.fullmatch(r"[A-Za-z0-9_]+(?:\.[A-Za-z0-9_-]+){2,}", flatpak_id):
        roots = ((base_path("XDG_DATA_HOME", Path.home() / ".local/share") / "flatpak", "--user"), (Path("/var/lib/flatpak"), "--system"))
        for root, scope in roots:
            if path.resolve().is_relative_to(root / "app" / flatpak_id):
                result = subprocess.run(["flatpak", "info", scope, "--show-ref", flatpak_id], capture_output=True, text=True, timeout=10)
                ref = result.stdout.strip()
                if result.returncode or not re.fullmatch(r"app/" + re.escape(flatpak_id) + r"/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", ref):
                    raise ValueError("Could not identify the installed Flatpak application")
                return dict(package=flatpak_id, manager="Flatpak", target=scope + ":" + ref,
                            command=["flatpak", "uninstall", scope, "--no-related", ref])
    management = runpy.run_path(str(Path(__file__).with_name("management.py")))
    distro = management["family"]()
    queries = {"arch": ["pacman", "-Qoq", "--", str(path)],
               "debian": ["dpkg-query", "-S", str(path)],
               "fedora": ["rpm", "-qf", "--qf", "%{NAME}\\n", "--", str(path)]}
    if distro not in queries:
        raise ValueError("Application removal is not supported on this distribution")
    result = subprocess.run(queries[distro], capture_output=True, text=True, timeout=10)
    packages = result.stdout.splitlines() if result.returncode == 0 else []
    if distro == "debian":
        packages = [line.rpartition(": ")[0] for line in packages if line.rpartition(": ")[2] == str(path)]
    packages = list(dict.fromkeys(packages))
    if len(packages) != 1 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+_.:@-]*", packages[0]):
        raise ValueError("No installed package owns this launcher. Remove this application using its original installer")
    package = packages[0]
    managers = {"arch": "pacman", "debian": "apt-get", "fedora": "dnf"}
    manager = managers[distro]
    return dict(package=package, manager=manager, target=manager + ":" + package,
                command=["sudo", manager, "-R" if distro == "arch" else "remove", "--", package])


def applications_main():
    Gio, GLib = application_libraries()
    try:
        return applications_action(Gio)
    except GLib.Error as error:
        raise RuntimeError(str(error)) from None


def tray_menu_main():
    """Read exported tray actions even when an app advertises /NO_DBUSMENU."""
    from gi.repository import Gio, GLib
    import time

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    properties = "org.freedesktop.DBus.Properties"
    interface = "com.canonical.dbusmenu"

    def call(service, path, iface, method, signature, args, timeout=1000):
        return bus.call_sync(service, path, iface, method, GLib.Variant(signature, args),
                             None, Gio.DBusCallFlags.NONE, timeout, None).unpack()

    def endpoint(owner, path):
        if not Gio.dbus_is_unique_name(owner) or not GLib.Variant.is_object_path(path):
            raise ValueError("Invalid tray menu address")

    def entries(node, depth=0):
        if depth > 12:
            raise ValueError("Tray menu nesting is too deep")
        result = []
        for child in node[2]:
            identifier, props, children = child
            if not props.get("visible", True):
                continue
            nested = entries(child, depth + 1)
            toggle = props.get("toggle-type", "")
            state = props.get("toggle-state", 0)
            result.append(dict(id=identifier, text=re.sub(r"_(.)", r"\1", props.get("label", "")),
                               enabled=props.get("enabled", True), isSeparator=props.get("type") == "separator",
                               icon=props.get("icon-name", ""), buttonType={"checkmark": 1, "radio": 2}.get(toggle, 0),
                               checkState=2 if state == 1 else 1 if state == -1 else 0,
                               hasChildren=bool(children) or props.get("children-display") == "submenu", children=nested))
        return result

    action, *args = sys.argv[1:]
    if action == "open" and len(args) == 2:
        identifier, title = args
        addresses = call("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", properties, "Get", "(ss)",
                         ("org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"))[0]
        matches = []
        deadline = time.monotonic() + 4
        for address in addresses[:128]:
            if time.monotonic() >= deadline:
                raise RuntimeError("Tray item discovery timed out")
            service, slash, suffix = address.partition("/")
            path = "/" + suffix if slash else "/StatusNotifierItem"
            try:
                owner = call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", "(s)", (service,), 500)[0]
                values = call(owner, path, properties, "GetAll", "(s)", ("org.kde.StatusNotifierItem",), 500)[0]
            except GLib.Error:
                continue
            if values.get("Id") == identifier and values.get("Title", "") == title:
                matches.append((owner, path, values))
        if len(matches) != 1:
            raise RuntimeError("Tray item is unavailable or ambiguous")
        owner, item_path, values = matches[0]
        # Some apps attach their exported actions only after this notification.
        # The shell reads the resulting DBusMenu; it never displays a platform menu.
        call(owner, item_path, "org.kde.StatusNotifierItem", "ContextMenu", "(ii)", (0, 0))
        path = values.get("Menu", "")
        if not path or path in ("/", "/NO_DBUSMENU"):
            path = item_path.rstrip("/") + "/Menu"
    elif action == "read" and len(args) == 2:
        owner, path = args
    elif action == "activate" and len(args) == 3:
        owner, path, identifier = args
        endpoint(owner, path)
        call(owner, path, interface, "Event", "(isvu)", (int(identifier), "clicked", GLib.Variant("i", 0), 0))
        return 0
    else:
        raise ValueError("Usage: tray-menu open ID TITLE | read OWNER PATH | activate OWNER PATH ITEM")
    endpoint(owner, path)
    if action == "open":
        try:
            call(owner, path, interface, "AboutToShow", "(i)", (0,))
        except GLib.Error:
            pass
    _, layout = call(owner, path, interface, "GetLayout", "(iias)", (0, -1, ["label", "enabled", "visible", "type", "icon-name", "toggle-type", "toggle-state", "children-display"]))
    print(json.dumps(dict(owner=owner, path=path, items=entries(layout))))
    return 0
