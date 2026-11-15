#!/usr/bin/env python3

import errno
import fcntl
import json
import os
import pty
from pathlib import Path
import runpy
import shutil
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
API = runpy.run_path(str(ROOT / "scripts/lib/setup.py"))


class Screen:
    def __init__(self, keys=(), height=32, width=90):
        self.keys, self.height, self.width = iter(keys), height, width
        self.lines, self.frames = {}, []

    def keypad(self, enabled): pass
    def getmaxyx(self): return self.height, self.width
    def erase(self): self.lines = {}
    def refresh(self): self.frames.append("\n".join(self.lines.values()))
    def get_wch(self): return next(self.keys)
    def move(self, y, x): pass
    def timeout(self, milliseconds): pass
    def clearok(self, enabled): pass
    def addnstr(self, y, x, text, size, style):
        line = list(self.lines.get(y, "").ljust(self.width))
        part = text[:size]
        line[x:x + len(part)] = part
        self.lines[y] = "".join(line)


def ui_checks(base):
    import curses
    wizard = API["Wizard"]
    with patch("curses.has_colors", return_value=False), patch("curses.curs_set"), \
            patch.dict(wizard.run.__globals__, pending_packages=lambda plan: ["fixture"]):
        no = Screen(("j", "\n"))
        assert wizard(no).run() == 0
        assert "fresh install" in no.frames[0] and "Package" in no.frames[0]
        screen = Screen(("\n", "\t", " ", "\n", " ", "\t", "\n", "\n", "j", "\n", "\t", "j", "\n",
                         "\n", "\n", "\n", "j", "j", "\n"))
        instance = wizard(screen)
        assert "wallpapers" not in instance.selected, "Setup downloads wallpapers without opting in"
        assert instance.run() == 0
        assert "input" not in instance.selected and "themes" not in instance.selected
        assert instance.backup is False, "Editing lost the backup choice"
        assert any("Packages" in frame for frame in screen.frames)
        assert any("Appearance" in frame for frame in screen.frames)
        assert any("Ready" in frame and "Installs 1 packages" in frame for frame in screen.frames)
        assert "Tab back" not in next(frame for frame in screen.frames if "Input tools" in frame)
        assert "Tab back" not in next(frame for frame in screen.frames if "Ready" in frame)
        assert all("> " not in frame for frame in screen.frames)
        assert no.lines[3].index("fresh install") == 16, "Version info stretched across the terminal"
        assert no.lines[9].strip() == "Choose optional programs and configs."
        for page, keys in ((1, API["OPTIONS"][:4]), (2, API["OPTIONS"][4:])):
            descriptions = Screen((*["j"] * len(keys), "\x1b"))
            instance = wizard(descriptions)
            instance.navigate(page)
            try:
                instance.run()
                raise AssertionError("Escape did not cancel setup")
            except KeyboardInterrupt:
                pass
            for key in keys:
                assert API["DESCRIPTIONS"][key] in " ".join(descriptions.frames)
        short = Screen(("j", "j", "\n"), height=24, width=60)
        instance = wizard(short)
        instance.selected = set(API["OPTIONS"])
        instance.plan = API["make_plan"](instance.selected, family="arch")
        instance.pending = ["fixture"]
        instance.navigate(4)
        assert instance.run() == 0
        for label in API["LABELS"].values():
            assert label in short.frames[0], (label, short.frames[0])

        class CompletionScreen(Screen):
            def get_wch(self):
                key = super().get_wch()
                if key == "small":
                    self.height, self.width = 20, 50
                    return curses.KEY_RESIZE
                if key == "restore":
                    self.height, self.width = 24, 60
                    return curses.KEY_RESIZE
                return key

        complete = CompletionScreen(("small", "restore", "\n"))
        instance = wizard(complete)
        instance.plan = API["make_plan"]([], family="arch")
        stages, restarts = [], []
        with patch.object(wizard, "command", lambda self, args, *rest: stages.append(args)), \
                patch.dict(instance.install.__globals__["MANAGEMENT"], restart_runtime=lambda: restarts.append(True) or False):
            assert instance.install() == 0
        frames = [frame for frame in complete.frames if "Installation complete" in frame]
        assert len(frames) == 3 and all("Enter to close" in frame for frame in frames), "Completion hint disappeared after resizing"
        assert "installation details" in frames[1] and "6/6 stages complete" in frames[2]
        assert len(stages) == len(API["STAGES"]) and restarts == [True], "Redrawing completion repeated installation work"
    print("Setup navigation, disabled Packages/Ready back, edit persistence, option descriptions and compact layout passed.")


def login_shell_checks(base):
    apply = API["apply_login_shell"]
    plan = API["make_plan"](["fish"], family="arch")
    no_fish = API["make_plan"]([], family="arch")
    account = SimpleNamespace(pw_name="fixture-user", pw_shell="/bin/bash")
    with patch("pwd.getpwuid", return_value=account), \
            patch.object(Path, "read_text", return_value="# shells\n/bin/bash\n/usr/bin/fish\n"), \
            patch("os.access", return_value=True), patch("subprocess.run") as run:
        apply(plan)
        run.assert_called_once_with(["sudo", "-n", "chsh", "-s", "/usr/bin/fish", "fixture-user"], check=True)
        run.reset_mock()
        account.pw_shell = "/usr/bin/fish"
        apply(plan)
        run.assert_not_called()
        account.pw_shell = "/bin/bash"
        apply(no_fish)
        run.assert_not_called()
        with patch("os.access", return_value=False):
            try:
                apply(plan)
                raise AssertionError("An unavailable login shell was accepted")
            except ValueError:
                pass
        run.assert_not_called()
    print("Fish opt-in, current-account login shell, already-configured skip and registered executable validation passed.")


def maintenance_checks(base):
    ui = API["MaintenanceUI"]
    with patch("curses.has_colors", return_value=False), patch("curses.curs_set"):
        for index, action in enumerate(("start", "update", "doctor", "restart", "uninstall")):
            screen = Screen((*["j"] * index, "\n"))
            assert ui(screen).menu() == action
            assert all(label in screen.frames[0] for label in ("Start", "Update", "Doctor", "Restart", "Uninstall"))
            assert "Version" in screen.frames[0] and "v" + (ROOT / "version").read_text().strip().removeprefix("v") in screen.frames[0]
            assert "Installed" not in screen.frames[0] and "Package" not in screen.frames[0], "CLI retained setup version rows"
            assert screen.lines[6].strip() == "Menu", "CLI left an empty metadata row"
        management = ui.uninstall.__globals__["MANAGEMENT"]
        calls, authentications = [], []
        def command(instance, arguments, *args, **kwargs):
            calls.append(arguments)
        with patch.dict(management, uninstall_locations=lambda: {"command": base / "bin/bloodyShell"},
                        uninstall_plan=lambda *args: {}, sddm_paths=lambda: [base / "theme"]), \
                patch.object(ui, "command", command), \
                patch.object(ui, "authenticate", lambda instance: authentications.append(True) or True):
            assert ui(Screen(("\n",))).uninstall() == 0
            assert not calls, "Default No changed the installation"
            assert ui(Screen(("k", "\n", "\n", "\n"))).uninstall() == 0
            assert calls[-1][-2:] == ["--apply", "--json"] and not authentications
            calls.clear()
            screen = Screen(("k", "\n", " ", "j", " ", "\t", "k", "\n", "\n", "\n"))
            assert ui(screen).uninstall() == 0
            assert len(calls) == 1 and calls[0][-2:] == ["--delete-sddm", "--delete-settings"]
            assert len(authentications) == 1
            assert any("Delete SDDM theme?" in frame and "Delete shell settings?" in frame for frame in screen.frames)
    management = API["MANAGEMENT"]
    ordered = ["v0.0.3-beta.1", "0.0.3-beta.2", "0.0.3-beta.10", "0.0.3-rc.1", "0.0.3", "0.0.4"]
    assert sorted(ordered, key=management["version_key"]) == ordered
    assert management["version_key"]("0.0.3+build.1") == management["version_key"]("v0.0.3")
    assert all(item["tool"] != "btop" for item in management["catalog"]())
    with patch.dict(os.environ, SHELL="/bin/bash"), patch("pwd.getpwuid", return_value=SimpleNamespace(pw_shell="/usr/bin/fish")):
        blocks = management["path_blocks"](base / "bin")
        assert base / "config/fish/conf.d/bloodyShell-path.fish" in blocks, "The newly selected Fish login shell lost the CLI PATH"
    for invalid in ("../release", "v0.0.03", "0.0.3-beta.01", "0.0.3-beta..1", "0.0.3/escape"):
        try:
            management["version_key"](invalid)
            raise AssertionError("Invalid release tag accepted: " + invalid)
        except ValueError:
            pass
    target, backup = base / "collision-runtime", base / "collision-backup"
    target.mkdir()
    (target / "shell.qml").write_text("original")
    (backup / "shell").mkdir(parents=True)
    (backup / "shell/keep").write_text("existing backup")
    install = management["install_runtime"]
    with patch.dict(install.__globals__, stage_runtime=lambda *args, **kwargs: None), patch("subprocess.run") as command:
        try:
            install(base / "source", target, base / "bin", backup)
            raise AssertionError("An existing update backup was overwritten")
        except RuntimeError:
            pass
        command.assert_not_called()
    assert (target / "shell.qml").read_text() == "original" and (backup / "shell/keep").read_text() == "existing backup"
    print("Five-action menu, uninstall confirmation/defaults/options/back, conditional authentication, btop removal and release ordering passed.")


def wallpaper_option_checks(base):
    requests = []
    loader = runpy.run_path
    def import_resource(name, *args, **kwargs):
        requests.append(name)
        return dict(destination=str(base / name), imported=0)
    resources = dict(import_resource=import_resource)
    def load(path, *args, **kwargs):
        return resources if str(path).endswith("resources.py") else loader(path, *args, **kwargs)
    with patch("runpy.run_path", side_effect=load):
        API["install_configs"](API["make_plan"]([], family="arch"))
        assert requests == ["compositor"], "Skipping wallpapers still requested their collection"
        requests.clear()
        API["install_configs"](API["make_plan"](["wallpapers"], family="arch"))
        assert requests == ["compositor", "wallpapers"], "Selected wallpapers were not imported"
    print("Wallpaper downloads are opt-in and separate from required compositor/config imports.")


def plan_checks(base):
    for family in ("arch", "fedora", "debian"):
        minimal = API["make_plan"]([], False, family)
        for entry in API["MANAGEMENT"]["catalog"]():
            if entry["kind"] == "required":
                assert set(entry[family].split()) - {"-"} <= set(minimal["packages"]), "A required dependency depends on optional selections"
        plan = API["make_plan"](API["OPTIONS"], False, family)
        assert len(plan["packages"]) == len(set(plan["packages"]))
        assert not set(plan["packages"]) & set(plan["appearance_packages"])
        assert "fish" in plan["packages"] and plan["configs"] == ["gtk-3.0", "gtk-4.0"]
        assert any("noto" in name for name in plan["appearance_packages"])
        assert not any("papirus" in name for name in plan["appearance_packages"])
        path = base / (family + ".json")
        path.write_text(json.dumps(plan)); path.chmod(0o600)
        assert API["read_plan"](path) == plan
        plan["packages"].append("unreviewed-package")
        path.write_text(json.dumps(plan))
        try:
            API["read_plan"](path)
            raise AssertionError("An altered plan was accepted")
        except ValueError:
            pass
    path.chmod(0o644)
    try:
        API["read_plan"](path)
        raise AssertionError("A nonprivate plan was accepted")
    except ValueError:
        pass
    print("Distro plans, selected groups, package deduplication, MacTahoe choices, private plans and tamper rejection passed.")


def config_checks(base):
    config, state = base / "config", base / "state"
    (config / "niri/bloodyShell").mkdir(parents=True)
    (config / "niri/config.kdl").write_text('input {}\n')
    user = config / "niri/bloodyShell/05-user.kdl"
    user.write_text("// Keep user customization\n")
    (config / "gtk-3.0").mkdir()
    (config / "gtk-3.0/settings.ini").write_text("[Settings]\npersonal=true\n")
    (config / "gtk-4.0").mkdir()
    (config / "gtk-4.0/settings.ini").write_text("[Settings]\npersonal=true\n")
    plan = API["make_plan"](["themes"], False, "arch")
    API["install_configs"](plan)
    assert user.read_text() == "// Keep user customization\n"
    for name in ("gtk-3.0", "gtk-4.0"):
        assert "MacTahoe" in (config / name / "settings.ini").read_text()
    assert not list(state.rglob("personal*"))
    assert not any(path.is_file() for path in (state / "bloodyShell/backups").rglob("*"))
    plan["backup"] = True
    previous = (config / "gtk-3.0/settings.ini").read_text()
    API["install_configs"](plan)
    assert any(path.read_text() == previous for path in state.glob("bloodyShell/backups/*/gtk-3.0/settings.ini"))
    original = {path.relative_to(config): path.read_bytes() for path in config.rglob("*") if path.is_file()}
    loader = runpy.run_path
    resources = loader(str(ROOT / "scripts/lib/resources.py"))
    original_import = resources["import_config"]
    def fail(source, name, transaction=None):
        if name == "gtk-4.0":
            raise OSError("fixture import failed")
        return original_import(source, name, transaction)
    resources["import_config"] = fail
    def load(path, *args, **kwargs):
        return resources if str(path).endswith("resources.py") else loader(path, *args, **kwargs)
    with patch("runpy.run_path", side_effect=load):
        try:
            API["install_configs"](plan)
            raise AssertionError("Import failure was ignored")
        except OSError:
            pass
    assert {path.relative_to(config): path.read_bytes() for path in config.rglob("*") if path.is_file()} == original
    resources = loader(str(ROOT / "scripts/lib/resources.py"))
    replace = os.replace
    def interrupt(source, destination):
        if Path(destination) == config / "gtk-3.0" and Path(source).parent.name.startswith(".bloodyShell-config-"):
            raise SystemExit(143)
        return replace(source, destination)
    with patch("os.replace", side_effect=interrupt):
        try:
            resources["import_config"](ROOT / "dots/config/gtk-3.0", "gtk-3.0")
            raise AssertionError("Interrupted import continued")
        except SystemExit:
            pass
    assert {path.relative_to(config): path.read_bytes() for path in config.rglob("*") if path.is_file()} == original
    copy_tree = shutil.copytree
    def partial_backup(source, destination, *args, **kwargs):
        if Path(source) == config / "gtk-3.0" and "backups" in Path(destination).parts:
            Path(destination).mkdir(parents=True)
            (Path(destination) / "partial").write_text("incomplete backup")
            raise SystemExit(143)
        return copy_tree(source, destination, *args, **kwargs)
    with patch("shutil.copytree", side_effect=partial_backup):
        try:
            resources["import_config"](ROOT / "dots/config/gtk-3.0", "gtk-3.0")
            raise AssertionError("Interrupted backup continued")
        except SystemExit:
            pass
    assert {path.relative_to(config): path.read_bytes() for path in config.rglob("*") if path.is_file()} == original
    assert not list(state.rglob("partial"))
    assert not list(config.glob(".bloodyShell-config-*"))
    assert not list(config.glob(".bloodyShell-rollback-*"))
    print("Required niri import, preserved user fragments, GTK/MacTahoe config import, backup/skip, batch rollback and interrupted commit passed.")


def theme_checks(base):
    run = subprocess.run
    broken = False
    def command(args, **kwargs):
        if args[:2] == ["git", "clone"]:
            source = Path(args[-1]); source.mkdir()
            (source / "install.sh").write_text("fixture installer")
        elif args[0] == "bash":
            destination = Path(args[args.index("--dest") + 1])
            assert " " not in str(destination), "Upstream installer needs a simple staging path"
            for name in ("MacTahoe", "MacTahoe-light", "MacTahoe-dark"):
                directory = destination / name; directory.mkdir(parents=True)
                if not (broken and name == "MacTahoe-dark"):
                    (directory / "index.theme").write_text("new " + name)
        elif args[0] != "fc-cache":
            raise AssertionError(args)
        return subprocess.CompletedProcess(args, 0)
    icons = base / "my data/icons"
    for name in ("MacTahoe", "MacTahoe-light", "MacTahoe-dark"):
        (icons / name).mkdir(parents=True)
        (icons / name / "index.theme").write_text("original " + name)
    plan = API["make_plan"](["themes"], True, "arch")
    with patch("subprocess.run", side_effect=command):
        broken = True
        try:
            API["install_theme"](plan)
            raise AssertionError("A damaged theme was accepted")
        except ValueError:
            pass
        assert all((icons / name / "index.theme").read_text() == "original " + name
                   for name in ("MacTahoe", "MacTahoe-light", "MacTahoe-dark"))
        broken = False
        API["install_theme"](plan)
        assert list((base / "state/bloodyShell/backups").glob("*-icons-*/MacTahoe/index.theme"))
        plan["backup"] = False
        API["install_theme"](plan)
        assert not list(icons.glob(".bloodyShell-theme-*"))
    print("MacTahoe staging, user-local install, paths with spaces, backups, incomplete-theme rollback and cleanup passed.")


def worker_checks(base):
    source = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
    source = "\n".join('readonly PACKAGE="' + str(ROOT) + '"' if line.startswith("readonly PACKAGE=") else line for line in source.splitlines())
    script, calls = base / "worker", base / "calls"
    script.write_text(source + '''
install_packages() { printf 'packages %s\\n' "$*" >> "$TEST_CALLS"; }
apply_greeter() { printf 'login\\n' >> "$TEST_CALLS"; }
apply_shell() { printf 'shell\\n' >> "$TEST_CALLS"; }
restart_shell() { printf 'restart\\n' >> "$TEST_CALLS"; }
tool_available() { return 0; }
python3() {
    case "$*" in
        *"internal setup worker-plan "*) command python3 "$@" ;;
        *) printf '%s\\n' "$*" >> "$TEST_CALLS" ;;
    esac
}
for stage in 0 1 2 3 4 5; do cmd_install_stage "$stage" "$TEST_PLAN"; done
''')
    sudo = base / "bin/sudo"
    sudo.write_text('#!/bin/sh\nprintf "sudo %s\\n" "$*" >> "$TEST_CALLS"\n')
    sudo.chmod(0o700)
    for family in ("arch", "fedora", "debian"):
        plan = API["make_plan"](API["OPTIONS"], True, family)
        path = base / "worker-plan.json"; path.write_text(json.dumps(plan)); path.chmod(0o600)
        calls.unlink(missing_ok=True)
        env = dict(os.environ, TEST_CALLS=str(calls), TEST_PLAN=str(path))
        result = subprocess.run(["bash", str(script)], env=env, text=True, capture_output=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        lines = calls.read_text().splitlines()
        if family == "arch":
            assert "sudo -n pacman -Syu --noconfirm" in lines
        elif family == "fedora":
            assert "sudo -n dnf upgrade -y" in lines
        else:
            assert any("DEBIAN_FRONTEND=noninteractive apt-get" in line and "--force-confold upgrade -y" in line for line in lines)
        assert lines.index("login") < next(index for index, line in enumerate(lines) if "setup configs" in line)
        assert next(index for index, line in enumerate(lines) if "setup login-shell" in line) < lines.index("shell")
        assert next(index for index, line in enumerate(lines) if "setup configs" in line) < lines.index("shell")
        assert any("setup verify" in line for line in lines)
        assert sum(line.startswith("packages ") for line in lines) == 2
    print("Worker ordering, one reviewed package plan, full system update, noninteractive sudo, required configs and final dependency verification passed.")


class Terminal:
    def __init__(self, command, env):
        self.master, self.slave = pty.openpty()
        self.attributes = termios.tcgetattr(self.slave)
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 90, 0, 0))
        def session():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        self.process = subprocess.Popen(command, env=dict(env, TERM="xterm-256color"), stdin=self.slave,
                                        stdout=self.slave, stderr=self.slave, preexec_fn=session)
        self.output = b""

    def wait(self, text, timeout=8):
        start = len(self.output)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if text.encode() in self.output[start:]:
                return
            if select.select([self.master], [], [], 0.05)[0]:
                try:
                    self.output += os.read(self.master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
            elif self.process.poll() is not None:
                break
        raise AssertionError((text, self.process.poll(), self.output.decode(errors="replace")[-7000:]))

    def send(self, text):
        os.write(self.master, text.encode())

    def finish(self):
        self.process.wait(timeout=5)
        assert termios.tcgetattr(self.slave) == self.attributes, "Setup did not restore terminal settings"
        self.close_descriptors()
        return self.process.returncode

    def close_descriptors(self):
        for name in ("master", "slave"):
            descriptor = getattr(self, name)
            if descriptor is not None:
                os.close(descriptor)
                setattr(self, name, None)

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait()
        self.close_descriptors()


def terminal_checks(base):
    package = base / "repository"
    package.mkdir()
    shutil.copytree(ROOT / "scripts/lib", package / "scripts/lib")
    shutil.copy2(ROOT / "scripts/bloodyShell", package / "scripts/bloodyShell")
    for name in ("version", "shell.qml"):
        shutil.copy2(ROOT / name, package / name)
    (package / "dots/niri").mkdir(parents=True)
    shutil.copy2(ROOT / "dots/niri/config.kdl", package / "dots/niri/config.kdl")
    with (package / "scripts/lib/management.py").open("a") as output:
        output.write('\nfamily = lambda: "arch"\n')
    stage = base / "fake-stage.py"
    stage.write_text('''import os,sys,time,subprocess
from pathlib import Path
base=Path(os.environ['TEST_TUI_BASE'])
with (base/'stages').open('a') as output: output.write(sys.argv[1]+'\\n')
if os.environ.get('TEST_TUI_FAIL')==sys.argv[1]:
    print('fixture stage failure',flush=True);sys.exit(7)
if os.environ.get('TEST_TUI_WAIT')==sys.argv[1]:
    child=subprocess.Popen(['sleep','60'])
    (base/'worker-pid').write_text(str(os.getpid()))
    (base/'child-pid').write_text(str(child.pid))
    print('fixture waiting',flush=True);time.sleep(60)
print('fixture progress',flush=True);time.sleep(0.15)
''')
    source = (ROOT / "setup").read_text()
    source = source.replace('set -euo pipefail', '''set -euo pipefail
if [[ "${1:-}" == install-stage ]]; then exec /usr/bin/python3 "$TEST_TUI_BASE/fake-stage.py" "$2"; fi''', 1)
    (package / "setup").write_text(source)
    binary = base / "bin"
    (binary / "pacman").write_text("#!/bin/sh\nexit 1\n")
    (binary / "pacman").chmod(0o700)
    (binary / "sudo").write_text('''#!/usr/bin/python3
import getpass,os,sys,termios
from pathlib import Path
base=Path(os.environ['TEST_TUI_BASE'])
if '-n' in sys.argv: sys.exit(0 if (base/'authenticated').exists() else 1)
assert '-S' not in sys.argv and os.isatty(0), 'sudo did not receive the terminal'
assert termios.tcgetattr(0)[3] & termios.ICANON, 'curses still owns terminal input'
secret=getpass.getpass('Password: ')
if secret=='fixture-password':
    (base/'authenticated').touch();sys.exit(0)
print('sudo: fixture authentication failure',file=sys.stderr,flush=True)
sys.exit(1)
''')
    (binary / "sudo").chmod(0o700)
    temporary = base / "temporary"
    temporary.mkdir()
    env = dict(os.environ, TEST_TUI_BASE=str(base), TMPDIR=str(temporary))

    def reach_ready(terminal):
        terminal.wait("Continue with installation?")
        terminal.send("\n");terminal.wait("Input tools")
        fcntl.ioctl(terminal.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 20, 50, 0, 0))
        os.kill(terminal.process.pid, signal.SIGWINCH)
        terminal.wait("Resize the terminal")
        fcntl.ioctl(terminal.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 90, 0, 0))
        os.kill(terminal.process.pid, signal.SIGWINCH)
        terminal.wait("Input tools")
        terminal.send("\n");terminal.wait("Fonts and Themes")
        terminal.send("\n");terminal.wait("Back up your current config files?")
        terminal.send("\n");terminal.wait("Installs")

    terminal = Terminal(["bash", str(package / "setup")], env)
    try:
        reach_ready(terminal)
        terminal.send("jj\n")
        assert terminal.finish() == 0
        assert not (base / "stages").exists() and not (base / "authenticated").exists()
    except BaseException:
        terminal.close(); raise
    for mode in ("back", "terminate"):
        terminal = Terminal(["bash", str(package / "setup")], env)
        try:
            reach_ready(terminal)
            terminal.send("\n");terminal.wait("Password: ")
            if mode == "back":
                terminal.send("\x03");terminal.wait("Ready")
                terminal.send("jj\n")
                expected = 0
            else:
                terminal.process.terminate()
                expected = 143
            assert terminal.finish() == expected
            assert not (base / "stages").exists() and not (base / "authenticated").exists()
        except BaseException:
            terminal.close(); raise
    for mode in ("success", "failure", "cancel", "terminate"):
        (base / "stages").unlink(missing_ok=True)
        (base / "authenticated").unlink(missing_ok=True)
        case_env = dict(env)
        if mode == "failure": case_env['TEST_TUI_FAIL'] = "2"
        if mode in ("cancel", "terminate"): case_env['TEST_TUI_WAIT'] = "1"
        terminal = Terminal(["bash", str(package / "setup")], case_env)
        try:
            reach_ready(terminal)
            terminal.send("\n");terminal.wait("Password: ")
            if mode == "success":
                terminal.send("incorrect-password\n")
                terminal.wait("Authentication failed")
                assert b"fixture authentication failure" in terminal.output
                assert b"incorrect-password" not in terminal.output
                terminal.send("\n");terminal.wait("Password: ")
            terminal.send("fixture-password\n")
            if mode == "success":
                terminal.wait("Enter to close")
                assert b"Installation complete" in terminal.output
                fcntl.ioctl(terminal.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 60, 0, 0))
                os.kill(terminal.process.pid, signal.SIGWINCH)
                terminal.wait("Enter to close")
                expected, stages = 0, ["0", "1", "2", "3", "4", "5"]
            elif mode == "failure":
                terminal.wait("Installation failed")
                expected, stages = 1, ["0", "1", "2"]
            else:
                terminal.wait("fixture waiting")
                if mode == "cancel":
                    terminal.send("\x1b");terminal.wait("Cancelled");terminal.send("\n")
                    expected = 130
                else:
                    terminal.process.terminate(); expected = 143
                stages = ["0", "1"]
            if mode in ("success", "failure"):
                with (base / "state/bloodyShell/.operation.lock").open("a") as operation:
                    fcntl.flock(operation, fcntl.LOCK_EX | fcntl.LOCK_NB)
                terminal.send("\n")
            assert terminal.finish() == expected, mode
            assert (base / "stages").read_text().splitlines() == stages
            assert b"fixture-password" not in terminal.output, "Password was echoed"
            assert not list(temporary.iterdir()), "Setup temporary files leaked"
            for name in ("worker-pid", "child-pid"):
                if mode in ("cancel", "terminate"):
                    pid = (base / name).read_text()
                    stat = Path('/proc') / pid / 'stat'
                    assert not stat.exists() or stat.read_text().rsplit(')', 1)[1].split()[0] == 'Z', "Setup left a running worker"
        except BaseException:
            terminal.close(); raise
    for log in (base / "state/bloodyShell/setup").glob("*.log"):
        assert "fixture-password" not in log.read_text() and not log.stat().st_mode & 0o077
    print("Real terminal flow, resize, native sudo/PAM handoff, failed authentication retry, password privacy, all stages, cancellation and terminal cleanup passed.")


def maintenance_terminal_checks(base):
    installed = base / "config/quickshell/bloodyShell"
    shutil.copytree(base / "repository", installed, ignore=shutil.ignore_patterns("setup", "dots"))
    assert not (installed / "setup").exists()
    with (installed / "scripts/lib/management.py").open("a") as output:
        output.write('''
def doctor_main():
    print('[{"name":"doctor-fixture-check","ok":true,"required":true,"detail":"Checked"}]')
    return 0
def update_main():
    print('Up to date · fixture', flush=True)
    return 0
''')
    binary = base / "bin"
    command = binary / "bloodyShell"
    shutil.copy2(ROOT / "scripts/bloodyShell", command)
    (binary / "qs").write_text('''#!/usr/bin/python3
import json,os,sys
from pathlib import Path
with (Path(os.environ['TEST_TUI_BASE'])/'cli-actions').open('a') as output:
    output.write(json.dumps(sys.argv[1:])+'\\n')
if sys.argv[1]=='list': print('[]')
''')
    (binary / "qs").chmod(0o700)
    runtime = base / "runtime"
    runtime.mkdir(exist_ok=True)
    env = dict(os.environ, TEST_TUI_BASE=str(base), XDG_BIN_HOME=str(binary), XDG_RUNTIME_DIR=str(runtime), WAYLAND_DISPLAY="fixture")
    for index, action in enumerate(("start", "update", "doctor", "restart")):
        terminal = Terminal([str(command)], env)
        try:
            terminal.wait("Enter open")
            assert b"Version" in terminal.output and b"Installed" not in terminal.output and b"Package" not in terminal.output
            terminal.send("j" * index + "\n")
            if action in ("update", "doctor"):
                terminal.wait("nter close")
                terminal.send("\n")
            assert terminal.finish() == 0, action
        except BaseException:
            terminal.close(); raise
    actions = [json.loads(line) for line in (base / "cli-actions").read_text().splitlines()]
    assert sum("--daemonize" in action for action in actions) == 2
    settings = base / "config/bloodyShell/settings.json"
    settings.parent.mkdir(exist_ok=True)
    settings.write_text('personal settings')
    for confirmed in (False, True):
        terminal = Terminal([str(command), "uninstall"], env)
        try:
            terminal.wait("Continue with uninstall?")
            if confirmed:
                terminal.send("k\n");terminal.wait("Delete shell settings?")
                terminal.send("\n");terminal.wait("nter close")
                terminal.send("\n")
            else:
                terminal.send("\n")
            assert terminal.finish() == 0, (confirmed, terminal.output.decode(errors="replace")[-6000:])
        except BaseException:
            terminal.close(); raise
        assert installed.exists() != confirmed and command.exists() != confirmed
        assert settings.read_text() == 'personal settings'
        assert (base / "config/niri/bloodyShell/05-user.kdl").exists()
    print("Installed CLI without setup passed: real-terminal menu Start/Update/Doctor/Restart, uninstall No/Yes, option defaults and retained settings/niri.")


def main():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-setup-checks-") as temporary:
        base = Path(temporary)
        for name in ("home", "config", "state", "cache", "bin", "runtime"):
            (base / name).mkdir()
        niri = base / "bin/niri"; niri.write_text("#!/bin/sh\nexit 0\n"); niri.chmod(0o700)
        env = dict(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_DATA_HOME=str(base / "my data"), XDG_RUNTIME_DIR=str(base / "runtime"), XDG_BIN_HOME=str(base / "bin"),
                   PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        with patch.dict(os.environ, env):
            plan_checks(base)
            wallpaper_option_checks(base)
            ui_checks(base)
            login_shell_checks(base)
            maintenance_checks(base)
            config_checks(base)
            theme_checks(base)
            worker_checks(base)
            terminal_checks(base)
            maintenance_terminal_checks(base)


if __name__ == "__main__":
    main()
