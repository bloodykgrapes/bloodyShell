#!/usr/bin/env python3

import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def run_checks():
    installer = runpy.run_path(str(ROOT / "scripts/setup/install-command"))["install"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-command-") as temporary:
        base = Path(temporary)
        home = base / "user's home $(touch unexpected)"
        home.mkdir()
        config = home / "config"
        binary = home / "local bin"
        target = config / "quickshell/bloodyShell"
        target.mkdir(parents=True)
        (target / "shell.qml").write_text("test")
        (target / "version").write_text("1.2.3\n")
        (target / "setup").write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n')
        original = home / "managed-bashrc"
        original.write_text("export KEEP_ME=yes\n")
        (home / ".bashrc").symlink_to(original)
        binary.mkdir()
        old = home / "old-command"
        old.write_text("previous executable")
        (binary / "bloodyShell").symlink_to(old)
        result = installer(ROOT / "scripts/bloodyShell", binary, config, home, base / "backup", "/bin/bash", "/usr/bin:/bin")
        assert result["backups"]
        command = binary / "bloodyShell"
        assert command.is_file() and not command.is_symlink() and os.access(command, os.X_OK)
        assert old.read_text() == "previous executable", "Command replacement must not follow symlinks"
        assert (base / "backup/command").is_symlink()
        assert (home / ".bashrc").is_symlink(), "Preserve managed startup-file symlinks"
        assert (base / "backup/bashrc").read_text() == "export KEEP_ME=yes\n"
        repeated = installer(ROOT / "scripts/bloodyShell", binary, config, home, base / "backup", "/bin/bash", "/usr/bin:/bin")
        assert not repeated["changed"] and not repeated["backups"]
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_RUNTIME_DIR=str(runtime), PATH="/usr/bin:/bin")
        checked = subprocess.run(["bash", "--noprofile", "--norc", "-c", '. "$HOME/.bashrc"; . "$HOME/.bashrc"; printf "%s" "$PATH"'], env=env, capture_output=True, text=True, timeout=5)
        assert checked.returncode == 0, checked.stderr
        assert checked.stdout == str(binary) + ":/usr/bin:/bin", checked.stdout
        assert not (ROOT / "unexpected").exists() and not (home / "unexpected").exists()

        for shell in ("zsh", "fish", "nu"):
            root = base / shell
            root.mkdir()
            result = installer(ROOT / "scripts/bloodyShell", root / "bin", root / "config", root, root / "backup", shell, "/usr/bin:/bin")
            if shell == "zsh":
                assert (root / ".zshenv").is_file()
            elif shell == "fish":
                script = root / "config/fish/conf.d/bloodyShell.fish"
                assert "set -gx PATH" in script.read_text()
                if shutil.which("fish"):
                    subprocess.run(["fish", "--no-execute", str(script)], check=True)
            else:
                assert result["manual"] and not (root / ".profile").exists()
        root = base / "path-ready"
        installer(ROOT / "scripts/bloodyShell", root / "bin", root / "config", root, root / "backup", "bash", str(root / "bin"))
        assert not (root / ".bashrc").exists(), "No startup-file edits when the command is on PATH"

        fake = base / "fake"
        fake.mkdir()
        qs = fake / "qs"
        qs.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
base = Path(os.environ["TEST_BASE"])
with (base / "calls").open("a") as stream: stream.write(json.dumps(args) + "\\n")
state = base / "running"
if args[0] == "list":
    if os.environ.get("TEST_INVALID"): print("broken json")
    elif os.environ.get("TEST_EMPTY"): pass
    elif os.environ.get("TEST_NONE"): print("No running instances.")
    elif "--all" in args:
        data = json.loads((base / "instances").read_text())
        for entry in data:
            if isinstance(entry, dict): entry.setdefault("pid", os.getppid())
        print(json.dumps(data))
    else: print(json.dumps([dict(id="test-instance", pid=123)] if state.exists() else []))
elif args[0] == "kill":
    state.unlink(missing_ok=True)
else:
    if "--daemonize" in args: state.touch()
    sys.exit(int(os.environ.get("TEST_FAIL", "0")))
''')
        qs.chmod(0o755)
        env.update(PATH=str(fake) + ":/usr/bin:/bin", TEST_BASE=str(base), WAYLAND_DISPLAY="test-only")

        def invoke(*args, overrides=None):
            return subprocess.run([str(command), *args], env=dict(env, **(overrides or {})), capture_output=True, text=True, timeout=8)

        def calls():
            return [json.loads(line) for line in (base / "calls").read_text().splitlines()]

        assert invoke("help").returncode == 0
        assert invoke("version").stdout.strip() == "bloodyShell 1.2.3"
        assert invoke("path").stdout.strip() == str(target)
        for action in ("install", "update", "doctor", "configs", "greetd"):
            result = invoke(action, "--example")
            assert result.returncode == 0 and result.stdout == action + "\n--example\n", result.stderr
        assert invoke("setup").returncode == 0
        assert invoke().returncode == 0
        assert calls()[-1] == ["--no-duplicate", "--path", str(target), "--daemonize"]
        assert json.loads(invoke("status", "--json").stdout)["running"]
        assert invoke("restart").returncode == 0
        assert ["kill", "--id", "test-instance"] in calls()
        for call in calls():
            if call[0] == "list":
                assert call == ["list", "--path", str(target), "--json", "--no-color"], "Lifecycle operations must remain scoped to their installation"
        assert invoke("stop").returncode == 0
        assert not json.loads(invoke("status", "--json").stdout)["running"]
        assert invoke("run", "--no-color").returncode == 0
        assert calls()[-1] == ["--no-duplicate", "--path", str(target), "--no-color"]
        development = base / "renamed checkout's directory $(touch unexpected)"
        development.mkdir()
        (development / "shell.qml").write_text("//@ pragma ShellId bloodyShell\nimport Quickshell\nShellRoot {}\n")
        discovered = base / "instances"
        discovered.write_text(json.dumps([
            dict(id="unrelated-shell", shell_id="other", config_path=str(base / "other/shell.qml"), launch_time="2026-11-08T23:59:00"),
            dict(id="greeter", shell_id="bloodyShell-greeter", config_path=str(base / "greeter/shell.qml"), launch_time="2026-11-08T23:58:00"),
            dict(id="installed-shell", shell_id="bloodyShell", config_path=str(target / "shell.qml"), launch_time="2026-11-08T10:00:00"),
            dict(id="development-shell", shell_id="bloodyShell", config_path=str(development / "shell.qml"), launch_time="2026-11-08T11:00:00"),
            dict(id="other-display", shell_id="bloodyShell", pid=os.getpid(), launch_time="2026-11-08T23:57:00")
        ]))
        for action in ("settings", "launcher", "wallpapers", "power", "helper"):
            assert invoke(action).returncode == 0
            assert calls()[-1] == ["ipc", "--id", "development-shell", "call", "--", action, "toggle"]
            assert calls()[-2] == ["list", "--all", "--json", "--no-color"]
            assert invoke(action, "show").returncode == 0
            assert calls()[-1][-1] == "show"
            assert calls()[-1][-3] == "--", "Do not parse show as the IPC inspection subcommand"
        assert invoke("lock").returncode == 0 and calls()[-1][-2:] == ["lock", "lock"]
        assert invoke("screenshot").returncode == 0 and calls()[-1][-3:] == ["--", "screenshot", "show"]
        for capture_mode in ("show", "screen", "hide"):
            assert invoke("screenshot", capture_mode).returncode == 0 and calls()[-1][-3:] == ["--", "screenshot", capture_mode]
        assert invoke("alt-tab").returncode == 0 and calls()[-1][-3:] == ["altTab", "begin", "false"]
        assert invoke("alt-tab", "next").returncode == 0 and calls()[-1][-1] == "false"
        assert invoke("alt-tab", "previous").returncode == 0 and calls()[-1][-1] == "true"
        assert invoke("logs").returncode == 0 and calls()[-1][-2:] == ["--tail", "200"]
        assert calls()[-1][:3] == ["log", "--id", "development-shell"]
        assert invoke("logs", "--tail", "25").returncode == 0 and calls()[-1][-2:] == ["--tail", "25"]
        development.rename(base / "moved again")
        target.rename(base / "installed payload temporarily absent")
        assert invoke("screenshot").returncode == 0 and calls()[-1][2] == "development-shell", "IPC routing must not read the payload or depend on its old directory"
        assert invoke("logs").returncode == 0 and calls()[-1][2] == "development-shell"
        (base / "installed payload temporarily absent").rename(target)
        (base / "moved again").rename(development)
        discovered.write_text(json.dumps([dict(id="legacy-shell", shell_id="old-path-hash", config_path=str(development / "shell.qml"))]))
        assert invoke("settings").returncode == 0 and calls()[-1][2] == "legacy-shell", "Recognize an existing instance before it reloads the stable shell identity"
        discovered.write_text(json.dumps([dict(id="unrelated-shell", shell_id="other", config_path=str(target / "shell.qml"))]))
        result = invoke("screenshot")
        assert result.returncode != 0 and "No running bloodyShell instance" in result.stderr
        assert calls()[-1] == ["list", "--all", "--json", "--no-color"], "Do not call unrelated shells or auto-start a shell"
        assert invoke("screenshot", overrides=dict(TEST_EMPTY="1")).returncode != 0
        result = invoke("screenshot", overrides=dict(TEST_NONE="1"))
        assert result.returncode != 0 and "No running bloodyShell instance" in result.stderr
        assert json.loads(invoke("status", "--json", overrides=dict(TEST_NONE="1")).stdout)["running"] is False
        assert invoke("settings", overrides=dict(TEST_INVALID="1")).returncode != 0
        discovered.write_text(json.dumps([dict(id="invalid-instance", shell_id="bloodyShell", pid="invalid")]))
        assert invoke("screenshot").returncode != 0
        before = len(calls())
        for args in (("unknown",), ("settings", "invalid"), ("settings", "show", "extra"), ("screenshot", "invalid"), ("screenshot", "window"), ("screenshot", "screen", "extra"), ("alt-tab", "invalid"), ("lock", "extra"), ("restart", "extra"), ("status", "--invalid")):
            assert invoke(*args).returncode != 0
        assert invoke("restart", overrides=dict(WAYLAND_DISPLAY="")).returncode != 0
        assert len(calls()) == before, "Reject invalid commands and unavailable sessions before touching running shells"
        assert invoke("start", overrides=dict(TEST_FAIL="7")).returncode == 7
        assert invoke("status", overrides=dict(TEST_INVALID="1")).returncode != 0
        api = runpy.run_path(str(ROOT / "scripts/bloodyShell"))
        native = runtime / "quickshell/by-id"
        native.mkdir(parents=True)
        (native / "cached-shell").mkdir()
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], env=env)
        try:
            entry = dict(id="cached-shell", shell_id="bloodyShell", pid=process.pid, launch_time="2026-11-09T10:00:00")
            discovered.write_text(json.dumps([entry]))
            with patch.dict(os.environ, env), patch("pathlib.Path.is_socket", return_value=True):
                before = len(calls())
                assert api["active_instance"](str(qs))["id"] == "cached-shell"
                assert len(calls()) == before + 1, "Cold discovery queries Quickshell"
                assert api["active_instance"](str(qs))["id"] == "cached-shell"
                assert len(calls()) == before + 1, "Repeated actions must skip the discovery process"
                cache = api["discovery_cache"](api["display"](os.environ))[0]
                assert cache.stat().st_mode & 0o077 == 0, "Instance cache must be private"
                (native / "newer-shell").mkdir()
                newer = dict(entry, id="newer-shell", launch_time="2026-11-09T11:00:00")
                discovered.write_text(json.dumps([entry, newer]))
                assert api["active_instance"](str(qs))["id"] == "newer-shell"
                assert len(calls()) == before + 2, "A new instance must invalidate cached routing"
                stored = json.loads(cache.read_text())
                stored["birth"] = "reused-pid"
                cache.write_text(json.dumps(stored))
                assert api["active_instance"](str(qs))["id"] == "newer-shell" and len(calls()) == before + 3
                cache.write_text("broken json")
                assert api["active_instance"](str(qs))["id"] == "newer-shell" and len(calls()) == before + 4
                with patch("pathlib.Path.is_socket", return_value=False):
                    assert api["active_instance"](str(qs))["id"] == "newer-shell" and len(calls()) == before + 5
                cache.unlink()
                with patch("os.replace", side_effect=OSError("Cache is unavailable")):
                    assert api["active_instance"](str(qs))["id"] == "newer-shell"
                assert not list(cache.parent.iterdir()), "Failed cache writes must remove temporary files"
                with patch.dict(os.environ, WAYLAND_DISPLAY="another-session"):
                    try:
                        api["active_instance"](str(qs))
                    except RuntimeError as error:
                        assert "No running bloodyShell instance" in str(error)
                    else:
                        raise AssertionError("Cached routing crossed desktop sessions")
                api["active_instance"](str(qs))
                process.terminate()
                process.wait(timeout=5)
                try:
                    api["active_instance"](str(qs))
                except RuntimeError:
                    pass
                else:
                    raise AssertionError("Cached routing accepted a dead process")
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        source = subprocess.run([str(ROOT / "scripts/bloodyShell"), "path"], env=env, capture_output=True, text=True, timeout=5)
        assert source.stdout.strip() == str(ROOT), "Source checkout commands control the source checkout"
    print("Active-instance discovery/cache, session filtering, newer instances, PID reuse, directory moves, command routing, scoped lifecycle, errors and command installation passed in isolation.")


if __name__ == "__main__":
    run_checks()
