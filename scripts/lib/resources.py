"""Versioned optional resources and opt-in greeter exports. Dispatched by backend.py."""

from contextlib import contextmanager
from datetime import datetime
from pathlib import Path, PurePosixPath
import argparse
import configparser
import hashlib
import fcntl
import filecmp
import json
import os
import pwd
import re
import runpy
import shutil
import subprocess
import sys
import tarfile
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[2]
REPO = "bloodykgrapes/bloodyShell"
VERSION = (ROOT / "version").read_text().strip()
# Release resources must match their runtime. Source checkouts use their local files.
REF = "v" + VERSION
IMAGES = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}
VIDEOS = {".mp4", ".webm", ".mkv", ".mov", ".m4v", ".avi"}
TRANSITIONS = {"none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"}
RESERVED_DOTS = {"niri", "sddm", "wallpapers"}


def home():
    return Path(os.environ.get("HOME", str(Path.home())))


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(home() / ".config")))


def wallpapers_dir():
    return home() / "Pictures/Wallpapers"


def program_name(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", value):
        raise ValueError("Invalid app configuration name")
    return value


def download(url, destination=None):
    command = ["curl", "-fsSL", "--retry", "1", "--max-time", "120" if destination else "20"]
    if destination:
        command += ["-o", str(destination)]
    result = subprocess.run(command + [url], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not download repository files")
    return result.stdout


def programs():
    source = ROOT / "dots"
    if source.is_dir():
        return sorted(path.name for path in source.iterdir() if path.is_dir() and path.name not in RESERVED_DOTS and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", path.name))
    data = json.loads(download(f"https://api.github.com/repos/{REPO}/contents/dots?ref={REF}"))
    if not isinstance(data, list):
        raise ValueError("Invalid repository response")
    return sorted(program_name(item["name"]) for item in data if item.get("type") == "dir" and item.get("name") not in RESERVED_DOTS)


def resource_path(resource):
    if resource == "compositor":
        return Path("dots/niri")
    if resource == "dots":
        return Path("dots")
    if resource == "wallpapers":
        return Path("dots/wallpapers")
    if resource == "greeter":
        return Path("dots/sddm")
    if resource.startswith("dots/"):
        name = program_name(resource[5:])
        if name in {"sddm", "wallpapers"}:
            raise ValueError("Use the separate login-screen or wallpaper import")
        return Path("dots") / name
    raise ValueError("Unknown repository resource")


@contextmanager
def source_for(resource):
    relative = resource_path(resource)
    if (ROOT / relative).is_dir():
        yield ROOT
        return
    with tempfile.TemporaryDirectory(prefix="bloodyShell-import-") as temporary:
        stage = Path(temporary)
        archive = stage / "source.tar.gz"
        download(f"https://github.com/{REPO}/archive/refs/tags/{REF}.tar.gz", archive)
        with tarfile.open(archive, "r:gz") as package:
            total = 0
            for member in package:
                parts = PurePosixPath(member.name).parts
                if len(parts) < 2:
                    continue
                path = PurePosixPath(*parts[1:])
                if path.is_absolute() or ".." in path.parts:
                    raise ValueError("Unsafe repository archive path")
                if not path.is_relative_to(PurePosixPath(relative.as_posix())):
                    continue
                if resource == "dots" and len(path.parts) > 1 and path.parts[1] in RESERVED_DOTS:
                    continue
                target = stage / path
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                elif member.isfile():
                    total += member.size
                    if total > 512 * 1024 * 1024:
                        raise ValueError("Repository resource is too large")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with package.extractfile(member) as src, target.open("wb") as dest:
                        shutil.copyfileobj(src, dest)
                    target.chmod(member.mode & 0o755)
                else:
                    raise ValueError("Repository resources cannot contain links or special files")
        if not (stage / relative).is_dir():
            raise ValueError("The repository does not contain this resource")
        yield stage


def copy_image(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    candidate = destination
    number = 0
    while candidate.exists() or candidate.is_symlink():
        if candidate.is_file() and not candidate.is_symlink() and filecmp.cmp(source, candidate, shallow=False):
            return candidate, False
        number += 1
        suffix = "-bloodyShell" + (f"-{number}" if number > 1 else "")
        candidate = destination.with_name(destination.stem + suffix + destination.suffix)
    try:
        descriptor = os.open(candidate, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o666)
    except FileExistsError:
        return copy_image(source, destination)
    try:
        with os.fdopen(descriptor, "wb") as dest, source.open("rb") as src:
            shutil.copyfileobj(src, dest)
    except BaseException:
        candidate.unlink(missing_ok=True)
        raise
    return candidate, True


def import_wallpapers(source):
    source = Path(source).resolve()
    if not source.is_dir():
        raise ValueError("Wallpaper source is missing")
    directory = wallpapers_dir()
    copied = 0
    for image in sorted(source.rglob("*")):
        if not image.is_file() or image.is_symlink() or image.suffix.lower() not in IMAGES | VIDEOS:
            continue
        _, created = copy_image(image, directory / image.relative_to(source))
        copied += int(created)
    return dict(destination=str(directory), imported=copied)


def import_config(source, program):
    program_name(program)
    destination = config_home() / program
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    with tempfile.TemporaryDirectory(prefix=".bloodyShell-config-", dir=destination.parent) as temporary:
        # Keep niri at the original directory depth so relative external includes
        # and symlinks also resolve correctly during staged validation.
        staged = Path(temporary) if program == "niri" else Path(temporary) / program
        if program == "niri":
            prepare_niri(source, destination, staged)
        else:
            shutil.copytree(source, staged, symlinks=True)
        if destination.exists() or destination.is_symlink():
            stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S") + "-import-" + uuid.uuid4().hex[:8]
            backup = Path(os.environ.get("XDG_STATE_HOME") or home() / ".local/state") / "bloodyShell/backups" / stamp / program
            backup.parent.mkdir(parents=True)
            shutil.move(str(destination), backup)
        try:
            os.replace(staged, destination)
        except OSError:
            if backup is not None:
                shutil.move(str(backup), destination)
            raise
    return dict(destination=str(destination), backup=str(backup) if backup else "")


def prepare_niri(source, destination, staged):
    api = runpy.run_path(str(Path(__file__).with_name("desktop.py")))
    managed, user = api["NIRI_MANAGED"], api["NIRI_USER"]
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


def import_resource(resource):
    with source_for(resource) as source:
        relative = resource_path(resource)
        if resource == "wallpapers":
            return import_wallpapers(source / relative)
        if resource == "compositor":
            return import_config(source / relative, "niri")
        if resource == "dots":
            return import_dots(source / relative)
        if resource.startswith("dots/"):
            return import_config(source / relative, resource[5:])
        environment = dict(os.environ, BLOODYSHELL_RESOURCE_DIR=str(source))
        result = subprocess.run(["bash", str(ROOT / "setup"), "sddm"], env=environment)
        if result.returncode:
            raise RuntimeError("Greeter setup failed")
        return dict(destination="/usr/share/sddm/themes/bloodyShell")


def import_dots(source):
    names = sorted(program_name(path.name) for path in source.iterdir() if path.is_dir() and path.name not in RESERVED_DOTS)
    if not names:
        raise ValueError("No application configurations are available")
    imported = []
    try:
        for name in names:
            imported.append(import_config(source / name, name))
    except BaseException:
        # Treat the grouped action as one operation: restore earlier imports if
        # a later application configuration cannot be installed.
        for result in reversed(imported):
            destination = Path(result["destination"])
            if destination.is_symlink() or destination.is_file():
                destination.unlink()
            else:
                shutil.rmtree(destination)
            if result["backup"]:
                shutil.move(result["backup"], destination)
        raise
    return dict(destination=str(config_home()), imports=imported, backups=[result["backup"] for result in imported if result["backup"]])


def status():
    dependencies = runpy.run_path(str(Path(__file__).with_name("management.py")))
    return dict(terminal=dependencies["terminal"](), entries=[
        dict(id="compositor", kind="compositor", name="niri", destination=str(config_home() / "niri")),
        dict(id="dots", kind="dots", name="dots", programs=programs(), destination=str(config_home())),
        dict(id="greeter", kind="greeter", name="greeter", destination="/usr/share/sddm/themes/bloodyShell"),
         dict(id="wallpapers", kind="wallpapers", name="wallpapers", destination=str(wallpapers_dir()))])


def resources_main():
    parser = argparse.ArgumentParser(description="Import optional bloodyShell repository files")
    parser.add_argument("action", choices=("status", "programs", "import"))
    parser.add_argument("resource", nargs="?")
    parser.add_argument("--wait", action="store_true")
    parser.add_argument("--human", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "status":
            print(json.dumps(status()))
        elif args.action == "programs":
            print("\n".join(programs()))
        else:
            if not args.resource:
                raise ValueError("Resource name is required")
            result = import_resource(args.resource)
            if args.human or args.wait:
                print("Imported → " + result["destination"])
                for backup in [result.get("backup"), *result.get("backups", [])]:
                    if backup:
                        print("Backup → " + backup)
            else:
                print(json.dumps(result))
        return 0
    except (OSError, ValueError, RuntimeError, tarfile.TarError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        if args.wait and sys.stdin.isatty():
            try:
                input("\nPress Enter to close…")
            except (EOFError, KeyboardInterrupt):
                pass


def write_export(source, directory, keyboard_layouts=None):
    data = json.loads(source.read_text()) if source.is_file() else {}
    if keyboard_layouts is None:
        existing = configparser.ConfigParser(interpolation=None)
        existing.read(directory / "theme.conf")
        try:
            keyboard_layouts = json.loads(existing.get("General", "keyboardLayouts", fallback="null"))
        except (ValueError, configparser.Error):
            keyboard_layouts = None
    avatars = directory / "avatars"
    if avatars.is_symlink():
        raise ValueError("Login-screen avatar storage must not be a symlink")
    settings = dict(animationLevel=str(data.get("themeAnimations", 1)) if data.get("themeAnimations", 1) in (0, 1, 2) else "1",
                    widgetClock24="false" if data.get("barWidgetClock24") is False else "true",
                    shellLanguage=data.get("shellLanguage") if data.get("shellLanguage") in ("en", "ru", "system") else "system")
    if keyboard_layouts is not None:
        if not isinstance(keyboard_layouts, list) or not 1 <= len(keyboard_layouts) <= 32 or any(
            not isinstance(entry, dict) or not isinstance(entry.get("layout"), str) or
            not re.fullmatch(r"[A-Za-z0-9_+-]{1,64}", entry["layout"]) or
            not isinstance(entry.get("variant", ""), str) or not re.fullmatch(r"[A-Za-z0-9_+-]{0,64}", entry.get("variant", ""))
            for entry in keyboard_layouts
        ):
            raise ValueError("Invalid login-screen keyboard layouts")
        settings["keyboardLayouts"] = json.dumps([{key: entry.get(key, "") for key in ("layout", "variant")} for entry in keyboard_layouts])
    wallpaper = Path(str(data.get("wallpaperCurrent", ""))) if data.get("greeterSync") is True else Path("/nonexistent")
    if wallpaper.is_file() and wallpaper.suffix.lower() in VIDEOS:
        wallpaper = wallpaper_preview(wallpaper)
    if wallpaper.is_file() and wallpaper.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
        destination = directory / ("wallpaper" + wallpaper.suffix.lower())
        temporary = directory / (destination.name + ".tmp")
        shutil.copyfile(wallpaper, temporary)
        temporary.chmod(0o644)
        temporary.replace(destination)
        settings["wallpaperCurrent"] = str(destination)
    for old in directory.glob("wallpaper.*"):
        if str(old) != settings.get("wallpaperCurrent") and old.is_file():
            old.unlink()
    account = pwd.getpwuid(os.getuid())
    for source_avatar in (() if data.get("greeterSync") is not True else (Path(account.pw_dir) / ".face", Path(account.pw_dir) / ".face.icon", Path("/var/lib/AccountsService/icons") / account.pw_name)):
        if not source_avatar.is_file() or not os.access(source_avatar, os.R_OK):
            continue
        avatars.mkdir(exist_ok=True)
        avatars.chmod(0o755)
        temporary = avatars / (account.pw_name + ".tmp")
        shutil.copyfile(source_avatar, temporary)
        temporary.chmod(0o644)
        temporary.replace(avatars / account.pw_name)
        settings["avatarUser"] = account.pw_name
        break
    else:
        (avatars / account.pw_name).unlink(missing_ok=True)
    temporary = directory / "theme.conf.tmp"
    configuration = configparser.ConfigParser(interpolation=None)
    configuration.optionxform = str
    configuration["General"] = settings
    with temporary.open("w") as output:
        configuration.write(output)
    temporary.chmod(0o644)
    temporary.replace(directory / "theme.conf")


def export(source, directory, keyboard_layouts=None):
    if directory.is_symlink():
        raise ValueError("Login-screen storage must not be a symlink")
    with (directory / ".appearance.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        write_export(source, directory, keyboard_layouts)


def greeter_main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--if-configured", action="store_true")
    parser.add_argument("--keyboard-layouts", type=json.loads)
    args = parser.parse_args()
    if args.if_configured and (not args.directory.is_dir() or not os.access(args.directory, os.W_OK)):
        sys.exit(0)
    try:
        export(args.source, args.directory, args.keyboard_layouts)
    except (OSError, ValueError) as error:
        print("Greeter appearance: " + str(error), file=sys.stderr)
        sys.exit(1)



def wallpaper_file(value):
    path = Path(value).expanduser().resolve()
    if not path.is_file() or path.suffix.lower() not in IMAGES | VIDEOS:
        raise ValueError("Choose an image or video file")
    return path


def wallpaper_preview(path):
    path = wallpaper_file(path)
    if path.suffix.lower() not in VIDEOS:
        return path
    info = path.stat()
    key = hashlib.sha256(f"{path}\0{info.st_size}\0{info.st_mtime_ns}".encode()).hexdigest()
    cache = Path(os.environ.get("XDG_CACHE_HOME") or home() / ".cache") / "bloodyShell/wallpapers"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    target = cache / (key + ".png")
    if target.is_file() and not target.is_symlink() and target.stat().st_size > 0:
        target.touch()
        return target
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix=".preview-", suffix=".png", dir=cache, delete=False) as file:
            temporary = Path(file.name)
        command = ["setpriv", "--pdeathsig", "TERM", "ffmpeg", "-nostdin", "-v", "error", "-y",
                   "-threads", "1", "-filter_threads", "1", "-protocol_whitelist", "file,pipe",
                   "-i", str(path), "-map", "0:v:0", "-frames:v", "1", "-an",
                   "-vf", "scale=720:720:force_original_aspect_ratio=decrease", str(temporary)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=15)
        if result.returncode or temporary.stat().st_size == 0:
            raise ValueError("Could not read the video's first frame")
        temporary.replace(target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    entries = sorted((item for item in cache.glob("*.png") if re.fullmatch(r"[a-f0-9]{64}\.png", item.name)), key=lambda item: item.stat().st_mtime_ns)
    for old in entries[:-128]:
        old.unlink(missing_ok=True)
    return target


def wallpaper_info(value):
    path = wallpaper_file(value)
    return dict(path=str(path), video=path.suffix.lower() in VIDEOS, preview=str(wallpaper_preview(path)))


def wallpaper_main():
    parser = argparse.ArgumentParser(description="Wallpaper selection and previews")
    parser.add_argument("action", choices=("list", "preview", "apply", "inspect", "colors"))
    parser.add_argument("path", nargs="?", default="")
    parser.add_argument("--transition", choices=sorted(TRANSITIONS), default="grow")
    args = parser.parse_args()
    try:
        if args.action == "colors":
            path = wallpaper_file(args.path)
            result = subprocess.run(["setpriv", "--pdeathsig", "TERM", "ffmpeg", "-nostdin", "-v", "error", "-threads", "1", "-filter_threads", "1",
                                     "-protocol_whitelist", "file,pipe", "-i", str(path), "-frames:v", "1", "-vf", "scale=24:24:flags=area", "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"],
                                    capture_output=True, timeout=10)
            if result.returncode:
                raise ValueError("Could not read wallpaper colors")
            print(json.dumps(list(result.stdout)))
            return 0
        if args.action == "list":
            directory = Path(args.path).expanduser()
            found = []
            if directory.is_dir():
                for root, directories, files in os.walk(directory, followlinks=False):
                    if len(Path(root).relative_to(directory).parts) >= 2:
                        directories[:] = []
                    found.extend(str(Path(root) / name) for name in files if Path(name).suffix.lower() in IMAGES | VIDEOS)
            print(json.dumps(dict(paths=sorted(found))))
            return 0
        if args.action == "inspect":
            try:
                data = wallpaper_info(args.path) if args.path else None
            except (OSError, ValueError):
                data = None
            if data is None:
                query = subprocess.run(["setpriv", "--pdeathsig", "TERM", "awww", "query"], capture_output=True, text=True, timeout=5)
                for line in query.stdout.splitlines():
                    if "image: " not in line:
                        continue
                    try:
                        data = wallpaper_info(line.split("image: ", 1)[1])
                        break
                    except (OSError, ValueError):
                        pass
            print(json.dumps(data or {}))
            return 0
        data = wallpaper_info(args.path)
        if args.action == "apply":
            command = ["setpriv", "--pdeathsig", "TERM", "awww", "img", data["preview"],
                       "--transition-type", args.transition, "--transition-pos", "center",
                       "--transition-duration", "1.2", "--transition-fps", "120",
                       "--transition-bezier", "0.16,0.85,0.2,1.0"]
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise ValueError(result.stderr.strip() or "Could not change the wallpaper")
        print(json.dumps(data))
        return 0
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1
