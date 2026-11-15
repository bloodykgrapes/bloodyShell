"""Shared terminal UI, repository installation plans and shell maintenance."""

import argparse
import configparser
from contextlib import ExitStack
import json
import os
from pathlib import Path
import pwd
import re
import runpy
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import textwrap
import time


ROOT = Path(__file__).resolve().parents[2]
MANAGEMENT = runpy.run_path(str(Path(__file__).with_name("management.py")))
FILES = MANAGEMENT["FILES"]
STAGES = ("Checking", "Packages", "Appearance", "System setup", "Shell and configs", "Finishing up")
OPTIONS = ("input", "audio", "brightness", "fish", "themes", "login", "wallpapers")
LABELS = dict(zip(OPTIONS, ("Input tools", "Audio tools", "Brightness tools", "Fish", "Fonts and Themes", "Login screen", "Wallpapers")))
DESCRIPTIONS = {
    "input": "Builds the on-screen keyboard and Alt+Tab helper.",
    "audio": "Adds the audio visualizer, sound effects and media controls.",
    "brightness": "Adds display brightness and night-light controls.",
    "fish": "Installs Fish and makes it your login shell.",
    "themes": "Installs Noto and JetBrains Mono, Adwaita GTK and MacTahoe icons.",
    "login": "Installs the bloodyShell login screen and enables SDDM at next boot.",
    "wallpapers": "Downloads the optional wallpaper collection.",
}
NATIVE_PACKAGES = {
    "arch": "gcc pkgconf qt6-base qt6-declarative wayland libxkbcommon",
    "fedora": "gcc-c++ pkgconf-pkg-config qt6-qtbase-devel qt6-qtdeclarative-devel wayland-devel libxkbcommon-devel",
    "debian": "g++ pkg-config qt6-base-dev qt6-base-dev-tools qt6-declarative-dev libwayland-dev libwayland-bin libxkbcommon-dev",
}
THEME_PACKAGES = {
    "arch": "noto-fonts noto-fonts-emoji ttf-jetbrains-mono adwaita-icon-theme gnome-themes-extra gtk3 fontconfig git",
    "fedora": "google-noto-sans-fonts google-noto-color-emoji-fonts jetbrains-mono-fonts adwaita-icon-theme gnome-themes-extra gtk3 fontconfig git",
    "debian": "fonts-noto-core fonts-noto-color-emoji fonts-jetbrains-mono adwaita-icon-theme gnome-themes-extra libgtk-3-bin fontconfig git",
}
THEME_REPOSITORY = "https://github.com/vinceliuice/MacTahoe-icon-theme.git"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def home_path(variable, fallback):
    return Path(os.environ.get(variable) or Path.home() / fallback)


def state_home():
    return MANAGEMENT["state_directory"]()


def version(path, default="fresh install"):
    try:
        return "v" + path.read_text().strip().removeprefix("v")
    except OSError:
        return default


def groups(family):
    entries = MANAGEMENT["catalog"]()
    def tools(*names):
        return list(dict.fromkeys(token for entry in entries if entry["tool"] in names
                                  for token in entry[family].split() if token != "-"))
    return {
        "input": NATIVE_PACKAGES[family].split(),
        "audio": tools("cava", "easyeffects", "playerctl"),
        "brightness": tools("brightnessctl", "wlsunset"),
        "fish": ["fish", {"arch": "util-linux", "fedora": "util-linux-user", "debian": "passwd"}[family]],
        "themes": THEME_PACKAGES[family].split(),
        "login": tools("sddm"),
        "wallpapers": [],
    }


def make_plan(selected, backup=True, family=None):
    family = MANAGEMENT["family"]() if family is None else family
    if family not in NATIVE_PACKAGES:
        raise ValueError("This installer supports Arch, Fedora and Debian based distributions.")
    selected = [key for key in OPTIONS if key in selected]
    catalog = MANAGEMENT["catalog"]()
    required = [token for entry in catalog if entry["kind"] == "required"
                for token in entry[family].split() if token != "-"]
    if family == "arch":
        required += ["base-devel", "git"]
    missing = [entry["tool"] for entry in catalog if entry["kind"] == "required"
               and entry[family] == "-" and not MANAGEMENT["available"](entry["tool"])]
    choice = groups(family)
    packages = required + [name for key in selected if key not in ("themes", "login") for name in choice[key]]
    appearance = [name for key in ("themes", "login") if key in selected for name in choice[key]]
    if "login" in selected:
        packages += choice["input"]
    return dict(family=family, selected=selected, backup=backup,
                packages=list(dict.fromkeys(packages)),
                appearance_packages=[name for name in dict.fromkeys(appearance) if name not in packages],
                configs=["gtk-3.0", "gtk-4.0"] if "themes" in selected else [], manual=missing)


def read_plan(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
        raise ValueError("The installation plan must be a private file owned by you.")
    plan = json.loads(path.read_text())
    if not isinstance(plan, dict) or not isinstance(plan.get("selected"), list) or not all(key in OPTIONS for key in plan["selected"]):
        raise ValueError("Invalid installation choices")
    if type(plan.get("backup")) is not bool:
        raise ValueError("Invalid backup choice")
    expected = make_plan(plan["selected"], plan["backup"], plan.get("family", ""))
    if set(plan) != set(expected) or any(plan[key] != expected[key] for key in expected if key != "manual"):
        raise ValueError("Installation plan does not match the package catalog")
    return expected


def pending_packages(plan):
    names = [name for name in plan["packages"] + plan["appearance_packages"] if not name.startswith("copr:")]
    if not names:
        return []
    command = {"arch": ["pacman", "-Qq"], "fedora": ["rpm", "-q", "--qf", "%{NAME}\\n"],
               "debian": ["dpkg-query", "-W", "-f=${Package} ${db:Status-Status}\\n"]}[plan["family"]]
    result = subprocess.run(command + names, text=True, capture_output=True, timeout=15)
    installed = {line.split()[0] for line in result.stdout.splitlines()
                 if plan["family"] != "debian" or line.endswith(" installed")}
    return [name for name in names if name not in installed]


remove_path = FILES["remove_path"]


def discard_backup(path):
    path = Path(path)
    remove_path(path)
    try:
        path.parent.rmdir()
    except OSError:
        pass


def install_configs(plan):
    resources = runpy.run_path(str(Path(__file__).with_name("resources.py")))
    with ExitStack() as transaction:
        imported = [resources["import_resource"]("compositor", transaction)]
        for name in plan["configs"]:
            with tempfile.TemporaryDirectory(prefix="bloodyShell-gtk-") as temporary:
                source = Path(temporary) / name
                shutil.copytree(ROOT / "dots/config" / name, source)
                config = configparser.ConfigParser(interpolation=None)
                config.optionxform = str
                config.read(source / "settings.ini")
                config["Settings"]["gtk-icon-theme-name"] = "MacTahoe"
                with (source / "settings.ini").open("w") as output:
                    config.write(output, space_around_delimiters=False)
                imported.append(resources["import_config"](source, name, transaction))
    if not plan["backup"]:
        for result in imported:
            if result.get("backup"):
                discard_backup(result["backup"])
    for result in imported:
        print("Imported → " + result["destination"], flush=True)
    if "wallpapers" in plan["selected"]:
        result = resources["import_resource"]("wallpapers")
        print("Wallpapers → " + result["destination"], flush=True)


def install_theme(plan):
    if "themes" not in plan["selected"]:
        return
    icons = home_path("XDG_DATA_HOME", ".local/share") / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bloodyShell-theme-", dir="/tmp") as build, \
            tempfile.TemporaryDirectory(prefix=".bloodyShell-theme-", dir=icons) as temporary:
        temporary, build = Path(temporary), Path(build)
        source, built, staged = build / "source", build / "icons", temporary / "icons"
        subprocess.run(["git", "clone", "--depth", "1", "--", THEME_REPOSITORY, str(source)], check=True)
        subprocess.run(["bash", str(source / "install.sh"), "--dest", str(built), "--theme", "default"], check=True)
        shutil.copytree(built, staged, symlinks=True)
        changed, backup = [], None
        try:
            for name in ("MacTahoe", "MacTahoe-light", "MacTahoe-dark"):
                if not (staged / name / "index.theme").is_file():
                    raise ValueError("MacTahoe did not build " + name)
                destination, previous = icons / name, temporary / (name + ".previous")
                if destination.exists() or destination.is_symlink():
                    os.replace(destination, previous)
                changed.append((destination, previous))
                os.replace(staged / name, destination)
            if plan["backup"]:
                backup = state_home() / "backups" / (time.strftime("%Y-%m-%d_%H-%M-%S") + "-icons-" + str(os.getpid()))
                for destination, previous in changed:
                    if previous.exists() or previous.is_symlink():
                        backup.mkdir(parents=True, exist_ok=True)
                        saved = backup / destination.name
                        FILES["copy_path"](previous, saved)
        except BaseException:
            for destination, previous in reversed(changed):
                remove_path(destination)
                if previous.exists() or previous.is_symlink():
                    os.replace(previous, destination)
            if backup is not None:
                remove_path(backup)
            raise
    print("MacTahoe → " + str(icons), flush=True)
    if shutil.which("fc-cache"):
        subprocess.run(["fc-cache", "-f"], check=True)


def apply_theme_settings(plan):
    if "themes" not in plan["selected"]:
        return
    command = ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "MacTahoe"]
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS") and shutil.which("dbus-run-session"):
        command = ["dbus-run-session", "--", *command]
    subprocess.run(command, check=True)


def apply_login_shell(plan):
    if "fish" not in plan["selected"]:
        return
    account = pwd.getpwuid(os.getuid())
    shells = [line.strip() for line in Path("/etc/shells").read_text().splitlines()
              if line.strip() and not line.lstrip().startswith("#")]
    fish = next((path for path in shells if Path(path).name == "fish" and os.access(path, os.X_OK)), None)
    if fish is None:
        raise ValueError("Fish must be installed and listed in /etc/shells before setting the login shell.")
    if account.pw_shell != fish:
        subprocess.run(["sudo", "-n", "chsh", "-s", fish, account.pw_name], check=True)
    print("Login shell → " + fish + " (next login)", flush=True)


def preflight(plan):
    if os.geteuid() == 0:
        raise ValueError("Run setup as your normal user.")
    manager = {"arch": "pacman", "fedora": "dnf", "debian": "apt-get"}[plan["family"]]
    if not shutil.which(manager) or not shutil.which("sudo"):
        raise ValueError("This installation needs " + manager + " and sudo.")
    if plan["manual"]:
        raise ValueError("Install these required tools first: " + ", ".join(plan["manual"]))
    for relative in ("shell.qml", "version", "dots/niri/config.kdl"):
        if not (ROOT / relative).is_file():
            raise ValueError("Missing installation file: " + relative)


def elapsed(seconds):
    seconds = max(0, int(seconds))
    return f"{seconds // 60:02d}:{seconds % 60:02d}"


class TerminalUI:
    def __init__(self, screen, mode="Setup", versions=None):
        import curses
        self.curses, self.screen = curses, screen
        self.mode = mode
        if versions is None:
            target = home_path("XDG_CONFIG_HOME", ".config") / "quickshell/bloodyShell/version"
            versions = (("Installed", version(target)), ("Package", version(ROOT / "version", "?")))
        self.versions = versions
        self.color = self.success = self.failure = 0
        self.selection = curses.A_REVERSE | curses.A_BOLD
        if curses.has_colors() and not os.environ.get("NO_COLOR"):
            curses.start_color()
            curses.use_default_colors()
            curses.init_pair(1, curses.COLOR_CYAN, -1)
            curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_CYAN)
            curses.init_pair(3, curses.COLOR_GREEN, -1)
            curses.init_pair(4, curses.COLOR_RED, -1)
            self.color = curses.color_pair(1)
            self.selection = curses.color_pair(2) | curses.A_BOLD
            self.success, self.failure = curses.color_pair(3), curses.color_pair(4)
        screen.keypad(True)
        self.cursor_visible(False)


    def cursor_visible(self, visible):
        try:
            self.curses.curs_set(int(visible))
        except self.curses.error:
            pass


    def put(self, y, text="", x=2, style=0):
        height, width = self.screen.getmaxyx()
        if 0 <= y < height - 1 and x < width - 1:
            try:
                self.screen.addnstr(y, max(0, x), text, max(0, width - x - 2), style)
            except self.curses.error:
                pass


    def header(self, title, description=""):
        self.screen.erase()
        self.put(1, " bloodyShell ", style=self.color | self.curses.A_REVERSE | self.curses.A_BOLD)
        self.put(1, self.mode, x=16, style=self.curses.A_BOLD)
        self.put(2, "─" * self.content_width(), style=self.curses.A_DIM)
        for y, (label, value) in enumerate(self.versions, 3):
            self.put(y, label, style=self.curses.A_DIM)
            self.put(y, value, x=16)
        heading = 5 + len(self.versions)
        self.put(heading, title, style=self.curses.A_BOLD)
        self.put(heading + 1, "─" * self.content_width(), style=self.curses.A_DIM)
        lines = textwrap.wrap(description, self.content_width())
        for row, line in enumerate(lines, heading + 2):
            self.put(row, line, style=self.curses.A_DIM)
        return heading + 2 + len(lines) + bool(lines)


    def footer(self, text):
        self.put(self.screen.getmaxyx()[0] - 2, text, style=self.curses.A_DIM)
        self.screen.refresh()


    def content_width(self):
        return max(1, min(84, self.screen.getmaxyx()[1] - 4))


    def choices(self, y, items):
        for index, item in enumerate(items):
            label, detail = (item, "") if isinstance(item, str) else item
            active = index == self.cursor
            style = self.selection if active else 0
            self.put(y + index, " " * self.content_width(), style=style)
            self.put(y + index, label, x=3, style=style | self.curses.A_BOLD)
            if detail:
                self.put(y + index, detail, x=5 + len(label),
                         style=style if active else self.curses.A_DIM)


    def key(self):
        key = self.read_key()
        if key in ("q", "\x1b", "\x03"):
            raise KeyboardInterrupt
        return key


    def resize(self):
        try:
            size = os.get_terminal_size(sys.stdout.fileno())
        except OSError:
            return False
        if (size.lines, size.columns) == self.screen.getmaxyx():
            return False
        self.curses.resizeterm(size.lines, size.columns)
        return True


    def read_key(self):
        self.screen.timeout(150)
        try:
            while True:
                if self.resize():
                    return self.curses.KEY_RESIZE
                try:
                    return self.screen.get_wch()
                except self.curses.error:
                    pass
        finally:
            self.screen.timeout(-1)


    def move(self, key, count):
        if key in (self.curses.KEY_UP, "k"):
            self.cursor = (self.cursor - 1) % count
        elif key in (self.curses.KEY_DOWN, "j"):
            self.cursor = (self.cursor + 1) % count


    def enter(self, key):
        return key in ("\n", "\r", self.curses.KEY_ENTER)


    def authenticate(self):
        if subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return True
        while True:
            y = self.header("Password for " + pwd.getpwuid(os.getuid()).pw_name)
            self.footer("Ctrl+C back")
            self.screen.move(y, 2)
            self.screen.refresh()
            self.cursor_visible(True)
            self.curses.def_prog_mode()
            try:
                # Let sudo own the terminal and PAM conversation, including echo,
                # keyboard input and diagnostic messages. Never collect a password.
                self.curses.reset_shell_mode()
                with subprocess.Popen(["sudo", "-p", "Password: ", "-v"]) as child:
                    try:
                        result = child.wait()
                    except BaseException:
                        child.terminate()
                        try:
                            child.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            child.kill()
                            child.wait()
                        raise
            except KeyboardInterrupt:
                return False
            finally:
                self.curses.reset_prog_mode()
                self.curses.flushinp()
                self.cursor_visible(False)
            if result == 0:
                self.screen.clearok(True)
                return True
            # Keep sudo's actual error visible until the user retries or returns.
            self.footer("Authentication failed · Enter retry   Esc back")
            while True:
                key = self.read_key()
                if key in ("\x1b", "\x03"):
                    self.screen.clearok(True)
                    return False
                if self.enter(key):
                    self.screen.clearok(True)
                    break


    def progress(self, states, times, started, current=None, message="", title="Installation", names=STAGES):
        self.resize()
        y = self.header(title)
        now = time.monotonic()
        spinner = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[int(now * 10) % 10]
        styles = {"pending": self.curses.A_DIM, "running": self.color | self.curses.A_BOLD,
                  "done": self.success, "failed": self.failure | self.curses.A_BOLD}
        for index, (name, state) in enumerate(zip(names, states)):
            mark = {"pending": "·", "running": spinner, "done": "✓", "failed": "✕"}[state]
            self.put(y + index, f"{mark} {name}", style=styles[state])
            value = now - current if state == "running" else times[index]
            if state != "pending":
                self.put(y + index, elapsed(value), x=34, style=self.curses.A_DIM)
        width = max(4, min(40, self.content_width() - 18))
        completed = states.count("done")
        filled = width * completed // len(states)
        row = y + len(states) + 1
        self.put(row, "░" * width, style=self.curses.A_DIM)
        self.put(row, "█" * filled, style=self.failure if "failed" in states else self.color)
        self.put(row, f"{completed * 100 // len(states):3d}%", x=width + 4, style=self.curses.A_BOLD)
        self.put(row, elapsed(now - started), x=width + 11, style=self.curses.A_DIM)
        self.put(row + 1, f"{completed}/{len(states)} stages complete", style=self.curses.A_DIM)
        self.put(row + 3, message, style=self.curses.A_DIM)
        if "running" in states:
            self.footer("Esc cancel")
        else:
            self.screen.refresh()


    def command(self, args, log, render, environment=None):
        child = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 preexec_fn=os.setpgrp, env=environment)
        selector = selectors.DefaultSelector()
        selector.register(child.stdout, selectors.EVENT_READ)
        output, keepalive = "", time.monotonic()
        self.screen.timeout(100)
        try:
            while child.poll() is None or selector.get_map():
                for event, _ in selector.select(timeout=0.1):
                    chunk = os.read(event.fileobj.fileno(), 8192)
                    if not chunk:
                        selector.unregister(event.fileobj)
                        continue
                    text = chunk.decode(errors="replace")
                    log.write(text)
                    log.flush()
                    output = (output + ANSI.sub("", text))[-16000:]
                lines = output.replace("\r", "\n").splitlines()
                render(lines[-1] if lines else "")
                try:
                    if self.screen.get_wch() in ("\x03", "\x1b"):
                        raise KeyboardInterrupt
                except self.curses.error:
                    pass
                if time.monotonic() - keepalive > 45:
                    subprocess.run(["sudo", "-n", "-v"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    keepalive = time.monotonic()
            if child.wait():
                raise RuntimeError("\n".join(lines[-8:]) or "Installation command failed")
        finally:
            selector.close()
            self.screen.timeout(-1)
            FILES["stop_process"](child, timeout=5)
            child.stdout.close()



class Wizard(TerminalUI):
    def __init__(self, screen):
        super().__init__(screen)
        self.selected = {"input", "audio", "themes"}
        if any(Path("/sys/class/backlight").iterdir()):
            self.selected.add("brightness")
        self.backup = True
        self.page, self.cursor, self.error = 0, 0, ""
        self.plan = make_plan(self.selected)
        self.pending = None


    def navigate(self, page):
        self.page, self.cursor = page, int(not self.backup) if page == 3 else 0
        self.error = ""


    def render_choices(self, keys):
        available = groups(self.plan["family"])
        width = max(len(LABELS[key]) for key in keys)
        rows = []
        for key in keys:
            label = f"{'✓' if key in self.selected else '○'}  {LABELS[key]:<{width}}"
            names = ", ".join(available[key])
            if key == "themes":
                names = "Noto, JetBrains Mono, Adwaita, MacTahoe"
            elif key == "wallpapers":
                names = "optional download"
            names = textwrap.shorten(names, max(2, self.content_width() - len(label) - 6), placeholder="…")
            rows.append((label, "(" + names + ")"))
        return rows


    def run(self):
        while True:
            height, width = self.screen.getmaxyx()
            if height < 24 or width < 60:
                self.screen.erase()
                self.put(1, "Resize the terminal to at least 60 × 24.")
                self.footer("Esc cancel")
                self.key()
                continue
            if self.page == 0:
                y = self.header("Installation", "Choose optional programs and configs.")
                self.put(y, "Continue with installation?")
                self.choices(y + 2, ("Yes", "No"))
                self.footer("↑↓ select   Enter continue   Esc cancel")
                key = self.key()
                self.move(key, 2)
                if self.enter(key):
                    if self.cursor:
                        return 0
                    self.navigate(1)
            elif self.page in (1, 2):
                keys = OPTIONS[:4] if self.page == 1 else OPTIONS[4:]
                y = self.header("Packages" if self.page == 1 else "Appearance")
                self.choices(y, self.render_choices(keys))
                for offset, line in enumerate(textwrap.wrap(DESCRIPTIONS[keys[self.cursor]], self.content_width() - 2)):
                    self.put(y + len(keys) + 2 + offset, line, x=3, style=self.curses.A_DIM)
                self.footer("↑↓ move  Space toggle  Enter next" +
                            ("  Tab back" if self.page == 2 else "") + "  Esc cancel")
                key = self.key()
                self.move(key, len(keys))
                if key == " ":
                    option = keys[self.cursor]
                    self.selected.symmetric_difference_update((option,))
                    self.pending = None
                elif self.enter(key):
                    self.navigate(self.page + 1)
                elif key == "\t" and self.page == 2:
                    self.navigate(self.page - 1)
            elif self.page == 3:
                y = self.header("Back up", "Back up your current config files?")
                self.choices(y, ("Back up", "Skip"))
                self.footer("↑↓ select   Enter next   Tab back   Esc cancel")
                key = self.key()
                self.move(key, 2)
                if self.enter(key):
                    self.backup = self.cursor == 0
                    self.plan = make_plan(self.selected, self.backup)
                    self.pending = pending_packages(self.plan)
                    self.navigate(4)
                elif key == "\t":
                    self.navigate(2)
            else:
                y = self.header("Ready")
                summary = [f"Installs {len(self.pending)} packages", "Updates the system"]
                labels = ["Fish as login shell" if key == "fish" else LABELS[key] for key in self.plan["selected"]]
                summary += labels
                summary += ["Back up current configs" if self.backup else "Skip config backups"]
                compact = height < y + len(summary) + 9
                if compact:
                    enabled = ", ".join(labels) or "none"
                    summary = summary[:2] + textwrap.wrap("Enabled: " + enabled, self.content_width() - 2) + summary[-1:]
                for offset, line in enumerate(summary):
                    self.put(y + offset, "- " + line)
                if self.error:
                    self.put(height - 8, self.error, style=self.color)
                self.choices(height - 6, ("Install", "Edit", "Cancel"))
                self.footer("↑↓ select   Enter confirm   Esc cancel")
                key = self.key()
                self.move(key, 3)
                if self.enter(key):
                    if self.cursor == 1:
                        self.navigate(1)
                    elif self.cursor == 2:
                        return 0
                    else:
                        try:
                            preflight(self.plan)
                            if self.authenticate():
                                return self.install()
                        except (OSError, ValueError, RuntimeError) as error:
                            self.error = str(error)


    def install(self):
        states, times, started = ["pending"] * len(STAGES), [0] * len(STAGES), time.monotonic()
        failure, destination = None, None
        with tempfile.TemporaryDirectory(prefix="bloodyShell-install-") as temporary:
            temporary = Path(temporary)
            plan_file, log_file = temporary / "plan.json", temporary / "install.log"
            plan_file.write_text(json.dumps(self.plan))
            plan_file.chmod(0o600)
            with log_file.open("w") as log, MANAGEMENT["operation_lock"]():
                index, current = 0, started
                try:
                    for index in range(len(STAGES)):
                        current = time.monotonic()
                        states[index] = "running"
                        render = lambda message: self.progress(states, times, started, current, message)
                        render("")
                        self.command(["bash", str(ROOT / "setup"), "install-stage", str(index), str(plan_file)], log, render)
                        times[index] = time.monotonic() - current
                        states[index] = "done"
                except (OSError, RuntimeError, KeyboardInterrupt) as error:
                    failure = error
                    states[index] = "failed"
                    times[index] = time.monotonic() - current
                    directory = state_home() / "setup"
                    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
                    destination = directory / (time.strftime("%Y-%m-%d_%H-%M-%S") + "-" + str(time.time_ns()) + ".log")
                    shutil.copyfile(log_file, destination)
                    destination.chmod(0o600)
        # Completion screens and the new shell must not keep an operation lock.
        if failure is not None:
            cancelled = isinstance(failure, KeyboardInterrupt)
            title = "Cancelled" if cancelled else "Installation failed"
            message = title
            result = 130 if cancelled else 1
        else:
            try:
                restarted = MANAGEMENT["restart_runtime"]()
            except (OSError, subprocess.SubprocessError):
                restarted = False
            message = "Open a new terminal for the CLI; log in again for niri keybinds."
            if restarted is False:
                message = "Files installed. Run bloodyShell doctor if the shell could not start."
            title = "Installation complete"
            result = 0
        while True:
            self.resize()
            height, width = self.screen.getmaxyx()
            if height < 24 or width < 60:
                self.screen.erase()
                self.put(1, title, style=self.curses.A_BOLD)
                self.put(3, "Resize the terminal for installation details.")
            else:
                self.progress(states, times, started, message=message)
                if destination:
                    self.put(height - 4, "Log: " + str(destination))
            self.footer(title + " · Enter to close")
            if self.enter(self.read_key()):
                return result



class MaintenanceUI(TerminalUI):
    def __init__(self, screen):
        super().__init__(screen, mode="", versions=(("Version", version(ROOT / "version", "?")),))
        self.cursor = 0

    def ready(self):
        height, width = self.screen.getmaxyx()
        if height >= 24 and width >= 60:
            return True
        self.screen.erase()
        self.put(1, "Resize the terminal to at least 60 × 24.")
        self.footer("Esc close")
        self.key()
        return False

    def menu(self):
        items = ("Start", "Update", "Doctor", "Restart", "Uninstall")
        descriptions = ("Start the shell.", "Check for updates and install the latest release.",
                        "Check shell files and dependencies.", "Restart the shell.",
                        "Remove the shell and choose which settings to keep.")
        while True:
            if not self.ready():
                continue
            y = self.header("Menu")
            self.choices(y, items)
            self.put(y + len(items) + 2, descriptions[self.cursor], style=self.curses.A_DIM)
            self.footer("↑↓ select  Enter open  Esc close")
            key = self.key()
            self.move(key, len(items))
            if self.enter(key):
                return items[self.cursor].lower()

    def result(self, title, lines):
        offset = 0
        while True:
            if not self.ready():
                continue
            y = self.header(title)
            wrapped = [part for line in lines for part in textwrap.wrap(line, self.content_width()) or [""]]
            count = max(1, self.screen.getmaxyx()[0] - y - 4)
            offset = min(offset, max(0, len(wrapped) - count))
            for index, line in enumerate(wrapped[offset:offset + count]):
                self.put(y + index, line)
            self.footer(("↑↓ scroll  " if len(wrapped) > count else "") + "Enter close  Esc close")
            key = self.read_key()
            if self.enter(key) or key in ("q", "\x1b", "\x03"):
                return
            if key in (self.curses.KEY_DOWN, "j"):
                offset = min(offset + 1, max(0, len(wrapped) - count))
            elif key in (self.curses.KEY_UP, "k"):
                offset = max(0, offset - 1)
            elif key == self.curses.KEY_NPAGE:
                offset += count
            elif key == self.curses.KEY_PPAGE:
                offset = max(0, offset - count)

    def task(self, action, arguments=()):
        if action == "update" and MANAGEMENT["command_location"]()[1] / "bloodyShell" == MANAGEMENT["SYSTEM_COMMAND"]:
            if not self.authenticate():
                return 130
        names = ("Checking for updates", "Downloading", "Installing") if action == "update" else ("Checking installation",)
        states, times = ["pending"] * len(names), [0] * len(names)
        states[0] = "running"
        started = current = time.monotonic()
        index = 0
        failure = None
        with tempfile.TemporaryDirectory(prefix="bloodyShell-command-") as temporary:
            temporary = Path(temporary)
            status = temporary / "status"
            environment = dict(os.environ, BLOODYSHELL_STATUS=str(status), NO_COLOR="1")
            def render(message):
                nonlocal index, current
                if action == "update" and status.is_file():
                    match = re.match(r"step ([1-3])/3", status.read_text())
                    if match:
                        next_index = int(match[1]) - 1
                        if next_index > index:
                            times[index] = time.monotonic() - current
                            for previous in range(index, next_index):
                                states[previous] = "done"
                            index, current = next_index, time.monotonic()
                            states[index] = "running"
                self.progress(states, times, started, current,
                              "Checking shell files and dependencies…" if action == "doctor" else message,
                              title=action.title(), names=names)
            with (temporary / "output").open("w+") as output:
                try:
                    self.command([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", action, *arguments], output, render, environment)
                except (OSError, RuntimeError, KeyboardInterrupt) as error:
                    failure = error
                output.seek(0)
                text = output.read()
        if action == "doctor" and text.strip():
            try:
                results = json.loads(text)
                lines = [("✓ " if item["ok"] else "✕ " if item["required"] else "○ ") + item["name"] +
                         (": " + item["detail"] if item.get("detail") else "") for item in results]
                self.result("Doctor", lines)
                return int(any(not item["ok"] and item["required"] for item in results))
            except (ValueError, KeyError, TypeError):
                pass
        if failure is not None:
            self.result("Cancelled" if isinstance(failure, KeyboardInterrupt) else action.title() + " failed",
                        (text or str(failure) or "Cancelled").splitlines())
            return 130 if isinstance(failure, KeyboardInterrupt) else 1
        self.result(action.title() + " complete", text.splitlines())
        return 0

    def uninstall(self, delete_settings=False, delete_sddm=False):
        locations = MANAGEMENT["uninstall_locations"]()
        MANAGEMENT["uninstall_plan"](locations, delete_settings, delete_sddm)
        selected = {name for name, value in (("settings", delete_settings), ("sddm", delete_sddm)) if value}
        page = 0
        self.cursor = 1
        while True:
            if not self.ready():
                continue
            if page == 0:
                y = self.header("Uninstall", "Remove bloodyShell, its command and generated cache files.")
                self.put(y, "Niri and app configs, wallpapers and backups are kept.", style=self.curses.A_DIM)
                self.put(y + 2, "Continue with uninstall?")
                self.choices(y + 4, ("Yes", "No"))
                self.footer("↑↓ select  Enter confirm  Esc cancel")
                key = self.key()
                self.move(key, 2)
                if self.enter(key):
                    if self.cursor:
                        return 0
                    page, self.cursor = 1, 0
                continue
            y = self.header("Options")
            keys = ("sddm", "settings")
            labels = ("Delete SDDM theme?", "Delete shell settings?")
            self.choices(y, [f"{'✓' if key in selected else '○'}  {label}" for key, label in zip(keys, labels)])
            description = ("Removes the theme, login-screen images and bloodyShell's SDDM drop-in. Requires sudo."
                           if self.cursor == 0 else "Removes your bloodyShell settings. Niri and application configs are kept.")
            for offset, line in enumerate(textwrap.wrap(description, self.content_width() - 2)):
                self.put(y + 4 + offset, line, x=3, style=self.curses.A_DIM)
            self.footer("↑↓  Space toggle  Enter uninstall  Tab back  Esc cancel")
            key = self.key()
            self.move(key, 2)
            if key == " ":
                selected.symmetric_difference_update((keys[self.cursor],))
            elif key == "\t":
                page, self.cursor = 0, 1
            elif self.enter(key):
                if ("sddm" in selected and MANAGEMENT["sddm_paths"]() or locations["command"] == MANAGEMENT["SYSTEM_COMMAND"]):
                    if not self.authenticate():
                        continue
                arguments = ["--apply", "--json"]
                arguments += ["--delete-" + key for key in keys if key in selected]
                started = time.monotonic()
                with tempfile.TemporaryFile(mode="w+") as output:
                    try:
                        self.command([sys.executable, str(ROOT / "scripts/bloodyShell"), "internal", "uninstall", *arguments], output,
                                     lambda message: self.progress(["running"], [0], started, started, "Removing the shell and command…",
                                                                   title="Uninstall", names=("Removing bloodyShell",)))
                    except (OSError, RuntimeError, KeyboardInterrupt) as error:
                        self.result("Uninstall stopped", (str(error) or "Cancelled").splitlines())
                        return 130 if isinstance(error, KeyboardInterrupt) else 1
                self.result("Uninstall complete", ["bloodyShell and its command were removed.",
                            "Shell settings were deleted." if "settings" in selected else "Shell settings were kept.",
                            "SDDM theme was deleted." if "sddm" in selected else "SDDM theme was kept.",
                            "Niri and app configs, wallpapers and backups were kept."])
                return 0


def terminal(callback):
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise RuntimeError("Open bloodyShell in a terminal to use the interactive menu.")
    import curses
    with FILES["operation_signals"](signal.SIGTERM, signal.SIGHUP):
        return curses.wrapper(callback)


def uninstall_wizard(delete_settings=False, delete_sddm=False):
    return terminal(lambda screen: MaintenanceUI(screen).uninstall(delete_settings, delete_sddm))


def dispatch():
    if len(sys.argv) > 1 and sys.argv[1] in ("menu", "update", "doctor"):
        action, arguments = sys.argv[1], sys.argv[2:]
        if action == "menu":
            if arguments:
                raise ValueError("The menu does not take arguments")
            selected = terminal(lambda screen: MaintenanceUI(screen).menu())
            os.execv(sys.executable, [sys.executable, str(ROOT / "scripts/bloodyShell"), selected])
        return terminal(lambda screen: MaintenanceUI(screen).task(action, ["--json"] if action == "doctor" else arguments))
    parser = argparse.ArgumentParser(description="Repository setup")
    parser.add_argument("action", choices=("wizard", "worker-plan", "configs", "theme", "theme-settings", "login-shell", "check", "verify"))
    parser.add_argument("file", nargs="?")
    args = parser.parse_args()
    if args.action == "wizard":
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            raise RuntimeError("Open ./setup in a terminal to install.")
        if os.geteuid() == 0:
            raise RuntimeError("Run setup as your normal user.")
        import curses
        try:
            return curses.wrapper(lambda screen: Wizard(screen).run())
        except KeyboardInterrupt:
            return 130
    if not args.file:
        parser.error("An installation plan is required")
    plan = read_plan(args.file)
    if args.action == "worker-plan":
        for key in ("family", "backup", "packages", "appearance_packages", "selected"):
            value = plan[key]
            for item in value if isinstance(value, list) else [str(value).lower()]:
                print(key + "\t" + item)
    elif args.action == "configs":
        install_configs(plan)
    elif args.action == "theme":
        install_theme(plan)
    elif args.action == "theme-settings":
        apply_theme_settings(plan)
    elif args.action == "login-shell":
        apply_login_shell(plan)
    elif args.action == "check":
        preflight(plan)
    elif args.action == "verify":
        missing = [item["tool"] for item in MANAGEMENT["catalog"]()
                   if item["kind"] == "required" and not MANAGEMENT["available"](item["tool"])]
        if missing:
            raise RuntimeError("Missing required tools: " + ", ".join(missing))
    return 0


def main():
    with FILES["operation_signals"](signal.SIGTERM, signal.SIGHUP):
        return dispatch()
