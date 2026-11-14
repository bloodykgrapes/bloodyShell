#!/usr/bin/env python3
"""Exercise setup uninstall through real installed launchers and isolated services."""

import fcntl
import io
from contextlib import redirect_stdout
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
    with tempfile.TemporaryDirectory(prefix="bloodyShell-uninstall-") as temporary:
        root = Path(temporary)
        for record_state in ("normal", "missing", "invalid"):
            base = root / record_state
            env, target, command = fixture(base)
            state = base / "state/bloodyShell"
            record = state / "install.json"
            assert not record.exists(), "Installer still creates tracking records"
            if record_state != "missing":
                state.mkdir(parents=True, exist_ok=True)
                record.write_text("broken JSON" if record_state == "invalid" else '{"obsolete":true}')
            settings = base / "config/bloodyShell/settings.json"
            settings.parent.mkdir()
            settings.write_text('{"personal":true}')
            for path in (base / "config/niri/user.kdl", base / "config/kitty/kitty.conf", state / "backups/keep"):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("keep")
            cache = base / "cache/bloodyShell"
            (cache / "wallpapers").mkdir(parents=True)
            (cache / "wallpapers/poster.png").write_text("generated")
            private = base / "runtime/bloodyShell"
            private.mkdir()
            (private / "temporary").write_text("generated")
            (target / "user-edited.qml").write_text("runtime file")
            command.write_bytes(command.read_bytes()+b"\n# Edited installed command\n")
            preview = json.loads(run(base, env, "--json").stdout)
            assert str(target) in preview["remove"] and str(command) in preview["remove"]
            assert str(cache) in preview["remove"] and str(settings.parent) not in preview["remove"]
            assert target.exists() and not (base / "calls").exists(), "Preview changed files or contacted the shell"
            removed = json.loads(run(base, env, "--apply", "--json", installed=True).stdout)
            assert not target.exists() and not command.exists() and not cache.exists() and not private.exists()
            assert not record.exists() and not removed["delete_settings"] and not removed["delete_sddm"]
            assert settings.read_text() == '{"personal":true}'
            assert (base / "config/niri/user.kdl").read_text() == "keep"
            assert (base / "config/kitty/kitty.conf").read_text() == "keep"
            assert (state / "backups/keep").read_text() == "keep"
            assert "# >>> bloodyShell PATH >>>" not in (base / "home/.bashrc").read_text()
            run(base, env, "--apply")
        base = root / "shutdown"
        env, target, command = fixture(base)
        state = base / "state/bloodyShell"
        state.mkdir(parents=True, exist_ok=True)
        with (state / "operation.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            run(base, env, "--apply", success=False)
        assert target.exists() and command.exists()
        entries = [dict(id="installed",shell_id="bloodyShell",config_path=str(target)),
                   dict(id="unrelated",shell_id="other-shell",config_path="/other")]
        (base / "instances").write_text(json.dumps(entries))
        for failure in ("TEST_QUERY_FAIL","TEST_STOP_FAIL"):
            run(base,dict(env,**{failure:"1"}),"--apply",success=False)
            assert target.exists() and command.exists()
        run(base, env, "--apply")
        assert json.loads((base / "instances").read_text()) == entries[1:]
        base = root / "other-instance"
        env, target, command = fixture(base)
        cache = base / "cache/bloodyShell"
        cache.mkdir()
        (cache / "keep-live").write_text("live")
        (base / "instances").write_text(json.dumps([dict(id="development",shell_id="bloodyShell",config_path="/another/checkout")]))
        run(base,env,"--apply","--delete-settings",success=False)
        assert target.exists() and command.exists()
        plan=json.loads(run(base,env,"--apply","--json").stdout)
        assert str(cache) in plan["kept_cache"] and (cache / "keep-live").exists()
        assert not target.exists() and not command.exists()
        base = root / "delete-settings"
        env, target, command = fixture(base)
        settings=base / "config/bloodyShell"
        settings.mkdir()
        (settings / "settings.json").write_text("{}")
        assert str(settings) in json.loads(run(base,env,"--delete-settings","--json").stdout)["remove"]
        assert settings.exists()
        run(base,env,"--apply","--delete-settings")
        assert not settings.exists()
        run(base,env,"--apply","--restore",success=False)
        base = root / "cache-config-overlap"
        env, target, command=fixture(base)
        settings=base / "config/bloodyShell"
        settings.mkdir()
        (settings / "settings.json").write_text("keep")
        run(base,dict(env,XDG_CACHE_HOME=env["XDG_CONFIG_HOME"]),"--apply")
        assert (settings / "settings.json").read_text()=="keep"
        base = root / "source-checkout"
        env,target,command=fixture(base)
        (target / ".git").mkdir()
        run(base,env,"--apply",success=False)
        assert target.exists() and command.exists()
        base = root / "runtime-link"
        env,target,command=fixture(base)
        source=base / "source"
        shutil.move(str(target),source)
        (source / ".git").mkdir()
        target.symlink_to(source,target_is_directory=True)
        personal=base / "personal"
        personal.mkdir()
        (personal / "keep").write_text("keep")
        (base / "cache/bloodyShell").symlink_to(personal,target_is_directory=True)
        run(base,env,"--apply")
        assert not target.is_symlink() and source.exists() and (personal / "keep").read_text()=="keep"
        assert not (base / "cache/bloodyShell").is_symlink()
        base = root / "path-cleanup"
        env,target,command=fixture(base)
        profile=base / "home/.bashrc"
        profile.write_text("# personal before\n"+profile.read_text()+"# personal after\n")
        managed=base / "managed-bashrc"
        profile.rename(managed)
        profile.symlink_to(managed)
        run(base,env,"--apply")
        assert profile.is_symlink() and "personal before" in managed.read_text() and "personal after" in managed.read_text()
        assert "bloodyShell PATH" not in managed.read_text()
    print("Simple uninstall passed: folder removal, absent/corrupt records, edited runtime and CLI, full cache cleanup, preserved configs/backups, optional settings, scoped shutdown, live shared caches, locks, symlinks and PATH cleanup.")


class TerminalInput(io.StringIO):
    def isatty(self): return True


def optional_checks():
    api=runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    scope=api["uninstall_main"].__globals__
    original_run=subprocess.run
    with tempfile.TemporaryDirectory(prefix="bloodyShell-uninstall-options-") as temporary:
        for answer in ("keep", "delete", "flags", "cancel", "sudo-failure"):
            base=Path(temporary) / answer
            env,target,command=fixture(base)
            settings=base / "config/bloodyShell"
            settings.mkdir()
            (settings / "settings.json").write_text("personal")
            theme=base / "system/themes/bloodyShell"
            theme.mkdir(parents=True)
            (theme / "Main.qml").write_text("theme")
            dropin=base / "system/sddm.conf.d/zz-bloodyShell.conf"
            dropin.parent.mkdir()
            dropin.write_text("theme config")
            shared=base / "system/shared/bloodyShell"
            shared.mkdir(parents=True)
            (shared / "avatar").write_text("shared image")
            other=base / "system/sddm.conf"
            other.write_text("personal login-manager config")
            privileged=[]
            def tools(args,**kwargs):
                if args[0]!="sudo": return original_run(args,**kwargs)
                privileged.append(args)
                if answer=="sudo-failure": raise subprocess.CalledProcessError(1,args)
                if args[1:]==["-v"]: return subprocess.CompletedProcess(args,0)
                assert args[1:4]==["rm","-rf","--"] and set(args[4:])=={str(theme),str(dropin),str(shared)},args
                for name in args[4:]:
                    path=Path(name)
                    if path.is_dir(): shutil.rmtree(path)
                    else: path.unlink()
                return subprocess.CompletedProcess(args,0)
            replies="n\n\n" if answer=="keep" else "yes\ny\n"
            output=io.StringIO()
            args=["uninstall","--apply"] + (["--delete-sddm","--delete-settings"] if answer=="flags" else [])
            stdin=io.StringIO("") if answer=="flags" else TerminalInput(replies)
            with patch.dict(os.environ,env,clear=True), patch.dict(scope,SDDM_THEME=theme,SDDM_CONFIG=dropin,SDDM_STATE=shared), patch.object(sys,"argv",args), patch.object(sys,"stdin",stdin), patch("subprocess.run",side_effect=tools), redirect_stdout(output):
                if answer=="cancel":
                    with patch("builtins.input",side_effect=KeyboardInterrupt):
                        try: api["uninstall_main"]()
                        except KeyboardInterrupt: pass
                        else: raise AssertionError("Cancellation was ignored")
                elif answer=="sudo-failure":
                    try: api["uninstall_main"]()
                    except subprocess.CalledProcessError: pass
                    else: raise AssertionError("Administrator authorization failure was ignored")
                else: api["uninstall_main"]()
            if answer in ("cancel","sudo-failure"):
                assert target.exists() and command.exists() and settings.exists() and theme.exists()
            else:
                if answer=="flags":
                    assert "[y/N]" not in output.getvalue(), "Non-interactive flags prompted for input"
                else:
                    assert "Delete SDDM theme? [y/N]" in output.getvalue() and "Delete shell settings? [y/N]" in output.getvalue()
                assert not target.exists() and not command.exists()
                assert settings.exists()==(answer=="keep") and theme.exists()==(answer=="keep")
                assert shared.exists()==(answer=="keep") and dropin.exists()==(answer=="keep")
                if answer=="keep": assert not privileged
            assert other.read_text()=="personal login-manager config"
    print("Uninstall questions passed: both default to No, explicit deletion removes only shell settings/SDDM files, sudo is conditional, and cancellation/authentication failure preserves the installation.")


if __name__ == "__main__":
    checks()
    optional_checks()
