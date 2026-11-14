"""Dependency catalog, command installation and diagnostics. Dispatched by backend.py."""

from pathlib import Path, PurePosixPath
import argparse
from contextlib import contextmanager
import fcntl
import json
import os
import re
import signal
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import tarfile
import stat


ROOT = Path(__file__).resolve().parents[2]
SYSTEM_COMMAND = Path("/usr/local/bin/bloodyShell")
FILES = runpy.run_path(str(Path(__file__).with_name("files.py")))


def catalog():
    text = (ROOT / "setup").read_text().split("readonly DEPENDENCIES=(", 1)[1].split("\n)", 1)[0]
    return [dict(zip(("kind", "tool", "feature", "arch", "fedora", "debian"), match.split("|")))
            for match in re.findall(r'^\s*"([^"\n]+)"', text, re.M)]


def available(tool):
    if tool == "qt6-multimedia":
        paths = [Path(value) for key in ("QML_IMPORT_PATH", "QML2_IMPORT_PATH") for value in os.environ.get(key, "").split(os.pathsep) if value]
        paths.extend((Path("/usr/lib/qt6/qml"), Path("/usr/lib64/qt6/qml")))
        paths.extend(Path("/usr/lib").glob("*/qt6/qml"))
        return any((path / "QtMultimedia/qmldir").is_file() for path in paths)
    if not shutil.which(tool):
        return False
    if tool == "sddm":
        return bool(shutil.which("sddm-greeter-qt6"))
    if tool == "nmcli":
        helper = ROOT / "scripts/lib/network.py"
        try:
            return helper.is_file() and subprocess.run([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", "network-auth", "--check"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    return True


def family():
    fields = {}
    for line in Path("/etc/os-release").read_text().splitlines():
        key, separator, value = line.partition("=")
        if separator:
            fields[key] = value.strip('"')
    names = (fields.get("ID", "") + " " + fields.get("ID_LIKE", "")).split()
    for name, result in (("arch", "arch"), ("fedora", "fedora"), ("rhel", "fedora"), ("debian", "debian"), ("ubuntu", "debian")):
        if name in names:
            return result
    return ""


def terminal():
    for executable, args in (("kitty", []), ("foot", []), ("konsole", ["--nofork", "-e"]), ("gnome-terminal", ["--wait", "--"]), ("xterm", ["-e"])):
        path = shutil.which(executable)
        if path:
            return [path] + args
    return []


def packages(entry, distro):
    return [value for value in entry.get(distro, "-").split() if value != "-" and not value.startswith("copr:")]


def plan(action, tool, distro=None):
    distro = family() if distro is None else distro
    entries = catalog()
    entry = next((item for item in entries if item["tool"] == tool), None)
    if not entry or action not in ("install", "remove"):
        raise ValueError("Unknown dependency or operation")
    names = packages(entry, distro)
    if not names:
        raise ValueError("This dependency needs manual installation on this distribution")
    protected = {name for item in entries if item["kind"] == "required" for name in packages(item, distro)}
    if action == "remove" and (entry["kind"] == "required" or tool == "python3" or protected.intersection(names)):
        raise ValueError("Required shell packages cannot be removed here")
    if distro == "arch":
        if action == "remove":
            return [["sudo", "pacman", "-R", *names]]
        repo = all(subprocess.run(["pacman", "-Si", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 for name in names)
        if repo:
            return [["sudo", "pacman", "-S", "--needed", *names]]
        helper = shutil.which("paru") or shutil.which("yay")
        if not helper:
            raise ValueError("Install paru or yay to download this AUR dependency")
        return [[helper, "-S", "--needed", *names]]
    if distro == "fedora":
        commands = []
        if action == "install":
            commands = [["sudo", "dnf", "copr", "enable", token[5:]] for token in entry["fedora"].split() if token.startswith("copr:")]
        return commands + [["sudo", "dnf", action, *names]]
    if distro == "debian":
        return [["sudo", "apt-get", action, *names]]
    raise ValueError("Unsupported distribution")


def dependencies_status():
    distro = family()
    entries = catalog()
    protected = {name for item in entries if item["kind"] == "required" for name in packages(item, distro)}
    return {"terminal": terminal(), "entries": [
        {"tool": item["tool"], "required": item["kind"] == "required" or item["tool"] == "python3", "installed": available(item["tool"]),
         "packages": packages(item, distro), "removable": item["kind"] != "required" and item["tool"] != "python3" and not protected.intersection(packages(item, distro)),
         "supported": bool(packages(item, distro))} for item in entries]}


def dependencies_main():
    if len(sys.argv) == 3 and sys.argv[1] == "check":
        known = {entry["tool"] for entry in catalog()}
        return 0 if sys.argv[2] in known and available(sys.argv[2]) else 1
    if sys.argv[1:] == ["status"]:
        print(json.dumps(dependencies_status()))
        return 0
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: dependencies status | install/remove <tool>")
        commands = plan(*sys.argv[1:])
        for command in commands:
            print("\n" + shlex.join(command) + "\n", flush=True)
            result = subprocess.run(command)
            if result.returncode:
                return result.returncode
        return 0
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        if sys.stdin.isatty():
            try:
                input("\nPress Enter to close…")
            except (EOFError, KeyboardInterrupt):
                pass


def checks():
    results = []
    def record(name, ok, required=True, detail=""):
        results.append(dict(name=name, ok=bool(ok), required=required, detail=detail))

    dependencies = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    for entry in dependencies["catalog"]():
        record(entry["tool"], dependencies["available"](entry["tool"]), entry["kind"] == "required", entry["feature"])
    record("SDDM theme", (ROOT / "dots/sddm/Main.qml").is_file() or Path("/usr/share/sddm/themes/bloodyShell/Main.qml").is_file(), False,
           "Optional; import from Settings → Updates")
    for path in (ROOT / "assets/shaders").glob("*.frag"):
        record(path.name + " bundle", path.with_suffix(path.suffix + ".qsb").is_file())
    if shutil.which("niri") and (ROOT / "dots/niri/config.kdl").is_file():
        result = subprocess.run(["niri", "validate", "-c", str(ROOT / "dots/niri/config.kdl")], capture_output=True, text=True, timeout=10)
        record("Bundled niri configuration", result.returncode == 0, detail=(result.stderr.strip() if result.returncode else "Validated"))
    if shutil.which("pkg-config"):
        result = subprocess.run(["pkg-config", "--exists", "Qt6Quick"], capture_output=True, timeout=5)
        record("Native Alt+Tab build support", result.returncode == 0 and shutil.which("c++"), False, "Qt 6 Quick development files, moc, pkg-config and a C++ compiler")
        result = subprocess.run(["pkg-config", "--exists", "Qt6Quick", "wayland-client", "xkbcommon"], capture_output=True, timeout=5)
        record("On-screen keyboard build support", result.returncode == 0 and shutil.which("c++") and shutil.which("wayland-scanner"), False,
               "Qt 6 Quick, Wayland, and xkbcommon development files, wayland-scanner, and a C++ compiler")
    else:
        record("Native Alt+Tab build support", False, False, "Install pkg-config and Qt 6 development tools")
    record("Wayland session", bool(os.environ.get("WAYLAND_DISPLAY")), False, "Run inside niri to use the shell")
    return results


def doctor_main():
    parser = argparse.ArgumentParser(description="Read-only bloodyShell installation diagnostics")
    parser.add_argument("--json", action="store_true")
    arguments = parser.parse_args()
    results = checks()
    if arguments.json:
        print(json.dumps(results, indent=2))
    else:
        for result in results:
            status = "OK" if result["ok"] else "MISSING" if result["required"] else "OPTIONAL"
            print(f'{status:8} {result["name"]}: {result["detail"]}')
    return int(any(not result["ok"] and result["required"] for result in results))


def write_command(command, contents, mode=0o755):
    if command != SYSTEM_COMMAND:
        FILES["atomic_write"](command, contents, mode)
        return
    with tempfile.TemporaryDirectory(prefix="bloodyShell-command-") as temporary:
        source = Path(temporary) / "bloodyShell"
        source.write_bytes(contents)
        subprocess.run(["sudo", "/usr/bin/install", "-D", "-o", "root", "-g", "root", "-m", f"{mode:o}", "--", str(source), str(command)], check=True)


def remove_command(command):
    if command == SYSTEM_COMMAND:
        subprocess.run(["sudo", "/usr/bin/rm", "-f", "--", str(command)], check=True)
    else:
        command.unlink(missing_ok=True)


def install(source, binary, backup):
    changed = []
    saved = []

    def save(target, label):
        if target.exists() or target.is_symlink():
            destination = backup / label
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists() or destination.is_symlink():
                raise RuntimeError(f"Backup already exists: {destination}")
            if target.is_symlink():
                destination.symlink_to(os.readlink(target))
            else:
                shutil.copy2(target, destination)
            saved.append(str(destination))

    command = binary / "bloodyShell"
    contents = source.read_bytes()
    if command.is_dir() and not command.is_symlink():
        raise RuntimeError(f"Command path is a directory: {command}")
    if command.is_symlink() or not command.is_file() or command.read_bytes() != contents:
        save(command, "command")
        write_command(command, contents)
        changed.append(str(command))
    else:
        if stat.S_IMODE(command.stat().st_mode) != 0o755:
            write_command(command, contents)

    return dict(command=str(command), changed=changed, backups=saved)


PATH_START = "# >>> bloodyShell PATH >>>\n"
PATH_END = "# <<< bloodyShell PATH <<<\n"
PATH_PATTERN = re.compile(r"^# >>> bloodyShell PATH >>>\r?\n.*?^# <<< bloodyShell PATH <<<[^\S\r\n]*(?:\r?\n|$)", re.M | re.S)


def path_blocks(binary):
    if not binary.is_absolute() or any(char in str(binary) for char in ":\n\r\0"):
        raise RuntimeError("The command directory must be absolute and cannot contain colons or line breaks")
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    shell = Path(os.environ.get("SHELL", "bash")).name
    quoted = shlex.quote(str(binary.absolute()))
    posix = f'case ":$PATH:" in\n    *:{quoted}:*) ;;\n    *) export PATH={quoted}:"$PATH" ;;\nesac\n'
    profiles = [home / ".profile"]
    if shell == "bash" or (home / ".bashrc").exists():
        profiles.append(home / ".bashrc")
    for name in (".bash_profile", ".bash_login"):
        if (home / name).exists():
            profiles.append(home / name)
    zsh = Path(os.environ.get("ZDOTDIR") or home)
    for name in (".zprofile", ".zshrc"):
        if shell == "zsh" or (zsh / name).exists():
            profiles.append(zsh / name)
    blocks = {path: PATH_START + posix + PATH_END for path in profiles}
    if shell == "fish" or (config / "fish").is_dir():
        fish = "'" + str(binary.absolute()).replace("\\", "\\\\").replace("'", "\\'") + "'"
        blocks[config / "fish/conf.d/bloodyShell-path.fish"] = PATH_START + f'if not contains -- {fish} $PATH\n    set -gx PATH {fish} $PATH\nend\n' + PATH_END
    # niri-session and other user services inherit environment.d on login.
    environment = str(binary.absolute()).replace("\\", "\\\\").replace('"', '\\"').replace("$", "$$")
    blocks[config / "environment.d/90-bloodyShell-path.conf"] = PATH_START + f'PATH="{environment}:${{PATH:-/usr/local/bin:/usr/bin:/bin}}"\n' + PATH_END
    return blocks


def path_plan(binary):
    planned = {}
    for path, block in path_blocks(binary).items():
        target = path.resolve()
        if not FILES["safe_path"](target) or target.exists() and target.stat().st_uid != os.getuid():
            raise RuntimeError("Unsafe shell profile location: " + str(path))
        before, mode = FILES["read_file"](target)
        current = before.decode() if before is not None else ""
        if PATH_START.rstrip() in current or PATH_END.rstrip() in current:
            matches = list(PATH_PATTERN.finditer(current))
            if not matches or current.count(PATH_START.rstrip()) != len(matches) or current.count(PATH_END.rstrip()) != len(matches):
                raise RuntimeError("Incomplete bloodyShell PATH block: " + str(path))
            contents = current
            for index, match in reversed(list(enumerate(matches))):
                contents = contents[:match.start()] + (block if index == 0 else "") + contents[match.end():]
        else:
            separator = "" if not current else "\n" if current.endswith("\n") else "\n\n"
            contents = current + separator + block
        planned[str(path)] = dict(target=target, before=before, contents=contents.encode(), mode=mode)
    return planned


def apply_path_plan(planned):
    for name, entry in planned.items():
        if entry["before"] == entry["contents"]:
            continue
        if Path(name).resolve() != entry["target"] or FILES["read_file"](entry["target"])[0] != entry["before"]:
            raise RuntimeError("Shell profile changed during installation: " + name)
        entry["applied"] = True
        FILES["atomic_write"](entry["target"], entry["contents"], entry["mode"])


def rollback_path_plan(planned):
    for name, entry in planned.items():
        if not entry.get("applied"):
            continue
        target = entry["target"]
        if Path(name).resolve() != target or FILES["read_file"](target)[0] != entry["contents"]:
            continue
        if entry["before"] is None:
            target.unlink(missing_ok=True)
        else:
            FILES["atomic_write"](target, entry["before"], entry["mode"])


def release_main():
    if len(sys.argv) != 3:
        raise RuntimeError("Usage: extract-release ARCHIVE DESTINATION")
    archive, target = map(Path, sys.argv[1:])
    if target.is_symlink() or not target.is_dir() or any(target.iterdir()):
        raise RuntimeError("Release extraction needs an empty directory")
    root = None
    total = 0
    seen = set()
    links = []
    with tarfile.open(archive, "r:gz") as package:
        for member in package:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or not path.parts:
                raise RuntimeError("Unsafe release archive path")
            if root is None:
                root = path.parts[0]
            if path.parts[0] != root:
                raise RuntimeError("Release archive must contain one root directory")
            if len(path.parts) == 1:
                if not member.isdir():
                    raise RuntimeError("Invalid release archive root")
                continue
            relative = Path(*path.parts[1:])
            if relative in seen:
                raise RuntimeError("Duplicate path in release archive")
            seen.add(relative)
            if len(seen) > 100000:
                raise RuntimeError("Release archive contains too many files")
            destination = target / relative
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                total += member.size
                if total > 512 * 1024 * 1024:
                    raise RuntimeError("Release archive is too large")
                destination.parent.mkdir(parents=True, exist_ok=True)
                with package.extractfile(member) as source, destination.open("xb") as output:
                    shutil.copyfileobj(source, output)
                destination.chmod(member.mode & 0o755)
            elif member.issym():
                link = PurePosixPath(member.linkname)
                if link.is_absolute():
                    raise RuntimeError("Absolute link in release archive")
                resolved = (destination.parent / str(link)).resolve()
                if not resolved.is_relative_to(target.resolve()):
                    raise RuntimeError("Link escapes release archive")
                links.append((destination, str(link)))
            else:
                raise RuntimeError("Special file in release archive")
        for destination, link in links:
            if not destination.parent.resolve().is_relative_to(target.resolve()):
                raise RuntimeError("Link escapes release archive")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(link)
        for destination, _ in links:
            if not destination.resolve(strict=True).is_relative_to(target.resolve()):
                raise RuntimeError("Link escapes release archive")


RUNTIME_FILES = ("shell.qml", "setup", "version")
RUNTIME_DIRS = ("assets", "modules", "scripts", "translations")


def runtime_member(relative):
    parts = relative.parts
    return bool(parts) and not any(part.startswith(".") or part == "__pycache__" for part in parts) and relative.suffix.lower() not in (".md", ".pyc", ".pyo") and (
        relative.as_posix() in RUNTIME_FILES or parts[0] in RUNTIME_DIRS
    ) and not any(relative.is_relative_to(path) for path in (Path("scripts/tests"), Path("scripts/tools")))


def stage_main():
    if len(sys.argv) != 4:
        raise RuntimeError("Usage: stage-runtime SOURCE DESTINATION BIN_DIR")
    source, target, binary = (Path(value).absolute() for value in sys.argv[1:])
    if target.is_symlink() or not target.is_dir() or any(target.iterdir()) or target.is_relative_to(source):
        raise RuntimeError("Runtime staging needs an empty directory outside the source")
    expected = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "quickshell/bloodyShell"
    if not FILES["safe_path"](expected) or (expected / ".git").exists():
        raise RuntimeError("Refusing to replace a symlink installation or source checkout")
    for name in RUNTIME_FILES:
        if not (source / name).is_file() or (source / name).is_symlink():
            raise RuntimeError("Missing runtime file: " + name)
    paths = [source / name for name in RUNTIME_FILES]
    for name in RUNTIME_DIRS:
        directory = source / name
        if directory.exists():
            if directory.is_symlink() or not directory.is_dir():
                raise RuntimeError("Invalid runtime directory: " + name)
            paths.extend([directory, *directory.rglob("*")])
    for path in paths:
        relative = path.relative_to(source)
        if not runtime_member(relative):
            continue
        destination = target / relative
        if path.is_symlink():
            resolved = path.resolve(strict=True)
            if not resolved.is_relative_to(source) or not runtime_member(resolved.relative_to(source)):
                raise RuntimeError("Runtime link points outside the installed files: " + str(relative))
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.symlink_to(os.path.relpath(resolved, path.parent))
        elif path.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        elif path.is_file():
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
        else:
            raise RuntimeError("Runtime contains a special file: " + str(relative))
    for path in target.rglob("*"):
        if path.is_symlink() and (not path.resolve(strict=True).is_relative_to(target)):
            raise RuntimeError("Runtime contains an unsafe link")
        if path.is_file() and path.suffix == ".py":
            compile(path.read_bytes(), str(path), "exec")
    compile((target / "scripts/bloodyShell").read_bytes(), str(target / "scripts/bloodyShell"), "exec")
    for name in ("scripts/bloodyShell", "scripts/lib/backend.py", "scripts/lib/management.py"):
        if not (target / name).is_file():
            raise RuntimeError("Package is missing " + name)
    subprocess.run(["bash", "-n", str(target / "setup")], check=True)
    path_plan(binary)


@contextmanager
def command_signals():
    def interrupt(signum, frame):
        raise SystemExit(128 + signum)
    previous = {sig: signal.signal(sig, interrupt) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def install_main():
    with command_signals():
        return install_command_main()


def install_command_main():
    if len(sys.argv) != 4:
        raise RuntimeError("Usage: install-command SOURCE BIN_DIR BACKUP_DIR")
    source, binary, backup = map(Path, sys.argv[1:4])
    result = install_command(source, binary, backup)
    print(json.dumps(result))


def install_command(source, binary, backup):
    command = binary / "bloodyShell"
    if not FILES["safe_path"](binary):
        raise RuntimeError("Unsafe command directory: " + str(binary))
    planned = path_plan(binary)
    previous_link = os.readlink(command) if command.is_symlink() else None
    before = FILES["read_file"](command) if previous_link is None else None
    try:
        result = install(source, binary, backup)
        apply_path_plan(planned)
        discard_tracking_files()
    except BaseException:
        rollback_path_plan(planned)
        if previous_link is not None:
            command.unlink(missing_ok=True)
            command.symlink_to(previous_link)
        elif before is not None:
            if before[0] is None:
                remove_command(command)
            else:
                write_command(command, before[0], before[1])
        raise
    return result


def command_location():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    current = Path(os.environ.get("BLOODYSHELL_COMMAND", ""))
    if os.environ.get("XDG_BIN_HOME"):
        binary = Path(os.environ["XDG_BIN_HOME"])
    elif current.is_absolute() and current.name == "bloodyShell":
        binary = current.parent
    else:
        binary = Path.home() / ".local/bin"
    return config / "quickshell/bloodyShell", binary


def refresh_command():
    runtime, binary = command_location()
    if not (runtime / "shell.qml").is_file() or (runtime / ".git").exists():
        raise RuntimeError("Install the shell with ./setup install before refreshing its command")
    source = ROOT / "scripts/bloodyShell"
    backup = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "bloodyShell/backups" / ("cli-" + str(time.time_ns())) / "launcher"
    with command_signals():
        result = install_command(source, binary, backup)
    return dict(result, destination=result["command"])


TRACKING_FILES = ("install.json", "changes.json", "changes.lock")


def discard_tracking_files():
    directory = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "bloodyShell"
    if not FILES["safe_path"](directory):
        raise RuntimeError("Unsafe state directory: " + str(directory))
    for name in TRACKING_FILES:
        (directory / name).unlink(missing_ok=True)


SDDM_THEME = Path("/usr/share/sddm/themes/bloodyShell")
SDDM_CONFIG = Path("/etc/sddm.conf.d/zz-bloodyShell.conf")
SDDM_STATE = Path("/var/lib/bloodyShell")


def uninstall_locations():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "bloodyShell"
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "bloodyShell"
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())
    runtime /= "bloodyShell" if os.environ.get("XDG_RUNTIME_DIR") else "bloodyShell-" + str(os.getuid())
    installed, binary = command_location()
    profiles = set(path_blocks(binary))
    profiles.update(Path.home() / name for name in (".profile", ".bashrc", ".bash_profile", ".bash_login", ".zprofile", ".zshrc"))
    profiles.update((config / "environment.d/90-bloodyShell-path.conf", config / "fish/conf.d/bloodyShell-path.fish"))
    return dict(runtime=installed, command=binary / "bloodyShell", settings=config / "bloodyShell", state=state,
                metadata=[state / name for name in TRACKING_FILES], caches=[cache, runtime], profiles=sorted(profiles))


def check_uninstall_path(path):
    if not path.is_absolute() or path == Path.home() or path in Path.home().parents or any(parent.is_symlink() for parent in path.parents):
        raise RuntimeError("Uninstall refused an unsafe path: " + str(path))
    if path.exists() and not path.is_symlink() and path.stat().st_uid != os.getuid():
        raise RuntimeError("Uninstall path belongs to another user: " + str(path))


def remove_path(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def path_block_cleanup(paths, apply=False):
    changed, seen = [], set()
    for path in paths:
        if not path.is_absolute() or not path.is_file():
            continue
        target = path.resolve()
        if target in seen or target.stat().st_uid != os.getuid():
            continue
        seen.add(target)
        text = target.read_text()
        clean, count = PATH_PATTERN.subn("", text)
        if not count:
            continue
        changed.append(str(path))
        if apply:
            if not clean.strip() and path.name in ("90-bloodyShell-path.conf", "bloodyShell-path.fish"):
                path.unlink()
            else:
                FILES["atomic_write"](target, clean.encode(), stat.S_IMODE(target.stat().st_mode))
    return changed


def uninstall_plan(locations, delete_settings=False, delete_sddm=False):
    root = locations["runtime"]
    if not root.is_symlink() and (root / ".git").exists():
        raise RuntimeError("Uninstall refused: the runtime is a source checkout")
    protected = [locations["settings"].parent, locations["state"]]
    if not delete_settings:
        protected.append(locations["settings"])
    caches = [path for path in locations["caches"] if not any(saved == path or saved.is_relative_to(path) for saved in protected)]
    remove = [root, locations["command"], *locations["metadata"], *caches]
    if delete_settings:
        remove.append(locations["settings"])
    for path in remove:
        check_uninstall_path(path)
    remove = [str(path) for path in dict.fromkeys(remove) if path.exists() or path.is_symlink()]
    sddm = [str(path) for path in (SDDM_THEME, SDDM_CONFIG, SDDM_STATE) if path.exists() or path.is_symlink()] if delete_sddm else []
    return dict(runtime=str(root), command=str(locations["command"]), remove=remove, sddm=sddm,
                path_files=path_block_cleanup(locations["profiles"]), delete_settings=delete_settings,
                delete_sddm=delete_sddm, kept_cache=[])


@contextmanager
def uninstall_lock(state):
    check_uninstall_path(state)
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(state / "operation.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another installation, update or uninstall is in progress") from None
        yield


def uninstall_question(text):
    try:
        return input(text + " [y/N] ").strip().lower() in ("y", "yes")
    except EOFError:
        return False


def uninstall_main():
    parser = argparse.ArgumentParser(prog="bloodyShell uninstall", description="Remove the installed shell, CLI and generated data; keep configs by default")
    parser.add_argument("--apply", action="store_true", help="stop and remove the installed shell, CLI, cache and temporary files")
    parser.add_argument("--delete-sddm", action="store_true", help="also remove the SDDM theme, shell drop-in and shared login images (sudo)")
    parser.add_argument("--delete-settings", action="store_true", help="also remove shell settings; keep niri and application configs")
    parser.add_argument("--json", action="store_true")
    options = parser.parse_args()
    if os.geteuid() == 0:
        raise RuntimeError("Run uninstall as your normal user, without sudo")
    locations = uninstall_locations()
    if options.apply and not options.json and sys.stdin.isatty():
        if not options.delete_sddm and any(path.exists() or path.is_symlink() for path in (SDDM_THEME, SDDM_CONFIG, SDDM_STATE)):
            options.delete_sddm = uninstall_question("Delete SDDM theme?")
        if not options.delete_settings and (locations["settings"].exists() or locations["settings"].is_symlink()):
            options.delete_settings = uninstall_question("Delete shell settings?")
    plan = uninstall_plan(locations, options.delete_settings, options.delete_sddm)
    if not options.apply:
        if options.json:
            print(json.dumps(plan))
        else:
            for name in plan["remove"] + plan["sddm"]:
                print("Remove: " + name)
            for name in plan["path_files"]:
                print("Remove bloodyShell PATH block: " + name)
            print("Preview only. Use uninstall --apply to proceed. Shell settings and SDDM are optional; niri configs, application configs and backups are kept.")
        return 0
    with uninstall_lock(locations["state"]):
        if plan["sddm"]:
            subprocess.run(["sudo", "-v"], check=True)
        control = runpy.run_path(str(ROOT / "scripts/bloodyShell"))
        command = shutil.which("qs") or shutil.which("quickshell")
        if command:
            control["stop"](command, locations["runtime"], quiet=True)
            others = any(control["is_shell"](entry) for entry in control["instances"](command))
        else:
            for process in Path("/proc").glob("[0-9]*"):
                try:
                    if process.stat().st_uid == os.getuid() and (process / "comm").read_text().strip() in ("qs", "quickshell"):
                        raise RuntimeError("Quickshell is running but its command is unavailable; stop it before uninstalling")
                except (FileNotFoundError, PermissionError):
                    continue
            others = False
        if others and options.delete_settings:
            raise RuntimeError("Stop other bloodyShell instances before deleting shared shell settings")
        plan = uninstall_plan(locations, options.delete_settings, options.delete_sddm)
        if others:
            plan["kept_cache"] = [str(path) for path in locations["caches"] if str(path) in plan["remove"]]
            plan["remove"] = [name for name in plan["remove"] if name not in plan["kept_cache"]]
        if plan["sddm"]:
            subprocess.run(["sudo", "rm", "-rf", "--", *plan["sddm"]], check=True)
        plan["path_files"] = path_block_cleanup(locations["profiles"], apply=True)
        for name in plan["remove"]:
            remove_path(Path(name))
    if options.json:
        print(json.dumps(plan))
    else:
        print("bloodyShell uninstalled.")
        if plan["kept_cache"]:
            print("Shared cache kept because another bloodyShell instance is running.")
        print("Niri configs, application configs and backups were kept.")
    return 0
