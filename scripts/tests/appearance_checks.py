#!/usr/bin/env python3

import configparser
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-appearance-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.update(HOME=str(base / "home"), XDG_DATA_HOME=str(base / "data"), TEST_APPEARANCE_BASE=str(base),
                   QT_PLUGIN_PATH=str(base / "plugins"), QT_QPA_PLATFORMTHEME="", XDG_DATA_DIRS=str(base / "system-data"),
                   XDG_CONFIG_DIRS=str(base / "system-config"), XDG_CURRENT_DESKTOP="niri:GNOME",
                   XDG_DESKTOP_PORTAL_DIR=str(base / "system-data/xdg-desktop-portal/portals"))
        env.pop("WAYLAND_DISPLAY", None)
        for directory in ("home", "data", "plugins/styles", "wallpapers"):
            (base / directory).mkdir(parents=True)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=0,
            wallpaperDirectory=str(base / "wallpapers"), themeStyle=1, shellLanguage="en")))
        for name in ("custom", "duplicate", "proxy", "qt5", "broken"):
            (base / f"plugins/styles/lib{name}.so").touch()
        tools = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
base = Path(os.environ["TEST_APPEARANCE_BASE"])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
if name == "gsettings":
    if args[0] == "get":
        values = {"color-scheme":"prefer-dark", "gtk-theme":"Adwaita", "icon-theme":"FixtureIcons", "cursor-theme":"FixtureCursor", "cursor-size":24, "font-name":"Noto Sans 10"}
        value = values[args[2]]
        print(value if isinstance(value, int) else repr(value))
    else:
        with (base / "gtk-calls").open("a") as stream: stream.write(json.dumps(args) + "\\n")
elif name == "qtpaths6":
    print(base / "plugins")
elif name == "qtplugininfo":
    key = Path(args[-1]).stem
    keys = {"libcustom":["Test Style"], "libduplicate":["Fusion", "Test Style"], "libproxy":["qt6ct-style", "qt5ct-style"], "libqt5":["Qt5Only"], "libqt6ct-style":["qt6ct-style"]}.get(key, [])
    if key == "libbroken": print("invalid json")
    else: print(json.dumps({"IID":"org.qt-project.Qt.QStyleFactoryInterface", "version":(5 if key=="libqt5" else 6)<<16, "MetaData":{"Keys":keys}}))
elif name == "fc-list": print("Noto Sans")
elif name in ("dbus-update-activation-environment", "systemctl"):
    with (base / "activation-calls").open("a") as stream: stream.write(json.dumps([name] + args) + "\\n")
elif name == "qt6ct": sys.exit(1)
else: raise AssertionError(name)
'''
        for name in ("gsettings", "qtpaths6", "qtplugininfo", "qt6ct", "fc-list", "dbus-update-activation-environment", "systemctl"):
            path = base / "bin" / name
            path.write_text(tools)
            path.chmod(0o700)
        helper = [str(base / "scripts/runtime/appearance")]
        config = base / "config/qt6ct/qt6ct.conf"
        config.parent.mkdir()
        initial = '[Appearance]\nstyle=fusion\ncustom_palette=true\ncolor_scheme_path=/keep/palette.conf\nicon_theme=KeepIcons\n\n[Fonts]\ngeneral="Keep Font,12,-1"\n\n[Troubleshooting]\nignored_applications=keep-app\n'
        config.write_text(initial)
        backing = base / "qt-config-target.conf"
        config.replace(backing)
        config.symlink_to(backing)
        portal_key = "org.freedesktop.impl.portal.FileChooser"
        portal_template = '[preferred]\ndefault=gnome;gtk;\norg.freedesktop.impl.portal.ScreenCast=gnome\norg.freedesktop.impl.portal.Secret=gnome-keyring\n\n[keep]\nkey=value\n'
        portal_metadata = base / "system-data/xdg-desktop-portal/portals"
        portal_metadata.mkdir(parents=True)
        for name, interface in (("gtk", portal_key + ";org.freedesktop.impl.portal.Print;org.freedesktop.impl.portal.Settings"), ("kde", portal_key + ";org.freedesktop.impl.portal.Print"), ("secret", "org.freedesktop.impl.portal.Secret"), ("screen", "org.freedesktop.impl.portal.ScreenCast")):
            (portal_metadata / (name + ".portal")).write_text(f"[portal]\nDBusName=org.example.{name}\nInterfaces={interface};\n")
        global_portal = base / "system-config/xdg-desktop-portal/niri-portals.conf"
        global_portal.parent.mkdir(parents=True)
        global_portal.write_text(portal_template)
        result = subprocess.run(helper + ["list"], env=env, text=True, capture_output=True, check=True)
        styles = [line.split("\t", 1)[1] for line in result.stdout.splitlines() if line.startswith("qt\t")]
        assert styles == ["Fusion", "Test Style", "Windows"], styles
        def portal_status():
            result = subprocess.run(helper + ["read"], env=env, text=True, capture_output=True, check=True)
            return json.loads(next(line.split("=", 1)[1] for line in result.stdout.splitlines() if line.startswith("portal-data=")))

        status = portal_status()
        assert [backend["id"] for backend in status["backends"]] == ["gtk", "kde", "screen", "secret"], status
        assert [backend["id"] for backend in status["backends"] if "FileChooser" in backend["interfaces"]] == ["gtk", "kde"]
        assert "Secret" in status["interfaces"] and "ScreenCast" in status["interfaces"]
        denied = subprocess.run(helper + ["set", "portal:FileChooser=screen"], env=env, text=True, capture_output=True)
        assert denied.returncode != 0 and not (base / "config/xdg-desktop-portal").exists()
        assert config.read_text() == initial, "An invalid portal changed Qt preferences"
        subprocess.run(helper + ["set", "portal:FileChooser=kde"], env=env, check=True)
        portal_config = base / "config/xdg-desktop-portal/niri-portals.conf"
        portal_values = configparser.ConfigParser(interpolation=None)
        portal_values.read(portal_config)
        assert portal_values["preferred"][portal_key] == "kde"
        assert portal_values["preferred"]["org.freedesktop.impl.portal.ScreenCast"] == "gnome"
        assert portal_values["preferred"]["org.freedesktop.impl.portal.Secret"] == "gnome-keyring"
        assert portal_values["keep"]["key"] == "value" and global_portal.read_text() == portal_template
        assert "style=fusion" in config.read_text() and "standard_dialogs=xdgdesktopportal" in config.read_text()
        assert not (base / "activation-calls").exists(), "Portal choice changed the Qt session backend"
        generic_portal = portal_config.with_name("portals.conf")
        generic_portal.write_text("[preferred]\n" + portal_key + "=gtk\n")
        assert portal_status()["preferences"]["FileChooser"] == "kde", "Desktop-specific portal configuration lost precedence"
        portal_backing = base / "portal-config-target.conf"
        portal_config.replace(portal_backing)
        portal_config.symlink_to(portal_backing)
        subprocess.run(helper + ["set", "portal:FileChooser="], env=env, check=True)
        portal_values.clear()
        portal_values.read(portal_config)
        assert not portal_values.has_option("preferred", portal_key)
        assert portal_values["preferred"]["default"] == "gnome;gtk;" and portal_values["keep"]["key"] == "value"
        assert portal_config.is_symlink() and generic_portal.read_text().endswith("=gtk\n")
        portal_backing.write_text("[preferred\nbroken")
        denied = subprocess.run(helper + ["set", "portal:FileChooser=gtk"], env=env, text=True, capture_output=True)
        assert denied.returncode != 0 and portal_backing.read_text() == "[preferred\nbroken"
        portal_backing.write_text(portal_template)
        before = portal_backing.read_bytes()
        denied = subprocess.run(helper + ["set", "portal:Print=kde", "portal:ScreenCast=gtk"], env=env, text=True, capture_output=True)
        assert denied.returncode != 0 and portal_backing.read_bytes() == before, "An unsupported provider partially applied a portal batch"
        subprocess.run(helper + ["set", "portal:default=kde", "portal:ScreenCast=screen", "portal:Secret=secret", "portal:Print=kde"], env=env, check=True)
        status = portal_status()
        assert status["preferences"]["default"] == "kde;gnome;gtk", "Changing the primary backend discarded fallback order"
        assert status["preferences"]["ScreenCast"] == "screen" and status["preferences"]["Secret"] == "secret"
        assert status["preferences"]["Print"] == "kde" and "FileChooser" not in status["preferences"]
        subprocess.run(helper + ["set", "portal:default=", "portal:ScreenCast=", "portal:Secret=", "portal:Print="], env=env, check=True)
        assert portal_status()["preferences"] == {}, "Default reset retained portal overrides"
        future = portal_metadata / "future.portal"
        future.write_text("[portal]\nDBusName=org.example.Future\nInterfaces=org.freedesktop.impl.portal.NewFeature;\n")
        assert "NewFeature" in portal_status()["interfaces"], "New installed portal functions are ignored"
        future.unlink()
        portal_backing.write_text(portal_template)
        config.write_text(initial)
        result = subprocess.run(helper + ["read"], env=env, text=True, capture_output=True, check=True)
        assert "qt-theme=fusion\n" in result.stdout and "qt-active=no\n" in result.stdout
        denied = subprocess.run(helper + ["set", "qt-theme=Not installed $(touch unexpected)"], env=env, text=True, capture_output=True)
        assert denied.returncode != 0 and config.read_text() == initial
        assert not (base / "config/environment.d").exists()
        subprocess.run(helper + ["set", "qt-theme=test style"], env=env, check=True)
        values = configparser.ConfigParser()
        values.read(config)
        assert values["Appearance"]["style"] == "Test Style"
        assert values["Appearance"]["color_scheme_path"] == "/keep/palette.conf" and values["Appearance"]["custom_palette"] == "true"
        assert values["Fonts"]["general"] == '"Keep Font,12,-1"' and values["Troubleshooting"]["ignored_applications"] == "keep-app"
        assert config.is_symlink(), "Updating a Qt preference replaced the user's config symlink"
        qt_env = base / "config/environment.d/90-bloodyShell-qt.conf"
        assert qt_env.read_text() == "QT_QPA_PLATFORMTHEME=qt6ct\n"
        assert json.loads((base / "activation-calls").read_text().splitlines()[0]) == ["dbus-update-activation-environment", "--systemd", "QT_QPA_PLATFORMTHEME=qt6ct"]
        assert not (base / "gtk-calls").exists(), "Changing Qt also changed GTK settings"
        result = subprocess.run(helper + ["read"], env=dict(env, QT_QPA_PLATFORMTHEME="qt5ct"), text=True, capture_output=True, check=True)
        assert "qt-configured=yes\n" in result.stdout and "qt-active=yes\n" in result.stdout
        qt_env.unlink()
        subprocess.run(helper + ["set", "qt-theme=Fusion"], env=dict(env, QT_QPA_PLATFORMTHEME="qt5ct"), check=True)
        assert not qt_env.exists(), "An existing Qt backend alias was overridden"
        config.write_text(initial)

        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot
{
    id: tests
    property int phase: 0
    property var dialogSelector: null
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name)
    {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    Window { id: window; visible: true; width: 820; height: 740; PageAppearance { id: page; anchors.fill: parent } }
    Timer
    {
        interval: 80; running: true; repeat: true
        onTriggered:
        {
            if (!Config.initialized || !ServiceAppearance.loaded || ServiceAppearance.qtThemes.length < 3) return;
            try
            {
                const row = tests.find(page, "qtThemeRow"), selector = tests.find(page, "qtThemeSelector"), enable = tests.find(page, "enableQtTheme");
                const portal = tests.find(page, "portalSettings"), picker = tests.find(page, "portalSelector-FileChooser");
                const installed = tests.find(page, "installedPortals");
                if (tests.phase === 0)
                {
                    tests.check(selector.currentIndex >= 0 && selector.current === "Fusion", "Qt style keys are case-sensitive in the UI");
                    tests.check(enable.visible && selector.enabled, "Qt theming cannot be enabled");
                    const siblings = row.parent.children, previous = siblings[siblings.indexOf(row)-1];
                    tests.check(previous.label === Tr.tr("settings.appearance.gtkTheme"), "Qt theme is not immediately after GTK");
                    tests.check(portal && siblings[siblings.indexOf(row)+1] === portal && picker.options.length === 3, "Portal selector is misplaced or offers unsupported providers");
                    tests.check(row.description === "" && portal.description === "", "Qt or portal hints remain visible");
                    tests.check(installed.description === "GTK, KDE, screen, secret", "Installed portal list is incomplete");
                    tests.check(!tests.find(page, "portalSelector-default") && !tests.find(page, "portalFunctions"), "Advanced portal controls remain in settings");
                    tests.dialogSelector = picker;
                    ServiceAppearance.qt6ct = false;
                    tests.check(!selector.enabled && !enable.visible && picker.enabled, "Portal selection depends on qt6ct");
                    picker.selected("kde");
                    const pending = ServiceAppearance.pending;
                    ServiceAppearance.setQtTheme("Windows");
                    tests.check(ServiceAppearance.pending === pending, "Missing qt6ct still accepted a write");
                    ServiceAppearance.qt6ct = true;
                    enable.clicked();
                    tests.check(!enable.visible && ServiceAppearance.qtConfigured, "Qt integration did not enable");
                    selector.selected("Test Style");
                    tests.phase++;
                }
                else if (tests.phase === 1 && !ServiceAppearance.busy)
                {
                    tests.find(page, "refreshPortals").clicked();
                    tests.phase++;
                }
                else if (tests.phase === 2 && ServiceAppearance.qtTheme === "Test Style" && ServiceAppearance.qtConfigured)
                {
                    tests.check(ServiceAppearance.error === "", "Qt style write failed");
                    tests.check(ServiceAppearance.portalValue("FileChooser") === "kde" && picker.current === "kde", "Saved file picker portal was not restored");
                    tests.check(ServiceAppearance.portalValue("default") === "gnome;gtk" && ServiceAppearance.portalValue("ScreenCast") === "gnome" && ServiceAppearance.portalValue("Secret") === "gnome-keyring", "Dialog choice changed unrelated portal preferences");
                    tests.check(picker === tests.dialogSelector, "Saving preferences rebuilds the dialog selector");
                    ServiceAppearance.qtActive = true;
                    tests.check(row.description === "" && !enable.visible, "Active Qt session shows a hint or enable button");
                    ServiceAppearance.qtTheme = "RemovedStyle";
                    tests.check(selector.options[0].label === Tr.tr("settings.appearance.notInstalled").arg("RemovedStyle"), "Unavailable current Qt styles disappeared");
                    Config.set("shellLanguage", "ru");
                    window.width = 640;
                    tests.phase++;
                }
                else if (tests.phase === 3 && row.label === "Тема Qt")
                {
                    tests.check(selector.width <= row.width - 36 && portal.parent === row.parent, "Portal layout or translation is broken");
                    tests.check(portal.label === "Открытие и сохранение файлов", "Portal function names are not translated");
                    ServiceAppearance.setQtTheme("MissingStyle");
                    tests.phase++;
                }
                else if (tests.phase === 4 && !ServiceAppearance.busy && ServiceAppearance.qtTheme === "Test Style" && ServiceAppearance.error !== "")
                {
                    picker.selected("");
                    tests.phase++;
                }
                else if (tests.phase === 5 && !ServiceAppearance.busy)
                {
                    ServiceAppearance.refresh(false);
                    tests.phase++;
                }
                else if (tests.phase === 6 && ServiceAppearance.portalValue("FileChooser") === "")
                {
                    tests.check(picker.current === "" && picker.options[0].value === "", "Default portal cannot be restored");
                    ServiceAppearance.portalPreferences = {FileChooser:"gtk;kde"};
                    tests.check(picker.options.some(option => option.value === "gtk;kde" && option.label === "GTK → KDE"), "Existing portal fallback order was lost");
                    ServiceAppearance.portalPreferences = {FileChooser:"removed"};
                    tests.check(picker.options.some(option => option.value === "removed" && option.label === Tr.tr("settings.portals.unavailable").arg("removed")), "Unavailable current portal disappeared");
                    console.log("APPEARANCE_PASSED compact portal settings, installed inventory, capability filtering, independent themes, config preservation, error recovery, and translations");
                    Qt.quit();
                }
            }
            catch (error) { console.error("APPEARANCE_FAILED", error); Qt.quit(); }
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("APPEARANCE_FAILED timeout", tests.phase, Config.initialized, ServiceAppearance.loaded, JSON.stringify(ServiceAppearance.qtThemes), ServiceAppearance.qtTheme, ServiceAppearance.qtConfigured, ServiceAppearance.error); Qt.quit(); } }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=12)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "APPEARANCE_PASSED" in output, output
        assert not re.search(r"APPEARANCE_FAILED|TypeError|ReferenceError|Binding loop|Cannot assign|Unable to assign", output), output
        values.read(config)
        assert values["Appearance"]["style"] == "Test Style" and qt_env.exists()
        assert values["Appearance"]["standard_dialogs"] == "xdgdesktopportal"
        portal_values.clear()
        portal_values.read(portal_config)
        assert not portal_values.has_option("preferred", portal_key)
        assert portal_values["preferred"]["org.freedesktop.impl.portal.ScreenCast"] == "gnome"
        assert portal_values["preferred"]["org.freedesktop.impl.portal.Secret"] == "gnome-keyring"
        assert portal_values["preferred"]["default"] == "gnome;gtk;"
    print("Qt themes, all portal backends and functions, config preservation, isolated activation, and Appearance UI passed without changing the desktop session.")


if __name__ == "__main__":
    checks()
