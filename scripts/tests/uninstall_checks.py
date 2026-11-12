#!/usr/bin/env python3
"""Exercise setup uninstall through real installed launchers and isolated services."""

import fcntl
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


def fixture(base):
    for name in ("home", "config", "state", "cache", "runtime", "bin", "custom commands"):
        (base / name).mkdir(mode=0o700, parents=True)
    target = base / "config/quickshell/bloodyShell"
    (target / "scripts").mkdir(parents=True)
    shutil.copytree(ROOT / "scripts/lib", target / "scripts/lib", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy2(ROOT / "scripts/bloodyShell", target / "scripts/bloodyShell")
    shutil.copy2(ROOT / "setup", target / "setup")
    (target / "shell.qml").write_text("//@ pragma ShellId bloodyShell\n// installed\n")
    (target / "version").write_text("1.0.0\n")
    env = dict(os.environ, HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"),
               XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
               XDG_DATA_HOME=str(base / "data"),
               XDG_RUNTIME_DIR=str(base / "runtime"), XDG_BIN_HOME=str(base / "custom commands"),
               TEST_UNINSTALL_BASE=str(base), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
    tool = base / "bin/qs"
    tool.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
base = Path(os.environ["TEST_UNINSTALL_BASE"])
args = sys.argv[1:]
with (base / "calls").open("a") as stream: stream.write(json.dumps(args) + "\\n")
data = json.loads((base / "instances").read_text())
if args[0] == "list":
    if os.environ.get("TEST_QUERY_FAIL"): sys.exit(1)
    if "--path" in args: data = [entry for entry in data if entry["config_path"] == args[args.index("--path")+1]]
    print(json.dumps(data))
elif args[0] == "kill":
    if os.environ.get("TEST_STOP_FAIL"): sys.exit(1)
    selected = args[args.index("--id")+1]
    (base / "instances").write_text(json.dumps([entry for entry in data if entry["id"] != selected]))
else: raise AssertionError(args)
''')
    tool.chmod(0o700)
    (base / "instances").write_text("[]")
    (base / "bin/niri").write_text("#!/bin/sh\nexit 0\n")
    (base / "bin/niri").chmod(0o700)
    command = base / "custom commands/bloodyShell"
    register = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                               str(target / "scripts/bloodyShell"), str(command.parent), str(base / "state/backup")],
                              env=env, text=True, capture_output=True, timeout=10)
    assert register.returncode == 0, register.stdout + register.stderr
    return env, target, command


def run(base, env, *args, success=True, installed=False):
    start = [str(base / "custom commands/bloodyShell"), "uninstall"] if installed else ["bash", str(ROOT / "setup"), "uninstall"]
    result = subprocess.run([*start, *args], env=env, capture_output=True, text=True, timeout=12)
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-uninstall-") as temporary:
        root = Path(temporary)
        base = root / "normal"
        env, target, command = fixture(base)
        state = base / "state/bloodyShell"
        settings = base / "config/bloodyShell/settings.json"
        settings.parent.mkdir()
        settings.write_text('{"personal":true}')
        backups = state / "backups"
        backups.mkdir()
        (backups / "keep").write_text("previous config")
        cache = base / "cache/bloodyShell/keyboard"
        cache.mkdir(parents=True)
        (cache / "plugin.so").write_text("cached")
        record = (state / "install.json").read_bytes()
        plan = json.loads(run(base, env, "--json").stdout)
        assert str(command) in plan["remove"] and target.exists()
        assert str(cache) in plan["cleanup"]
        assert not (base / "calls").exists(), "Preview contacted or stopped the shell"
        assert (state / "install.json").read_bytes() == record
        assert (state / "install.json").stat().st_mode & 0o777 == 0o600
        # Both the CLI and setup route the uninstall without depending on the source checkout.
        with (state / "operation.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            run(base, env, "--apply", success=False)
        assert target.exists() and command.exists() and not (base / "calls").exists()
        entries = [dict(id="installed", shell_id="bloodyShell", config_path=str(target)),
                   dict(id="unrelated", shell_id="other-shell", config_path="/other")]
        (base / "instances").write_text(json.dumps(entries))
        for failure in ("TEST_QUERY_FAIL", "TEST_STOP_FAIL"):
            run(base, dict(env, **{failure: "1"}), "--apply", success=False)
            assert target.exists() and command.exists(), "Failed shutdown removed installed files"
        # The recorded command path wins over a later XDG_BIN_HOME change.
        alternative = base / "alternative commands"
        alternative.mkdir()
        (alternative / "bloodyShell").write_text("unrelated command")
        removed = json.loads(run(base, dict(env, XDG_BIN_HOME=str(alternative), XDG_DATA_HOME=str(base / "other data")), "--apply", "--json", installed=True).stdout)
        assert not removed["preserve"] and not target.exists() and not command.exists()
        assert (alternative / "bloodyShell").read_text() == "unrelated command"
        assert not (state / "install.json").exists() and not cache.exists()
        assert settings.read_text() == '{"personal":true}' and (backups / "keep").is_file()
        assert json.loads((base / "instances").read_text()) == entries[1:]
        assert "No recorded installation" in run(base, env, "--apply").stdout
        assert (ROOT / "setup").exists(), "Uninstall removed the source checkout"

        for edited in (False, True):
            base = root / ("replace-edited" if edited else "replace-command")
            env, target, command = fixture(base)
            application = base / "data/applications/bloodyShell.desktop"
            application.parent.mkdir(parents=True)
            application.write_text("[Desktop Entry]\nName=bloodyShell\nType=Application\nExec=unused\n")
            manifest = base / "state/bloodyShell/install.json"
            record = json.loads(manifest.read_text())
            api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
            record.update(application=str(application), application_fingerprint=api["fingerprint"](application))
            manifest.write_text(json.dumps(record))
            if edited:
                application.write_text(application.read_text() + "# user edit\n")
                command.write_text(command.read_text() + "\n# user edit\n")
            replacement = base / "system commands"
            registered = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                                         str(target / "scripts/bloodyShell"), str(replacement), str(base / "state/replacement-backup")],
                                        env=env, capture_output=True, text=True, timeout=8)
            assert registered.returncode == 0, registered.stderr
            assert application.exists() == edited and command.exists() == edited
            updated = json.loads(manifest.read_text())
            assert updated["command"] == str(replacement / "bloodyShell") and "application" not in updated
            invoked = subprocess.run(["bash", "--noprofile", "--norc", "-c", "bloodyShell version"],
                                     env=dict(env, PATH=str(replacement) + os.pathsep + env["PATH"]), capture_output=True, text=True, timeout=5)
            assert invoked.returncode == 0 and invoked.stdout.strip() == "bloodyShell 1.0.0", invoked.stderr

        base = root / "modified"
        env, target, command = fixture(base)
        custom = target / "personal.txt"
        custom.write_text("keep user data")
        (target / "shell.qml").write_text("// user's edits\n")
        # Reinstalling only the command must not adopt changed/extra runtime files.
        repaired = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                                   str(target / "scripts/bloodyShell"), str(command.parent), str(base / "state/backup")],
                                  env=env, capture_output=True, text=True, timeout=8)
        assert repaired.returncode == 0, repaired.stderr
        command.write_text(command.read_text() + "\n# user's edits\n")
        rejected = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                                   str(target / "scripts/bloodyShell"), str(command.parent), str(base / "state/backup")],
                                  env=env, capture_output=True, text=True, timeout=8)
        assert rejected.returncode != 0 and command.read_text().endswith("# user's edits\n")
        cache = base / "cache/bloodyShell/keyboard"
        cache.mkdir(parents=True)
        (cache / "plugin.so").write_text("live cache")
        # A different development instance shares caches but must never be killed.
        other = dict(id="development", shell_id="bloodyShell", config_path=str(ROOT))
        (base / "instances").write_text(json.dumps([other]))
        plan = json.loads(run(base, env, "--apply", "--json").stdout)
        assert str(command) in plan["preserve"] and str(custom) in plan["preserve"]
        assert command.is_file() and custom.read_text() == "keep user data"
        assert (target / "shell.qml").read_text() == "// user's edits\n"
        assert not (target / "scripts/bloodyShell").exists() and cache.exists()
        assert json.loads((base / "instances").read_text()) == [other]
        assert (base / "state/bloodyShell/install.json").exists()

        base = root / "registration-rollback"
        env, target, command = fixture(base)
        application = base / "data/applications/bloodyShell.desktop"
        application.parent.mkdir(parents=True)
        application.write_text("generated application")
        manifest = base / "state/bloodyShell/install.json"
        api = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
        recorded = json.loads(manifest.read_text())
        recorded.update(application=str(application), application_fingerprint=api["fingerprint"](application))
        manifest.write_text(json.dumps(recorded))
        record = (base / "state/bloodyShell/install.json").read_bytes()
        replacement = base / "new commands/bloodyShell"
        arguments = [str(ROOT / "scripts/lib/management.py"), str(target / "scripts/bloodyShell"), str(replacement.parent), str(base / "state/replacement-backup")]
        with patch.dict(os.environ, env), patch.object(sys, "argv", arguments), patch.dict(api["install_main"].__globals__, SYSTEM_COMMAND=replacement), patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, "sudo")) as sudo:
            try:
                api["install_main"]()
            except subprocess.CalledProcessError:
                pass
            else:
                raise AssertionError("Failed sudo installation was accepted")
            assert sudo.call_count == 1, "A failed sudo install should not request sudo again for rollback"
        assert command.exists() and application.exists() and not replacement.exists()
        (target / ".git").mkdir()
        failed = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                                 str(target / "scripts/bloodyShell"), str(replacement.parent), str(base / "state/replacement-backup")],
                                env=env, capture_output=True, text=True, timeout=8)
        assert failed.returncode != 0 and command.exists() and application.read_text() == "generated application" and not replacement.exists()
        assert (base / "state/bloodyShell/install.json").read_bytes() == record

        base = root / "edited-path"
        env, target, command = fixture(base)
        profile = base / "home/.profile"
        profile.write_text(profile.read_text().replace("case ", "# personal change\ncase ", 1))
        bashrc = base / "home/.bashrc"
        bashrc.write_text(bashrc.read_text() + "export PRIVATE_TOKEN=do-not-print\n")
        preview = run(base, env, "--json").stdout
        assert str(profile) in json.loads(preview)["preserve"]
        assert "PRIVATE_TOKEN" not in preview and "ZG8tbm90LXByaW50" not in preview and '"contents"' not in preview, "Uninstall reports must not disclose shell profile contents"
        before = command.read_bytes()
        repaired = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "install-command",
                                   str(target / "scripts/bloodyShell"), str(command.parent), str(base / "state/backup")], env=env, capture_output=True, text=True, timeout=8)
        assert repaired.returncode != 0 and command.read_bytes() == before
        removed = json.loads(run(base, env, "--apply", "--json").stdout)
        assert str(profile) in removed["preserve"] and "# personal change" in profile.read_text()
        assert bashrc.read_text() == "export PRIVATE_TOKEN=do-not-print\n" and not target.exists()

        base = root / "restore"
        env, target, command = fixture(base)
        niri = base / "config/niri"
        (niri / "bloodyShell").mkdir(parents=True)
        (niri / "config.kdl").write_text("// user config\n")
        fragment = niri / "bloodyShell/06-user-input.kdl"
        fragment.write_text("// original\n")
        result = subprocess.run([sys.executable, str(target / "scripts/bloodyShell"), "internal", "niri-config", "write", fragment.name, "// changed"], env=env, capture_output=True, text=True, timeout=8)
        assert result.returncode == 0, result.stderr
        fragment.write_text("// later user edit\n")
        run(base, env, "--apply", "--restore", success=False)
        assert target.is_dir() and command.is_file() and fragment.read_text() == "// later user edit\n"
        fragment.write_text("// changed\n")
        run(base, env, "--apply", "--restore")
        assert fragment.read_text() == "// original\n" and not target.exists()

        base = root / "unsafe"
        env, target, command = fixture(base)
        original = base / "original"
        target.rename(original)
        target.symlink_to(original, target_is_directory=True)
        run(base, env, "--apply", success=False)
        assert original.is_dir() and command.is_file()
        target.unlink()
        original.rename(target)
        manifest = base / "state/bloodyShell/install.json"
        record = json.loads(manifest.read_text())
        record["files"]["../outside"] = {}
        manifest.write_text(json.dumps(record))
        run(base, env, "--apply", success=False)
        assert target.is_dir() and command.is_file()
        manifest.unlink()
        run(base, env, "--apply", success=False)
        assert target.is_dir() and command.is_file(), "Unrecorded installation was removed"

        base = root / "cache-links"
        env, target, command = fixture(base)
        personal = base / "personal"
        personal.mkdir()
        (personal / "keep").write_text("user data")
        cache = base / "cache/bloodyShell/keyboard"
        cache.parent.mkdir(parents=True)
        cache.symlink_to(personal, target_is_directory=True)
        plan = json.loads(run(base, env, "--apply", "--json").stdout)
        assert str(cache) in plan["preserve_data"]
        assert not target.exists() and cache.is_symlink() and (personal / "keep").is_file()

        base = root / "restart-lock"
        env, target, command = fixture(base)
        command.write_text('''import os, subprocess
from pathlib import Path
lock = Path(os.environ["XDG_STATE_HOME"]) / "bloodyShell/operation.lock"
result = subprocess.run(["flock", "-n", str(lock), "true"])
assert result.returncode == 0, "Restart inherited a held installer lock"
print("RESTART_LOCK_RELEASED")
''')
        script = base / "restart-check"
        script.write_text((ROOT / "setup").read_text().rsplit('main "$@"', 1)[0] + "\nlock_installation\nrestart_shell\n")
        restarted = subprocess.run(["bash", str(script)], env=dict(env, WAYLAND_DISPLAY="test-only"), capture_output=True, text=True, timeout=8)
        assert restarted.returncode == 0 and "RESTART_LOCK_RELEASED" in restarted.stdout, restarted.stdout + restarted.stderr
    print("Uninstall passed: previews, self-removal, scoped shutdown, command registration/rollback, locks, edited/untracked files, shared caches, restoration, symlinks and invalid records.")


if __name__ == "__main__":
    checks()
