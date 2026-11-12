"""Dependency catalog, command installation and diagnostics. Dispatched by backend.py."""

from pathlib import Path, PurePosixPath
import argparse
import base64
from contextlib import contextmanager
import fcntl
import hashlib
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
import tarfile
import stat


ROOT = Path(__file__).resolve().parents[2]
SYSTEM_COMMAND = Path("/usr/local/bin/bloodyShell")


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


def replace(path, contents, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix="." + path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(contents)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def write_command(command, contents, mode=0o755):
    if command != SYSTEM_COMMAND:
        replace(command, contents, mode)
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


def command_fingerprint(command):
    return fingerprint(command, owner=0 if command == SYSTEM_COMMAND else os.getuid())


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


def path_plan(binary, ownership, record=None):
    previous = (record or {}).get("path_files", {})
    if not isinstance(previous, dict):
        raise RuntimeError("Invalid PATH integration record")
    planned = {}
    blocks = path_blocks(binary)
    # Continue managing profiles from the original install after a shell change.
    for name, entry in previous.items():
        path = Path(name)
        if path not in blocks:
            blocks[path] = entry["text"].lstrip("\n")
    for path, block in blocks.items():
        old = previous.get(str(path))
        snapshot = ownership["snapshot"](path)
        target = Path(snapshot["target"])
        if not path.is_absolute() or not ownership["safe"](target) or target.exists() and target.stat().st_uid != os.getuid():
            raise RuntimeError("Unsafe shell profile location: " + str(path))
        current = base64.b64decode(snapshot["data"]).decode() if snapshot["data"] is not None else ""
        if old:
            if snapshot["target"] != old["before"]["target"] or current.count(old["text"]) != 1:
                raise RuntimeError("The managed PATH block was edited or replaced: " + str(path))
            separator = old["text"][:len(old["text"]) - len(old["text"].lstrip("\n"))]
            text = separator + block
            contents = current.replace(old["text"], text, 1)
            before = old["before"]
        else:
            if PATH_START.rstrip() in current or PATH_END.rstrip() in current:
                raise RuntimeError("Unrecorded PATH block in shell profile: " + str(path))
            separator = "" if not current else "\n" if current.endswith("\n") else "\n\n"
            text = separator + block
            contents = current + text
            before = snapshot
        planned[str(path)] = dict(before=before, text=text, snapshot=snapshot,
                                  contents=contents.encode(), mode=snapshot["mode"] if snapshot["data"] is not None else 0o644)
    return planned


def apply_path_plan(planned, ownership):
    for name, entry in planned.items():
        if entry["snapshot"]["data"] is None or base64.b64decode(entry["snapshot"]["data"]) != entry["contents"]:
            if ownership["snapshot"](Path(name)) != entry["snapshot"]:
                raise RuntimeError("Shell profile changed during installation: " + name)
            entry["applied"] = True
            ownership["atomic"](Path(entry["snapshot"]["target"]), entry["contents"], entry["mode"])


def rollback_path_plan(planned, ownership):
    for name, entry in planned.items():
        if not entry.get("applied"):
            continue
        snapshot = entry["snapshot"]
        target = Path(snapshot["target"])
        current = ownership["snapshot"](target)
        if current == snapshot:
            continue
        if str(Path(name).resolve()) != snapshot["target"] or current["data"] != base64.b64encode(entry["contents"]).decode() or current["mode"] != entry["mode"]:
            print("Preserved file changed during installation: " + name, file=sys.stderr)
            continue
        if snapshot["data"] is None:
            target.unlink(missing_ok=True)
        else:
            ownership["atomic"](target, base64.b64decode(snapshot["data"]), snapshot["mode"])


def path_removals(record, ownership):
    changes, preserve = {}, []
    for name, entry in record.get("path_files", {}).items():
        path = Path(name)
        before = entry["before"]
        if not path.is_absolute() or not ownership["safe"](Path(before["target"])) or str(path.resolve()) != before["target"]:
            preserve.append(name)
            continue
        if not path.exists():
            continue
        if path.stat().st_uid != os.getuid():
            preserve.append(name)
            continue
        current = ownership["snapshot"](path)
        data = base64.b64decode(current["data"]).decode()
        text = entry["text"]
        if data.count(text) != 1:
            if PATH_START.rstrip() in data or PATH_END.rstrip() in data:
                preserve.append(name)
            continue
        original = base64.b64decode(before["data"]).decode() if before["data"] is not None else ""
        if data == original + text:
            contents = base64.b64decode(before["data"]) if before["data"] is not None else None
        else:
            start = data.index(text)
            prefix, suffix = data[:start], data[start + len(text):]
            separator = "\n" if prefix and suffix and not prefix.endswith("\n") and not suffix.startswith("\n") else ""
            contents = (prefix + separator + suffix).encode()
        changes[name] = dict(target=current["target"], contents=base64.b64encode(contents).decode() if contents is not None else None, mode=current["mode"], snapshot=current)
    return changes, preserve


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
    ownership = runpy.run_path(str(ROOT / "scripts/lib/ownership.py"))
    expected = ownership["roots"]()["config"] / "quickshell/bloodyShell"
    if not ownership["safe"](expected) or (expected / ".git").exists():
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
    manifest = install_manifest(ownership)
    if not ownership["safe"](manifest):
        raise RuntimeError("Unsafe installation record location")
    old_record = json.loads(manifest.read_text()) if manifest.exists() else None
    if old_record is not None and (not isinstance(old_record, dict) or old_record.get("runtime") != str(expected)):
        raise RuntimeError("Installation record belongs to a different runtime")
    path_plan(binary, ownership, old_record)
    command = binary / "bloodyShell"
    if old_record and old_record.get("command") == str(command) and command.exists() and command_fingerprint(command) != old_record.get("command_fingerprint"):
        raise RuntimeError("The installed command was edited or replaced")
    if old_record and old_record.get("command") == str(SYSTEM_COMMAND) and binary / "bloodyShell" != SYSTEM_COMMAND and SYSTEM_COMMAND.exists():
        # Authentication happens before the installed runtime is moved.
        if command_fingerprint(SYSTEM_COMMAND) == old_record.get("command_fingerprint"):
            print("Authorize removal of the previous command: " + str(SYSTEM_COMMAND), file=sys.stderr)
            subprocess.run(["sudo", "-v"], check=True)


def install_main():
    def interrupt(signum, frame):
        raise SystemExit(128 + signum)
    previous = {sig: signal.signal(sig, interrupt) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        return install_command_main()
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def install_command_main():
    if len(sys.argv) not in (4, 5) or len(sys.argv) == 5 and sys.argv[4] != "--refresh-files":
        raise RuntimeError("Usage: install-command SOURCE BIN_DIR BACKUP_DIR [--refresh-files]")
    source, binary, backup = map(Path, sys.argv[1:4])
    ownership = runpy.run_path(str(ROOT / "scripts/lib/ownership.py"))
    command = binary / "bloodyShell"
    manifest = install_manifest(ownership)
    root = source.resolve().parents[1]
    if not ownership["safe"](manifest):
        raise RuntimeError("Unsafe installation record location")
    old_record = json.loads(manifest.read_text()) if manifest.exists() else None
    if old_record is not None:
        if not isinstance(old_record, dict) or old_record.get("version") != 1:
            raise RuntimeError("Invalid installation record")
        if (command.exists() or command.is_symlink()) and str(command.absolute()) == old_record.get("command"):
            if command_fingerprint(command) != old_record.get("command_fingerprint"):
                raise RuntimeError("The installed command was edited or replaced; move or restore it before reinstalling the command")
    if command == SYSTEM_COMMAND:
        if not ownership["safe"](command):
            raise RuntimeError("Unsafe system command location")
        if command.exists():
            command_fingerprint(command)
            if (old_record is None or old_record.get("command") != str(command)) and command.read_bytes() != source.read_bytes():
                raise RuntimeError("System command already exists; move it before installing: " + str(command))
    planned = path_plan(binary, ownership, old_record)
    previous = ownership["snapshot"](command) if not command.is_symlink() else None
    previous_link = os.readlink(command) if command.is_symlink() else None
    retired = {}
    if old_record is not None:
        for key, name in (("command", "bloodyShell"), ("application", "bloodyShell.desktop")):
            if not isinstance(old_record.get(key), str):
                continue
            path = Path(old_record[key])
            if path == command or not (path.exists() or path.is_symlink()):
                continue
            if path.name != name or not ownership["safe"](path) or command_fingerprint(path) != old_record.get(key + "_fingerprint"):
                print("Preserved edited or unsafe file: " + str(path), file=sys.stderr)
                continue
            retired[path] = ownership["snapshot"](path)
    try:
        result = install(source, binary, backup)
        apply_path_plan(planned, ownership)
        for path in retired:
            remove_command(path)
        record_installation(root, command, ownership, planned, refresh=len(sys.argv) == 5)
    except BaseException:
        rollback_path_plan(planned, ownership)
        # Registration is part of installation; do not leave a new launcher on failure.
        if previous_link is not None:
            command.unlink(missing_ok=True)
            command.symlink_to(previous_link)
        elif previous is not None and ownership["snapshot"](command) != previous:
            if previous["data"] is None:
                remove_command(command)
            else:
                write_command(command, base64.b64decode(previous["data"]), previous["mode"])
        for path, snapshot in retired.items():
            if not path.exists():
                write_command(path, base64.b64decode(snapshot["data"]), snapshot["mode"])
        raise
    print(json.dumps(result))


def fingerprint(path, owner=None):
    info = path.lstat()
    if info.st_uid != (os.getuid() if owner is None else owner):
        raise RuntimeError("File belongs to another user: " + str(path))
    if stat.S_ISLNK(info.st_mode):
        return dict(kind="symlink", target=os.readlink(path))
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("Not a regular installed file: " + str(path))
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return dict(kind="file", sha256=digest.hexdigest(), mode=stat.S_IMODE(info.st_mode))


def install_manifest(ownership):
    return ownership["roots"]()["state"] / "bloodyShell/install.json"


def record_installation(root, command, ownership, planned, refresh=False):
    if not ownership["safe"](root) or (root / ".git").exists():
        raise RuntimeError("Refusing to register a symlink installation or source checkout")
    manifest = install_manifest(ownership)
    if not ownership["safe"](manifest) or manifest.is_relative_to(root):
        raise RuntimeError("Unsafe installation record location")
    old_record = json.loads(manifest.read_text()) if manifest.exists() else None
    if old_record is not None and (old_record.get("runtime") != str(root) or not isinstance(old_record.get("files"), dict)):
        raise RuntimeError("Existing installation record belongs to a different runtime or is invalid")
    if old_record is not None and not refresh:
        # Repairing a launcher must not adopt subsequent user edits as installed files.
        files = old_record["files"]
    else:
        files = {str(path.relative_to(root)): fingerprint(path) for path in root.rglob("*")
                 if path.is_symlink() or path.is_file()}
    record = dict(version=1, runtime=str(root), command=str(command.absolute()),
                  command_fingerprint=command_fingerprint(command), files=files,
                  path_files={name: dict(before=entry["before"], text=entry["text"]) for name, entry in planned.items()})
    ownership["atomic"](manifest, (json.dumps(record, indent=2) + "\n").encode())


@contextmanager
def uninstall_lock(ownership):
    directory = install_manifest(ownership).parent
    if not ownership["safe"](directory):
        raise RuntimeError("Unsafe installation state directory")
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(directory / "operation.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another installation, update or uninstall is in progress") from None
        yield


def uninstall_plan(ownership):
    root = ownership["roots"]()["config"] / "quickshell/bloodyShell"
    manifest = install_manifest(ownership)
    if not ownership["safe"](root) or not ownership["safe"](manifest):
        raise RuntimeError("Uninstall refused: installation or record path contains a symlink")
    if not manifest.exists():
        if root.exists():
            raise RuntimeError("Installation has no ownership record. Install or repair this version first; existing files were preserved.")
        return dict(runtime=str(root), remove=[], preserve=[], command=None, manifest=None, cleanup=[], preserve_data=[])
    if manifest.stat().st_uid != os.getuid():
        raise RuntimeError("Installation record belongs to another user")
    record = json.loads(manifest.read_text())
    if (not isinstance(record, dict) or record.get("version") != 1 or record.get("runtime") != str(root)
            or not isinstance(record.get("files"), dict) or not isinstance(record.get("command"), str)
            or not isinstance(record.get("command_fingerprint"), dict)):
        raise RuntimeError("Installation record does not match this installation")
    if (root / ".git").exists():
        raise RuntimeError("Uninstall refused: the installation is a source checkout")
    remove, preserve = [], []
    for relative, expected in record["files"].items():
        if not isinstance(expected, dict) or expected.get("kind") not in ("file", "symlink"):
            raise RuntimeError("Invalid file fingerprint in installation record")
        part = Path(relative)
        if part.is_absolute() or not part.parts or ".." in part.parts:
            raise RuntimeError("Invalid file path in installation record")
        path = root / part
        if not ownership["safe"](path.parent):
            preserve.append(str(path))
        elif path.exists() or path.is_symlink():
            if fingerprint(path) == expected:
                remove.append(str(path))
            else:
                preserve.append(str(path))
    if root.is_dir():
        for path in root.rglob("*"):
            if (path.is_file() or path.is_symlink()) and str(path.relative_to(root)) not in record["files"]:
                preserve.append(str(path))
    command = Path(record["command"])
    if not command.is_absolute() or command.name != "bloodyShell":
        raise RuntimeError("Invalid launcher path in installation record")
    if command.exists() or command.is_symlink():
        if ownership["safe"](command.parent) and command_fingerprint(command) == record["command_fingerprint"]:
            remove.append(str(command))
        else:
            preserve.append(str(command))
    path_changes, path_preserve = path_removals(record, ownership)
    preserve.extend(path_preserve)
    cleanup, preserve_data = [], []
    for row in ownership["inventory"]():
        if row["kind"] != "disposable" or not row["exists"]:
            continue
        path = Path(row["path"])
        if row["safe"] and path.stat().st_uid == os.getuid():
            cleanup.append(str(path))
        else:
            preserve_data.append(str(path))
    return dict(runtime=str(root), remove=remove, preserve=sorted(set(preserve)),
                command=str(command), manifest=str(manifest), cleanup=cleanup, preserve_data=preserve_data, path_changes=path_changes)


def uninstall_main():
    parser = argparse.ArgumentParser(prog="bloodyShell uninstall", description="Preview removal of the recorded runtime and command; preserve personal and system settings")
    parser.add_argument("--apply", action="store_true", help="stop the installed shell and remove unchanged installed files")
    parser.add_argument("--restore", action="store_true", help="restore unchanged tracked integrations before uninstalling")
    parser.add_argument("--json", action="store_true")
    options = parser.parse_args()
    if os.geteuid() == 0:
        raise RuntimeError("Run uninstall as your normal user, without sudo")
    ownership = runpy.run_path(str(ROOT / "scripts/lib/ownership.py"))
    plan = uninstall_plan(ownership)
    if not options.apply:
        if options.json:
            print(json.dumps(dict(plan, path_changes=list(plan.get("path_changes", {}))), indent=2))
        else:
            print(f'Preview: remove {len(plan["remove"])} unchanged installed files from {plan["runtime"]} and the recorded command.')
            for name in plan.get("path_changes", {}):
                print("Remove managed PATH block: " + name)
            for path in plan["preserve"]:
                print("Preserve modified or untracked file: " + path)
            for path in plan["cleanup"]:
                print("Disposable cache/runtime data (kept if another shell is running): " + path)
            for path in plan["preserve_data"]:
                print("Preserve cache with an unverified owner or symlink: " + path)
            if options.restore:
                ownership["restore"]([])
            print("Settings, backups, imports, packages, greeter, PAM and fstab are preserved. Use uninstall --apply to proceed.")
        return 0
    if not plan["manifest"]:
        print("No recorded installation to remove.")
        return 0
    with uninstall_lock(ownership):
        plan = uninstall_plan(ownership)
        if str(SYSTEM_COMMAND) in plan["remove"]:
            subprocess.run(["sudo", "-v"], check=True)
        control = runpy.run_path(str(ROOT / "scripts/bloodyShell"))
        command = shutil.which("qs") or shutil.which("quickshell")
        if command:
            control["stop"](command, Path(plan["runtime"]), quiet=True)
            others = any(control["is_shell"](entry) for entry in control["instances"](command))
        else:
            # Uninstall also works after dependencies were removed, provided no Qt shell remains.
            for process in Path("/proc").glob("[0-9]*"):
                try:
                    if process.stat().st_uid == os.getuid() and (process / "comm").read_text().strip() in ("qs", "quickshell"):
                        raise RuntimeError("Quickshell is running but its command is unavailable; stop it before uninstalling")
                except (FileNotFoundError, PermissionError):
                    continue
            others = False
        if options.restore:
            if others:
                raise RuntimeError("Stop other bloodyShell instances before restoring shared user integrations")
            if ownership["restore"](["--apply"]):
                raise RuntimeError("Restoration preserved edited integrations; installation was kept. Review conflicts or uninstall without --restore.")
        # Recheck after stopping services: shutdown may have changed installed data.
        plan = uninstall_plan(ownership)
        if not others:
            ownership["cleanup_owned"]([dict(path=path, safe=True) for path in plan["cleanup"]])
        else:
            plan["preserve_data"].extend(plan["cleanup"])
            plan["cleanup"] = []
        for name, entry in plan["path_changes"].items():
            if ownership["snapshot"](Path(name)) != entry["snapshot"]:
                plan["preserve"].append(name)
                continue
            target = Path(entry["target"])
            if entry["contents"] is None:
                target.unlink(missing_ok=True)
            else:
                ownership["atomic"](target, base64.b64decode(entry["contents"]), entry["mode"])
        for name in plan["remove"]:
            if name == str(SYSTEM_COMMAND):
                remove_command(SYSTEM_COMMAND)
            else:
                Path(name).unlink()
        root = Path(plan["runtime"])
        if root.is_dir():
            directories = [path for path in root.rglob("*") if path.is_dir() and not path.is_symlink()]
            for path in sorted(directories, key=lambda item: len(item.parts), reverse=True) + [root]:
                try:
                    path.rmdir()
                except OSError:
                    pass
        if not plan["preserve"]:
            Path(plan["manifest"]).unlink(missing_ok=True)
        if options.json:
            print(json.dumps(dict(plan, path_changes=list(plan.get("path_changes", {}))), indent=2))
        else:
            print("Installed shell and unchanged launcher files removed.")
            for path in plan["preserve"]:
                print("Preserved modified or untracked file: " + path)
            for path in plan["preserve_data"]:
                print("Preserved cache/runtime data: " + path)
            print("Personal settings, backups and system integrations were preserved.")
    return 0

