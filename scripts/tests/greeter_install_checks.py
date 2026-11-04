#!/usr/bin/env python3

import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="bloodyShell-greeter-install-") as temporary:
    base = Path(temporary)
    share = base / "share"
    state = base / "state"
    config = base / "greetd.toml"
    pam = base / "pam"
    share.mkdir()
    (share / "old").write_text("previous greeter")
    config.write_text('[default_session]\ncommand = "agreety"\n')
    pam.write_text("auth include system-local-login\nsession include system-local-login\n")
    source = (ROOT / "setup").read_text()
    source = source[:source.rfind('\nmain "$@"')]
    lines = source.splitlines()
    overrides = {"PACKAGE": ROOT, "GREETER_SHELL": share, "GREETER_STATE": state, "GREETD_CONF": config, "GREETD_PAM": pam}
    for index, line in enumerate(lines):
        for key, value in overrides.items():
            if line.startswith("readonly " + key + "="):
                lines[index] = "readonly " + key + "=" + shlex.quote(str(value))
    source = "\n".join(lines)
    source += '''
interactive() { return 0; }
greetd() { :; }
cage() { :; }
qs() { :; }
getent() { return 0; }
systemctl()
{
    if [[ "${TEST_SWITCH:-}" == 1 ]]; then
        [[ "$1" != is-enabled ]] || return 1
        [[ "$1" != show ]] || { echo gdm.service; return 0; }
    fi
    return 0
}
ask() { return 0; }
display_scale() { echo 1; }
sudo()
{
    case "$1" in
        -v) return 0 ;;
        chown) return 0 ;;
        systemctl)
            printf '%s\n' "$*" >> "$TEST_SERVICE_LOG"
            if [[ "${TEST_FAIL_ENABLE:-}" == 1 && "$*" == "systemctl enable greetd" ]]; then return 1; fi
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
    env = dict(os.environ, XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"))
    result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True, timeout=12)
    print(result.stdout + result.stderr)
    assert result.returncode == 0
    parsed = tomllib.loads(config.read_text())
    assert parsed["default_session"]["user"] == "greeter"
    assert str(share / "shell.qml") in parsed["default_session"]["command"]
    assert "XDG_CACHE_HOME=" + str(state / "cache") in parsed["default_session"]["command"]
    assert (share / "Widgets.qml").is_file()
    assert list(base.glob("share.bak-*/old"))
    assert list(base.glob("greetd.toml.bak-*"))
    assert json.loads((state / "settings.json").read_text())["animationLevel"] == 1
    log = base / "services.log"
    env.update(TEST_SWITCH="1", TEST_SERVICE_LOG=str(log))
    result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True, timeout=12)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "systemctl disable gdm.service" in log.read_text() and "systemctl enable greetd" in log.read_text()
    log.write_text("")
    env["TEST_FAIL_ENABLE"] = "1"
    result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True, timeout=12)
    assert result.returncode != 0 and log.read_text().splitlines()[-1] == "systemctl enable gdm.service"
    print("Greeter install, backups, display-manager switching/rollback, and export passed without changing system files.")
