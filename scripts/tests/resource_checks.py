#!/usr/bin/env python3

import io
import json
import os
from pathlib import Path
import runpy
import shutil
import tarfile
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def checks():
    api = runpy.run_path(str(ROOT / "scripts/runtime/resources"))
    scope = api["import_resource"].__globals__
    with tempfile.TemporaryDirectory(prefix="bloodyshell-resources-") as temporary:
        base = Path(temporary)
        home = base / "home"
        config = base / "config"
        source = base / "source"
        images = source / "assets/wallpapers"
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
        with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config)), patch.dict(scope, ROOT=source):
            result = api["import_wallpapers"](images)
            data = json.loads(settings.read_text())
            assert result["imported"] == 2
            assert (personal / "one.png").read_bytes() == b"personal image"
            assert data["wallpaperDirectory"] == str(personal)
            assert Path(data["wallpaperCurrent"]).read_bytes() == b"bundled image"
            assert Path(data["wallpaperCurrent"]).name == "one-bloodyShell.png"
            assert data["configVersion"] == 1 and data["custom"] == "kept"
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
            assert api["import_wallpapers"](images)["settings"] == {}
            assert settings.read_bytes() == unchanged

            dots = source / "dots/kitty"
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
            for name in ("dots/../bad", "dots/..", "dots/", "unknown", "dots/a/b"):
                try:
                    api["resource_path"](name)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Invalid import target accepted: " + name)

            installed = base / "installed"
            installed.mkdir()
            (installed / "setup").write_text('test "$1" = greetd && test -f "$BLOODYSHELL_RESOURCE_DIR/greeter/shell.qml"\nprintf "%s" "$BLOODYSHELL_RESOURCE_DIR" > "$HOME/greeter-source"\n')
            archive = base / "repository.tar.gz"
            with tarfile.open(archive, "w:gz") as package:
                for name, text in (("greeter/shell.qml", "greeter"), ("dots/kitty/kitty.conf", "remote config"), ("assets/wallpapers/repo.png", "remote wallpaper"), ("outside/unused", "unused")):
                    member = tarfile.TarInfo("repository-main/" + name)
                    contents = text.encode()
                    member.size = len(contents)
                    member.mode = 0o644
                    package.addfile(member, io.BytesIO(contents))

            def download(url, target=None):
                if target:
                    shutil.copyfile(archive, target)
                else:
                    return json.dumps([dict(type="dir", name="kitty"), dict(type="dir", name="niri"), dict(type="file", name="ignored")])

            with patch.dict(scope, ROOT=installed, download=download):
                assert api["programs"]() == ["kitty", "niri"]
                remote = api["import_resource"]("dots/kitty")
                assert (config / "kitty/kitty.conf").read_text() == "remote config"
                assert (Path(remote["backup"]) / "kitty.conf").read_text() == "new config"
                api["import_resource"]("wallpapers")
                assert (personal / "repo.png").read_text() == "remote wallpaper"
                api["import_resource"]("greeter")
                assert (home / "greeter-source").read_text()
                assert not Path((home / "greeter-source").read_text()).exists(), "Temporary repository files were not cleaned up"
                assert not list(base.rglob("unused"))
                for unsafe, kind in (("repository-main/dots/kitty/../../escape", tarfile.REGTYPE), ("repository-main/dots/kitty/link", tarfile.SYMTYPE)):
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
    print("Wallpaper relocation, collision handling, repeated imports, custom paths, dotfile backups, remote imports and archive checks passed without changing user files.")


if __name__ == "__main__":
    checks()
