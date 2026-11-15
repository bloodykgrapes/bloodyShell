"""Versioned resource imports, CLI refresh and login-screen appearance export."""

from contextlib import contextmanager, ExitStack
from datetime import datetime
from pathlib import Path
import argparse
import configparser
import hashlib
import io
import fcntl
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
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[2]
FILES = runpy.run_path(str(Path(__file__).with_name("files.py")))
COMPOSITORS = runpy.run_path(str(Path(__file__).with_name("compositors") / "__init__.py"))
REPO = "bloodykgrapes/bloodyShell"
WALLPAPERS_REPO = "bloodykgrapes/bloodyShell.wallpapers"
WALLPAPERS_REF = "main"
VERSION = (ROOT / "version").read_text().strip()
REF = "v" + VERSION.removeprefix("v")
IMAGES = {".jpg", ".jpeg", ".jfif", ".png", ".webp", ".bmp", ".gif"}
VIDEOS = {".mp4", ".webm", ".mkv", ".mov", ".m4v", ".avi"}
TRANSITIONS = {"none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"}
GREETER_FILES = ("Main.qml", "Widgets.qml", "Theme.qml", "metadata.desktop", "theme.conf", "niri.kdl")


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
    result = FILES["run"](command + [url], capture_output=True, text=True, timeout=130)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not download repository files")
    return result.stdout


def repository_paths(repository, reference):
    ref = quote(reference, safe="")
    data = json.loads(download(f"https://api.github.com/repos/{repository}/git/trees/{ref}?recursive=1"))
    if not isinstance(data, dict) or not isinstance(data.get("tree"), list) or data.get("truncated"):
        raise ValueError("Could not read the complete import file list.")
    return {item["path"] for item in data["tree"] if isinstance(item, dict) and item.get("type") == "blob"
            and isinstance(item.get("path"), str) and item.get("mode") != "120000"}


def shell_paths():
    if (ROOT / "dots").is_dir():
        return {path.relative_to(ROOT).as_posix() for path in (ROOT / "dots").rglob("*") if path.is_file() and not path.is_symlink()}
    return repository_paths(REPO, REF)


def config_programs(paths):
    return sorted({path.split("/")[2] for path in paths if path.startswith("dots/config/") and len(path.split("/")) >= 4
                   and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", path.split("/")[2])})


def resource_catalog():
    errors, names = [], []
    available = dict(dots=False, greeter=False, compositor=False, wallpapers=False)
    try:
        paths = shell_paths()
        names = config_programs(paths)
        compositor = COMPOSITORS["load"]()["INFO"]
        available.update(dots=bool(names), greeter=all("dots/sddm/" + name in paths for name in GREETER_FILES),
                         compositor=all(compositor["resource"] + "/" + name in paths for name in compositor["files"]))
        if not (ROOT / "dots").is_dir() and not all(available[key] for key in ("dots", "greeter", "compositor")):
            errors.append("Import files are missing from " + REF + ".")
    except (OSError, RuntimeError, ValueError) as error:
        errors.append("Shell files: " + str(error))
    try:
        paths = repository_paths(WALLPAPERS_REPO, WALLPAPERS_REF)
        available["wallpapers"] = any(path.startswith("images/") and Path(path).suffix.lower() in IMAGES | VIDEOS for path in paths)
        if not available["wallpapers"]:
            errors.append("No wallpapers are available in " + WALLPAPERS_REPO + "/images.")
    except (OSError, RuntimeError, ValueError) as error:
        errors.append("Wallpapers: " + str(error))
    return dict(programs=names, available=available, error="\n".join(errors))


def programs():
    return config_programs(shell_paths())


def resource_path(resource):
    if resource == "compositor":
        return Path(COMPOSITORS["load"]()["INFO"]["resource"])
    if resource == "dots":
        return Path("dots/config")
    if resource == "wallpapers":
        return Path("images")
    if resource == "greeter":
        return Path("dots/sddm")
    if resource.startswith("dots/"):
        name = program_name(resource[5:])
        if name in {"niri", "sddm", "wallpapers"}:
            raise ValueError("Use the separate compositor, login-screen or wallpaper import")
        return Path("dots/config") / name
    raise ValueError("Unknown repository resource")


@contextmanager
def source_for(resource):
    relative = resource_path(resource)
    if resource == "wallpapers":
        repository, namespace, reference = WALLPAPERS_REPO, "heads", WALLPAPERS_REF
    else:
        if (ROOT / "dots").is_dir():
            if not (ROOT / relative).is_dir():
                raise ValueError("Missing resource folder: " + str(ROOT / relative))
            yield ROOT
            return
        repository, namespace, reference = REPO, "tags", REF
    with tempfile.TemporaryDirectory(prefix="bloodyShell-import-") as temporary:
        stage = Path(temporary)
        archive, extracted = stage / "source.tar.gz", stage / "source"
        extracted.mkdir()
        ref = quote(reference, safe="")
        download(f"https://github.com/{repository}/archive/refs/{namespace}/{ref}.tar.gz", archive)
        FILES["extract_archive"](archive, extracted, prefix=relative)
        if not (extracted / relative).is_dir():
            raise ValueError("The repository does not contain this resource")
        yield extracted


def copy_image(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    candidate = destination
    number = 0
    while candidate.exists() or candidate.is_symlink():
        if candidate.is_file() and not candidate.is_symlink() and FILES["same_contents"](source, candidate):
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


@contextmanager
def config_change(source, program):
    program_name(program)
    destination = config_home() / program
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    original = destination.exists() or destination.is_symlink()
    with tempfile.TemporaryDirectory(prefix=".bloodyShell-config-", dir=destination.parent) as temporary, \
            tempfile.TemporaryDirectory(prefix=".bloodyShell-rollback-", dir=destination.parent) as rollback:
        # Keep compositor configs at their original depth so relative includes
        # and symlinks also resolve correctly during staged validation.
        staged = Path(temporary) if program in COMPOSITORS["BACKENDS"] else Path(temporary) / program
        if program in COMPOSITORS["BACKENDS"]:
            COMPOSITORS["load"](program)["prepare"](source, destination, staged)
        else:
            shutil.copytree(source, staged, symlinks=True)
        previous = Path(rollback) / program
        try:
            if original:
                stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S") + "-import-" + uuid.uuid4().hex[:8]
                backup = Path(os.environ.get("XDG_STATE_HOME") or home() / ".local/state") / "bloodyShell/backups" / stamp / program
                backup.parent.mkdir(parents=True)
                FILES["copy_path"](destination, backup)
                os.replace(destination, previous)
            os.replace(staged, destination)
            yield dict(destination=str(destination), backup=str(backup) if backup else "")
        except BaseException:
            if previous.exists() or previous.is_symlink():
                FILES["remove_path"](destination)
                os.replace(previous, destination)
            elif not original and not staged.exists():
                FILES["remove_path"](destination)
            if backup is not None:
                FILES["remove_path"](backup)
                try:
                    backup.parent.rmdir()
                except OSError:
                    pass
            raise


def import_config(source, program, transaction=None):
    change = config_change(source, program)
    if transaction is not None:
        return transaction.enter_context(change)
    with change as result:
        return result


def import_resource(resource, transaction=None, names=None):
    if names is not None and resource != "dots":
        raise ValueError("Application names only apply to the configs import")
    if resource == "cli":
        management = runpy.run_path(str(Path(__file__).with_name("management.py")))
        return management["refresh_command"]()
    with source_for(resource) as source:
        relative = resource_path(resource)
        if resource == "wallpapers":
            return import_wallpapers(source / relative)
        if resource == "compositor":
            return import_config(source / relative, COMPOSITORS["load"]()["INFO"]["config"], transaction)
        if resource == "dots":
            return import_dots(source / relative, names, transaction)
        if resource.startswith("dots/"):
            return import_config(source / relative, resource[5:], transaction)
        environment = dict(os.environ, BLOODYSHELL_RESOURCE_DIR=str(source))
        result = subprocess.run(["bash", str(ROOT / "scripts/lib/system.sh")], env=environment)
        if result.returncode:
            raise RuntimeError("Greeter setup failed")
        return dict(destination="/usr/share/sddm/themes/bloodyShell")


def clear_resource(resource):
    if resource != "greeter":
        raise ValueError("Only the login screen can be cleared")
    management = runpy.run_path(str(Path(__file__).with_name("management.py")))
    with management["operation_lock"]():
        return management["clear_greeter"]()


def import_dots(source, names=None, transaction=None):
    names = sorted({program_name(name) for name in names} if names is not None else
                   {program_name(path.name) for path in source.iterdir() if path.is_dir()})
    if not names:
        raise ValueError("No application configurations are available")
    for name in names:
        resource_path("dots/" + name)
        if not (source / name).is_dir():
            raise ValueError("No application configuration is available for " + name)
    with ExitStack() as local:
        imported = [import_config(source / name, name, transaction if transaction is not None else local) for name in names]
    return dict(destination=str(config_home()), imports=imported, backups=[result["backup"] for result in imported if result["backup"]])


def status():
    dependencies = runpy.run_path(str(Path(__file__).with_name("management.py")))
    compositor = COMPOSITORS["load"]()["INFO"]
    error = ""
    catalog = dict(programs=[], available={})
    try:
        catalog = resource_catalog()
        error = catalog["error"]
    except (OSError, RuntimeError, ValueError) as failure:
        error = str(failure)
    return dict(error=error, terminal=dependencies["terminal"](), entries=[
        dict(id="greeter", kind="greeter", name="greeter", available=catalog["available"].get("greeter", False), destination=str(dependencies["SDDM_THEME"]), installed=bool(dependencies["sddm_paths"]())),
        dict(id="compositor", kind="compositor", name=compositor["name"], available=catalog["available"].get("compositor", False), destination=str(config_home() / compositor["config"])),
        dict(id="dots", kind="dots", name="dots", programs=catalog["programs"], available=catalog["available"].get("dots", False), destination=str(config_home())),
        dict(id="wallpapers", kind="wallpapers", name="wallpapers", available=catalog["available"].get("wallpapers", False), destination=str(wallpapers_dir()))])


def resources_main():
    parser = argparse.ArgumentParser(description="Import bloodyShell repository files")
    parser.add_argument("action", choices=("status", "programs", "import", "clear"))
    parser.add_argument("resource", nargs="?")
    parser.add_argument("--only", nargs="+")
    parser.add_argument("--wait", action="store_true")
    parser.add_argument("--human", action="store_true")
    args = parser.parse_args()
    try:
        if args.only is not None and (args.action != "import" or args.resource != "dots"):
            raise ValueError("--only requires import dots")
        if args.action == "status":
            print(json.dumps(status()))
        elif args.action == "programs":
            print("\n".join(programs()))
        else:
            if not args.resource:
                raise ValueError("Resource name is required")
            if args.action == "clear":
                result = clear_resource(args.resource)
            elif args.resource == "cli":
                result = import_resource(args.resource)
            else:
                management = runpy.run_path(str(Path(__file__).with_name("management.py")))
                with management["operation_lock"]():
                    result = import_resource(args.resource, names=args.only)
            if args.human or args.wait:
                print(("Cleared → " if args.action == "clear" else "Command refreshed → " if args.resource == "cli" else "Imported → ") + result["destination"])
                for backup in [result.get("backup"), *result.get("backups", [])]:
                    if backup:
                        print("Backup → " + backup)
            else:
                print(json.dumps(result))
        return 0
    except (OSError, ValueError, RuntimeError, tarfile.TarError, subprocess.SubprocessError) as error:
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
    existing = configparser.ConfigParser(interpolation=None)
    existing.read(directory / "theme.conf")
    if keyboard_layouts is None:
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
    wallpaper = existing.get("General", "wallpaperCurrent", fallback="")
    if wallpaper:
        settings["wallpaperCurrent"] = wallpaper
        selection = existing.get("General", "wallpaperSource", fallback="")
        if selection:
            settings["wallpaperSource"] = selection
    account = pwd.getpwuid(os.getuid())
    for source_avatar in (Path(account.pw_dir) / ".face", Path(account.pw_dir) / ".face.icon", Path("/var/lib/AccountsService/icons") / account.pw_name):
        if not source_avatar.is_file() or not os.access(source_avatar, os.R_OK):
            continue
        avatars.mkdir(exist_ok=True)
        avatars.chmod(0o755)
        FILES["atomic_copy"](source_avatar, avatars / account.pw_name)
        settings["avatarUser"] = account.pw_name
        break
    else:
        (avatars / account.pw_name).unlink(missing_ok=True)
    configuration = configparser.ConfigParser(interpolation=None)
    configuration.optionxform = str
    configuration["General"] = settings
    output = io.StringIO()
    configuration.write(output)
    FILES["atomic_write"](directory / "theme.conf", output.getvalue().encode())


@contextmanager
def greeter_lock(directory, create=False):
    if directory.is_symlink():
        raise ValueError("Login-screen storage must not be a symlink")
    flags = os.O_NOFOLLOW | os.O_RDONLY | (os.O_CREAT if create else 0)
    with os.fdopen(os.open(directory / ".appearance.lock", flags, 0o644), "r") as lock:
        if create and os.fstat(lock.fileno()).st_mode & 0o777 != 0o644:
            os.fchmod(lock.fileno(), 0o644)
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def export(source, directory, keyboard_layouts=None):
    with greeter_lock(directory, create=True):
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


GREETER_STATE = Path("/var/lib/bloodyShell")


def greeter_wallpaper_status(directory=GREETER_STATE, expected=""):
    configuration = configparser.ConfigParser(interpolation=None)
    configuration.read(directory / "theme.conf")
    management = runpy.run_path(str(Path(__file__).with_name("management.py")))
    wallpaper = configuration.get("General", "wallpaperCurrent", fallback="")
    matches = False
    if expected and wallpaper:
        try:
            matches = hashlib.sha256(Path(expected).expanduser().read_bytes()).digest() == hashlib.sha256(Path(wallpaper).read_bytes()).digest()
        except OSError:
            pass
    return dict(installed=(directory / "theme.conf").is_file(), writable=os.access(directory, os.W_OK), wallpaper=wallpaper, matches=matches,
                selection=configuration.get("General", "wallpaperSource", fallback=""), terminal=management["terminal"]())


def set_greeter_wallpaper(value, directory=GREETER_STATE):
    image = wallpaper_file(value)
    if image.suffix.lower() not in IMAGES:
        raise ValueError("Choose an image for the login screen")
    if directory.is_symlink() or not (directory / "theme.conf").is_file():
        raise ValueError("Install the bloodyShell login screen first")
    # This is one shared selection; per-user appearance exports never replace it.
    with greeter_lock(directory):
        configuration = configparser.ConfigParser(interpolation=None)
        configuration.optionxform = str
        configuration.read(directory / "theme.conf")
        content = image.read_bytes()
        target = directory / ("wallpaper-" + hashlib.sha256(content).hexdigest() + image.suffix.lower())
        previous = Path(configuration.get("General", "wallpaperCurrent", fallback=""))
        configuration["General"]["wallpaperCurrent"] = str(target)
        configuration["General"]["wallpaperSource"] = str(image)
        output = io.StringIO()
        configuration.write(output)
        writable = os.access(directory, os.W_OK)
        # Authenticate as the shared directory's account, never write as root
        # into storage that account can modify.
        elevated = ["sudo", "-u", "#" + str(directory.stat().st_uid)]
        created = not target.exists()
        try:
            if writable:
                FILES["atomic_write"](target, content)
                FILES["atomic_write"](directory / "theme.conf", output.getvalue().encode())
            else:
                with tempfile.TemporaryDirectory(prefix="bloodyShell-login-wallpaper-") as temporary:
                    stage = Path(temporary)
                    (stage / "wallpaper").write_bytes(content)
                    (stage / "theme.conf").write_text(output.getvalue())
                    stage.chmod(0o755)
                    (stage / "wallpaper").chmod(0o644)
                    (stage / "theme.conf").chmod(0o644)
                    staged = directory / (".theme-" + uuid.uuid4().hex)
                    try:
                        subprocess.run([*elevated, "install", "-m", "644", "--", str(stage / "wallpaper"), str(target)], check=True)
                        subprocess.run([*elevated, "install", "-m", "644", "--", str(stage / "theme.conf"), str(staged)], check=True)
                        subprocess.run([*elevated, "mv", "-f", "--", str(staged), str(directory / "theme.conf")], check=True)
                    finally:
                        subprocess.run([*elevated, "-n", "rm", "-f", "--", str(staged)], check=False)
        except BaseException:
            if created:
                if writable:
                    target.unlink(missing_ok=True)
                else:
                    subprocess.run([*elevated, "-n", "rm", "-f", "--", str(target)], check=False)
            raise
        if previous != target and previous.parent == directory and re.fullmatch(r"wallpaper-[a-f0-9]{64}\.[a-z]+", previous.name):
            if writable:
                previous.unlink(missing_ok=True)
            else:
                subprocess.run([*elevated, "-n", "rm", "-f", "--", str(previous)], check=False)
    return dict(wallpaper=str(target))


def greeter_wallpaper_main():
    parser = argparse.ArgumentParser(description="Shared login-screen wallpaper")
    parser.add_argument("action", choices=("status", "apply"))
    parser.add_argument("path", nargs="?")
    parser.add_argument("--wait", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "apply" and not args.path:
            raise ValueError("Choose a login-screen wallpaper")
        result = greeter_wallpaper_status(expected=args.path or "") if args.action == "status" else set_greeter_wallpaper(args.path)
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, configparser.Error, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        if args.wait and sys.stdin.isatty():
            try:
                input("\nPress Enter to close…")
            except (EOFError, KeyboardInterrupt):
                pass



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
        result = FILES["run"](command, capture_output=True, text=True, timeout=15)
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
            result = FILES["run"](["setpriv", "--pdeathsig", "TERM", "ffmpeg", "-nostdin", "-v", "error", "-threads", "1", "-filter_threads", "1",
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
            if data is None and not args.path:
                query = FILES["run"](["setpriv", "--pdeathsig", "TERM", "awww", "query"], capture_output=True, text=True, timeout=5)
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
            result = FILES["run"](command, capture_output=True, text=True, timeout=10)
            if result.returncode:
                raise ValueError(result.stderr.strip() or "Could not change the wallpaper")
        print(json.dumps(data))
        return 0
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1
