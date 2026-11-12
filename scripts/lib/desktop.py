"""Desktop integrations: autostart, niri configuration and exported tray menus."""

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
import tempfile


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
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.is_file() and not path.is_symlink() else 0o644
    handle, temporary = tempfile.mkstemp(prefix=".bloodyShell-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as output:
            os.fchmod(output.fileno(), mode)
            output.write(text)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


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

# Transactional edits to bloodyShell's niri fragments.

NIRI_MANAGED = ("00-environment.kdl", "01-layout.kdl", "02-window.kdl", "03-layer.kdl", "04-binds.kdl")
NIRI_USER = ("05-user.kdl", "06-user-input.kdl", "07-user-output.kdl")


def niri_write(name, content):
    if name not in NIRI_USER:
        raise ValueError("Shell settings may only write user niri fragments: " + name)
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "niri"
    directory = config / "bloodyShell"
    if not directory.is_dir():
        raise ValueError("The bloodyShell niri configuration is not installed")
    api = runpy.run_path(str(Path(__file__).with_name("ownership.py")))
    target, main_config = directory / name, config / "config.kdl"
    originals = {path: api["snapshot"](path) for path in (target, main_config)}
    accepted = False
    try:
        api["atomic"](target.resolve(), (content.rstrip("\n") + "\n").encode(), originals[target]["mode"])
        if main_config.is_file():
            text = main_config.read_text()
            if not re.search(r'^\s*include\s+"bloodyShell/' + re.escape(name) + r'"', text, re.M):
                api["atomic"](main_config.resolve(), (text.rstrip("\n") + '\n\ninclude "bloodyShell/' + name + '"\n').encode(), originals[main_config]["mode"])
        if shutil.which("niri"):
            result = subprocess.run(["niri", "validate", "-c", str(main_config)], capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise ValueError("niri did not accept " + name + "; previous configuration restored")
        accepted = True
    finally:
        if not accepted:
            import base64
            for path, original in originals.items():
                if original["data"] is None:
                    path.resolve().unlink(missing_ok=True)
                else:
                    api["atomic"](path.resolve(), base64.b64decode(original["data"]), original["mode"])


def kdl_mask(text, strings=True):
    """Mask strings/comments without changing positions, for conservative node edits."""
    result = list(text)
    i = 0
    while i < len(text):
        start = i
        comment = text.startswith(("//", "/*"), i)
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
        elif text.startswith("/*", i):
            depth = 1
            i += 2
            while i < len(text) and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
        else:
            raw = re.match(r'(?:r(#+)?|(#+))"', text[i:])
            if raw:
                hashes = raw.group(1) or raw.group(2) or ""
                opening = i + len(raw.group()) - 1
                quote = '"""' if text.startswith('"""', opening) else '"'
                end = text.find(quote + hashes, opening + len(quote))
                i = len(text) if end < 0 else end + len(quote) + len(hashes)
            elif text[i] == '"':
                quote = '"""' if text.startswith('"""', i) else '"'
                i += len(quote)
                while i < len(text):
                    if text[i] == "\\":
                        i += 2
                    elif text.startswith(quote, i):
                        i += len(quote)
                        break
                    else:
                        i += 1
            else:
                i += 1
                continue
        for index in range(start, min(i, len(text))) if strings or comment else ():
            if result[index] != "\n":
                result[index] = " "
    return "".join(result)


MOUSE_DEFAULTS = dict(speed=0.0, profile="adaptive", naturalScroll=False, leftHanded=False,
                      scrollHorizontal=1.0, scrollVertical=1.0, middleEmulation=False)
MOUSE_NODES = {"speed": "accel-speed", "profile": "accel-profile", "naturalScroll": "natural-scroll",
               "leftHanded": "left-handed", "middleEmulation": "middle-emulation",
               "scrollHorizontal": "scroll-factor", "scrollVertical": "scroll-factor"}


def kdl_block(text, name, parent=None):
    mask = kdl_mask(text)
    start, end = (parent[1] + 1, parent[2] - 1) if parent else (0, len(text))
    for match in re.finditer(r"\b" + re.escape(name) + r"\s*\{", mask[start:end]):
        offset = start + match.start()
        prefix = mask[start:offset]
        if prefix.count("{") != prefix.count("}") or prefix.rstrip().endswith("/-"):
            continue
        opening = start + match.end() - 1
        depth, close = 1, opening + 1
        while close < end and depth:
            if mask[close] == "{": depth += 1
            elif mask[close] == "}": depth -= 1
            close += 1
        if depth:
            raise ValueError("Unclosed " + name + " configuration")
        return offset, opening, close
    return None


def mouse_nodes(text):
    outer = kdl_block(text, "input")
    block = kdl_block(text, "mouse", outer) if outer else None
    if not block:
        return outer, None, []
    start, end = block[1] + 1, block[2] - 1
    mask, comments = kdl_mask(text), kdl_mask(text, strings=False)
    nodes = []
    for match in re.finditer(r"(?:^|(?<=[;\n{}]))[ \t]*(/-\s*)?([a-zA-Z][\w-]*)\b[^;\n{}]*", mask[start:end]):
        prefix = mask[start:start + match.start(2)]
        if match.group(1) or prefix.count("{") != prefix.count("}"):
            continue
        first = start + match.start(2)
        last = start + match.end()
        last = first + len(comments[first:last].rstrip())
        nodes.append((match.group(2), first, last, comments[first + len(match.group(2)):last].strip()))
    return outer, block, nodes


def mouse_settings(text):
    values = dict(MOUSE_DEFAULTS)
    _, _, nodes = mouse_nodes(text)
    for name, _, _, value in nodes:
        if name == "accel-speed": values["speed"] = float(value)
        elif name == "accel-profile":
            raw = re.fullmatch(r'(?:r)?(#+)"(.*)"\1', value)
            values["profile"] = raw.group(2) if raw else json.loads(value)
        elif name == "scroll-factor":
            number = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
            base = re.match(r"^(" + number + r")(?:\s|$)", value)
            values["scrollHorizontal"] = values["scrollVertical"] = float(base.group(1)) if base else 1.0
            for axis, key in (("horizontal", "scrollHorizontal"), ("vertical", "scrollVertical")):
                match = re.search(r"\b" + axis + r"\s*=\s*(" + number + r")", value)
                if match: values[key] = float(match.group(1))
        else:
            key = next((key for key, node in MOUSE_NODES.items() if node == name), None)
            if key in ("naturalScroll", "leftHanded", "middleEmulation"): values[key] = True
    return values


def mouse_config(text, changes):
    import math
    if not isinstance(changes, dict) or not changes or any(key not in MOUSE_NODES for key in changes):
        raise ValueError("Unknown mouse setting")
    for key, value in changes.items():
        if key == "profile": valid = value in ("flat", "adaptive")
        elif isinstance(MOUSE_DEFAULTS[key], bool): valid = isinstance(value, bool)
        else:
            limit = 1 if key == "speed" else 10
            valid = type(value) in (int, float) and math.isfinite(value) and -limit <= value <= limit
        if not valid: raise ValueError("Invalid mouse setting: " + key)
    outer, block, nodes = mouse_nodes(text)
    values = mouse_settings(text) | changes
    selected = {MOUSE_NODES[key] for key in changes}
    lines = []
    for name in dict.fromkeys(MOUSE_NODES.values()):
        if name not in selected: continue
        if name == "scroll-factor": lines.append(f'scroll-factor horizontal={values["scrollHorizontal"]} vertical={values["scrollVertical"]}')
        else:
            key = next(key for key, node in MOUSE_NODES.items() if node == name)
            if isinstance(values[key], bool):
                if values[key]: lines.append(name)
            else: lines.append(name + " " + json.dumps(values[key]))
    if block:
        rendered = {line.split()[0]: line for line in lines}
        first_nodes = {}
        for name, first, _, _ in nodes: first_nodes.setdefault(name, first)
        for name, first, last, _ in reversed(nodes):
            if name not in selected: continue
            replacement = rendered.get(name, "") if first_nodes[name] == first else ""
            if not replacement:
                if text[last:last + 1] == ";": last += 1
                line_start = text.rfind("\n", 0, first) + 1
                line_end = text.find("\n", last)
                if line_end < 0: line_end = len(text)
                if not text[line_start:first].strip() and not text[last:line_end].strip():
                    first, last = line_start, min(line_end + 1, len(text))
            text = text[:first] + replacement + text[last:]
        missing = [line for line in lines if line.split()[0] not in first_nodes]
        if not missing: return text
        _, block, _ = mouse_nodes(text)
        opening_line = text[text.rfind("\n", 0, block[0]) + 1:block[0]]
        indent = opening_line if not opening_line.strip() else "    "
        close = block[2] - 1
        line_start = text.rfind("\n", 0, close) + 1
        if not text[line_start:close].strip():
            return text[:line_start] + "".join(indent + "    " + line + "\n" for line in missing) + text[line_start:]
        return text[:close] + "\n" + "\n".join(indent + "    " + line for line in missing) + "\n" + indent + text[close:]
    body = "\n".join("        " + line for line in lines)
    mouse = "\n    mouse {\n" + body + "\n    }\n"
    if outer: return text[:outer[2] - 1] + mouse + text[outer[2] - 1:]
    return text.rstrip() + "\n\ninput {" + mouse + "}\n"


def cursor_block(text):
    return kdl_block(text, "cursor")


def cursor_config(text, theme, size):
    if not isinstance(theme, str) or not theme or any(c in theme for c in "\n\r\x00") or not 1 <= size <= 256:
        raise ValueError("Invalid cursor settings")
    span = cursor_block(text)
    values = '    xcursor-theme ' + json.dumps(theme, ensure_ascii=False) + '\n    xcursor-size ' + str(size) + '\n'
    if span is None:
        return text.rstrip() + "\n\ncursor {\n" + values + "}\n"
    _, opening, close = span
    mask = kdl_mask(text)
    body = text[opening + 1:close - 1]
    body_mask = mask[opening + 1:close - 1]
    # Only replace these two node values; preserve other cursor options and input data.
    for match in reversed(list(re.finditer(r"(?m)(?:^|(?<=;))[ \t]*xcursor-(?:theme|size)\b[^\n;{}]*(?:;)?", body_mask))):
        body = body[:match.start()] + body[match.end():]
    return text[:opening + 1] + "\n" + body.strip("\n") + "\n" + values + text[close - 1:]


def keyboard_config(text, content):
    import textwrap
    content = textwrap.dedent(content).strip()
    span = kdl_block(content, "keyboard")
    if span is None or span[0] != 0 or span[2] != len(content):
        raise ValueError("Invalid keyboard block")
    outer = kdl_block(text, "input")
    keyboard = kdl_block(text, "keyboard", outer) if outer else None
    if keyboard:
        prefix = text[text.rfind("\n", 0, keyboard[0]) + 1:keyboard[0]]
        indent = prefix if not prefix.strip() else "    "
        return text[:keyboard[0]] + content.replace("\n", "\n" + indent) + text[keyboard[2]:]
    block = "    " + content.replace("\n", "\n    ") + "\n"
    if outer: return text[:outer[2] - 1] + "\n" + block + text[outer[2] - 1:]
    return text.rstrip() + "\n\ninput {\n" + block + "}\n"


def niri_main():
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, terminate)
    directory = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "niri/bloodyShell"
    input_file = directory / "06-user-input.kdl"
    if sys.argv[1:] == ["mouse-read"] or len(sys.argv) == 3 and sys.argv[1] == "mouse":
        available = directory.is_dir() and (directory.parent / "config.kdl").is_file() and shutil.which("niri") is not None
        text = input_file.read_text() if input_file.exists() else ""
        if sys.argv[1] == "mouse":
            if not available: raise ValueError("Mouse settings are unavailable: niri configuration is not installed")
            niri_write(input_file.name, mouse_config(text, json.loads(sys.argv[2])))
            text = input_file.read_text()
        print(json.dumps(dict(available=available, mouse=mouse_settings(text))))
    elif len(sys.argv) == 3 and sys.argv[1] == "keyboard":
        text = input_file.read_text() if input_file.exists() else ""
        niri_write(input_file.name, keyboard_config(text, sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "write":
        niri_write(*sys.argv[2:])
    elif len(sys.argv) == 4 and sys.argv[1] == "cursor":
        directory = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "niri/bloodyShell"
        path = directory / "06-user-input.kdl"
        text = path.read_text() if path.exists() else ""
        niri_write(path.name, cursor_config(text, sys.argv[2], int(sys.argv[3])))
    else:
        raise ValueError("Usage: niri-config write USER_FILE CONTENT | cursor THEME SIZE | keyboard BLOCK | mouse-read | mouse JSON")
    return 0


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
