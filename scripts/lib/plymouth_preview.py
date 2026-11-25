"""Build still previews from Plymouth theme descriptors and installed assets."""

import configparser
import os
from pathlib import Path
import platform
import re


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif"}
FIRMWARE_LOGO = Path("/sys/firmware/acpi/bgrt/image")
FRAME_NAME = re.compile(r"(?:(throbber|animation|progress|spinner|frame)[-_]?)?(\d+)")
TEXT_MODULES = {"details", "text", "tribar"}


def image_uri(path):
    return path.as_uri() if path.is_file() and os.access(path, os.R_OK) else ""


def distribution():
    try:
        return platform.freedesktop_os_release()
    except OSError:
        return {}


def script_artwork(script, assets, logo):
    try:
        with script.open(encoding="utf-8", errors="replace") as stream:
            source = stream.read(256 * 1024)
    except OSError:
        return {}

    source = re.sub(r"(?m)^\s*(?://|#).*?$", "", source)
    result = {}
    for position, red, green, blue in re.findall(
        r"Window\.SetBackground(Top|Bottom)Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", source
    ):
        try:
            result["top" if position == "Top" else "bottom"] = "#" + "".join(
                f"{round(min(1, float(value)) * 255):02x}" for value in (red, green, blue))
        except ValueError:
            continue
    for name in re.findall(r'\bImage\s*\(\s*["\']([^"\']+)["\']', source):
        if name == "special://logo" and logo:
            result.setdefault("logo", logo)
            continue
        path = Path(name)
        if path.suffix.lower() not in IMAGE_SUFFIXES or path.is_absolute() or ".." in path.parts:
            continue
        if re.match(r"^(?:bullet|box|entry|lock|password|keyboard|progress|capslock|keymap)", path.stem, re.I):
            continue
        if image := image_uri(assets / path):
            role = "background" if path.stem.lower().startswith(("background", "bg")) else "logo"
            result.setdefault(role, image)
    return result


def hex_color(value, alpha=False):
    match = re.fullmatch(r"0x((?:[0-9a-f]{2})?[0-9a-f]{6})", value, re.I)
    if not match:
        return ""
    digits = match[1]
    return "#" + (digits if alpha else digits[-6:])


def ratio(value, fallback, maximum=1):
    try:
        return max(0, min(1, float(value) / maximum))
    except ValueError:
        return fallback


def installed_images(directory, assets):
    images = {}
    folders = dict.fromkeys((directory, assets, *(assets / name for name in ("images", "assets", "frames"))))
    for folder in folders:
        try:
            for image in sorted(folder.iterdir()):
                if image.suffix.lower() in IMAGE_SUFFIXES and image_uri(image):
                    images.setdefault(image.stem.lower(), image)
        except OSError:
            continue
    return images


def animation_frame(images, module):
    groups = {}
    for name, image in images.items():
        match = FRAME_NAME.fullmatch(name)
        if match:
            kind, number = match.groups()
            if kind or len(number) >= 2:
                groups.setdefault(kind, []).append((int(number), image))
    # In the two-step plugin, animation-* is reserved for the end of boot.
    order = ("progress", "throbber") if module == "two-step" else ("animation", "throbber", "progress")
    for kind in (*order, "spinner", "frame", None):
        if sequence := groups.get(kind):
            index = len(sequence) // (4 if kind == "throbber" else 2)
            return sorted(sequence)[index][1].as_uri()
    return ""


def splash_progress(settings):
    if settings.get("useprogressbar", "").lower() not in ("true", "yes", "1"):
        return None
    return {
        "track": hex_color(settings.get("progressbarbackgroundcolor", ""), alpha=True) or "#606060",
        "fill": hex_color(settings.get("progressbarforegroundcolor", ""), alpha=True) or "#ffffff",
        "x": ratio(settings.get("progressbarhorizontalalignment", ""), 0.5),
        "y": ratio(settings.get("progressbarverticalalignment", ""), 0.8),
        "width": ratio(settings.get("progressbarwidth", ""), 0.4, 1920),
        "height": ratio(settings.get("progressbarheight", ""), 0.02, 1080),
    }


def artwork(directory, descriptor, os_release):
    module = descriptor.get("Plymouth Theme", "ModuleName", fallback="")
    settings = dict(descriptor.items(module)) if descriptor.has_section(module) else {}
    if descriptor.has_section("boot-up"):
        settings.update(descriptor.items("boot-up"))
    assets = directory / settings.get("imagedir", "")
    images = installed_images(directory, assets)

    def find(*names):
        return next((images[name].as_uri() for name in names if name in images), "")

    firmware = settings.get("usefirmwarebackground", "").lower() in ("true", "yes", "1")
    preview = next((find(name) for name in (directory.name + "-preview", "preview", "screenshot", "thumbnail")
                    if name in images and (not firmware or images[name].is_relative_to(directory))), "")
    distro = os_release.get("NAME", "")
    icon = os_release.get("LOGO", "")
    distro_logo = next((uri for suffix in (".png", ".svg") if icon and "/" not in icon
                       and (uri := image_uri(Path("/usr/share/pixmaps") / (icon + suffix)))), "")
    script = {}
    if path := settings.get("scriptfile"):
        script_path = directory / path
        script = script_artwork(script_path if script_path.is_file() else assets / path, assets, distro_logo)
    frame = ""
    if settings.get("useanimation", "").lower() not in ("false", "no", "0"):
        frame = animation_frame(images, module) or find("progress-bar", "progress_bar")
    star = find("star", "sparkle") if module in ("fade-throbber", "space-flares") else ""
    logo = find("logo", "watermark", "center-image", "header-image") or script.get("logo", "")
    frame_position = 0.8 if logo or module == "space-flares" else 0.5
    return {
        "image": preview,
        "kind": module if module in TEXT_MODULES or star else "",
        "system": distro,
        "background": find("background", "bg", "background-image", "splash") or script.get("background", ""),
        "top": hex_color(settings.get("backgroundstartcolor", "")) or script.get("top", ""),
        "bottom": hex_color(settings.get("backgroundendcolor", "")) or script.get("bottom", ""),
        "firmware": firmware,
        "firmwareImage": image_uri(FIRMWARE_LOGO) if firmware else "",
        "logo": logo or (distro_logo if module == "fade-throbber" else ""),
        "logoX": ratio(settings.get("watermarkhorizontalalignment", ""), 0.5),
        "logoY": ratio(settings.get("watermarkverticalalignment", ""), 0.5 if module == "script" or not frame else 0.38),
        "frame": frame,
        "frameX": ratio(settings.get("horizontalalignment", ""), 0.5),
        "frameY": ratio(settings.get("verticalalignment", ""), 0.75 if module == "script" else frame_position),
        "progress": splash_progress(settings),
        "star": star,
    }


def theme_info(name, path, os_release):
    descriptor = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        descriptor.read(path, encoding="utf-8")
    except (UnicodeError, configparser.Error):
        pass
    return {
        "id": name,
        "name": descriptor.get("Plymouth Theme", "Name", fallback=name).strip() or name,
        "description": descriptor.get("Plymouth Theme", "Description", fallback="").strip(),
        "preview": artwork(path.parent, descriptor, os_release),
    }
