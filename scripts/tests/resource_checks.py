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
            compositor = source / "dots/niri"
            compositor.mkdir()
            (compositor / "config.kdl").write_text("compositor must stay separate")
            other = source / "dots/fastfetch"
            other.mkdir()
            (other / "config.jsonc").write_text("new fastfetch")
            for gtk in ("gtk-3.0", "gtk-4.0"):
                (source / "dots" / gtk).mkdir()
                (source / "dots" / gtk / "settings.ini").write_text("[Settings]\ngtk-font-name=Fixture Font 11\n")
            (source / "dots/sddm").mkdir()
            (source / "dots/sddm/Main.qml").write_text("login theme stays separate")
            catalog = api["status"]()
            assert [entry["id"] for entry in catalog["entries"]] == ["compositor", "dots", "greeter", "wallpapers"]
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
            for name in ("dots/../bad", "dots/..", "dots/", "unknown", "dots/a/b"):
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
                for name, text in (("dots/sddm/Main.qml", "greeter"), ("dots/kitty/kitty.conf", "remote config"), ("dots/wallpapers/repo.png", "remote wallpaper"), ("outside/unused", "unused")):
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
    print("Wallpaper imports, collision handling, repeated imports, unchanged settings, dotfile backups, remote imports and archive checks passed without changing user files.")


if __name__ == "__main__":
    checks()
