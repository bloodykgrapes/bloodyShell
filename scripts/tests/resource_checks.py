#!/usr/bin/env python3

import configparser
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tarfile
import tempfile
import time
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
    scope = api["import_resource"].__globals__
    with tempfile.TemporaryDirectory(prefix="bloodyshell-resources-") as temporary:
        base = Path(temporary)
        home = base / "home"
        config = base / "config"
        source = base / "source"
        images = source / "dots/wallpapers"
        images.mkdir(parents=True)
        (images / "one.png").write_bytes(b"bundled image")
        (images / "two.jpg").write_bytes(b"second image")
        (images / "readme.txt").write_text("not an image")
        personal = home / "Pictures/Wallpapers"
        personal.mkdir(parents=True)
        (personal / "one.png").write_bytes(b"personal image")
        settings = config / "bloodyShell/settings.json"
        settings.parent.mkdir(parents=True)
        original = dict(configVersion=1, wallpaperDirectory=str(images), wallpaperCurrent=str(images / "one.png"), custom="kept")
        settings.write_text(json.dumps(original))
        with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(base / "state")), patch.dict(scope, ROOT=source):
            result = api["import_wallpapers"](images)
            assert result["imported"] == 2
            assert (personal / "one.png").read_bytes() == b"personal image"
            assert (personal / "one-bloodyShell.png").read_bytes() == b"bundled image"
            assert json.loads(settings.read_text()) == original, "Import must preserve shell settings"
            before = {str(path): (path.read_bytes(), path.stat().st_mtime_ns) for path in personal.iterdir()}
            saved = settings.stat().st_mtime_ns
            assert api["import_wallpapers"](images)["imported"] == 0
            assert before == {str(path): (path.read_bytes(), path.stat().st_mtime_ns) for path in personal.iterdir()}
            assert settings.stat().st_mtime_ns == saved
            custom = base / "custom pictures"
            custom.mkdir()
            (custom / "mine.png").write_bytes(b"custom")
            settings.write_text(json.dumps(dict(original, wallpaperDirectory=str(custom), wallpaperCurrent=str(custom / "mine.png"))))
            unchanged = settings.read_bytes()
            assert api["import_wallpapers"](images)["imported"] == 0
            assert settings.read_bytes() == unchanged

            dots = source / "dots/config/kitty"
            dots.mkdir(parents=True)
            (dots / "kitty.conf").write_text("new config")
            destination = config / "kitty"
            destination.mkdir()
            (destination / "kitty.conf").write_text("personal config")
            outcome = api["import_resource"]("dots/kitty")
            assert (destination / "kitty.conf").read_text() == "new config"
            assert (Path(outcome["backup"]) / "kitty.conf").read_text() == "personal config"
            shutil.rmtree(destination)
            destination.symlink_to(base / "missing", target_is_directory=True)
            outcome = api["import_resource"]("dots/kitty")
            assert Path(outcome["backup"]).is_symlink() and not destination.is_symlink()
            compositor = source / "dots/niri"
            compositor.mkdir()
            (compositor / "config.kdl").write_text("compositor must stay separate")
            other = source / "dots/config/fastfetch"
            other.mkdir()
            (other / "config.jsonc").write_text("new fastfetch")
            for gtk in ("gtk-3.0", "gtk-4.0"):
                (source / "dots/config" / gtk).mkdir()
                (source / "dots/config" / gtk / "settings.ini").write_text("[Settings]\ngtk-font-name=Fixture Font 11\n")
            (source / "dots/sddm").mkdir()
            (source / "dots/sddm/Main.qml").write_text("login theme stays separate")
            catalog = api["status"]()
            assert [entry["id"] for entry in catalog["entries"]] == ["compositor", "dots", "greeter", "wallpapers", "cli"]
            assert catalog["entries"][1]["programs"] == ["fastfetch", "gtk-3.0", "gtk-4.0", "kitty"]
            installed_niri = config / "niri"
            installed_niri.mkdir()
            (installed_niri / "config.kdl").write_text("personal compositor")
            grouped = api["import_resource"]("dots")
            assert len(grouped["imports"]) == 4
            for gtk in ("gtk-3.0", "gtk-4.0"):
                assert "Fixture Font 11" in (config / gtk / "settings.ini").read_text()
            assert not (config / "sddm").exists() and not (config / "wallpapers").exists()
            assert (config / "fastfetch/config.jsonc").read_text() == "new fastfetch"
            assert (installed_niri / "config.kdl").read_text() == "personal compositor", "Dots imported compositor settings"
            original_import = api["import_config"]
            before_group = (config / "fastfetch/config.jsonc").read_text()
            (other / "config.jsonc").write_text("would be rolled back")
            def failing_import(folder, name):
                if name == "kitty":
                    raise OSError("fixture import failed")
                return original_import(folder, name)
            with patch.dict(scope, import_config=failing_import):
                try:
                    api["import_resource"]("dots")
                except OSError:
                    pass
                else:
                    raise AssertionError("Grouped import failure was ignored")
            assert (config / "fastfetch/config.jsonc").read_text() == before_group, "Grouped import left a partial replacement"
            for name in ("dots/../bad", "dots/..", "dots/", "unknown", "dots/a/b", "dots/niri", "dots/sddm", "dots/wallpapers"):
                try:
                    api["resource_path"](name)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Invalid import target accepted: " + name)

            installed = base / "installed"
            installed.mkdir()
            (installed / "setup").write_text('test "$1" = sddm && test -f "$BLOODYSHELL_RESOURCE_DIR/dots/sddm/Main.qml"\nprintf "%s" "$BLOODYSHELL_RESOURCE_DIR" > "$HOME/greeter-source"\n')
            archive = base / "repository.tar.gz"
            with tarfile.open(archive, "w:gz") as package:
                for name, text in (("dots/sddm/Main.qml", "greeter"), ("dots/config/kitty/kitty.conf", "remote config"), ("dots/wallpapers/repo.png", "remote wallpaper"), ("outside/unused", "unused")):
                    member = tarfile.TarInfo("repository-main/" + name)
                    contents = text.encode()
                    member.size = len(contents)
                    member.mode = 0o644
                    package.addfile(member, io.BytesIO(contents))

            def download(url, target=None):
                if target:
                    shutil.copyfile(archive, target)
                else:
                    assert "/contents/dots/config?ref=" in url, url
                    return json.dumps([dict(type="dir", name="kitty"), dict(type="file", name="ignored")])

            with patch.dict(scope, ROOT=installed, download=download):
                assert api["programs"]() == ["kitty"]
                remote = api["import_resource"]("dots/kitty")
                assert (config / "kitty/kitty.conf").read_text() == "remote config"
                assert (Path(remote["backup"]) / "kitty.conf").read_text() == "new config"
                api["import_resource"]("wallpapers")
                assert (personal / "repo.png").read_text() == "remote wallpaper"
                api["import_resource"]("greeter")
                assert (home / "greeter-source").read_text()
                assert not Path((home / "greeter-source").read_text()).exists(), "Temporary repository files were not cleaned up"
                assert not list(base.rglob("unused"))
                for unsafe, kind in (("repository-main/dots/config/kitty/../../escape", tarfile.REGTYPE), ("repository-main/dots/config/kitty/link", tarfile.SYMTYPE)):
                    with tarfile.open(archive, "w:gz") as package:
                        member = tarfile.TarInfo(unsafe)
                        member.type = kind
                        member.linkname = "/tmp/escape"
                        package.addfile(member)
                    try:
                        api["import_resource"]("dots/kitty")
                    except ValueError:
                        pass
                    else:
                        raise AssertionError("Unsafe archive was accepted")
            assert (personal / "one.png").read_bytes() == b"personal image"
    print("Wallpaper imports, collision handling, repeated imports, unchanged settings, dotfile backups, remote imports and archive checks passed without changing user files.")


def cli_checks():
    management = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-cli-refresh-") as temporary:
        base = Path(temporary)
        home = base / "user home"
        home.mkdir()
        config, state, binary = home / "config", home / "state", home / "custom bin"
        runtime = config / "quickshell/bloodyShell"
        (runtime / "scripts").mkdir(parents=True)
        (runtime / "shell.qml").write_text("installed shell")
        source = runtime / "scripts/bloodyShell"
        source.write_bytes((ROOT / "scripts/bloodyShell").read_bytes() + b"\n# Previous bundled command\n")
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(state), SHELL="/bin/bash")
        env["XDG_BIN_HOME"] = str(binary)
        env.pop("BLOODYSHELL_COMMAND", None)
        with patch.dict(os.environ, env, clear=True):
            management["install_command"](source, binary, base / "backup")
            command = binary / "bloodyShell"
            tracking = state / "bloodyShell"
            tracking.mkdir(parents=True, exist_ok=True)
            for name in ("install.json", "changes.json", "changes.lock"):
                (tracking / name).write_text("obsolete tracking data")
            result = subprocess.run(["bash", str(ROOT / "setup"), "cli"], env=env, capture_output=True, text=True, timeout=10)
            assert result.returncode == 0 and "Command refreshed" in result.stdout, result.stdout + result.stderr
            assert command.read_bytes() == (ROOT / "scripts/bloodyShell").read_bytes()
            assert source.read_bytes().endswith(b"# Previous bundled command\n"), "CLI refresh changed the runtime"
            assert not any((tracking / name).exists() for name in ("install.json", "changes.json", "changes.lock")), "Refresh retained tracking records"
            assert list((state / "bloodyShell/backups").glob("cli-*/launcher/command")), "Replaced command was not backed up"
            assert (home / ".bashrc").read_text().count("# >>> bloodyShell PATH >>>") == 1
            catalog = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))["status"]()
            assert catalog["entries"][-1]["id"] == "cli" and catalog["entries"][-1]["destination"] == str(command)
            resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
            def unavailable_programs():
                raise RuntimeError("Repository unavailable")
            with patch.dict(resources["status"].__globals__, programs=unavailable_programs):
                offline = resources["status"]()
            assert offline["error"] == "Repository unavailable" and offline["entries"][1]["programs"] == []
            assert offline["entries"][-1]["id"] == "cli", "Repository failure hid local CLI refresh"
            repeated = management["refresh_command"]()
            assert not repeated["changed"] and not repeated["backups"], "Repeated refresh rewrote an unchanged command"
            command.write_bytes(command.read_bytes() + b"\n# User edit\n")
            edited = command.read_bytes()
            updated = management["refresh_command"]()
            assert updated["changed"] and command.read_bytes() == (ROOT / "scripts/bloodyShell").read_bytes()
            assert any(Path(path).read_bytes() == edited for path in updated["backups"]), "Edited CLI was not backed up"
            command.unlink()
            repaired = management["refresh_command"]()
            assert repaired["changed"] and command.read_bytes() == (ROOT / "scripts/bloodyShell").read_bytes()
    print("CLI refresh passed: checkout source, custom command directory, PATH, backups, unchanged runtime, no tracking records, idempotence, backup of user edits and missing-command repair.")


def file_checks():
    files=runpy.run_path(str(ROOT / "scripts/lib/files.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyShell-atomic-files-") as temporary:
        base=Path(temporary)
        source,destination=base / "source",base / "destination"
        assert files["atomic_write"](source,b"x"*70000+b"a",0o600)
        assert source.stat().st_mode & 0o777 == 0o600
        modified=source.stat().st_mtime_ns
        assert not files["atomic_write"](source,source.read_bytes(),0o600) and source.stat().st_mtime_ns==modified
        assert files["atomic_copy"](source,destination)
        assert destination.stat().st_mode & 0o777 == 0o644
        modified=destination.stat().st_mtime_ns
        assert not files["atomic_copy"](source,destination) and destination.stat().st_mtime_ns==modified
        saved=source.stat()
        source.write_bytes(b"x"*70000+b"b")
        os.utime(source,ns=(saved.st_atime_ns,saved.st_mtime_ns))
        assert files["atomic_copy"](source,destination) and destination.read_bytes().endswith(b"b"),"Preserved timestamps hid changed content"
        source.write_bytes(b"replacement")
        before=destination.read_bytes()
        def failed_copy(input_file,output):
            output.write(b"incomplete")
            raise OSError("Interrupted copy")
        with patch("shutil.copyfileobj",side_effect=failed_copy):
            try: files["atomic_copy"](source,destination)
            except OSError: pass
            else: raise AssertionError("Interrupted copy succeeded")
        assert destination.read_bytes()==before and not list(base.glob(".*")),"Interrupted write changed the destination or left temporary files"
        outside=base / "outside"
        outside.write_bytes(b"personal")
        destination.unlink()
        destination.symlink_to(outside)
        assert files["atomic_copy"](source,destination) and not destination.is_symlink()
        assert outside.read_bytes()==b"personal" and destination.read_bytes()==b"replacement"
    print("Atomic file checks passed: unchanged writes/copies, mode preservation, changed content with stable timestamps, interrupted copies, temporary cleanup and symlink replacement.")


def backend_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-backend-files-") as temporary:
        base=Path(temporary)
        for name in ("home","config","state","runtime","bin"):
            (base / name).mkdir(mode=0o700)
        env=dict(os.environ,HOME=str(base / "home"),XDG_CONFIG_HOME=str(base / "config"),XDG_STATE_HOME=str(base / "state"),
                 XDG_RUNTIME_DIR=str(base / "runtime"),PATH=str(base / "bin")+os.pathsep+os.environ["PATH"])
        niri=base / "bin/niri"
        niri.write_text("#!/bin/sh\nexit 0\n")
        niri.chmod(0o700)
        directory=base / "config/niri/bloodyShell"
        directory.mkdir(parents=True)
        main=directory.parent / "config.kdl"
        main.write_text("// User config\n")
        entry=directory / "06-user-input.kdl"
        entry.write_text("// User input\n")
        def command(*args,success=True):
            result=subprocess.run([sys.executable,str(ROOT / "scripts/bloodyShell"),*args],env=env,capture_output=True,text=True,timeout=6)
            assert (result.returncode==0)==success,result.stdout+result.stderr
            return result
        command("internal","compositor","config","niri","write",entry.name,"// Updated input")
        before=main.read_bytes()
        niri.write_text("#!/bin/sh\nexit 1\n")
        command("internal","compositor","config","niri","write","07-user-output.kdl","invalid",success=False)
        assert main.read_bytes()==before and not (directory / "07-user-output.kdl").exists(),"Rejected config did not roll back"
        assert not list((base / "state").iterdir()),"Backend edit created persistent tracking"
        for removed in ("footprint","cleanup","restore"):
            assert "Unknown command" in command(removed,success=False).stderr
        cava=base / "bin/cava"
        cava.write_text("#!/usr/bin/env python3\nimport os,sys,time\nfrom pathlib import Path\npid=Path(os.environ['TEST_CAVA_PID'])\npid.with_suffix('.config').write_text(Path(sys.argv[2]).read_text())\npid.write_text(str(os.getpid()))\nwhile True: time.sleep(1)\n")
        cava.chmod(0o700)
        env["TEST_CAVA_PID"]=str(base / "cava.pid")
        process=subprocess.Popen([sys.executable,str(ROOT / "scripts/bloodyShell"),"internal","visualizer","28"],env=env)
        try:
            deadline=time.monotonic()+4
            while not (base / "cava.pid").exists():
                assert process.poll() is None and time.monotonic()<deadline
                time.sleep(0.02)
            child_pid=int((base / "cava.pid").read_text())
            visualizer=configparser.ConfigParser()
            visualizer.read(base / "cava.config")
            assert visualizer.getint("general","autosens")==0, "Cava automatic gain clips peaks before the shell can scale them"
            assert visualizer.getint("general","sensitivity")==1 and visualizer.getint("output","ascii_max_range")==65535, "Audio capture lost its peak headroom or precision"
            process.terminate()
            process.wait(timeout=5)
            assert not list((base / "runtime/bloodyShell").glob("visualizer-*"))
            assert not Path("/proc",str(child_pid)).exists(),"Visualizer child survived shutdown"
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    print("Backend file checks passed: validated writes, immediate rollback, no tracking records, removed tracking commands, private temporary files and child-process cleanup.")


if __name__ == "__main__":
    checks()
    cli_checks()
    file_checks()
    backend_checks()
