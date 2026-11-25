"""Dependency catalog, diagnostics, runtime updates, command installation and uninstall."""

from pathlib import Path
import argparse
import ast
from contextlib import contextmanager, ExitStack
import fcntl
import json
import os
import pwd
import re
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


def package_data(root=None):
    data = json.loads(((ROOT if root is None else root) / "assets/packages.json").read_text())
    if not isinstance(data, dict) or data.get("version") != 1 or data.get("distributions") != ["arch", "fedora", "debian"]:
        raise ValueError("Invalid package catalog")
    installer = data.get("installer")
    entries, options = data.get("dependencies"), installer.get("options") if isinstance(installer, dict) else None
    if not isinstance(entries, list) or not entries or not isinstance(options, list) or not options:
        raise ValueError("Invalid package catalog entries")
    for records, key in ((entries, "tool"), (options, "id")):
        identifiers = [entry.get(key) for entry in records if isinstance(entry, dict)]
        if len(identifiers) != len(records) or any(not isinstance(name, str) or not name for name in identifiers) or len(set(identifiers)) != len(identifiers):
            raise ValueError("Invalid or duplicate package catalog identifier")
    for entry in [*entries, *options]:
        mapping = entry.get("packages", {})
        if not isinstance(mapping, dict) or not isinstance(entry.get("description"), str) or not entry["description"].strip():
            raise ValueError("Invalid package metadata")
        for family, names in mapping.items():
            if family not in data["distributions"] or not isinstance(names, list) or any(not isinstance(name, str) or not re.fullmatch(r"(?:copr:)?[A-Za-z0-9][A-Za-z0-9+_.:/@-]*", name) for name in names):
                raise ValueError("Invalid package mapping")
    for entry in entries:
        if type(entry.get("required")) is not bool or not isinstance(entry.get("name"), str) or not entry["name"].strip() or set(entry["packages"]) != set(data["distributions"]):
            raise ValueError("Invalid dependency metadata")
        commands = entry.get("commands", [])
        if not isinstance(commands, list) or any(not isinstance(command, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+_.-]*", command) for command in commands):
            raise ValueError("Invalid dependency command")
    known = {entry["tool"] for entry in entries}
    choices = {entry["id"] for entry in options}
    for entry in options:
        if not isinstance(entry.get("label"), str) or not entry["label"].strip() or any(not isinstance(entry.get(key, []), list) or any(not isinstance(value, str) for value in entry.get(key, [])) for key in ("tools", "requires")):
            raise ValueError("Invalid installer option metadata")
        if entry.get("section") not in ("Packages", "Tools", "Appearance") or not set(entry.get("tools", [])).issubset(known) or not set(entry.get("requires", [])).issubset(choices):
            raise ValueError("Invalid installer option")
    return data


def catalog():
    data = package_data()
    return [dict(kind="required" if entry["required"] else "optional", tool=entry["tool"], name=entry["name"], feature=entry["description"],
                 **{family: " ".join(entry["packages"].get(family, [])) or "-" for family in data["distributions"]}) for entry in data["dependencies"]]


def installer_packages(family):
    data = package_data()
    if family not in data["distributions"]:
        raise ValueError("Unsupported package distribution")
    entries = {entry["tool"]: entry for entry in data["dependencies"]}
    return {option["id"]: list(dict.fromkeys([
        *option.get("packages", {}).get(family, []),
        *(name for tool in option.get("tools", []) for name in entries[tool]["packages"][family])
    ])) for option in data["installer"]["options"]}


def available(tool):
    if tool == "qs":
        return bool(shutil.which("qs") or shutil.which("quickshell"))
    if tool == "bluetoothd":
        return bool(shutil.which("bluetoothd") or any(path.is_file() for path in (Path("/usr/lib/bluetooth/bluetoothd"), Path("/usr/libexec/bluetooth/bluetoothd"))))
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
    entry = next((entry for entry in package_data()["dependencies"] if entry["tool"] == tool), {})
    return all(shutil.which(command) for command in entry.get("commands", []))


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


def state_directory():
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "bloodyShell"


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


def dependencies_status(kind=None):
    distro = family()
    entries = catalog()
    protected = {name for item in entries if item["kind"] == "required" for name in packages(item, distro)}
    return {"terminal": terminal(), "entries": [
        {"tool": item["tool"], "feature": item["feature"], "required": item["kind"] == "required" or item["tool"] == "python3", "installed": available(item["tool"]),
         "packages": packages(item, distro), "removable": item["kind"] != "required" and item["tool"] != "python3" and not protected.intersection(packages(item, distro)),
         "supported": bool(packages(item, distro))} for item in entries if kind is None or item["kind"] == kind]}


def dependencies_main():
    if sys.argv[1:] == ["family"]:
        print(family())
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "native-packages":
        distro = sys.argv[2]
        groups = installer_packages(distro)
        print("\n".join(dict.fromkeys(groups["input"])))
        return 0
    if sys.argv[1:] == ["catalog"]:
        print("\n".join("|".join(entry[key] for key in ("kind", "tool", "feature", "arch", "fedora", "debian")) for entry in catalog()))
        return 0
    if len(sys.argv) == 3 and sys.argv[1] == "check":
        known = {entry["tool"] for entry in catalog()}
        return 0 if sys.argv[2] in known and available(sys.argv[2]) else 1
    if sys.argv[1:] == ["status"] or (len(sys.argv) == 3 and sys.argv[1] == "status" and sys.argv[2] in ("required", "optional")):
        print(json.dumps(dependencies_status(sys.argv[2] if len(sys.argv) == 3 else None)))
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

    for entry in catalog():
        record(entry["tool"], available(entry["tool"]), entry["kind"] == "required", entry["feature"])
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
    login_shell = Path(pwd.getpwuid(os.getuid()).pw_shell).name
    if shell == "fish" or login_shell == "fish" or (config / "fish").is_dir():
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


RUNTIME_FILES = ("shell.qml", "version")
RUNTIME_DIRS = ("assets", "modules", "scripts", "translations")


def runtime_member(relative):
    parts = relative.parts
    return bool(parts) and not any(part.startswith(".") or part == "__pycache__" for part in parts) and relative.suffix.lower() not in (".md", ".pyc", ".pyo") and (
        relative.as_posix() in RUNTIME_FILES or parts[0] in RUNTIME_DIRS
    ) and not any(relative.is_relative_to(path) for path in (Path("scripts/tests"), Path("scripts/tools")))


def stage_runtime(source, target, binary):
    if target.is_symlink() or not target.is_dir() or any(target.iterdir()) or target.is_relative_to(source):
        raise RuntimeError("Runtime staging needs an empty directory outside the source")
    expected = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "quickshell/bloodyShell"
    if not FILES["safe_path"](expected) or (expected / ".git").exists():
        raise RuntimeError("Refusing to replace a symlink installation or source checkout")
    for name in RUNTIME_FILES:
        if not (source / name).is_file() or (source / name).is_symlink():
            raise RuntimeError("Missing runtime file: " + name)
    package_data(source)
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
        if path.is_file() and path.suffix == ".sh":
            subprocess.run(["bash", "-n", str(path)], check=True)
    compile((target / "scripts/bloodyShell").read_bytes(), str(target / "scripts/bloodyShell"), "exec")
    for name in ("scripts/bloodyShell", "scripts/lib/backend.py", "scripts/lib/management.py", "scripts/lib/setup.py", "scripts/lib/system.sh"):
        if not (target / name).is_file():
            raise RuntimeError("Package is missing " + name)
    backend = ast.parse((target / "scripts/lib/backend.py").read_text())
    registry = next((ast.literal_eval(node.value) for node in backend.body if isinstance(node, ast.Assign)
                     and any(isinstance(name, ast.Name) and name.id == "MODULES" for name in node.targets)), {})
    if not isinstance(registry, dict) or not {"setup", "update", "doctor", "uninstall", "resources"}.issubset(registry):
        raise RuntimeError("Package is missing the CLI maintenance backend")
    path_plan(binary)


VERSION_PATTERN = re.compile(r"v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?\Z")


def version_key(value):
    match = VERSION_PATTERN.fullmatch(value)
    if not match:
        raise ValueError("Invalid release version: " + value)
    core = tuple(int(part) for part in match.groups()[:3])
    prerelease = match[4]
    parts = prerelease.split(".") if prerelease else []
    if any(not part or part.isdigit() and len(part) > 1 and part.startswith("0") for part in parts):
        raise ValueError("Invalid release version: " + value)
    return core, not bool(prerelease), tuple((0, int(part)) if part.isdigit() else (1, part) for part in parts)


def install_runtime(source, target, binary, backup):
    """Replace the runtime while the caller holds the shared operation lock."""
    if not FILES["safe_path"](target) or (target / ".git").exists():
        raise RuntimeError("Refusing to replace a symlink installation or source checkout")
    if source == target:
        install_command(source / "scripts/bloodyShell", binary, backup / "launcher")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    previous = backup / "shell"
    committed = fresh_backup = False
    with tempfile.TemporaryDirectory(prefix=".bloodyShell-runtime-", dir=target.parent) as temporary:
        staged = Path(temporary) / "runtime"
        rollback = Path(temporary) / "previous"
        staged.mkdir()
        stage_runtime(source, staged, binary)
        try:
            if target.exists():
                previous.parent.mkdir(parents=True, exist_ok=True)
                if previous.exists():
                    raise RuntimeError("The update backup already exists")
                fresh_backup = True
                FILES["copy_path"](target, previous)
                os.replace(target, rollback)
            os.replace(staged, target)
            subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                            str(target / "scripts/bloodyShell"), str(binary), str(backup / "launcher")], check=True, stdout=subprocess.DEVNULL)
            committed = True
        finally:
            if not committed:
                if rollback.exists():
                    remove_path(target)
                    os.replace(rollback, target)
                elif not staged.exists():
                    remove_path(target)
                if fresh_backup:
                    remove_path(previous)


def runtime_main():
    if len(sys.argv) != 4:
        raise ValueError("Usage: install-runtime SOURCE BIN_DIR BACKUP_DIR")
    source, binary, backup = (Path(value).absolute() for value in sys.argv[1:])
    target = command_location()[0]
    with command_signals():
        install_runtime(source, target, binary, backup)
    print("Shell → " + str(target), flush=True)
    return 0


def restart_runtime(verify=False, source=None):
    target = command_location()[0]
    if not os.environ.get("WAYLAND_DISPLAY") or not (target / "scripts/bloodyShell").is_file():
        return None
    try:
        cli = runpy.run_path(str((source or target) / "scripts/bloodyShell"))
        command = cli["quickshell"]()
        previous = {entry["id"] for entry in cli["instances"](command, target)} if verify else set()
        cli["stop"](command, target, quiet=True)
        result = FILES["run"]([command, "--no-duplicate", "--path", str(target), "--daemonize"],
                              capture_output=True, text=True, timeout=30 if verify else 15)
        if result.returncode or not verify:
            return result.returncode == 0
        return verify_runtime(cli, command, target, previous)
    except (OSError, RuntimeError, subprocess.SubprocessError):
        return False


def verify_runtime(cli, command, target, previous, timeout=30, stable=2):
    """Require a fresh instance to answer IPC and remain ready before committing."""
    expected = (target / "version").read_text().strip()
    deadline = time.monotonic() + timeout
    ready_id, ready_since = None, None
    while time.monotonic() < deadline:
        healthy = None
        try:
            for entry in cli["instances"](command, target):
                if entry["id"] in previous:
                    continue
                reply = FILES["run"]([command, "ipc", "--id", entry["id"], "call", "--", "health", "status"],
                                     capture_output=True, text=True, timeout=min(2, max(0.1, deadline - time.monotonic())))
                if reply.returncode:
                    continue
                health = json.loads(reply.stdout)
                if isinstance(health, dict) and health.get("ready") is True and health.get("version") == expected:
                    healthy = entry["id"]
                    break
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
            pass
        if healthy is None:
            ready_id, ready_since = None, None
        elif healthy != ready_id:
            ready_id, ready_since = healthy, time.monotonic()
        elif time.monotonic() - ready_since >= stable:
            return True
        time.sleep(0.2)
    return False


def restore_runtime(target, binary, backup):
    """Restore the known working runtime and launcher without touching user configs."""
    previous = backup / "shell"
    if not previous.is_dir() or previous.is_symlink() or not FILES["safe_path"](target):
        raise RuntimeError("The previous shell backup is unavailable: " + str(previous))
    # Stop the rejected version before replacing its files. Failure to stop must
    # leave both the installed version and its backup available for recovery.
    cli = runpy.run_path(str(previous / "scripts/bloodyShell"))
    cli["stop"](cli["quickshell"](), target, quiet=True)
    with tempfile.TemporaryDirectory(prefix=".bloodyShell-recovery-", dir=target.parent) as temporary:
        staged, rejected = Path(temporary) / "runtime", Path(temporary) / "rejected"
        FILES["copy_path"](previous, staged)
        restored = False
        try:
            os.replace(target, rejected)
            os.replace(staged, target)
            launcher = backup / "launcher/command"
            if launcher.is_symlink():
                remove_command(binary / "bloodyShell")
                (binary / "bloodyShell").symlink_to(os.readlink(launcher))
            elif launcher.is_file():
                write_command(binary / "bloodyShell", launcher.read_bytes(), stat.S_IMODE(launcher.stat().st_mode))
            restored = True
        finally:
            if rejected.exists() and not restored:
                remove_path(target)
                os.replace(rejected, target)


def refresh_login_screen(source, tag, pending):
    if not SDDM_THEME.is_dir() or SDDM_THEME.is_symlink():
        pending.unlink(missing_ok=True)
        return
    pending.parent.mkdir(parents=True, exist_ok=True)
    FILES["atomic_write"](pending, (tag + "\n").encode(), 0o600)
    try:
        # Invoke the refresh function explicitly. Old releases only know how to install SDDM.
        result = subprocess.run(["bash", "-euo", "pipefail", "-c",
                                 'readonly NAME=bloodyShell PACKAGE="$1"\n'
                                 'source "$PACKAGE/scripts/lib/system.sh"\nrefresh_greeter',
                                 "bloodyShell-refresh-greeter", str(source)])
    except OSError as error:
        print("Could not refresh the login screen: " + str(error), file=sys.stderr, flush=True)
        return
    if result.returncode == 0:
        pending.unlink(missing_ok=True)
    else:
        message = "Administrator access is needed to refresh the login screen." if result.returncode == 75 else "The login-screen refresh failed."
        print(message + " Run bloodyShell update in a terminal to retry.", file=sys.stderr, flush=True)


def update_main():
    parser = argparse.ArgumentParser(prog="bloodyShell update", description="Check for and install a bloodyShell release")
    parser.add_argument("--beta", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--tag")
    options = parser.parse_args()
    if os.geteuid() == 0:
        raise RuntimeError("Run update as your normal user, without sudo")
    target, binary = command_location()
    state = state_directory()
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "bloodyShell"
    status_file = Path(os.environ.get("BLOODYSHELL_STATUS") or cache / "update.status")
    recovery_file = cache / "update-recovery.json"
    pending_login = cache / "login-screen-update.pending"
    def status(value):
        status_file.parent.mkdir(parents=True, exist_ok=True)
        FILES["atomic_write"](status_file, (value + "\n").encode(), 0o600)
    def step(index, message):
        status(f"step {index}/4 {message}")
        print(message, flush=True)
    def download(url, destination=None):
        command = ["curl", "-fsSL", "--retry", "2", "--max-time", "120" if destination else "20"]
        if destination is not None:
            command += ["-o", str(destination)]
        result = FILES["run"]([*command, url], capture_output=True, text=True, timeout=130)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or "GitHub is unreachable")
        return result.stdout
    try:
        status("running")
        with command_signals(), operation_lock(state):
            if not (target / "shell.qml").is_file():
                raise RuntimeError("The shell is not installed. Run ./setup from the source folder.")
            current = (target / "version").read_text().strip() if (target / "version").is_file() else "0.0.0"
            step(1, "Checking for updates")
            pending_tag = pending_login.read_text().strip() if pending_login.is_file() else ""
            if pending_tag and (not SDDM_THEME.is_dir() or SDDM_THEME.is_symlink()):
                pending_login.unlink(missing_ok=True)
                pending_tag = ""
            tag = options.tag
            if tag is None:
                releases = json.loads(download("https://api.github.com/repos/bloodykgrapes/bloodyShell/releases?per_page=30"))
                if not isinstance(releases, list):
                    raise ValueError("Invalid release response")
                candidates = []
                for release in releases:
                    if not isinstance(release, dict) or release.get("draft") or release.get("prerelease") and not options.beta:
                        continue
                    candidate = release.get("tag_name", "")
                    try:
                        key = version_key(candidate)
                    except (TypeError, ValueError):
                        continue
                    if options.beta or key[1]:
                        candidates.append((key, candidate))
                if not candidates:
                    raise RuntimeError("No releases are available")
                tag = max(candidates)[1]
            release_key = version_key(tag)
            up_to_date = not options.force and release_key <= version_key(current)
            retry_login = up_to_date and pending_tag and pending_tag.removeprefix("v") == current.removeprefix("v")
            if up_to_date and not retry_login:
                install_command(ROOT / "scripts/bloodyShell", binary, state / "backups" / ("cli-" + str(time.time_ns())))
                print("Up to date · " + current, flush=True)
                status("done " + current)
                return 0
            if retry_login:
                tag = pending_tag
            step(2, "Downloading " + tag.removeprefix("v"))
            with tempfile.TemporaryDirectory(prefix="bloodyShell-release-") as temporary:
                temporary = Path(temporary)
                archive, source = temporary / "release.tar.gz", temporary / "source"
                source.mkdir()
                download(f"https://github.com/bloodykgrapes/bloodyShell/archive/refs/tags/{tag}.tar.gz", archive)
                FILES["extract_archive"](archive, source, allow_links=True)
                if (source / "version").read_text().strip().removeprefix("v") != tag.removeprefix("v"):
                    raise ValueError("Package version does not match the release tag")
                if retry_login:
                    refresh_login_screen(source, tag, pending_login)
                    status("done " + current)
                    return 0 if not pending_login.exists() else 1
                step(3, "Installing " + tag.removeprefix("v"))
                backup = state / "backups" / (time.strftime("%Y-%m-%d_%H-%M-%S") + "-update-" + str(time.time_ns()))
                profiles = path_plan(binary)
                installed = False
                try:
                    with ExitStack() as transaction:
                        config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
                        if (config / "niri/bloodyShell").is_dir():
                            resources = runpy.run_path(str(source / "scripts/lib/resources.py"))
                            resources["import_config"](source / "dots/niri", "niri", transaction)
                        install_runtime(source, target, binary, backup)
                        installed = True
                        step(4, "Checking shell startup")
                        restarted = restart_runtime(verify=True, source=backup / "shell")
                        if restarted is False:
                            raise RuntimeError("The new shell did not pass its startup check")
                except BaseException as failure:
                    if not installed:
                        raise
                    status("step 4/4 Restoring the previous version")
                    print("Startup failed. Restoring the previous version", flush=True)
                    try:
                        restore_runtime(target, binary, backup)
                        rollback_path_plan(profiles)
                        message = "Update failed; restored version " + current
                        cache.mkdir(mode=0o700, parents=True, exist_ok=True)
                        FILES["atomic_write"](recovery_file, json.dumps(dict(tag=tag, version=current, error=message)).encode(), 0o600)
                        recovered = restart_runtime()
                    except BaseException as recovery:
                        raise RuntimeError("Startup failed and automatic recovery could not finish. Backup: " + str(backup) + ". " + str(recovery)) from failure
                    if recovered is False:
                        message += ". Run bloodyShell doctor; the restored shell could not restart"
                        FILES["atomic_write"](recovery_file, json.dumps(dict(tag=tag, version=current, error=message)).encode(), 0o600)
                    raise RuntimeError(message) from failure
                if restarted is None:
                    print("Startup check skipped outside a Wayland session. Previous version saved in " + str(backup), flush=True)
                refresh_login_screen(source, tag, pending_login)
            recovery_file.unlink(missing_ok=True)
            status("done " + tag.removeprefix("v"))
        print("Updated to " + tag.removeprefix("v"), flush=True)
        return 0
    except BaseException as error:
        status("failed " + (str(error).replace("\n", " ") if str(error) else "Update cancelled"))
        if isinstance(error, tarfile.TarError):
            raise RuntimeError("Invalid release archive: " + str(error)) from error
        raise


command_signals = FILES["operation_signals"]
remove_path = FILES["remove_path"]

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
    source = ROOT / "scripts/bloodyShell"
    backup = state_directory() / "backups" / ("cli-" + str(time.time_ns())) / "launcher"
    with command_signals(), operation_lock():
        if not (runtime / "shell.qml").is_file() or (runtime / ".git").exists():
            raise RuntimeError("Install the shell with ./setup install before refreshing its command")
        result = install_command(source, binary, backup)
    return dict(result, destination=result["command"])


TRACKING_FILES = ("install.json", "changes.json", "changes.lock")


def discard_tracking_files():
    directory = state_directory()
    if not FILES["safe_path"](directory):
        raise RuntimeError("Unsafe state directory: " + str(directory))
    for name in TRACKING_FILES:
        (directory / name).unlink(missing_ok=True)


SDDM_THEME = Path("/usr/share/sddm/themes/bloodyShell")
SDDM_CONFIG = Path("/etc/sddm.conf.d/zz-bloodyShell.conf")
SDDM_STATE = Path("/var/lib/bloodyShell")


def sddm_paths():
    return [path for path in (SDDM_THEME, SDDM_CONFIG, SDDM_STATE) if path.exists() or path.is_symlink()]


def clear_greeter():
    paths = [str(path) for path in sddm_paths()]
    if paths:
        subprocess.run(["sudo", "rm", "-rf", "--", *paths], check=True)
    return dict(destination=str(SDDM_THEME), removed=paths)


def uninstall_locations():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    state = state_directory()
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
    sddm = [str(path) for path in sddm_paths()] if delete_sddm else []
    return dict(runtime=str(root), command=str(locations["command"]), remove=remove, sddm=sddm,
                path_files=path_block_cleanup(locations["profiles"]), delete_settings=delete_settings,
                delete_sddm=delete_sddm, kept_cache=[])


@contextmanager
def operation_lock(state=None):
    state = state if state is not None else state_directory()
    check_uninstall_path(state)
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(state / "operation.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Another installation, update or uninstall is in progress") from None
        yield


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
    if not options.apply and not options.json and sys.stdin.isatty() and sys.stdout.isatty():
        ui = runpy.run_path(str(ROOT / "scripts/lib/setup.py"))
        return ui["uninstall_wizard"](options.delete_settings, options.delete_sddm)
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
    with operation_lock(locations["state"]):
        if plan["sddm"]:
            subprocess.run(["sudo", *(["-n"] if options.json else []), "-v"], check=True)
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
            clear_greeter()
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
