#!/usr/bin/env python3

import configparser
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="bloodyShell-sddm-install-") as temporary:
    base = Path(temporary)
    share, state, config = base / "theme", base / "state", base / "sddm.conf"
    system_config = base / "system.conf"
    system_config.write_text("# Keep this comment\n[General]\nDisplayServer=x11\n[Theme]\nCurrent=plasma\n[Users]\nMinimumUid=1000\n")
    share.mkdir()
    (share / "old").write_text("previous theme")
    config.write_text("[Theme]\nCurrent=previous\n")
    source = (ROOT / "setup").read_text()
    source = source[:source.rfind('\nmain "$@"')]
    lines = source.splitlines()
    overrides = {"PACKAGE": ROOT, "SDDM_THEME": share, "GREETER_STATE": state, "SDDM_CONF": config, "SDDM_SYSTEM_CONF": system_config}
    for index, line in enumerate(lines):
        for key, value in overrides.items():
            if line.startswith("readonly " + key + "="):
                lines[index] = "readonly " + key + "=" + shlex.quote(str(value))
    source = "\n".join(lines) + '''
interactive() { return 0; }
sddm() { :; }
sddm-greeter-qt6() { :; }
niri() { [[ "${TEST_INVALID_NIRI:-}" != 1 ]]; }
getent() { [[ "$2" == sddm ]]; }
systemctl()
{
    [[ "$1" != is-enabled ]] || { [[ "${TEST_SWITCH:-}" != 1 ]]; return; }
    [[ "$1" != show ]] || { if [[ "${TEST_SWITCH:-}" == 1 ]]; then echo gdm.service; else echo sddm.service; fi; return; }
    return 0
}
ask() { [[ "${TEST_DECLINE:-}" != 1 ]]; }
sudo()
{
    case "$1" in
        -v) return 0 ;;
        chown) return 0 ;;
        systemctl)
            printf '%s\n' "$*" >> "$TEST_SERVICE_LOG"
            if [[ "${TEST_FAIL_ENABLE:-}" == 1 && "$*" == "systemctl enable sddm.service" ]]; then return 1; fi
            return 0
            ;;
        install)
            shift
            local args=()
            while [[ $# -gt 0 ]]; do
                case "$1" in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac
            done
            command install "${args[@]}"
            ;;
        *) command "$@" ;;
    esac
}
apply_greeter
'''
    script = base / "test-setup"
    script.write_text(source)
    log = base / "services.log"
    env = dict(os.environ, XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "private-state"), XDG_CACHE_HOME=str(base / "cache"), TEST_SERVICE_LOG=str(log))

    def run(**options):
        result = subprocess.run(["bash", str(script)], env=dict(env, **options), capture_output=True, text=True, timeout=12)
        print(result.stdout + result.stderr)
        return result

    assert run().returncode == 0
    parsed = configparser.ConfigParser(interpolation=None)
    parsed.read(config)
    assert parsed["Theme"]["Current"] == "bloodyShell" and parsed["General"]["DisplayServer"] == "wayland"
    assert str(share / "niri.kdl") in parsed["Wayland"]["CompositorCommand"]
    assert (share / "Main.qml").is_file() and (share / "Widgets.qml").is_file()
    assert (share / "keyboard/Keyboard.qml").is_file() and (share / "keyboard/Key.qml").is_file()
    assert (share / "native/Engine.qml").is_file() and (share / "native/plugin/libvirtualkeyboard.so").is_file()
    installed_theme = configparser.ConfigParser(interpolation=None)
    installed_theme.read(share / "theme.conf")
    assert installed_theme["General"]["keyboardSource"] == "keyboard/Keyboard.qml"
    assert not (share / "sddm.conf").exists() and not (share / "session-data").exists()
    assert (share / "theme.conf.user").resolve() == state / "theme.conf"
    assert not (share / "Main.qml").stat().st_mode & 0o022
    assert list(base.glob("theme.bak-*/old")) and list(base.glob("sddm.conf.bak-*"))
    appearance = configparser.ConfigParser(interpolation=None)
    appearance.read(state / "theme.conf")
    assert appearance["General"]["animationLevel"] == "1"
    assert "Current=" not in system_config.read_text() and "DisplayServer=" not in system_config.read_text()
    assert "MinimumUid=1000" in system_config.read_text() and "# Keep this comment" in system_config.read_text()
    assert not log.exists(), "Already enabled SDDM was restarted or re-enabled"
    assert run(TEST_SWITCH="1").returncode == 0
    assert log.read_text().splitlines() == ["systemctl disable gdm.service", "systemctl enable sddm.service"]
    log.write_text("")
    old_theme = (share / "Main.qml").read_bytes()
    config.write_text("[Theme]\nCurrent=preserve-on-failure\n")
    system_config.write_text("[General]\nDisplayServer=x11\n[Users]\nMinimumUid=1200\n")
    before_system = system_config.read_bytes()
    assert run(TEST_SWITCH="1", TEST_FAIL_ENABLE="1").returncode != 0
    assert log.read_text().splitlines()[-1] == "systemctl enable gdm.service"
    assert (share / "Main.qml").read_bytes() == old_theme and "preserve-on-failure" in config.read_text()
    assert system_config.read_bytes() == before_system
    log.write_text("")
    assert run(TEST_SWITCH="1", TEST_DECLINE="1").returncode == 0
    assert not log.read_text(), "Declining the login-manager switch changed a service"
    original = config.read_bytes()
    assert run(TEST_INVALID_NIRI="1").returncode != 0 and config.read_bytes() == original
    assert not any(word in log.read_text() for word in (" start ", " stop ", " restart ", "--now"))
    print("SDDM install, Wayland/niri configuration, theme permissions, backups, service choice, validation and rollback passed without system changes.")
