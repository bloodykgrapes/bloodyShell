#!/usr/bin/env python3

import json
import io
from contextlib import redirect_stdout
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
    installer = runpy.run_path(str(ROOT / "scripts/lib/management.py"))["install"]
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
        result = installer(ROOT / "scripts/bloodyShell", binary, base / "backup")
        assert result["backups"]
        command = binary / "bloodyShell"
        assert command.is_file() and not command.is_symlink() and os.access(command, os.X_OK)
        assert old.read_text() == "previous executable", "Command replacement must not follow symlinks"
        assert (base / "backup/command").is_symlink()
        assert (home / ".bashrc").is_symlink(), "Preserve managed startup-file symlinks"
        assert original.read_text() == "export KEEP_ME=yes\n"
        assert not (base / "backup/bashrc").exists()
        repeated = installer(ROOT / "scripts/bloodyShell", binary, base / "backup")
        assert not repeated["changed"] and not repeated["backups"]
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_RUNTIME_DIR=str(runtime), PATH="/usr/bin:/bin")
        checked = subprocess.run(["bash", "--noprofile", "--norc", "-c", '. "$HOME/.bashrc"; . "$HOME/.bashrc"; printf "%s" "$PATH"'], env=env, capture_output=True, text=True, timeout=5)
        assert checked.returncode == 0, checked.stderr
        assert checked.stdout == "/usr/bin:/bin", checked.stdout
        assert not (ROOT / "unexpected").exists() and not (home / "unexpected").exists()

        # Install through the privileged boundary into an isolated directory
        # already on PATH, as terminals and niri inherit it.
        system = base / "system bin/bloodyShell"
        def sudo_install(args, **options):
            assert args[:2] == ["sudo", "/usr/bin/install"] and options["check"]
            assert args[-1] == str(system)
            system.parent.mkdir(exist_ok=True)
            shutil.copyfile(args[-2], system)
            system.chmod(0o755)
            return subprocess.CompletedProcess(args, 0)
        with patch.dict(installer.__globals__, SYSTEM_COMMAND=system), patch("subprocess.run", side_effect=sudo_install) as privileged:
            installer(ROOT / "scripts/bloodyShell", system.parent, base / "system backup")
            assert privileged.call_count == 1
            installer(ROOT / "scripts/bloodyShell", system.parent, base / "system backup")
            assert privileged.call_count == 1, "Unchanged system commands must not request sudo again"
        resolved = subprocess.run(["bash", "--noprofile", "--norc", "-c", "bloodyShell version"],
                                  env=dict(env, PATH=str(system.parent) + ":/usr/bin:/bin"), capture_output=True, text=True, timeout=5)
        assert resolved.returncode == 0 and resolved.stdout.strip() == "bloodyShell 1.2.3", resolved.stderr
        default = base / "default-install-path"
        default.write_text((ROOT / "setup").read_text().rsplit('main "$@"', 1)[0] + '\nprintf "%s" "$BIN_HOME"\n')
        clean = dict(env)
        clean.pop("XDG_BIN_HOME", None)
        result = subprocess.run(["bash", str(default)], env=clean, capture_output=True, text=True, timeout=5)
        assert result.returncode == 0 and result.stdout == str(home / ".local/bin"), result.stdout + result.stderr

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
        for action in ("install", "update", "doctor", "configs", "sddm"):
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
            dict(id="greeter", shell_id="bloodyShell-greeter", config_path=str(base / "dots/sddm/Main.qml"), launch_time="2026-11-08T23:58:00"),
            dict(id="installed-shell", shell_id="bloodyShell", config_path=str(target / "shell.qml"), launch_time="2026-11-08T10:00:00"),
            dict(id="development-shell", shell_id="bloodyShell", config_path=str(development / "shell.qml"), launch_time="2026-11-08T11:00:00"),
            dict(id="other-display", shell_id="bloodyShell", pid=os.getpid(), launch_time="2026-11-08T23:57:00")
        ]))
        for action in ("settings", "launcher", "wallpapers", "power", "helper", "keyboard"):
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
        discovered.write_text(json.dumps([dict(id="unrelated-shell", shell_id="other", config_path=str(development / "shell.qml"))]))
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


def path_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-PATH-") as temporary:
        base = Path(temporary)
        for shell in ("bash", "zsh", "fish"):
            home = base / (shell + " user's home $(touch unexpected)")
            home.mkdir()
            config, binary = home / "config", home / "local bin"
            target = config / "quickshell/bloodyShell"
            (target / "scripts").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/bloodyShell", target / "scripts/bloodyShell")
            (target / "shell.qml").write_text("// test runtime\n")
            (target / "version").write_text("1.2.3\n")
            managed = home / "managed-bashrc"
            original = b"export KEEP_ME=yes"
            managed.write_bytes(original)
            managed.chmod(0o640)
            (home / ".bashrc").symlink_to(managed)
            (home / ".bash_profile").write_text("export KEEP_LOGIN=yes\n")
            zsh = home / "zsh configs"
            zsh.mkdir()
            tools = home / "tools"
            tools.mkdir()
            (tools / "qs").write_text("#!/bin/sh\nprintf '[]\\n'\n")
            (tools / "qs").chmod(0o755)
            env = dict(HOME=str(home), SHELL="/bin/" + shell, PATH=str(tools) + ":/usr/bin:/bin", ZDOTDIR=str(zsh),
                       XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(home / "state"), XDG_CACHE_HOME=str(home / "cache"))
            arguments = ["install-command", str(target / "scripts/bloodyShell"), str(binary), str(home / "backup")]
            with patch.dict(os.environ, env, clear=True), patch.object(sys, "argv", arguments), redirect_stdout(io.StringIO()):
                api["install_main"]()
                record = json.loads((home / "state/bloodyShell/install.json").read_text())
                before = {name: (Path(name).read_bytes(), Path(name).stat().st_mtime_ns) for name in record["path_files"]}
                api["install_main"]()
                assert before == {name: (Path(name).read_bytes(), Path(name).stat().st_mtime_ns) for name in record["path_files"]}, "PATH installation must be idempotent"
            assert (home / ".bashrc").is_symlink() and managed.stat().st_mode & 0o777 == 0o640
            for profile in (home / ".profile", home / ".bashrc", home / ".bash_profile"):
                sourced = subprocess.run(["bash", "--noprofile", "--norc", "-c", '. "$1"; . "$1"; command -v bloodyShell; bloodyShell version; printf "%s" "$PATH"', "test", str(profile)],
                                         env=env, capture_output=True, text=True, timeout=5)
                assert sourced.returncode == 0, sourced.stderr
                lines = sourced.stdout.splitlines()
                assert lines[:2] == [str(binary / "bloodyShell"), "bloodyShell 1.2.3"] and lines[2].split(":").count(str(binary)) == 1
            if shell == "zsh":
                assert (zsh / ".zprofile").exists() and (zsh / ".zshrc").exists()
            if shell == "fish":
                fish_file = config / "fish/conf.d/bloodyShell-path.fish"
                assert fish_file.exists()
                if shutil.which("fish"):
                    sourced = subprocess.run(["fish", "--no-config", "-c", 'source "$argv[1]"; source "$argv[1]"; command -s bloodyShell', str(fish_file)], env=env, capture_output=True, text=True, timeout=5)
                    assert sourced.returncode == 0 and sourced.stdout.strip() == str(binary / "bloodyShell"), sourced.stderr
            generator = Path("/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator")
            if generator.is_file():
                result = subprocess.run(["bash", "--noprofile", "--norc", "-c", 'eval "$("$1")"; printf "%s" "$PATH"', "test", str(generator)], env=env, capture_output=True, text=True, timeout=5)
                assert result.returncode == 0 and result.stdout.split(":")[0] == str(binary), result.stdout + result.stderr
            managed.write_bytes(managed.read_bytes() + b"# personal addition\n")
            with patch.dict(os.environ, env, clear=True), patch.object(sys, "argv", ["uninstall", "--apply"]), redirect_stdout(io.StringIO()):
                api["uninstall_main"]()
            assert managed.read_bytes() == original + b"\n# personal addition\n" and (home / ".bashrc").is_symlink()
            assert (home / ".bash_profile").read_text() == "export KEEP_LOGIN=yes\n"
            assert not (home / ".profile").exists() and not (config / "environment.d/90-bloodyShell-path.conf").exists()
            assert not (ROOT / "unexpected").exists() and not (home / "unexpected").exists()
        # A failed registration rolls back only files written by that attempt.
        home = base / "rollback home"
        (home / "config/quickshell/bloodyShell/scripts").mkdir(parents=True)
        target = home / "config/quickshell/bloodyShell"
        shutil.copy2(ROOT / "scripts/bloodyShell", target / "scripts/bloodyShell")
        (target / "shell.qml").write_text("// runtime")
        (target / "version").write_text("1.2.3")
        (home / ".bashrc").write_text("# original")
        env = dict(HOME=str(home), SHELL="/bin/bash", PATH="/usr/bin:/bin", XDG_CONFIG_HOME=str(home / "config"), XDG_STATE_HOME=str(home / "state"))
        ownership = runpy.run_path(str(ROOT / "scripts/lib/ownership.py"))
        original_atomic = ownership["atomic"]
        def failing_atomic(path, data, mode=0o600):
            original_atomic(path, data, mode)
            if path == home / ".profile":
                raise OSError("simulated disk failure after the profile write")
        with patch.dict(os.environ, env, clear=True), patch.object(sys, "argv", ["install-command", str(target / "scripts/bloodyShell"), str(home / ".local/bin"), str(home / "backup")]), patch("runpy.run_path", return_value=dict(ownership, atomic=failing_atomic)), redirect_stdout(io.StringIO()):
            try:
                api["install_main"]()
            except OSError:
                pass
            else:
                raise AssertionError("Partial PATH installation was accepted")
        assert not (home / ".profile").exists() and not (home / ".local/bin/bloodyShell").exists()
        assert (home / ".bashrc").read_text() == "# original" and not (home / "state/bloodyShell/install.json").exists()
    print("Managed PATH blocks passed: Bash/login shells, ZDOTDIR, Fish, environment.d, literal paths, symlinks, permissions, idempotence and removal preserving user edits.")


if __name__ == "__main__":
    run_checks()
    path_checks()
