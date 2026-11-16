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
        (install / "scripts").mkdir()
        (install / "scripts/bloodyShell").write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
base = Path(os.environ["TEST_UPDATE_DIR"])
with (base / "attempts.jsonl").open("a") as log:
    assert sys.argv[1:3]==['internal','update']
    log.write(json.dumps(dict(args=sys.argv[2:], status=os.environ["BLOODYSHELL_STATUS"])) + "\\n")
status = Path(os.environ["BLOODYSHELL_STATUS"])
status.write_text("step 1/3 Fixture installation\\n")
time.sleep(0.3)
status.write_text("failed fixture failure\\n")
''')
        (install / "scripts/bloodyShell").chmod(0o700)
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
                    tests.check(ServiceUpdate.currentRelease.version === "1.0.0" && !ServiceUpdate.currentNotes, "Unfetched current version displayed invented release notes");
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
                   XDG_RUNTIME_DIR=str(base / "runtime"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                   TEST_UPDATE_DIR=str(base), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "UPDATES_PASSED" in output, "Automatic update regression failed"
        assert not re.search(r"UPDATES_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type", output), "Update service QML error"
        assert len((base / "attempts.jsonl").read_text().splitlines()) == 4
    print("Automatic update checks passed with fake release responses and an isolated installer; no shell files were replaced.")


def current_release_checks():
    helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
    with tempfile.TemporaryDirectory(prefix="bloodyshell-current-release-") as temporary:
        base = Path(temporary)
        for name in ("core", "services", "runtime", "cache", "bin", "checkout"):
            (base / name).mkdir(mode=0o700)
        state = base / "new-state"
        version = base / "checkout/version"
        version.write_text("1.0.0")
        (base / "control.json").write_text("{}")
        (base / "requests.jsonl").write_text("")
        shutil.copy2(ROOT / "modules/services/ServiceUpdate.qml", base / "services/ServiceUpdate.qml")
        helpers["stub"](base, "core", "Config", 'property bool initialized:true; property bool updateAuto:true; property bool updateBeta:false; property int updateCheck:0')
        helpers["stub"](base, "core", "Paths", "\n".join(f"property string {key}: {json.dumps(str(value))}" for key, value in dict(
            shellDir=base / "checkout", installDir=base / "installed", stateDir=state, fixtureDir=base).items()))
        helpers["stub"](base, "core", "Tr", 'function tr(key) { return key + " %1"; }')
        helpers["stub"](base, "core", "Registry", 'property var settings: []')
        helpers["stub"](base, "core", "OverlayState", 'property int settingsPage:0; function show(name) {}')
        helpers["module"](base, "core")
        helpers["module"](base, "services")
        curl = base / "bin/curl"
        curl.write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
base=Path(os.environ['TEST_CURRENT_DIR'])
data=json.loads((base/'control.json').read_text())
with (base/'requests.jsonl').open('a') as output: output.write(json.dumps(sys.argv[-1])+'\\n')
time.sleep(data.get('delay',0.02))
if data.get('fail'): sys.exit(7)
if data.get('plain_only') and '/tags/v' in sys.argv[-1]:
    sys.stdout.write('{}\\n404'); sys.exit(0)
sys.stdout.write(data.get('raw',json.dumps(data.get('release',{})))+'\\n'+str(data.get('http',200)))
''')
        curl.chmod(0o700)
        (base / "shell.qml").write_text(r'''import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "core"
import "services"
ShellRoot {
    id: tests
    property int stage:parseInt(Quickshell.env("TEST_CURRENT_STAGE"),10)
    function check(ok,message) {if(!ok)throw new Error(message);}
    function until(test,message) {for(let i=0;i<200&&!test();i++)events.wait(10);check(test(),message);}
    function response(data) {control.setText(JSON.stringify(data));control.waitForJob();}
    function entry(version,body) {return {tag_name:"v"+version,name:version,body:body,draft:false,prerelease:version.includes("-"),html_url:"https://github.com/fixture/releases/tag/v"+version,published_at:"2026-11-15T00:00:00Z"};}
    function requests() {log.reload();log.waitForJob();return log.text().trim().split("\n").filter(Boolean).map(line=>JSON.parse(line));}
    function fetch(data) {response(data);ServiceUpdate.loadCurrentRelease(true);until(()=>!ServiceUpdate.currentNotesLoading,"Request did not finish");}
    FileView {id:control;path:Paths.fixtureDir+"/control.json";blockLoading:true;blockWrites:true}
    FileView {id:log;path:Paths.fixtureDir+"/requests.jsonl";blockLoading:true}
    FileView {id:saved;path:Paths.stateDir+"/current-release.json";printErrors:false;blockLoading:true}
    TestCase {id:events;when:false;optional:true}
    Timer {interval:100;running:true;repeat:true;onTriggered:{
        if(!ServiceUpdate.versionReady||!ServiceUpdate.currentCacheReady)return;
        stop();
        try {
            if(tests.stage===0) {
                check(!ServiceUpdate.currentNotes && tests.requests().length===0,"Closed changelog fetched notes or displayed unverified content");
                tests.fetch({release:tests.entry("1.0.0","Published current notes.")});
                check(ServiceUpdate.currentNotes.notes==="Published current notes." && !ServiceUpdate.checked && !ServiceUpdate.installing,"Fetching changelog checked for updates or installed one");
                check(tests.requests()[0]==="https://api.github.com/repos/bloodykgrapes/bloodyShell/releases/tags/v1.0.0","Changelog did not request the exact version tag");
                saved.reload();saved.waitForJob();
                check(JSON.parse(saved.text()).release.notes==="Published current notes.","Successful notes were not cached");
                const before=tests.requests().length;
                ServiceUpdate.loadCurrentRelease();events.wait(50);
                check(tests.requests().length===before,"Reopening a fetched changelog made a duplicate request");
                tests.fetch({release:Object.assign(tests.entry("1.0.0","Plain tag notes."),{tag_name:"1.0.0"}),plain_only:true});
                check(ServiceUpdate.currentNotes.tag==="1.0.0" && tests.requests().slice(-2).map(url=>url.split("/tags/")[1]).join(",")==="v1.0.0,1.0.0","Plain version tag did not work after prefixed tag returned 404");
                tests.fetch({release:Object.assign(tests.entry("1.0.0","Plain tag notes."),{tag_name:"1.0.0"})});
                check(tests.requests().slice(-1)[0].endsWith("/tags/1.0.0"),"Known plain tag was not reused");
                tests.response({http:404});ServiceUpdate.version="1.1.0";
                tests.until(()=>ServiceUpdate.currentNotesMissing&&!ServiceUpdate.currentNotesLoading,"Unpublished tag did not report missing notes");
                check(!ServiceUpdate.currentNotes,"Unpublished version displayed another version's cached notes");
                tests.fetch({http:200,raw:"invalid JSON"});
                check(ServiceUpdate.currentNotesError.includes("invalidResponse")&&!ServiceUpdate.currentNotes,"Malformed notes were accepted");
                tests.fetch({http:429});check(ServiceUpdate.currentNotesError.includes("rateLimited"),"Rate limit was not reported");
                tests.fetch({release:tests.entry("9.9.9","Wrong version")});
                check(!ServiceUpdate.currentNotes && ServiceUpdate.currentNotesError.includes("invalidResponse"),"A mismatched tag was accepted");
                tests.fetch({release:Object.assign(tests.entry("1.1.0","Private draft"),{draft:true})});
                check(!ServiceUpdate.currentNotes,"Draft release notes became visible");
                tests.fetch({release:tests.entry("1.1.0","")});
                check(ServiceUpdate.currentNotes && ServiceUpdate.currentNotes.notes==="","Empty published notes were treated as an unpublished release");
                const count=tests.requests().length;
                tests.response({release:tests.entry("1.2.0","Stale response"),delay:0.2});ServiceUpdate.version="1.2.0";
                tests.until(()=>tests.requests().length>count,"Delayed request did not start");
                tests.response({release:tests.entry("1.3.0","Latest current notes.")});ServiceUpdate.version="1.3.0";
                tests.until(()=>ServiceUpdate.currentNotes&&ServiceUpdate.currentNotes.version==="1.3.0"&&!ServiceUpdate.currentNotesLoading,"Changing version kept a stale response or lost the new request");
                check(ServiceUpdate.currentNotes.notes==="Latest current notes.","A stale response replaced current notes");
                saved.reload();saved.waitForJob();check(JSON.parse(saved.text()).release.version==="1.3.0","Wrong version persisted in cache");
            } else if(tests.stage===1) {
                check(ServiceUpdate.currentNotes && ServiceUpdate.currentNotes.notes==="Latest current notes.","Cached notes did not survive shell restart");
                tests.fetch({fail:true});
                check(ServiceUpdate.currentNotes.notes==="Latest current notes." && ServiceUpdate.currentNotesError.includes("connectionFailed"),"Offline refresh discarded the cached changelog");
            } else check(!ServiceUpdate.currentNotes,"Corrupt or foreign-repository cache became visible");
            console.log("CURRENT_RELEASE_PASSED",tests.stage);Qt.quit();
        }catch(error){console.error("CURRENT_RELEASE_FAILED",error);Qt.quit();}
    }}
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"),
                   XDG_CACHE_HOME=str(base / "cache"), TEST_CURRENT_DIR=str(base), PATH=str(base / "bin") + os.pathsep + os.environ["PATH"])
        env.pop("WAYLAND_DISPLAY", None)
        for stage in (0, 1, 2, 2):
            if stage == 1:
                version.write_text("1.3.0")
            elif stage == 2:
                cache = state / "current-release.json"
                if cache.exists() and cache.read_text() == "invalid JSON":
                    cache.write_text(json.dumps(dict(repo="another/repo", release=dict(tag="v1.3.0", version="1.3.0", name="1.3.0", notes="Foreign notes", url="", date="", prerelease=False))))
                else:
                    cache.write_text("invalid JSON")
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, TEST_CURRENT_STAGE=str(stage)), capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            print(output)
            assert result.returncode == 0 and "CURRENT_RELEASE_PASSED" in output, output
            assert not re.search(r"CURRENT_RELEASE_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign", output), output
    print("Current release fetch, exact tags, request deduplication, unavailable/draft/malformed responses, version races, persistent cache, offline restart and invalid-cache recovery passed without checking for updates.")


if __name__ == "__main__":
    checks()
    current_release_checks()
