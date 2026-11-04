#!/usr/bin/env python3

import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="bloodyShell-programs-") as temporary:
    base = Path(temporary)
    source = (ROOT / "setup").read_text().rsplit('main "$@"', 1)[0]
    script = base / "check"
    script.write_text(source + '''
interactive() { [[ "$SCENARIO" != noninteractive ]]; }
distro_family() { echo arch; }
application_installed()
{
    if [[ "$SCENARIO" == installed ]]; then
        case "$1" in firefox|mpv|imv|kate) return 0 ;; esac
    fi
    return 1
}
query_available() { shift; AVAILABLE=" $* "; [[ "$SCENARIO" != unavailable ]] || AVAILABLE=" "; }
choose()
{
    echo "$1" >> "$TEST_CHOICES"
    CHOICE=1
    if [[ "$SCENARIO" == cancel ]]; then CHOICE=0; fi
    if [[ "$SCENARIO" == select || "$SCENARIO" == decline ]] && [[ "$1" == "Media player"* ]]; then CHOICE=2; fi
}
ask() { [[ "$SCENARIO" != decline ]]; }
install_packages() { printf '%s\\n' "$@" >> "$TEST_INSTALL"; }
install_applications
''')
    for scenario in ("none", "installed", "select", "decline", "unavailable", "cancel", "noninteractive"):
        log, choices = base / "install", base / "choices"
        log.write_text("")
        choices.write_text("")
        env = dict(os.environ, SCENARIO=scenario, TEST_INSTALL=str(log), TEST_CHOICES=str(choices),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"))
        result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True, timeout=5)
        assert result.returncode == 0, result.stdout + result.stderr
        assert log.read_text() == ("arch\nmpv\n" if scenario == "select" else ""), scenario
        if scenario in ("installed", "unavailable", "noninteractive"):
            assert not choices.read_text(), scenario

    binary = base / "bin"
    binary.mkdir()
    gum = binary / "gum"
    gum.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
args=sys.argv[1:]
Path(os.environ["TEST_GUM"]).write_text(json.dumps(args))
options=args[args.index("--")+1:]
if os.environ.get("TEST_EMPTY")!="1": print(options[0])
''')
    gum.chmod(0o700)
    script.write_text(source + '''
use_gum() { return 0; }
choose_many "Packages" --none "First|First description" "Second|Second description"
[[ "${#SELECTED[@]}" == "$TEST_COUNT" ]]
if [[ "$TEST_COUNT" == 1 ]]; then [[ "${SELECTED[0]}" == First ]]; fi
''')
    for empty in (False, True):
        env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"], TEST_GUM=str(base / "gum.json"),
                   TEST_EMPTY="1" if empty else "0", TEST_COUNT="0" if empty else "1")
        result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True, timeout=5)
        assert result.returncode == 0, result.stdout + result.stderr
        args = json.loads((base / "gum.json").read_text())
        assert args[args.index("--selected") + 1] == ""
        assert args[args.index("--selected-prefix") + 1] == "[✓] "
        assert args[args.index("--unselected-prefix") + 1] == "[ ] "
        assert "--ordered" in args
print("Optional programs, None/cancel/decline, existing apps, and gum multiselect checks passed without package changes.")
