"""niri configuration edits and bundled config imports."""

from pathlib import Path
import fcntl
import json
import os
import re
import runpy
import shutil
import signal
import subprocess
import sys

FILES = runpy.run_path(str(Path(__file__).resolve().parent.parent / "files.py"))
INFO = {"id":"niri", "name":"niri", "resource":"dots/niri", "config":"niri", "command":"niri"}

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
    # Lock the directory itself so edits and validation stay serialized without a lock file.
    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        target, main_config = directory / name, config / "config.kdl"
        originals = {path: FILES["read_file"](path) for path in (target, main_config)}
        if callable(content):
            content = content(originals[target][0].decode("utf-8") if originals[target][0] is not None else "")
        accepted = False
        try:
            FILES["atomic_write"](target.resolve(), (content.rstrip("\n") + "\n").encode(), originals[target][1])
            if main_config.is_file():
                text = main_config.read_text()
                if not re.search(r'^\s*include\s+"bloodyShell/' + re.escape(name) + r'"', text, re.M):
                    FILES["atomic_write"](main_config.resolve(), (text.rstrip("\n") + '\n\ninclude "bloodyShell/' + name + '"\n').encode(), originals[main_config][1])
            if shutil.which("niri"):
                result = subprocess.run(["niri", "validate", "-c", str(main_config)], capture_output=True, text=True, timeout=10)
                if result.returncode:
                    raise ValueError("niri did not accept " + name + "; previous configuration restored")
            accepted = True
        finally:
            if not accepted:
                for path, original in originals.items():
                    if original[0] is None:
                        path.resolve().unlink(missing_ok=True)
                    else:
                        FILES["atomic_write"](path.resolve(), original[0], original[1])
    finally:
        os.close(descriptor)


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


def configuration_main():
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
            niri_write(input_file.name, lambda current: mouse_config(current, json.loads(sys.argv[2])))
            text = input_file.read_text()
        print(json.dumps(dict(available=available, mouse=mouse_settings(text))))
    elif len(sys.argv) == 3 and sys.argv[1] == "keyboard":
        niri_write(input_file.name, lambda current: keyboard_config(current, sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "write":
        niri_write(*sys.argv[2:])
    elif len(sys.argv) == 4 and sys.argv[1] == "cursor":
        directory = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "niri/bloodyShell"
        path = directory / "06-user-input.kdl"
        niri_write(path.name, lambda current: cursor_config(current, sys.argv[2], int(sys.argv[3])))
    else:
        raise ValueError("Usage: compositor config niri write USER_FILE CONTENT | cursor THEME SIZE | keyboard BLOCK | mouse-read | mouse JSON")
    return 0


def prepare(source, destination, staged):
    managed, user = NIRI_MANAGED, NIRI_USER
    if destination.is_dir():
        shutil.copytree(destination, staged, symlinks=True, dirs_exist_ok=True)
    fragment_dir = staged / "bloodyShell"
    if fragment_dir.is_symlink():
        original = (destination / "bloodyShell").resolve()
        fragment_dir.unlink()
        shutil.copytree(original, fragment_dir, symlinks=True)
    fragment_dir.mkdir(parents=True, exist_ok=True)
    for name in managed:
        template = source / "bloodyShell" / name
        if not template.is_file() or template.is_symlink():
            raise ValueError("Missing managed niri fragment: " + name)
        target = fragment_dir / name
        target.unlink(missing_ok=True)
        shutil.copy2(template, target)
    for name in user:
        target = fragment_dir / name
        if not target.exists() and not target.is_symlink():
            shutil.copy2(source / "bloodyShell" / name, target)
    loader = staged / "config.kdl"
    loader.unlink(missing_ok=True)
    loader.write_text("".join('include "bloodyShell/' + name + '"\n' for name in (*managed, *user)))
    if shutil.which("niri"):
        result = subprocess.run(["niri", "validate", "-c", str(loader)], capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise ValueError("niri rejected the imported configuration; current files were kept: " + result.stderr.strip())


