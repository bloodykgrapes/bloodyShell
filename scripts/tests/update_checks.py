#!/usr/bin/env python3

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
    helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyshell-updates-") as temporary:
        base = Path(temporary)
        for name in ("core", "services", "runtime", "cache", "bin", "state", "checkout"):
            (base / name).mkdir(mode=0o700)
        install = base / "installed shell '$(fixture)'"
        install.mkdir()
        (install / "version").write_text("1.0.0\n")
        (base / "checkout/version").write_text("1.0.0\n")
        (base / "control.json").write_text("{}")
        for name in ("attempts.jsonl", "checks.jsonl"):
            (base / name).write_text("")
        shutil.copy2(ROOT / "modules/services/ServiceUpdate.qml", base / "services/ServiceUpdate.qml")
        source = (base / "services/ServiceUpdate.qml").read_text()
        source = source.replace("interval: 15000", "interval: 80").replace("interval: 10 * 60 * 1000", "interval: 100")
        (base / "services/ServiceUpdate.qml").write_text(source)
        helpers["stub"](base, "core", "Config", '''
    property bool initialized: true
    property bool updateAuto: true
    property bool updateBeta: false
    property int updateCheck: 0
''')
        helpers["stub"](base, "core", "Paths", "\n".join(
            f"property string {name}: {json.dumps(str(value))}" for name, value in dict(
                shellDir=install, installDir=install, stateDir=base / "state", fixtureDir=base).items()))
        helpers["stub"](base, "core", "Tr", 'function tr(key) { return key }')
        helpers["stub"](base, "core", "Registry", 'property var settings: []')
        helpers["stub"](base, "core", "OverlayState", 'property int settingsPage: 0; function show(name) {}')
        helpers["module"](base, "core")
        helpers["module"](base, "services")
        (base / "bin/curl").write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
base = Path(os.environ["TEST_UPDATE_DIR"])
with (base / "checks.jsonl").open("a") as log:
    log.write("1\\n")
control = json.loads((base / "control.json").read_text())
time.sleep(0.02)
sys.stdout.write(control.get("raw", json.dumps(control.get("releases", []))) + "\\n" + str(control.get("http", 200)))
''')
        (base / "bin/curl").chmod(0o700)
        (install / "setup").write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
base = Path(os.environ["TEST_UPDATE_DIR"])
with (base / "attempts.jsonl").open("a") as log:
    log.write(json.dumps(dict(args=sys.argv[1:], status=os.environ["BLOODYSHELL_STATUS"])) + "\\n")
status = Path(os.environ["BLOODYSHELL_STATUS"])
status.write_text("step 1/3 Fixture installation\\n")
time.sleep(0.3)
status.write_text("failed fixture failure\\n")
''')
        (install / "setup").chmod(0o700)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"

ShellRoot
{
    id: tests
    property var releases: [
        {tag_name:"v9.0.0", draft:true, prerelease:false},
        {tag_name:"v3.0.0-beta.1", draft:false, prerelease:true},
        {tag_name:"v2.0.0", draft:false, prerelease:false},
        {tag_name:"v1.0.0", draft:false, prerelease:false}
    ]
    property int stage: 0
    property double since: Date.now()
    property double previousCheck: 0
    property int beforeChecks: 0
    function check(ok, message) { if (!ok) throw new Error(message) }
    function next() { stage++; since = Date.now() }
    function attempts() { attemptLog.reload(); attemptLog.waitForJob(); return attemptLog.text().trim().split("\\n").filter(Boolean).map(line=>JSON.parse(line)); }
    function checks() { checkLog.reload(); checkLog.waitForJob(); return checkLog.text().trim().split("\\n").filter(Boolean).length; }
    function response(data) { control.waitForJob(); control.setText(JSON.stringify(data)); }
    FileView { id: control; path: Paths.fixtureDir + "/control.json"; blockLoading: true; blockWrites: true }
    FileView { id: attemptLog; path: Paths.fixtureDir + "/attempts.jsonl"; blockLoading: true }
    FileView { id: checkLog; path: Paths.fixtureDir + "/checks.jsonl"; blockLoading: true }
    Component.onCompleted: { void ServiceUpdate.version; response({releases:releases}); }
    Timer
    {
        interval: 50; repeat: true; running: true
        onTriggered:
        {
            try
            {
                const count = tests.attempts().length;
                if (tests.stage === 0 && ServiceUpdate.versionReady && Date.now() - tests.since > 150)
                {
                    tests.check(tests.checks() === 0 && count === 0, "Disabled checks started an automatic update");
                    Config.updateAuto = false; Config.updateCheck = 1; tests.next();
                }
                else if (tests.stage === 1 && ServiceUpdate.checked && !ServiceUpdate.busy)
                {
                    tests.check(count === 0 && ServiceUpdate.versionLatest === "2.0.0", "Auto-off installed a release or stable filtering failed");
                    Config.updateCheck = 0; Config.initialized = false; Config.updateAuto = true;
                    ServiceUpdate.autoUpdate();
                    tests.check(tests.attempts().length === 0, "Update started before settings loaded");
                    ServiceUpdate.versionReady = false; Config.initialized = true; tests.next();
                }
                else if (tests.stage === 2 && Date.now() - tests.since > 100)
                {
                    tests.check(count === 0, "Update started before the installed version loaded");
                    ServiceUpdate.versionReady = true; ServiceUpdate.autoUpdate(); tests.next();
                }
                else if (tests.stage === 3 && count === 1 && ServiceUpdate.installing)
                {
                    tests.check(JSON.stringify(tests.attempts()[0].args) === '["update","--tag","v2.0.0"]', "Automatic update did not target the selected stable release");
                    tests.beforeChecks = tests.checks();
                    ServiceUpdate.autoUpdate(); ServiceUpdate.update(); ServiceUpdate.check();
                    tests.next();
                }
                else if (tests.stage === 4 && ServiceUpdate.installFailed && !ServiceUpdate.busy)
                {
                    tests.check(count === 1 && tests.checks() === tests.beforeChecks, "Busy updater started concurrent work: installs=" + count + " checks=" + tests.checks() + " before=" + tests.beforeChecks);
                    ServiceUpdate.autoUpdate(); ServiceUpdate.autoUpdate();
                    Config.updateAuto = false; Config.updateAuto = true; tests.next();
                }
                else if (tests.stage === 5 && Date.now() - tests.since > 150)
                {
                    tests.check(count === 1, "A failed install retried without another successful check");
                    tests.previousCheck = ServiceUpdate.lastChecked;
                    Config.updateCheck = 2;
                    ServiceUpdate.lastChecked = Date.now() - ServiceUpdate.checkInterval - 1;
                    tests.next();
                }
                else if (tests.stage === 6 && count === 2 && ServiceUpdate.installFailed && !ServiceUpdate.busy)
                {
                    tests.check(ServiceUpdate.lastChecked > tests.previousCheck, "Scheduled check did not refresh the release");
                    Config.updateCheck = 0; tests.response({raw:"invalid json"}); ServiceUpdate.check(); tests.next();
                }
                else if (tests.stage === 7 && !ServiceUpdate.checking && ServiceUpdate.error === "service.update.invalidResponse")
                {
                    ServiceUpdate.autoUpdate(); tests.check(count === 2, "Malformed response started an update");
                    tests.response({http:403}); ServiceUpdate.check(); tests.next();
                }
                else if (tests.stage === 8 && !ServiceUpdate.checking && ServiceUpdate.error === "service.update.rateLimited")
                {
                    ServiceUpdate.autoUpdate(); tests.check(count === 2, "HTTP error started an update");
                    tests.response({releases:[{tag_name:"v1.0.0",draft:false,prerelease:false}]});
                    ServiceUpdate.check(); tests.next();
                }
                else if (tests.stage === 9 && !ServiceUpdate.busy && ServiceUpdate.error === "")
                {
                    tests.check(!ServiceUpdate.availableUpdate && count === 2, "Current version was installed again");
                    tests.response({releases:tests.releases}); Config.updateBeta = true; tests.next();
                }
                else if (tests.stage === 10 && count === 3 && ServiceUpdate.installFailed && !ServiceUpdate.busy)
                {
                    tests.check(tests.attempts()[2].args[2] === "v3.0.0-beta.1", "Beta channel was not respected");
                    Config.updateAuto = false;
                    tests.response({releases:[{tag_name:"v4.0.0",draft:false,prerelease:false}]});
                    ServiceUpdate.check(); tests.next();
                }
                else if (tests.stage === 11 && !ServiceUpdate.busy && ServiceUpdate.versionLatest === "4.0.0")
                {
                    tests.check(count === 3, "Auto-off installed a newly checked version");
                    ServiceUpdate.update(); tests.next();
                }
                else if (tests.stage === 12 && count === 4 && ServiceUpdate.installFailed && !ServiceUpdate.busy)
                {
                    tests.check(tests.attempts()[3].args[2] === "v4.0.0", "Manual retry stopped working");
                    tests.beforeChecks = tests.checks();
                    Paths.shellDir = Paths.fixtureDir + "/checkout";
                    Config.updateAuto = true; Config.updateCheck = 1;
                    ServiceUpdate.check(); ServiceUpdate.update(); ServiceUpdate.autoUpdate(); tests.next();
                }
                else if (tests.stage === 13 && Date.now() - tests.since > 180)
                {
                    tests.check(!ServiceUpdate.installed && count === 4 && tests.checks() === tests.beforeChecks, "Development copy checked or installed an update");
                    console.log("UPDATES_PASSED scheduling, auto opt-in, version readiness, stable/beta filtering, failures, retry and development protection");
                    Qt.quit();
                }
            }
            catch (error) { console.error("UPDATES_FAILED", tests.stage, error); Qt.quit() }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("UPDATES_FAILED timeout", tests.stage); Qt.quit() } }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"),
                   TEST_UPDATE_DIR=str(base), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "UPDATES_PASSED" in output, "Automatic update regression failed"
        assert not re.search(r"UPDATES_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), "Update service QML error"
        assert len((base / "attempts.jsonl").read_text().splitlines()) == 4
    print("Automatic update checks passed with fake release responses and an isolated installer; no shell files were replaced.")


if __name__ == "__main__":
    checks()
