"""niri configuration edits and bundled config imports."""

from pathlib import Path
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

NIRI_MANAGED = ("01-environment.kdl", "02-animations.kdl", "03-layer.kdl", "04-layout.kdl",
                "05-window.kdl", "06-input.kdl", "07-binds.kdl")
SETTINGS_FILE = "08-settings.kdl"
USER_FILE = "09-user.kdl"
NIRI_USER = (SETTINGS_FILE, USER_FILE)
INFO["files"] = ("config.kdl", *("bloodyShell/" + name for name in (*NIRI_MANAGED, *NIRI_USER)))


# Lock the parent directory, which stays in place while an import replaces the config.
configuration_lock = FILES["directory_lock"]


def niri_write(directory, edit):
    config = directory.parent
    if not config.parent.is_dir():
        raise ValueError("The bloodyShell niri configuration is not installed")
    name = SETTINGS_FILE
    with configuration_lock(config.parent):
        if not directory.is_dir():
            raise ValueError("The bloodyShell niri configuration is not installed")
        target, main_config = directory / name, config / "config.kdl"
        originals = {path: FILES["read_file"](path) for path in (target, main_config)}
        loader = (originals[main_config][0] or b"").decode("utf-8")
        if re.search(r'^\s*include\s+"bloodyShell/(?:06-user-input|07-user-output)\.kdl"', loader, re.M):
            raise ValueError("Import the current compositor configuration from Settings → Updates before changing niri settings")
        content = edit((originals[target][0] or b"").decode("utf-8"))
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
        return content


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
                      scrollHorizontal=1.0, scrollVertical=1.0, middleEmulation=False,
                      scrollMethod="", scrollButton=-1, scrollButtonLock=False)
MOUSE_NODES = {"speed": "accel-speed", "profile": "accel-profile", "naturalScroll": "natural-scroll",
               "leftHanded": "left-handed", "middleEmulation": "middle-emulation",
               "scrollHorizontal": "scroll-factor", "scrollVertical": "scroll-factor",
               "scrollMethod": "scroll-method", "scrollButton": "scroll-button", "scrollButtonLock": "scroll-button-lock"}


def kdl_blocks(text, name, parent=None, argument=""):
    mask = kdl_mask(text)
    search = kdl_mask(text, strings=False) if argument else mask
    start, end = (parent[1] + 1, parent[2] - 1) if parent else (0, len(text))
    pattern = r"(?:^|(?<=[;\n{}]))[ \t]*(" + re.escape(name) + r")" + argument + r"\s*\{"
    for match in re.finditer(pattern, search[start:end]):
        offset, opening = start + match.start(1), start + match.end() - 1
        prefix = mask[start:offset]
        if prefix.count("{") != prefix.count("}") or prefix.rstrip().endswith("/-"):
            continue
        if mask[offset:offset + len(name)] != name or mask[opening] != "{":
            continue
        depth, close = 1, opening + 1
        while close < end and depth:
            depth += (mask[close] == "{") - (mask[close] == "}")
            close += 1
        if depth:
            raise ValueError("Unclosed " + name + " configuration")
        yield (offset, opening, close), match.groups()[1:]


def kdl_block(text, name, parent=None):
    return next((span for span, _ in kdl_blocks(text, name, parent)), None)


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


def mouse_settings(text, defaults=""):
    values = dict(MOUSE_DEFAULTS)
    _, block, nodes = mouse_nodes(text)
    if block is None and defaults:
        _, _, nodes = mouse_nodes(defaults)
    for name, _, _, value in nodes:
        if name == "accel-speed": values["speed"] = float(value)
        elif name in ("accel-profile", "scroll-method"):
            raw = re.fullmatch(r'(?:r)?(#+)"(.*)"\1', value)
            values["profile" if name == "accel-profile" else "scrollMethod"] = raw.group(2) if raw else json.loads(value)
        elif name == "scroll-button": values["scrollButton"] = int(value, 0)
        elif name == "scroll-factor":
            number = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
            base = re.match(r"^(" + number + r")(?:\s|$)", value)
            values["scrollHorizontal"] = values["scrollVertical"] = float(base.group(1)) if base else 1.0
            for axis, key in (("horizontal", "scrollHorizontal"), ("vertical", "scrollVertical")):
                match = re.search(r"\b" + axis + r"\s*=\s*(" + number + r")", value)
                if match: values[key] = float(match.group(1))
        else:
            key = next((key for key, node in MOUSE_NODES.items() if node == name), None)
            if key in ("naturalScroll", "leftHanded", "middleEmulation", "scrollButtonLock"): values[key] = True
    return values


def mouse_config(text, changes, defaults=""):
    import math
    if not isinstance(changes, dict) or not changes or any(key not in MOUSE_NODES for key in changes):
        raise ValueError("Unknown mouse setting")
    for key, value in changes.items():
        if key == "profile": valid = value in ("flat", "adaptive")
        elif key == "scrollMethod": valid = value in ("", "no-scroll", "on-button-down", "two-finger", "edge")
        elif key == "scrollButton": valid = type(value) is int and -1 <= value <= 0xffff
        elif isinstance(MOUSE_DEFAULTS[key], bool): valid = isinstance(value, bool)
        else:
            limit = 1 if key == "speed" else 10
            valid = type(value) in (int, float) and math.isfinite(value) and -limit <= value <= limit
        if not valid: raise ValueError("Invalid mouse setting: " + key)
    outer, block, nodes = mouse_nodes(text)
    if block is None and defaults:
        # A new mouse block replaces the bundled block as a whole.
        _, bundled, _ = mouse_nodes(defaults)
        if bundled:
            inherited = "\n    " + defaults[bundled[0]:bundled[2]] + "\n"
            text = (text[:outer[2] - 1] + inherited + text[outer[2] - 1:] if outer
                    else text.rstrip() + "\n\ninput {" + inherited + "}\n")
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
            elif key in ("scrollMethod", "scrollButton") and values[key] == MOUSE_DEFAULTS[key]:
                continue
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


TOUCHPAD_DEFAULTS = dict(ignoreWhileTyping=True, ignoreExternalMouse=False)
TOUCHPAD_NODES = {"ignoreWhileTyping": "dwt", "ignoreExternalMouse": "disabled-on-external-mouse"}


def touchpad_nodes(text):
    outer = kdl_block(text, "input")
    block = kdl_block(text, "touchpad", outer) if outer else None
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


def touchpad_settings(text, defaults=""):
    values = dict(TOUCHPAD_DEFAULTS)
    _, block, nodes = touchpad_nodes(text)
    if block is None and defaults:
        _, _, nodes = touchpad_nodes(defaults)
    enabled = {name for name, _, _, value in nodes if value.split()[0:1] not in (["false"], ["0"])}
    for key, name in TOUCHPAD_NODES.items():
        values[key] = name in enabled
    return values


def touchpad_config(text, changes, defaults=""):
    if not isinstance(changes, dict) or not changes or any(key not in TOUCHPAD_NODES for key in changes):
        raise ValueError("Unknown touchpad setting")
    if any(type(value) is not bool for value in changes.values()):
        raise ValueError("Invalid touchpad setting")

    outer, block, nodes = touchpad_nodes(text)
    if block is None and defaults:
        _, bundled, _ = touchpad_nodes(defaults)
        if bundled:
            inherited = "\n    " + defaults[bundled[0]:bundled[2]] + "\n"
            text = (text[:outer[2] - 1] + inherited + text[outer[2] - 1:] if outer
                    else text.rstrip() + "\n\ninput {" + inherited + "}\n")
            outer, block, nodes = touchpad_nodes(text)

    values = touchpad_settings(text) | changes
    selected = {TOUCHPAD_NODES[key] for key in changes}
    if block:
        for name, first, last, _ in reversed(nodes):
            if name not in selected:
                continue
            if text[last:last + 1] == ";":
                last += 1
            line_start = text.rfind("\n", 0, first) + 1
            line_end = text.find("\n", last)
            if line_end < 0:
                line_end = len(text)
            if not text[line_start:first].strip() and not text[last:line_end].strip():
                first, last = line_start, min(line_end + 1, len(text))
            text = text[:first] + text[last:]

        outer, block, nodes = touchpad_nodes(text)
        existing = {name for name, _, _, _ in nodes}
        missing = [name for key, name in TOUCHPAD_NODES.items() if values[key] and name not in existing]
        if missing:
            close = block[2] - 1
            line_start = text.rfind("\n", 0, close) + 1
            indent = text[line_start:close]
            if not indent.strip():
                indent = "    "
            return text[:line_start] + "".join(indent + "    " + name + "\n" for name in missing) + text[line_start:]
        return text

    lines = [name for key, name in TOUCHPAD_NODES.items() if values[key]]
    if not lines:
        return text
    body = "\n".join("        " + line for line in lines)
    touchpad = "\n    touchpad {\n" + body + "\n    }\n"
    if outer:
        return text[:outer[2] - 1] + touchpad + text[outer[2] - 1:]
    return text.rstrip() + "\n\ninput {" + touchpad + "}\n"


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


def output_blocks(text):
    argument = r'\s+(?:"((?:\\.|[^"\\])*)"|r?(#+)"(.*?)"\3)'
    for (start, _, end), (quoted, _, raw) in kdl_blocks(text, "output", argument=argument):
        name = json.loads('"' + quoted + '"') if quoted is not None else raw
        yield name, start, end


def outputs_config(text, content):
    updates = {}
    last = 0
    for name, start, end in output_blocks(content):
        if content[last:start].strip() or name in updates:
            raise ValueError("Invalid display configuration")
        updates[name] = content[start:end]
        last = end
    if content[last:].strip():
        raise ValueError("Invalid display configuration")
    for name, start, end in reversed(list(output_blocks(text))):
        if name in updates:
            text = text[:start] + updates.pop(name) + text[end:]
    return "\n\n".join(part for part in (text.rstrip(), *updates.values()) if part)


def replace_named_block(text, name, replacement):
    spans = list(kdl_blocks(text, name))
    for start, _, end in reversed(spans):
        text = text[:start] + text[end:]
    if replacement:
        text = text.rstrip() + "\n\n" + replacement + "\n"
    return text


def replace_global_window_rule(text, replacement):
    for start, opening, end in reversed(list(kdl_blocks(text, "window-rule"))):
        body = text[opening + 1:end - 1]
        if re.search(r"(?m)^\s*match\b", kdl_mask(body)):
            continue
        text = text[:start] + text[end:]
    return text.rstrip() + "\n\n" + replacement + "\n"


def window_settings_config(text, changes):
    import math
    if not isinstance(changes, dict):
        raise ValueError("Invalid window settings")

    bools = ("centerFocused", "centerSingle", "clip", "animate", "blurBehind")
    integers = {"gaps": (0, 64), "radius": (0, 20), "borderMode": (0, 2), "borderWidth": (1, 8), "animationStyle": (0, 2)}
    numbers = {"overviewSize": (0.25, 1.5), "focusOpacity": (0.5, 1.0),
               "unfocusedOpacity": (0.5, 1.0), "animationSpeed": (0.25, 2.0)}
    colors = ("borderColor", "focusColor")

    values = {}
    for key, value in changes.items():
        if key in bools:
            if not isinstance(value, bool): raise ValueError("Invalid window setting")
            values[key] = value
        elif key in integers:
            low, high = integers[key]
            if type(value) is not int or not low <= value <= high: raise ValueError("Invalid window setting")
            values[key] = value
        elif key in numbers:
            low, high = numbers[key]
            if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
                raise ValueError("Invalid window setting")
            values[key] = float(value)
        elif key in colors:
            if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?", value):
                raise ValueError("Invalid window color")
            values[key] = value
        else:
            raise ValueError("Unknown window setting")

    def get(key, fallback):
        return values.get(key, fallback)

    mode = get("borderMode", 0)
    width = get("borderWidth", 2)
    border_color = get("borderColor", "#ffffff")
    focus_color = get("focusColor", "#ffffff")
    centered = get("centerFocused", False) or get("centerSingle", False)
    focus_lines = ["        off"] if mode == 0 else [
        "        width " + str(width),
        '        active-color "' + focus_color + '"',
        '        inactive-color "' + focus_color + '"'
    ]
    border_lines = ["        off"] if mode != 2 else [
        "        width " + str(width),
        '        active-color "' + border_color + '"',
        '        inactive-color "' + border_color + '"',
        '        urgent-color "' + border_color + '"'
    ]
    layout = "\n".join([
        "layout {",
        "    gaps " + str(get("gaps", 10)),
        '    center-focused-column "' + ("always" if centered else "never") + '"',
        "    focus-ring {", *focus_lines, "    }",
        "    border {", *border_lines, "    }",
        "}"
    ])
    overview = "overview {\n    zoom " + str(round(get("overviewSize", 0.75), 3)) + "\n}"

    style, animate = get("animationStyle", 0), get("animate", True)
    if not animate or style == 2:
        animations = "animations {\n    off\n}"
    else:
        speed = get("animationSpeed", 1.0)
        slowdown = round(1.0 / speed, 3)
        if style == 1:
            open_lines = ["    window-open {", "        duration-ms 340", '        curve "cubic-bezier" 0.18 0.92 0.24 1.0', "    }"]
            close_lines = ["    window-close {", "        duration-ms 220", '        curve "cubic-bezier" 0.4 0.0 0.7 0.2', "    }"]
            movement = "    window-movement {\n        spring damping-ratio=0.62 stiffness=620 epsilon=0.0001\n    }"
            resize = "    window-resize {\n        spring damping-ratio=0.72 stiffness=650 epsilon=0.0001\n    }"
        else:
            open_lines = ["    window-open {", "        duration-ms 240", '        curve "cubic-bezier" 0.05 0.7 0.1 1.0', "    }"]
            close_lines = ["    window-close {", "        duration-ms 170", '        curve "cubic-bezier" 0.2 0.0 0.0 1.0', "    }"]
            movement = "    window-movement {\n        spring damping-ratio=0.92 stiffness=850 epsilon=0.0001\n    }"
            resize = "    window-resize {\n        spring damping-ratio=1.0 stiffness=850 epsilon=0.0001\n    }"
        animations = "\n".join(["animations {", "    slowdown " + str(slowdown), *open_lines, *close_lines, movement, resize, "}"])

    opacity = round(get("unfocusedOpacity", 1.0), 3)
    focus_opacity = round(get("focusOpacity", 1.0), 3)
    rule = "\n".join([
        "window-rule {",
        "    geometry-corner-radius " + str(get("radius", 16)),
        "    clip-to-geometry " + ("true" if get("clip", True) else "false"),
        "    opacity " + str(opacity),
        "    draw-border-with-background false",
        "}",
        "window-rule {",
        "    match is-active=true",
        "    opacity " + str(focus_opacity),
        "}"
    ])

    blur = "\n".join([
        "blur {",
        "    passes 3",
        "    offset 3.3",
        "    noise 0.02",
        "    saturation 1.3",
        "}"
    ]) if get("blurBehind", True) else ""

    text = replace_named_block(text, "layout", layout)
    text = replace_named_block(text, "overview", overview)
    text = replace_named_block(text, "animations", animations)
    text = replace_named_block(text, "blur", blur)
    return replace_global_window_rule(text, rule)


def pointer_settings_config(text, changes):
    if not isinstance(changes, dict):
        raise ValueError("Invalid pointer settings")
    allowed = ("focusFollowsPointer", "pointerJumpsToFocus")
    values = {}
    for key, value in changes.items():
        if key not in allowed or not isinstance(value, bool):
            raise ValueError("Invalid pointer setting")
        values[key] = value

    names = ("focus-follows-mouse", "warp-mouse-to-focus")
    outer = kdl_block(text, "input")
    if outer:
        start, opening, close = outer
        body_start, body_end = opening + 1, close - 1
        mask = kdl_mask(text)
        skeleton = kdl_mask(text, strings=False)
        nodes = []
        pattern = r"(?:^|(?<=[;\n{}]))[ \t]*(/-\s*)?([a-zA-Z][\w-]*)\b"
        for match in re.finditer(pattern, skeleton[body_start:body_end]):
            prefix = skeleton[body_start:body_start + match.start(2)]
            if match.group(1) or prefix.count("{") != prefix.count("}"):
                continue
            first = body_start + match.start(2)
            depth, last = 0, first
            while last < body_end:
                char = skeleton[last]
                if char == "{": depth += 1
                elif char == "}":
                    depth -= 1
                    if depth <= 0: last += 1; break
                elif char in ";\n" and depth == 0:
                    last += 1
                    break
                last += 1
            if mask[first:first + len(match.group(2))] == match.group(2):
                nodes.append((match.group(2), first, last))
        for name, first, last in reversed(nodes):
            if name not in names:
                continue
            line_start = text.rfind("\n", 0, first) + 1
            line_end = text.find("\n", last)
            if line_end < 0: line_end = len(text)
            if not text[line_start:first].strip(): first = line_start
            if not text[last:line_end].strip(): last = min(line_end + 1, len(text))
            text = text[:first] + text[last:]

    lines = []
    if values.get("focusFollowsPointer", False):
        lines.append('focus-follows-mouse max-scroll-amount="0%"')
    if values.get("pointerJumpsToFocus", False):
        lines.append("warp-mouse-to-focus")
    if not lines:
        return text

    outer = kdl_block(text, "input")
    if outer:
        start, opening, close = outer
        prefix = text[text.rfind("\n", 0, start) + 1:start]
        indent = prefix if not prefix.strip() else "    "
        child = indent + "    "
        closing_line = text.rfind("\n", 0, close - 1) + 1
        if not text[closing_line:close - 1].strip():
            added = "".join(child + line + "\n" for line in lines)
            return text[:closing_line] + added + text[closing_line:]
        added = "\n" + "\n".join(child + line for line in lines) + "\n" + indent
        return text[:close - 1] + added + text[close - 1:]

    body = "\n".join("    " + line for line in lines)
    return text.rstrip() + "\n\ninput {\n" + body + "\n}\n"


def configuration_main():
    def terminate(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, terminate)
    directory = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "niri/bloodyShell"
    input_file = directory / SETTINGS_FILE
    if sys.argv[1:] == ["mouse-read"] or len(sys.argv) == 3 and sys.argv[1] == "mouse":
        available = directory.is_dir() and (directory.parent / "config.kdl").is_file() and shutil.which("niri") is not None
        default_file = directory / "06-input.kdl"
        if sys.argv[1] == "mouse":
            if not available: raise ValueError("Mouse settings are unavailable: niri configuration is not installed")
            def edit(current):
                defaults = default_file.read_text() if default_file.is_file() else ""
                return mouse_config(current, json.loads(sys.argv[2]), defaults)
            values = mouse_settings(niri_write(directory, edit))
        else:
            current = input_file.read_text() if input_file.is_file() else ""
            defaults = default_file.read_text() if default_file.is_file() else ""
            values = mouse_settings(current, defaults)
        print(json.dumps(dict(available=available, mouse=values)))
    elif sys.argv[1:] == ["touchpad-read"] or len(sys.argv) == 3 and sys.argv[1] == "touchpad":
        available = directory.is_dir() and (directory.parent / "config.kdl").is_file() and shutil.which("niri") is not None
        default_file = directory / "06-input.kdl"
        if sys.argv[1] == "touchpad":
            if not available:
                raise ValueError("Touchpad settings are unavailable: niri configuration is not installed")
            def edit(current):
                defaults = default_file.read_text() if default_file.is_file() else ""
                return touchpad_config(current, json.loads(sys.argv[2]), defaults)
            values = touchpad_settings(niri_write(directory, edit))
        else:
            current = input_file.read_text() if input_file.is_file() else ""
            defaults = default_file.read_text() if default_file.is_file() else ""
            values = touchpad_settings(current, defaults)
        print(json.dumps(dict(available=available, touchpad=values)))
    elif len(sys.argv) == 3 and sys.argv[1] == "keyboard":
        niri_write(directory, lambda current: keyboard_config(current, sys.argv[2]))
    elif len(sys.argv) == 3 and sys.argv[1] == "outputs":
        niri_write(directory, lambda current: outputs_config(current, sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "cursor":
        niri_write(directory, lambda current: cursor_config(current, sys.argv[2], int(sys.argv[3])))
    elif len(sys.argv) == 3 and sys.argv[1] == "windows":
        settings = json.loads(sys.argv[2])
        niri_write(directory, lambda current: window_settings_config(current, settings))
    elif len(sys.argv) == 3 and sys.argv[1] == "pointer":
        settings = json.loads(sys.argv[2])
        niri_write(directory, lambda current: pointer_settings_config(current, settings))
    else:
        raise ValueError("Usage: compositor config niri outputs BLOCKS | cursor THEME SIZE | keyboard BLOCK | mouse-read | mouse JSON | touchpad-read | touchpad JSON | windows JSON | pointer JSON")
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
            old_names = ("06-user-input.kdl", "07-user-output.kdl") if name == SETTINGS_FILE else ("05-user.kdl",)
            old_files = [destination / "bloodyShell" / old for old in old_names]
            old_contents = [path.read_text() for path in old_files if path.is_file()]
            if old_contents:
                FILES["atomic_write"](target, ("\n\n".join(text.rstrip() for text in old_contents) + "\n").encode(), 0o600)
            else:
                shutil.copy2(source / "bloodyShell" / name, target)
    loader = staged / "config.kdl"
    loader.unlink(missing_ok=True)
    template = source / "config.kdl"
    if not template.is_file() or template.is_symlink():
        raise ValueError("Missing niri configuration loader")
    shutil.copy2(template, loader)
    if shutil.which("niri"):
        result = subprocess.run(["niri", "validate", "-c", str(loader)], capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise ValueError("niri rejected the imported configuration; current files were kept: " + result.stderr.strip())


