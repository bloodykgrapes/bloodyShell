#!/usr/bin/env python3

import configparser
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
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
        images = source / "images"
        images.mkdir(parents=True)
        (images / "one.png").write_bytes(b"bundled image")
        (images / "two.jpg").write_bytes(b"second image")
        (images / "three.JFIF").write_bytes(b"jpeg image")
        (images / "readme.txt").write_text("not an image")
        personal = home / "Pictures/Wallpapers"
        personal.mkdir(parents=True)
        (personal / "one.png").write_bytes(b"personal image")
        settings = config / "bloodyShell/settings.json"
        settings.parent.mkdir(parents=True)
        original = dict(configVersion=1, wallpaperDirectory=str(images), wallpaperCurrent=str(images / "one.png"), custom="kept")
        settings.write_text(json.dumps(original))
        with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(base / "state")), patch.dict(scope, ROOT=source, download=lambda *args: json.dumps(dict(tree=[dict(type="blob", path="images/repo.png")]))):
            result = api["import_wallpapers"](images)
            assert result["imported"] == 3
            assert (personal / "three.JFIF").read_bytes() == b"jpeg image"
            assert api["wallpaper_file"](personal / "three.JFIF") == personal / "three.JFIF"
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
            assert [entry["id"] for entry in catalog["entries"]] == ["greeter", "compositor", "dots", "wallpapers"]
            assert next(entry for entry in catalog["entries"] if entry["id"] == "dots")["programs"] == ["fastfetch", "gtk-3.0", "gtk-4.0", "kitty"]
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
            original_inode = (config / "fastfetch").stat().st_ino
            existing_backups = set((base / "state").rglob("*-import-*"))
            (other / "config.jsonc").write_text("would be rolled back")
            def failing_import(folder, name, transaction=None):
                if name == "kitty":
                    raise OSError("fixture import failed")
                return original_import(folder, name, transaction)
            with patch.dict(scope, import_config=failing_import), patch("shutil.move", side_effect=AssertionError("Rollback must use local originals")):
                try:
                    api["import_resource"]("dots")
                except OSError:
                    pass
                else:
                    raise AssertionError("Grouped import failure was ignored")
            assert (config / "fastfetch/config.jsonc").read_text() == before_group, "Grouped import left a partial replacement"
            assert (config / "fastfetch").stat().st_ino == original_inode, "Rollback copied an old backup instead of restoring the original folder"
            assert set((base / "state").rglob("*-import-*")) == existing_backups, "Failed group left backup files"
            assert not list(config.glob(".bloodyShell-*")), "Failed group left staging folders"
            for names in (["fastfetch", "missing"], ["fastfetch", "../bad"], ["fastfetch", "niri"]):
                try:
                    api["import_resource"]("dots", names=names)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Invalid configs list was accepted")
                assert (config / "fastfetch").stat().st_ino == original_inode, "Names must be validated before any config is changed"
            subset = api["import_resource"]("dots", names=["fastfetch", "fastfetch"])
            assert len(subset["imports"]) == 1 and (config / "fastfetch/config.jsonc").read_text() == "would be rolled back"
            for name in ("dots/../bad", "dots/..", "dots/", "unknown", "dots/a/b", "dots/niri", "dots/sddm", "dots/wallpapers"):
                try:
                    api["resource_path"](name)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Invalid import target accepted: " + name)

            installed = base / "installed"
            shutil.copytree(ROOT / "dots/niri", installed / "dots/niri")
            (installed / "dots/config/kitty").mkdir(parents=True)
            (installed / "dots/config/kitty/kitty.conf").write_text("bundled config")
            (installed / "dots/sddm").mkdir()
            (installed / "dots/sddm/Main.qml").write_text("greeter")
            (installed / "scripts/lib").mkdir(parents=True)
            (installed / "scripts/lib/system.sh").write_text(
                'set -e\nroot="$(dirname -- "$0")/../.."\ncp "$root/dots/sddm/Main.qml" "$HOME/imported-greeter"\n')

            wallpaper_archive = base / "wallpapers.tar.gz"
            with tarfile.open(wallpaper_archive, "w:gz") as package:
                member = tarfile.TarInfo("wallpapers-main/images/repo.png")
                contents = b"remote wallpaper"
                member.size = len(contents)
                package.addfile(member, io.BytesIO(contents))
            downloads = []

            def download(url, target=None):
                downloads.append(url)
                assert target and url == f"https://github.com/{api['WALLPAPERS_REPO']}/archive/refs/heads/main.tar.gz", url
                shutil.copyfile(wallpaper_archive, target)

            with patch.dict(scope, ROOT=installed, download=download):
                assert api["programs"]() == ["kitty"]
                bundled = api["import_resource"]("dots/kitty")
                assert (config / "kitty/kitty.conf").read_text() == "bundled config"
                assert (Path(bundled["backup"]) / "kitty.conf").read_text() == "new config"
                api["import_resource"]("compositor")
                assert (installed_niri / "config.kdl").read_bytes() == (installed / "dots/niri/config.kdl").read_bytes()
                api["import_resource"]("greeter")
                assert (home / "imported-greeter").read_text() == "greeter"
                assert not downloads
                api["import_resource"]("wallpapers")
                assert (personal / "repo.png").read_text() == "remote wallpaper"
                assert len(downloads) == 1
                before_images = {path: path.read_bytes() for path in personal.rglob("*") if path.is_file()}
                for name, kind in (("images/../escape.png", tarfile.REGTYPE), ("images/link.png", tarfile.SYMTYPE)):
                    with tarfile.open(wallpaper_archive, "w:gz") as package:
                        member = tarfile.TarInfo("wallpapers-main/" + name)
                        member.type = kind
                        member.linkname = "/tmp/escape"
                        package.addfile(member)
                    try:
                        api["import_resource"]("wallpapers")
                    except ValueError:
                        pass
                    else:
                        raise AssertionError("Unsafe wallpaper archive was accepted")
                    assert before_images == {path: path.read_bytes() for path in personal.rglob("*") if path.is_file()}, "Rejected wallpaper archive changed personal images"
            assert (personal / "one.png").read_bytes() == b"personal image"
    print("Offline bundled imports, import backups, and wallpaper download and archive checks passed.")


def availability_checks():
    api = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
    scope = api["status"].__globals__
    with tempfile.TemporaryDirectory(prefix="bloodyShell-import-source-") as temporary:
        base = Path(temporary)
        source, installed = base / "source folder", base / "installed"
        files = {"dots/config/kitty/kitty.conf": "config",
                 "dots/niri/config.kdl": "compositor", "dots/sddm/Main.qml": "greeter"}
        for name, value in files.items():
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        shutil.copytree(ROOT / "dots/niri", source / "dots/niri", dirs_exist_ok=True)
        for name in api["GREETER_FILES"]:
            (source / "dots/sddm" / name).write_text("greeter fixture")
        (installed / "scripts").mkdir(parents=True)
        (installed / "scripts/bloodyShell").write_text("fixture")
        env = dict(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
                   XDG_BIN_HOME=str(base / "bin"), XDG_RUNTIME_DIR=str(base / "runtime"))
        calls = []
        def remote(url, destination=None):
            calls.append((url, destination))
            assert destination is None and api["WALLPAPERS_REPO"] + "/git/trees/main?recursive=1" in url
            return json.dumps(dict(tree=[dict(type="blob", path="images/video.webm")]))
        with patch.dict(os.environ, env):
            with patch.dict(scope, ROOT=source, download=remote):
                catalog = api["resource_catalog"]()
                assert catalog["error"] == "" and all(catalog["available"].values())
                assert len(calls) == 1 and api["WALLPAPERS_REPO"] in calls[0][0]
                with patch.dict(scope, download=lambda *args: (_ for _ in ()).throw(AssertionError("Local application listing used the network"))):
                    assert api["programs"]() == ["kitty"]
            calls.clear()
            with patch.dict(scope, ROOT=installed, download=remote):
                catalog = api["status"]()
                for name in ("dots/kitty", "compositor", "greeter"):
                    try:
                        api["import_resource"](name)
                    except ValueError as error:
                        assert "Bundled dots folder is missing" in str(error)
                    else:
                        raise AssertionError("An import succeeded without the bundled dots folder")
            entries = {entry["id"]: entry for entry in catalog["entries"]}
            assert len(calls) == 1
            assert "cli" not in entries and entries["wallpapers"]["available"]
            assert not any(entries[name]["available"] for name in ("dots", "greeter", "compositor"))
            assert "Bundled dots folder is missing" in catalog["error"]
            with patch.dict(scope, ROOT=source, download=lambda *args: (_ for _ in ()).throw(RuntimeError("repository unavailable"))):
                unavailable = api["resource_catalog"]()
            assert not unavailable["available"]["wallpapers"] and all(unavailable["available"][name] for name in ("dots", "greeter", "compositor"))
            assert "Wallpapers:" in unavailable["error"], "Wallpaper failure hid independent shell resources"
            for response in (dict(tree=[], truncated=True), dict(tree=[]), dict(tree=[dict(type="blob", mode="120000", path="images/link.png")])):
                with patch.dict(scope, ROOT=source, download=lambda *args: json.dumps(response)):
                    unavailable = api["resource_catalog"]()
                assert not unavailable["available"]["wallpapers"] and unavailable["error"]
    print("Local import catalogs and independent wallpaper availability checks passed.")


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
            assert all(entry["id"] != "cli" for entry in catalog["entries"])
            resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
            def unavailable_catalog():
                raise RuntimeError("Repository unavailable")
            with patch.dict(resources["status"].__globals__, resource_catalog=unavailable_catalog):
                offline = resources["status"]()
            assert offline["error"] == "Repository unavailable" and next(entry for entry in offline["entries"] if entry["id"] == "dots")["programs"] == []
            assert all(not entry["available"] for entry in offline["entries"])
            repeated = management["refresh_command"]()
            assert not repeated["changed"] and not repeated["backups"], "Repeated refresh rewrote an unchanged command"
            command.write_bytes(command.read_bytes() + b"\n# User edit\n")
            edited = command.read_bytes()
            with management["operation_lock"]():
                blocked = subprocess.run(["bash", str(ROOT / "setup"), "cli"], env=env, capture_output=True, text=True, timeout=5)
                assert blocked.returncode != 0 and "in progress" in blocked.stderr.lower(), blocked.stdout + blocked.stderr
                assert command.read_bytes() == edited, "CLI refresh bypassed the operation lock"
            updated = management["refresh_command"]()
            assert updated["changed"] and command.read_bytes() == (ROOT / "scripts/bloodyShell").read_bytes()
            assert any(Path(path).read_bytes() == edited for path in updated["backups"]), "Edited CLI was not backed up"
            command.unlink()
            repaired = management["refresh_command"]()
            assert repaired["changed"] and command.read_bytes() == (ROOT / "scripts/bloodyShell").read_bytes()
    print("CLI refresh passed: checkout source, custom command directory, PATH, backups, unchanged runtime, no tracking records, idempotence, backup of user edits and missing-command repair.")


def clear_checks():
    resources = runpy.run_path(str(ROOT / "scripts/lib/resources.py"))
    management = runpy.run_path(str(ROOT / "scripts/lib/management.py"))
    scope = management["clear_greeter"].__globals__
    with tempfile.TemporaryDirectory(prefix="bloodyShell-clear-resources-") as temporary:
        base = Path(temporary)
        home = base / "home"
        home.mkdir()
        theme, dropin, shared = base / "themes/bloodyShell", base / "sddm.conf.d/zz-bloodyShell.conf", base / "shared/bloodyShell"
        other = base / "sddm.conf.d/personal.conf"
        other.parent.mkdir(parents=True)
        other.write_text("personal login configuration")
        calls = []
        def install_fixture():
            theme.mkdir(parents=True, exist_ok=True)
            (theme / "Main.qml").write_text("theme")
            dropin.write_text("shell login configuration")
            shared.mkdir(parents=True, exist_ok=True)
            (shared / "wallpaper.png").write_text("exported image")
        def sudo(args, **kwargs):
            assert args[:4] == ["sudo", "rm", "-rf", "--"], args
            assert set(args[4:]) == {str(theme), str(dropin), str(shared)}, args
            calls.append(args)
            for name in args[4:]:
                management["remove_path"](Path(name))
            return subprocess.CompletedProcess(args, 0)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / "config"), XDG_STATE_HOME=str(home / "state"), XDG_BIN_HOME=str(home / "bin"))
        with patch.dict(os.environ, env, clear=True), patch.dict(scope, SDDM_THEME=theme, SDDM_CONFIG=dropin, SDDM_STATE=shared):
            install_fixture()
            with patch("runpy.run_path", return_value=management), patch("subprocess.run", side_effect=sudo):
                cleared = resources["clear_resource"]("greeter")
                assert cleared["destination"] == str(theme) and len(cleared["removed"]) == 3
                assert not theme.exists() and not dropin.exists() and not shared.exists()
                assert not resources["clear_resource"]("greeter")["removed"] and len(calls) == 1
            assert other.read_text() == "personal login configuration"
            install_fixture()
            with patch("runpy.run_path", return_value=management), patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, ["sudo"])):
                try:
                    resources["clear_resource"]("greeter")
                except subprocess.CalledProcessError:
                    pass
                else:
                    raise AssertionError("Failed administrator authorization succeeded")
            assert theme.exists() and dropin.exists() and shared.exists()
            for resource in ("cli", "compositor", "dots", "wallpapers", "dots/kitty", "../cli", "unknown"):
                try:
                    resources["clear_resource"](resource)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Unsupported resource was cleared: " + resource)
    print("Resource clear passed: fixed SDDM paths, preserved personal files, authorization failure, idempotence and rejected config/wallpaper clearing; no actual sudo command ran.")


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
        entry=directory / "08-settings.kdl"
        entry.write_text("// User input\n")
        def command(*args,success=True):
            result=subprocess.run([sys.executable,str(ROOT / "scripts/bloodyShell"),*args],env=env,capture_output=True,text=True,timeout=6)
            assert (result.returncode==0)==success,result.stdout+result.stderr
            return result
        command("internal","compositor","config","niri","outputs",'output "HDMI-A-1" { scale 1.0; }')
        before=main.read_bytes()
        before_entry=entry.read_bytes()
        niri.write_text("#!/bin/sh\nexit 1\n")
        command("internal","compositor","config","niri","outputs",'output "HDMI-A-1" { scale 2.0; }',success=False)
        assert main.read_bytes()==before and entry.read_bytes()==before_entry,"Rejected config did not roll back"
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


def cancellation_checks():
    with tempfile.TemporaryDirectory(prefix="bloodyShell-cancellation-") as temporary:
        base = Path(temporary)
        worker, runner = base / "worker.py", base / "runner.py"
        worker.write_text('''import os, subprocess, sys, time
from pathlib import Path
base = Path(sys.argv[1])
code = "import os, signal, sys, time; from pathlib import Path; signal.signal(signal.SIGTERM, signal.SIG_IGN); Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(60)"
subprocess.Popen([sys.executable, "-c", code, str(base / "child")])
(base / "worker").write_text(str(os.getpid()))
while True: time.sleep(1)
''')
        runner.write_text(f'''import runpy, subprocess, sys
files = runpy.run_path({str(ROOT / "scripts/lib/files.py")!r})
with files["operation_signals"]():
    files["run"]([sys.executable, {str(worker)!r}, sys.argv[1]], capture_output=True, timeout=0.5 if len(sys.argv) > 2 else 60)
''')
        for sig in (signal.SIGTERM, signal.SIGHUP, None):
            case = base / (sig.name if sig is not None else "timeout")
            case.mkdir()
            command = [sys.executable, str(runner), str(case)] + (["timeout"] if sig is None else [])
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 4
                while not (case / "child").exists() or not (case / "worker").exists():
                    assert process.poll() is None and time.monotonic() < deadline, "Worker did not start"
                    time.sleep(0.01)
                if sig is not None:
                    process.send_signal(sig)
                output, error = process.communicate(timeout=6)
                assert process.returncode == 128 + sig if sig is not None else "TimeoutExpired" in error, output + error
                for name in ("worker", "child"):
                    stat = Path("/proc", (case / name).read_text(), "stat")
                    assert not stat.exists() or stat.read_text().rsplit(")", 1)[1].split()[0] == "Z", "Cancellation left a worker running"
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=3)
                if (case / "worker").exists():
                    try:
                        os.killpg(int((case / "worker").read_text()), signal.SIGKILL)
                    except ProcessLookupError:
                        pass
    print("Managed workers stop on SIGTERM, terminal hangup and timeout, including children that ignore SIGTERM.")


if __name__ == "__main__":
    checks()
    availability_checks()
    cli_checks()
    clear_checks()
    file_checks()
    backend_checks()
    cancellation_checks()
