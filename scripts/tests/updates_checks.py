#!/usr/bin/env python3
"""Exercise imports, package lists and confirmations without changing user files."""

import json
import os
import re
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def service_load_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-service-load-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        for name in ("modules/services/ServiceLock.qml", "modules/ui/overlay/altTab/AltTabKeyboard.qml"):
            shutil.copy2(ROOT / name, base / name)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"), QML_DISABLE_DISK_CACHE="1")
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "modules/core"
import "modules/services"
ShellRoot {
    Component.onCompleted: Qt.callLater(() => {
        console.log("SERVICES_LOADED", ServiceDependencies.packages.length, ServiceRegion.firstDayOfWeek);
        Qt.quit();
    })
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "SERVICES_LOADED" in output, output
        assert not any(error in output for error in ("Failed to load configuration", "is not a type", "ReferenceError", "TypeError")), output
        print("Full service graph loaded without service stubs or QML disk cache.")


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-import-dialog-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env["XDG_STATE_HOME"] = str(base / "state")
        terminal = base / "bin/import-terminal"
        terminal.write_text("#!/usr/bin/env python3\nimport os, sys\nos.execvp(sys.argv[1], sys.argv[1:])\n")
        terminal.chmod(0o700)
        env["TEST_IMPORT_TERMINAL"] = str(terminal)
        (base / "scripts/lib/resources.py").write_text('''import json, os, sys
from pathlib import Path
def resources_main():
    if sys.argv[1:] == ["status"]:
        print(json.dumps(dict(terminal=[], entries=[
            dict(id="greeter",available=True,kind="greeter",destination="/fixture/greeter",installed=True),
            dict(id="compositor",available=True,kind="compositor",destination="/fixture/niri"),
            dict(id="dots",available=True,kind="dots",programs=["fastfetch","kitty"],destination="/fixture/config"),
            dict(id="wallpapers",available=True,kind="wallpapers",destination="/fixture/wallpapers")
        ])))
    elif sys.argv[1:] == ["import", "wallpapers"]:
        print(json.dumps(dict(settings={})))
    elif sys.argv[1:] == ["clear", "greeter", "--wait"]:
        with (Path(os.environ["TEST_SCREENSHOT_BASE"]) / "clear-calls").open("a") as output:
            print(json.dumps(sys.argv[1:]), file=output)
        print(json.dumps(dict(removed=[])))
    else:
        raise AssertionError("Unexpected import: " + repr(sys.argv))
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/common"
import "modules/services"
import "modules/ui/overlay/settings/pages"
import "modules/ui/overlay/settings/components"

ShellRoot {
    id: tests
    property int phase: 0
    property bool availabilityChecked: false
    property var originalEntries: []
    property int ticks: 0
    property int backgroundClicks: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) { return events.findChild(item, name); }
    function click(item) { events.mouseClick(item, item.width/2, item.height/2, Qt.LeftButton, Qt.NoModifier, 0); }
    Window {
        id: window; visible: true; width: 1000; height: 680
        Item {
            anchors.fill: parent
            readonly property alias popupLayer: popupLayer
            Loader { id: pageLoader; anchors.fill: parent; sourceComponent: PageUpdates {} }
            Button { id: background; x: 2; y: 2; text: "Background"; onClicked: tests.backgroundClicks++; }
            Item { id: popupLayer; anchors.fill: parent; z: 1000 }
        }
        TestCase { id: events; name: "ImportConfirmation"; when: false; optional: true }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (++tests.ticks > 120) { console.error("IMPORT_DIALOG_FAILED timeout", tests.phase); Qt.quit(); return; }
            try {
                const page = pageLoader.item;
                const imports = page ? tests.find(page, "resourceImports") : null;
                const dialog = page ? tests.find(page, "resourceConfirmation") : null;
                if (tests.phase === 0) {
                    if (!Config.initialized || !page || !page.active) return;
                    imports.expanded = true; tests.phase++;
                } else if (tests.phase === 1) {
                    if (ServiceResources.busy || ServiceResources.entries.length !== 4) return;
                    if (!tests.availabilityChecked) {
                        tests.originalEntries = ServiceResources.entries;
                        ServiceResources.entries = ServiceResources.entries.map(entry => Object.assign({}, entry, {available:false}));
                        tests.phase = 16; return;
                    }
                    const ids = ["greeter", "compositor", "dots", "wallpapers"];
                    tests.check(ServiceResources.entries.map(entry=>entry.id).join(",") === ids.join(","), "Import order is incorrect");
                    tests.check(ids.map(id=>tests.find(page, "importRow-"+id).label).join(",") === "Login screen,Compositor,Configs,Wallpapers", "Import labels are incorrect");
                    for (const id of ids) {
                        const row=tests.find(page,"importRow-"+id), clear=tests.find(row,"clearResource-"+id), button=tests.find(row,"importResource-"+id);
                        tests.check(button.text==="Import" && clear.visible===(id === "greeter"),"Import row has the wrong actions");
                        if(clear.visible)tests.check(clear.x<button.x && clear.enabled,"Clear does not appear before Import");
                    }
                    tests.find(imports, "importResource-compositor").clicked(); tests.phase++;
                } else if (tests.phase === 2) {
                    if (!dialog.opened) return;
                    tests.check(dialog.modal && dialog.focus && OverlayState.settingsPopup, "Confirmation is not modal");
                    tests.check(tests.find(dialog.contentItem, "cancelConfirmation").activeFocus, "Cancel does not receive initial focus");
                    events.keyClick(Qt.Key_Escape); tests.phase++;
                } else if (tests.phase === 3) {
                    if (dialog.visible) return;
                    tests.check(ServiceResources.pending === null && !OverlayState.settingsPopup, "Escape left a pending import");
                    window.width = 360;
                    Config.set("shellLanguage", "ru");
                    tests.find(imports, "importResource-dots").clicked(); tests.phase++;
                } else if (tests.phase === 4) {
                    if (!dialog.opened) return;
                    tests.check(dialog.description.includes("fastfetch") && dialog.description.includes("kitty"), "Dots confirmation hides affected applications");
                    const accept = tests.find(dialog.contentItem, "acceptConfirmation");
                    const position = accept.mapToItem(dialog.contentItem, 0, 0);
                    tests.check(position.x >= 0 && position.x + accept.width <= dialog.contentItem.width, "Localized buttons overflow the popup");
                    tests.click(accept);
                    tests.check(ServiceResources.pending !== null && dialog.visible && dialog.errorText !== "", "Missing terminal hides the confirmation or its error");
                    tests.click(tests.find(dialog.contentItem, "cancelConfirmation")); tests.phase++;
                } else if (tests.phase === 5) {
                    if (dialog.visible) return;
                    tests.check(ServiceResources.pending === null, "Cancel kept a pending import");
                    Config.set("shellLanguage", "en");
                    tests.find(imports, "importResource-greeter").clicked(); tests.phase++;
                } else if (tests.phase === 6) {
                    if (!dialog.opened) return;
                    tests.click(background); tests.phase++;
                } else if (tests.phase === 7) {
                    if (dialog.visible) return;
                    tests.check(ServiceResources.pending === null && tests.backgroundClicks === 0, "Outside click leaked to the page");
                    ServiceDependencies.packages = [{tool:"fixture",supported:true,removable:true,installed:true,required:false,packages:[]}];
                    ServiceDependencies.request("fixture", true); tests.phase++;
                } else if (tests.phase === 8) {
                    const dependency = tests.find(page, "dependencyConfirmation");
                    if (!dependency.opened) return;
                    tests.check(dependency.danger && dependency.modal, "Dependency confirmation did not use the modal dialog");
                    events.keyClick(Qt.Key_Escape); tests.phase++;
                } else if (tests.phase === 9) {
                    if (ServiceDependencies.pending !== null) return;
                    tests.find(imports, "importResource-wallpapers").clicked(); tests.phase++;
                } else if (tests.phase === 10) {
                    if (!dialog.opened) return;
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation"));
                    tests.check(ServiceResources.busy && ServiceUpdate.resourcesBusy, "Confirmed import does not block updates");
                    tests.phase++;
                } else if (tests.phase === 11) {
                    if (ServiceResources.busy || dialog.visible) return;
                    tests.check(ServiceResources.pending === null && ServiceResources.message !== "", "Import did not finish");
                    tests.find(imports, "clearResource-greeter").clicked(); tests.phase = 12;
                } else if (tests.phase === 12) {
                    if (!dialog.opened) return;
                    const accept=tests.find(dialog.contentItem,"acceptConfirmation");
                    tests.check(dialog.danger && accept.text==="Continue in terminal","Login-screen clear does not request a terminal");
                    tests.click(accept);
                    tests.check(ServiceResources.pending.action==="clear" && dialog.errorText!=="","Missing terminal lost the clear request");
                    ServiceResources.terminal=[Quickshell.env("TEST_IMPORT_TERMINAL")];
                    tests.click(accept);tests.phase++;
                } else if (tests.phase === 13) {
                    if (ServiceResources.busy || dialog.visible) return;
                    tests.check(ServiceResources.message==="Cleared." && !tests.find(imports,"clearResource-greeter").enabled,"Login-screen clear failed");
                    ServiceResources.request("compositor","clear");ServiceResources.request("wallpapers","clear");
                    tests.check(ServiceResources.pending===null,"Import-only resource accepted Clear");
                    tests.find(imports,"importResource-greeter").clicked();tests.phase++;
                } else if (tests.phase === 14) {
                    if (!dialog.opened) return;
                    pageLoader.active = false; tests.phase++;
                } else if (tests.phase === 15) {
                    tests.check(ServiceResources.pending === null && !OverlayState.settingsPopup, "Destroying the page left a modal grab");
                    tests.click(background);
                    tests.check(tests.backgroundClicks === 1, "Popup still intercepts input after page destruction");
                    console.log("IMPORT_DIALOG_PASSED order, labels, focus, Escape, cancel, outside click, errors, localization, dependency dialog, confirmation and destruction");
                    Qt.quit();
                } else if (tests.phase === 16) {
                    for (const id of ["greeter", "compositor", "dots", "wallpapers"]) {
                        tests.check(!tests.find(imports,"importResource-"+id).enabled,"Unavailable resource is enabled: "+id);
                        ServiceResources.request(id);
                        tests.check(ServiceResources.pending === null,"Unavailable resource accepted Import: "+id);
                    }
                    tests.check(tests.find(imports,"importResource-cli") === null,"CLI is still listed as an import");
                    ServiceResources.request("cli");
                    tests.check(ServiceResources.pending === null,"Removed CLI import accepted a request");
                    tests.check(tests.find(imports,"clearResource-greeter").enabled,"Missing remote files disabled local Clear");
                    ServiceResources.entries = tests.originalEntries;
                    tests.availabilityChecked = true;
                    tests.phase = 1;
                }
            } catch (error) { console.error("IMPORT_DIALOG_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
}
''')
        for animation in (0, 2):
            (base / "clear-calls").unlink(missing_ok=True)
            settings = base / "config/bloodyShell/settings.json"
            settings.write_text(json.dumps(dict(helperSeen=True, themeAnimations=animation, shellLanguage="en")))
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=16)
            output = result.stdout + result.stderr
            print(output)
            assert result.returncode == 0 and "IMPORT_DIALOG_PASSED" in output, output
            assert [json.loads(line) for line in (base / "clear-calls").read_text().splitlines()] == [["clear", "greeter", "--wait"]]
            assert not any(error in output for error in ("IMPORT_DIALOG_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output
    print("Import dialogs passed with animations disabled and fluid animations; no real configuration imports or package operations ran.")


def package_list_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-package-lists-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        control = base / "package-status.json"
        control.write_text(json.dumps(dict(fail=False, entries=[
            dict(tool="cava", feature="Audio visualizer.", packages=["cava"], required=False, installed=False, supported=True, removable=True),
            dict(tool="qt6-multimedia", feature="Video wallpaper playback.", packages=["qt6-multimedia", "qt6-multimedia-ffmpeg"], required=False, installed=True, supported=True, removable=True),
            dict(tool="brightnessctl", feature="Screen brightness control.", packages=[], required=False, installed=False, supported=False, removable=True),
            dict(tool="niri", feature="Compositor", packages=["niri"], required=True, installed=True, supported=True, removable=True),
            dict(tool="python3", feature="Shell helpers", packages=["python"], required=True, installed=False, supported=True, removable=False),
        ])))
        (base / "modules/services/ServiceGreeter.qml").write_text("pragma Singleton\nimport Quickshell\nSingleton {}\n")
        (base / "scripts/lib/management.py").write_text('''import json, os, sys, time
from pathlib import Path
def dependencies_main():
    assert sys.argv[1] == "status" and sys.argv[2] in ("optional", "required"), "Package tests must never run package operations"
    time.sleep(0.05)
    state = json.loads((Path(os.environ["TEST_SCREENSHOT_BASE"]) / "package-status.json").read_text())
    if state["fail"]:
        print("Fixture package status failure", file=sys.stderr)
        return 1
    print(json.dumps(dict(entries=[entry for entry in state["entries"] if entry["required"] == (sys.argv[2] == "required")], terminal=[])))
    return 0
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot {
    FileView { id: control; path:Quickshell.env("TEST_SCREENSHOT_BASE")+"/package-status.json"; blockLoading:true; blockWrites:true }
    Window {
        id: window; width:900; height:700; visible:true
        PageUpdates { id: page; anchors.fill:parent }
        TestCase {
            id: events; when:false; optional:true
            function check(ok,message) { if(!ok) throw new Error(message); }
            function until(predicate,message) { for(let i=0;i<200 && !predicate();i++) wait(10); check(predicate(),message); }
            function exercise() {
                const optional=findChild(page,"optionalPackages"), required=findChild(page,"requiredDependencies");
                check(optional && required && !findChild(page,"optionalTools"),"Settings must contain only Packages and Dependencies lists");
                optional.expanded=true;
                check(ServiceDependencies.packagesChecking && !ServiceDependencies.dependenciesChecking && required.summary!==Tr.tr("common.checking"),"Opening Packages also checks Dependencies");
                until(()=>!ServiceDependencies.busy && ServiceDependencies.packages.length===3,"Package catalog did not load");
                check(ServiceDependencies.dependencies.length===0,"Checking Packages loaded Dependencies");
                const packageRow=findChild(optional,"packageRow-cava");
                required.expanded=true;
                check(ServiceDependencies.dependenciesChecking && !ServiceDependencies.packagesChecking && optional.summary==="1 / 3","Opening Dependencies changes Packages state");
                until(()=>!ServiceDependencies.busy,"Dependencies did not finish refreshing");
                check(findChild(optional,"packageRow-cava")===packageRow,"Checking Dependencies rebuilt Packages rows");
                check(ServiceDependencies.packages.length===3 && ServiceDependencies.dependencies.length===2,"Catalog split is incorrect");
                check(optional.summary==="1 / 3" && required.summary==="1 / 2","Installed counts mix required and optional packages");
                check(!findChild(optional,"packageRow-niri") && !findChild(required,"packageRow-cava"),"An entry appears in the wrong list");
                check(findChild(required,"packageRow-python3").label==="python","Rows show command IDs instead of package names");
                check(findChild(required,"packageRow-niri").description==="","Required list contains optional feature descriptions");
                check(!findChild(required,"packageAction-niri").visible,"A required package offers Remove");
                check(findChild(required,"packageAction-python3").visible && findChild(required,"packageAction-python3").enabled,"Missing dependency cannot be repaired");
                check(findChild(optional,"packageAction-cava").text===Tr.tr("common.install") && findChild(optional,"packageAction-qt6-multimedia").text===Tr.tr("common.remove"),"Optional actions do not reflect installation state");
                check(!findChild(optional,"packageAction-brightnessctl").enabled,"Unsupported package operation is enabled");
                for(const language of ["en","ru"]) {
                    Config.set("shellLanguage",language);
                    until(()=>Tr.tr("settings.packages.title")===(language==="en"?"Packages":"Пакеты"),"Package translations did not load");
                    check(optional.title===Tr.tr("settings.packages.title") && required.title===Tr.tr("settings.dependencies.title"),"List titles do not follow the selected language");
                    check(findChild(optional,"packageRow-cava").description===Tr.tr("settings.packages.cava") && findChild(optional,"packageRow-cava").description!=="settings.packages.cava","Optional description is missing or not localized");
                    check(Tr.tr("settings.easyEffects.installHint").includes(optional.title) && Tr.tr("wallpapers.videoDependency").includes(optional.title),"Optional feature help points to the required list");
                }
                ServiceDependencies.request("niri",true);
                check(ServiceDependencies.pending===null,"Required package removal passed the service guard");
                const dialog=findChild(page,"dependencyConfirmation");
                findChild(optional,"packageAction-cava").clicked();
                until(()=>dialog.opened,"Optional install did not open confirmation");
                check(ServiceDependencies.pending.tool==="cava" && !ServiceDependencies.pending.remove && !dialog.danger,"Install confirmation is incorrect");
                findChild(dialog.contentItem,"acceptConfirmation").clicked();
                check(dialog.visible && ServiceDependencies.pending!==null && ServiceDependencies.error!=="","Missing terminal lost the requested operation");
                dialog.close(); until(()=>ServiceDependencies.pending===null && !dialog.visible,"Install cancellation did not clear the request");
                findChild(optional,"packageAction-qt6-multimedia").clicked();
                until(()=>dialog.opened,"Optional remove did not open confirmation");
                check(dialog.danger && ServiceDependencies.pending.remove && dialog.description.includes("qt6-multimedia-ffmpeg"),"Remove confirmation hides packages or has the wrong action");
                dialog.close(); until(()=>!dialog.visible,"Remove confirmation did not close");
                findChild(required,"packageAction-python3").clicked();
                until(()=>dialog.opened,"Missing dependency did not open an install confirmation");
                check(ServiceDependencies.pending.tool==="python3" && ServiceDependencies.pending.name==="python" && !dialog.danger,"Dependency repair dispatch uses the display name as a command ID");
                dialog.close(); until(()=>!dialog.visible,"Repair confirmation did not close");
                const state=JSON.parse(control.text());
                state.fail=true; control.setText(JSON.stringify(state)); control.waitForJob();
                ServiceDependencies.refresh(false);
                until(()=>!ServiceDependencies.busy && ServiceDependencies.error!=="","Failed status refresh did not report its error");
                check(ServiceDependencies.packagesError!=="" && ServiceDependencies.dependenciesError==="","A package check error leaked into Dependencies");
                check(optional.summary==="1 / 3" && required.summary==="1 / 2","Failed refresh discarded installed state");
                state.fail=false;
                state.entries=state.entries.map(entry=>Object.assign({},entry,{installed:entry.tool!=="brightnessctl"}));
                control.setText(JSON.stringify(state)); control.waitForJob();
                ServiceDependencies.refresh();
                until(()=>!ServiceDependencies.busy && ServiceDependencies.error==="","Package status did not recover");
                check(optional.summary==="2 / 3" && required.summary==="2 / 2" && !findChild(required,"packageAction-python3").visible,"Refreshed lists or required removal protection are stale");
                optional.expanded=false; required.expanded=false;
                check(ServiceDependencies.pending===null,"Closing lists left a pending package change");
                console.log("PACKAGE_LISTS_PASSED optional descriptions, required separation/protection, per-list counts, localized help, install/remove/repair confirmations, failures and refresh without package operations");
                Qt.quit();
            }
        }
        Timer { interval:120; running:Config.initialized; onTriggered:{ try { events.exercise(); } catch(error) { console.error("PACKAGE_LISTS_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "PACKAGE_LISTS_PASSED" in output, output
        assert not any(error in output for error in ("PACKAGE_LISTS_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output


def confirmation_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-confirmations-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)

        def instrument(folder, name, methods, properties):
            path = base / f"modules/{folder}/{name}.qml"
            source = path.read_text()
            for method, (arguments, body) in methods.items():
                source = source.replace(f"function {method}(", f"function original{method}(", 1)
            functions = "\n".join(f"    function {method}({arguments}) {{ {body} }}" for method, (arguments, body) in methods.items())
            source = source.replace("Singleton\n{", "Singleton\n{\n" + properties + "\n" + functions, 1)
            path.write_text(source)

        instrument("core", "Config", {"reset": ("", "testResets++;")}, "    property int testResets: 0")
        instrument("services", "ServiceDisplay", {
            "keep": ("", "testKept++; pending = null;"),
            "revert": ("", "if (pending) { testReverted++; pending = null; }")
        }, "    property int testKept: 0\n    property int testReverted: 0")
        instrument("services", "ServiceUser", {
            "confirmApply": ("", "testApplied++; pending = null;")
        }, "    property int testApplied: 0")
        instrument("services", "ServiceStorage", {
            "confirmMount": ("", "testMounted++; pending = null;")
        }, "    property int testMounted: 0")
        (base / "bin/pkexec").write_text('#!/bin/sh\ntouch "$HOME/unexpected-privileged-operation"\nexit 99\n')
        (base / "bin/pkexec").chmod(0o755)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot {
    id: tests
    property int phase: 0
    property int ticks: 0
    function check(ok, message) { if (!ok) throw new Error(message); }
    function find(item, name) { return events.findChild(item, name); }
    function click(item) { events.mouseClick(item, item.width/2, item.height/2, Qt.LeftButton, Qt.NoModifier, 0); }
    function exposed(item) {
        for (let ancestor = item.parent; ancestor; ancestor = ancestor.parent) {
            if (!ancestor.clip) continue;
            const point = item.mapToItem(ancestor, item.width / 2, item.height / 2);
            if (point.x < 0 || point.y < 0 || point.x >= ancestor.width || point.y >= ancestor.height) return false;
        }
        return item.visible;
    }
    function pendingMount() { ServiceStorage.pending = {label:"Test volume", mode:"persistent", target:"/mnt/Test Data"}; }
    function pendingAccount(count) { ServiceUser.pending = {values:{}, changes:Array.from({length:count}, (_, i) => ({label:"Field " + i, before:"Previous value", after:"Updated value"}))}; }
    Window {
        id: window; visible: true; width: 900; height: 680
        Item {
            anchors.fill: parent
            readonly property alias popupLayer: popupLayer
            Loader { id: pageLoader; anchors.fill: parent; sourceComponent: about }
            Item { id: popupLayer; anchors.fill: parent; z: 1000 }
        }
        Component { id: about; PageAbout {} }
        Component { id: display; PageDisplay {} }
        Component { id: storage; PageStorage {} }
        Component { id: account; PageUser {} }
        TestCase { id: events; name: "SettingsConfirmations"; when: false; optional: true }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (++tests.ticks > 180) { console.error("CONFIRMATIONS_FAILED timeout", tests.phase); Qt.quit(); return; }
            if (!pageLoader.item || !Config.initialized) return;
            try {
                const page = pageLoader.item;
                if (tests.phase === 0) {
                    if (tests.ticks < 8) return;
                    const maintenance = tests.find(page, "aboutMaintenance");
                    tests.check(maintenance && !maintenance.expanded, "Maintenance should start collapsed");
                    maintenance.expanded = true;
                    tests.phase = 20;
                } else if (tests.phase === 20) {
                    const button = tests.find(page, "requestReset");
                    page.contentY = Math.max(0, page.contentHeight - page.height);
                    if (!tests.exposed(button)) return;
                    tests.click(button); tests.phase = 1;
                } else if (tests.phase === 1) {
                    const dialog = tests.find(page, "resetConfirmation"); if (!dialog.opened) return;
                    tests.check(dialog.modal && tests.find(dialog.contentItem, "cancelConfirmation").activeFocus, "Reset is not a modal with Cancel focused");
                    tests.click(tests.find(dialog.contentItem, "cancelConfirmation")); tests.phase++;
                } else if (tests.phase === 2) {
                    tests.check(Config.testResets === 0 && !page.confirmReset, "Cancelling reset changed settings");
                    if (tests.find(page, "resetConfirmation").visible) return;
                    tests.click(tests.find(page, "requestReset")); tests.phase++;
                } else if (tests.phase === 3) {
                    const dialog = tests.find(page, "resetConfirmation"); if (!dialog.opened) return;
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation"));
                    tests.check(Config.testResets === 1, "Reset confirmation did not apply");
                    pageLoader.sourceComponent = display; tests.phase++;
                } else if (tests.phase === 4) {
                    ServiceDisplay.pending = {name:"Test", before:{}, after:{}}; ServiceDisplay.countdown = 15; tests.phase++;
                } else if (tests.phase === 5) {
                    const dialog = tests.find(page, "displayConfirmation"); if (!dialog.opened) return;
                    tests.check(dialog.description.includes("15"), "Display popup lost recovery countdown");
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation")); tests.phase++;
                } else if (tests.phase === 6) {
                    tests.check(ServiceDisplay.testKept === 1 && ServiceDisplay.testReverted === 0, "Keep triggered display recovery");
                    if (tests.find(page, "displayConfirmation").visible) return;
                    ServiceDisplay.pending = {name:"Test", before:{}, after:{}}; tests.phase++;
                } else if (tests.phase === 7) {
                    const dialog = tests.find(page, "displayConfirmation"); if (!dialog.opened) return;
                    events.keyClick(Qt.Key_Escape); tests.phase++;
                } else if (tests.phase === 8) {
                    if (ServiceDisplay.confirming) return;
                    tests.check(ServiceDisplay.testReverted === 1, "Escape did not revert display changes");
                    pageLoader.sourceComponent = storage; tests.phase++;
                } else if (tests.phase === 9) { tests.pendingMount(); tests.phase++;
                } else if (tests.phase === 10) {
                    const dialog = tests.find(page, "mountConfirmation"); if (!dialog.opened) return;
                    tests.check(dialog.description.includes("/mnt/Test Data"), "Mount popup hides destination");
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation")); tests.phase++;
                } else if (tests.phase === 11) {
                    tests.check(ServiceStorage.testMounted === 1, "Mount did not require acceptance");
                    if (tests.find(page, "mountConfirmation").visible) return;
                    tests.pendingMount(); tests.phase++;
                } else if (tests.phase === 12) {
                    const dialog = tests.find(page, "mountConfirmation"); if (!dialog.opened) return;
                    events.mouseClick(window.contentItem, 2, 2, Qt.LeftButton, Qt.NoModifier, 0); tests.phase++;
                } else if (tests.phase === 13) {
                    if (ServiceStorage.confirming) return;
                    tests.check(ServiceStorage.testMounted === 1, "Dismissing mount applied an operation");
                    window.width = 640; window.height = 420; pageLoader.sourceComponent = account; tests.phase++;
                } else if (tests.phase === 14) { tests.pendingAccount(20); tests.phase++;
                } else if (tests.phase === 15) {
                    const dialog = tests.find(page, "accountConfirmation"); if (!dialog.opened) return;
                    tests.check(dialog.height <= window.height - 32 && dialog.description.includes("Field 19"), "Long account confirmation does not fit the window or drops changes");
                    tests.click(tests.find(dialog.contentItem, "cancelConfirmation")); tests.phase++;
                } else if (tests.phase === 16) {
                    tests.check(ServiceUser.testApplied === 0 && !ServiceUser.confirming, "Cancel applied account changes");
                    if (tests.find(page, "accountConfirmation").visible) return;
                    tests.pendingAccount(1); tests.phase++;
                } else if (tests.phase === 17) {
                    const dialog = tests.find(page, "accountConfirmation"); if (!dialog.opened) return;
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation")); tests.phase++;
                } else if (tests.phase === 18) {
                    tests.check(ServiceUser.testApplied === 1, "Account acceptance did not apply changes");
                    tests.phase=19;
                }
            } catch (error) { console.error("CONFIRMATIONS_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
    Timer {
        interval: 100; running: tests.phase === 19; repeat: true
        onTriggered: {
            if (OverlayState.settingsPopup) return;
            console.log("CONFIRMATIONS_PASSED reset, display recovery, mount, account changes, cancellation, bounded long content, and destruction");
            Qt.quit();
        }
    }
}
''')
        for animation, language in ((0, "en"), (2, "ru")):
            (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(helperSeen=True, themeAnimations=animation, shellLanguage=language)))
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=22)
            output = result.stdout + result.stderr
            print(output)
            assert result.returncode == 0 and "CONFIRMATIONS_PASSED" in output, output
            assert not any(error in output for error in ("CONFIRMATIONS_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output
            assert not (base / "home/unexpected-privileged-operation").exists()
    print("Settings confirmations passed in both animation modes without changing accounts, displays, mounts or network connections.")


def popup_layout_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyShell-popup-layout-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/common"
import "modules/ui/overlay/settings/components"

ShellRoot {
    Window {
        id: window; visible:true; width:640; height:420
        property bool showHeader:true
        SettingsPopup {
            id: dialog; host:window.contentItem; preferredWidth:520
            panelContent: SettingsPopupLayout {
                anchors.fill: parent
                id: form
                title:"Shared popup layout"
                header: SettingsInput {visible:window.showHeader; width:parent.width; placeholderText:"Header control"}
                Repeater {model:20;SettingsRow {required property int index;label:"Option "+index}}
                actions: Button {text:"Cancel";onClicked:dialog.close()}
            }
        }
        SettingsPopup {
            id: picker; host:window.contentItem; preferredWidth:560;preferredHeight:540
            panelContent: SettingsPopupLayout {
                anchors.fill: parent
                id: pickerLayout;title:"List picker";fillContent:true
                ListView {
                    id: inner; width:parent.width;height:pickerLayout.bodyHeight;model:30;clip:true
                    delegate:SettingsRow {required property int index;label:"Application "+index}
                }
                actions:Button {text:"Cancel";onClicked:picker.close()}
            }
        }
        TestCase {
            id: input;when:false;optional:true
            function check(ok,message){if(!ok)throw new Error(message);}
            function find(item,name){if(item.objectName===name)return item;for(const child of item.children||[]){const found=find(child,name);if(found)return found;}return null;}
            function bounds(popup,layout){
                const actions=find(layout,"settingsPopupActions");
                check(popup.width<=window.width-32 && popup.height<=window.height-32,"Popup exceeds its host");
                check(actions.y+actions.height<=layout.height+0.5,"Popup actions are clipped");
                check(popup.x>=16 && popup.y>=16,"Popup is not centered within its margins");
            }
            function exercise(){
                for(const motion of [0,2])for(const theme of [0,1]){
                    Config.set("themeAnimations",motion);Config.set("themeStyle",theme);
                    window.width=640;window.height=420;window.showHeader=true;
                    dialog.open();wait(motion?400:30);
                    for(const accent of [false,true]){
                        Config.set("themeAccent",accent);wait(20);
                        check(String(Theme.accentForeground)===(Theme.lightForeground(Theme.colorAccent)?"#ffffff":"#000000"),"Primary button and toggle foreground contrast does not follow theme changes");
                    }
                    Config.set("themeAccent",false);
                    bounds(dialog,form);
                    const body=find(form,"settingsPopupBody"),title=find(form,"settingsPopupTitle"),actions=find(form,"settingsPopupActions");
                    check(body.interactive && body.height>0,"Long form does not scroll");
                    const titleY=title.y,actionsY=actions.y;
                    body.contentY=body.contentHeight-body.height;wait(10);
                    check(title.y===titleY && actions.y===actionsY,"Title or footer moves with popup content");
                    window.width=380;window.height=300;window.showHeader=false;wait(30);bounds(dialog,form);
                    form.errorText=Array(35).fill("Detailed error information").join("\\n");wait(300);bounds(dialog,form);
                    check(body.contentY>0 && find(form,"settingsPopupError").text.includes("Detailed error"),"Long errors are hidden or removed");
                    form.errorText="";dialog.close();wait(motion?240:20);
                    picker.open();wait(motion?400:30);bounds(picker,pickerLayout);
                    const outer=find(pickerLayout,"settingsPopupBody");
                    check(inner.height>0 && !outer.interactive && inner.contentHeight>inner.height,"List picker has nested outer scrolling");
                    pickerLayout.errorText=Array(30).fill("Picker failure").join("\\n");wait(300);bounds(picker,pickerLayout);
                    check(outer.interactive,"Long picker errors cannot be scrolled");
                    pickerLayout.errorText="";wait(30);
                    check(!outer.interactive && inner.height>0 && outer.contentY===0,"Clearing an error does not restore the picker");
                    picker.close();wait(motion?240:20);
                }
                console.log("POPUP_LAYOUT_PASSED shared slots, bounded sizing, fixed title/actions, long forms/errors, list scrolling, resize and themes");Qt.quit();
            }
        }
        Timer{interval:120;running:Config.initialized;onTriggered:{try{input.exercise();}catch(error){console.error("POPUP_LAYOUT_FAILED",error);Qt.quit();}}}
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "POPUP_LAYOUT_PASSED" in output, output
        assert not re.search(r"POPUP_LAYOUT_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def popup_animation_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-popup-animation-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/ui/overlay/settings/components"

ShellRoot {
    Window {
        id: window; width: 800; height: 600; visible: true
        SettingsConfirmation { id: dialog; host: window.contentItem; title: "Animation"; acceptText: "Apply" }
        SettingsConfirmation { id: other; host: window.contentItem; title: "Second popup"; acceptText: "Apply" }
        Component {
            id: temporaryPopup
            Item {
                id: temporaryHost; width:300; height:200
                SettingsConfirmation { objectName:"temporaryConfirmation"; host:temporaryHost; title:"Temporary"; acceptText:"Apply" }
            }
        }
        TestCase {
            id: events; name: "PopupAnimation"; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function exercise() {
                for (const mode of [0, 1, 2]) {
                    Config.set("themeAnimations", mode);
                    dialog.open();
                    check(dialog.presenting && OverlayState.settingsPopup, "Opening popup did not register");
                    wait(30);
                    if (mode === 0) check(dialog.reveal === 1 && dialog.scale === 1, "Disabled animations still animate");
                    else if (mode === 1) check(dialog.reveal > 0 && dialog.reveal < 1 && dialog.scale < 1, "Standard popup has no opening animation");
                    else {
                        const panel = dialog.contentItem;
                        check(dialog.reveal > 0 && dialog.reveal < 1 && dialog.scale === 1
                            && panel.surface.width < panel.width && panel.contentItem.width === panel.width,
                            "Fluid dialog does not reveal its bounds at a fixed content size");
                    }
                    wait(Theme.animationDurationControl + 40);
                    check(dialog.opened && dialog.reveal === 1 && dialog.scale === 1, "Opening did not settle");
                    dialog.close();
                    wait(30);
                    if (mode !== 0) {
                        check(dialog.visible && dialog.reveal > 0 && dialog.reveal < 1, "Popup has no closing animation");
                        const before = dialog.reveal;
                        dialog.open();
                        check(Math.abs(dialog.reveal - before) < 0.01, "Reopening a closing popup jumps");
                        wait(Theme.animationDurationControl + 40);
                        check(dialog.opened && dialog.reveal === 1, "Interrupted close did not reopen");
                        dialog.close();
                    }
                    wait(Theme.animationDurationClose + 40);
                    check(!dialog.visible && !OverlayState.settingsPopup, "Closing left a modal client");
                }
                Config.set("themeAnimations", 2);
                dialog.open(); wait(30);
                const before = dialog.reveal;
                dialog.close();
                check(Math.abs(dialog.reveal - before) < 0.01, "Closing an opening popup jumps");
                const closeDuration = Theme.animationDurationClose;
                Config.set("themeAnimations", 0); wait(closeDuration + 40);
                check(!dialog.visible && !OverlayState.settingsPopup, "Disabling animations interrupted closing");
                Config.set("themeAnimations", 2);
                dialog.open(); wait(30);
                const openDuration = Theme.animationDurationControl;
                Config.set("themeAnimations", 0); wait(openDuration + 40);
                check(dialog.opened && dialog.reveal === 1, "Disabling animations interrupted opening");
                other.open();
                dialog.close(); wait(30);
                check(OverlayState.settingsPopup, "Closing one popup cleared another popup's modal state");
                other.close(); wait(30);
                check(!OverlayState.settingsPopup, "Last popup left a modal client");
                const temporary = temporaryPopup.createObject(window.contentItem);
                const closing = findChild(temporary,"temporaryConfirmation");
                closing.open(); wait(20); closing.close(); temporary.destroy(); wait(30);
                check(!OverlayState.settingsPopup, "Destroyed popup retained modal state or deferred focus work");
                console.log("POPUP_ANIMATIONS_PASSED all modes, interrupted transitions, disabling animations and multiple popups");
                Qt.quit();
            }
        }
        Timer {
            interval: 100; running: Config.initialized
            onTriggered: { try { events.exercise(); } catch (error) { console.error("POPUP_ANIMATIONS_FAILED", error); Qt.quit(); } }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "POPUP_ANIMATIONS_PASSED" in output, output
        assert not any(error in output for error in ("POPUP_ANIMATIONS_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output


def release_notes_checks():
    helpers = runpy.run_path(str(ROOT / "scripts/tests/run.py"))
    png = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["png"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-release-notes-") as temporary:
        base = Path(temporary)
        folder = base / "modules/ui/overlay/settings/components"
        folder.mkdir(parents=True)
        for name in ("core", "common", "src"):
            (base / "modules" / name).mkdir()
        for name in ("runtime", "cache"):
            (base / name).mkdir(mode=0o700)
        shutil.copy2(ROOT / "modules/src/ReleaseNotes.js", base / "modules/src/ReleaseNotes.js")
        shutil.copy2(ROOT / "modules/common/ShellText.qml", base / "modules/common/ShellText.qml")
        helpers["stub"](base, "modules/core", "Theme", '''property string fontText: "Sans Serif"
            property color text2: "#eeeeee"; property color text3: "#aeb8c6"
            property color colorAttention: "#93c7ff"; property color colorField: "#202936"
            property color colorHairline: "#465363"''')
        helpers["stub"](base, "modules/core", "Tr", 'function tr(key) { return key === "common.loading" ? "Loading…" : "Preview"; }')
        helpers["module"](base, "modules/core")
        prefix = "https://raw.githubusercontent.com/bloodykgrapes/bloodyShell/v0.1.0/"
        images = base / "docs/images/0.1.0"
        images.mkdir(parents=True)
        for number, size in enumerate(((800, 450), (800, 500), (800, 450)), 1):
            (images / f"changelog-{number}.png").write_bytes(png(*size))
        source = (ROOT / "modules/ui/overlay/settings/components/SettingsReleaseNotes.qml").read_text()
        source = source.replace("source: tile.modelData.source", "source: tile.modelData.source.replace(" + json.dumps(prefix) + ", " + json.dumps(base.as_uri() + "/") + ")")
        (folder / "SettingsReleaseNotes.qml").write_text(source)
        sample = '''<p align="center">Installer, CLI and interface improvements.</p>

<p align="center">
    <img src="docs/images/0.1.0/changelog-1.png" alt="Setup" width="49%">
    <img src="docs/images/0.1.0/changelog-2.png" alt="CLI" width="49%">
    <br>
    <sub><b>Setup</b> wizard &nbsp;•&nbsp; <b>CLI</b> tool</sub>
</p>

<p align="center">
    <img src="docs/images/0.1.0/changelog-3.png" alt="Lock screen" width="98%">
    <br><sub><b>Lock</b> screen</sub>
</p>

### Added
- **UI:** Screenshot galleries.
- **Settings:** Notes with `inline code` and [links](docs/readme/README.ru.md).

### Fixed
- Kept text readable when images fail.
'''
        shell = r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/ui/overlay/settings/components"
import "modules/src/ReleaseNotes.js" as Notes

ShellRoot {
    id: tests
    property string sample: SAMPLE
    function check(ok,message) { if(!ok) throw new Error(message); }
    function findAll(item,name) {
        let result=item.objectName===name?[item]:[];
        for(const child of item.children||[])result=result.concat(findAll(child,name));
        return result;
    }
    function until(test,message) {
        for(let i=0;i<100 && !test();i++) events.wait(10);
        check(test(),message);
    }
    Window {
        id: window; width:820; height:700; visible:true; color:"#111820"
        Flickable {
            id: view; anchors.fill:parent; anchors.margins:20; clip:true; contentHeight:notes.implicitHeight
            SettingsReleaseNotes {
                id:notes; width:view.width; text:tests.sample; baseUrl:BASE_URL
                property string lastLink: ""
                onLinkActivated: link => lastLink=link
            }
        }
        TestCase {id:events;when:false;optional:true}
    }
    Timer {interval:100;running:true;onTriggered:{try {
        const blocks=Notes.parse(tests.sample,notes.baseUrl);
        check(blocks.map(block=>block.kind).join(",")==="text,gallery,gallery,text","Image blocks changed the order of release notes");
        check(blocks[1].images.length===2 && blocks[2].images.length===1,"HTML galleries lost images");
        check(blocks[1].images[0].source===notes.baseUrl+"docs/images/0.1.0/changelog-1.png","Relative image did not resolve against its release tag");
        check(blocks[1].caption.includes("<b>Setup</b>") && blocks[3].text.includes("### Fixed"),"Captions or Markdown were lost");
        check(Notes.resolve("https://github.com/user-attachments/assets/example?x=1&amp;y=2",notes.baseUrl)==="https://github.com/user-attachments/assets/example?x=1&y=2","GitHub attachments or HTML entities were corrupted");
        check(Notes.resolve("./docs/../images/a%20b.png",notes.baseUrl)===notes.baseUrl+"images/a%20b.png","Relative path normalization corrupted URL encoding");
        check(Notes.resolve("file:///private/image.png",notes.baseUrl)==="","Release body loaded a local file URL");
        const markdown=Notes.parse("![Setup](docs/images/0.1.0/changelog-1.png)\n![CLI](<docs/images/0.1.0/changelog-2.png>)",notes.baseUrl);
        check(markdown.length===1 && markdown[0].images.length===2,"Standalone Markdown images did not form a gallery");
        const separate=Notes.parse('<p><img src="one.png"><img src="two.png"></p>\n<p><img src="three.png"></p>',notes.baseUrl);
        check(separate.length===2 && separate[0].images.length===2 && separate[1].images.length===1,"Separate HTML galleries merged without captions");
        const code=Notes.parse("```html\n<img src=\"example.png\">\n```\n\n### Example",notes.baseUrl);
        check(code.length===1 && code[0].kind==="text" && code[0].text.includes("<img"),"Fenced code was interpreted as a screenshot");
        const previews=()=>tests.findAll(notes,"releaseImage");
        until(()=>previews().length===3 && previews().every(image=>image.status===Image.Ready),"Native image previews did not load");
        const tiles=tests.findAll(notes,"releaseImageTile");
        events.wait(30);
        check(tiles[0].y===tiles[1].y && tiles[1].x>tiles[0].x,"Wide gallery did not place two screenshots side by side");
        check(tiles[2].width===notes.width,"Single screenshot does not fill the column");
        check(tiles.every(tile=>tile.x+tile.width<=notes.width+1),"Screenshot overflows the notes");
        check(view.contentHeight>view.height,"Long notes do not contribute their image heights to scrolling");
        let captured=false;window.contentItem.grabToImage(result=>{result.saveToFile("/tmp/bloodyShell-release-notes-wide.png");captured=true;});
        until(()=>captured,"Wide screenshot failed");
        events.mouseClick(tiles[0],tiles[0].width/2,tiles[0].height/2,Qt.LeftButton,Qt.NoModifier,0);
        check(notes.lastLink===blocks[1].images[0].source,"Click did not open the original image URL");
        tiles[1].forceActiveFocus();events.keyClick(Qt.Key_Return);
        check(notes.lastLink===blocks[1].images[1].source,"Keyboard image activation failed");
        window.width=400;events.wait(100);
        check(tiles[0].width===notes.width && tiles[1].y>tiles[0].y,"Narrow gallery did not stack screenshots");
        check(previews().every(image=>image.paintedWidth<=image.width+1 && image.paintedHeight<=image.height+1),"Image fitting cropped or overflowed a screenshot");
        check(tests.findAll(notes,"releaseCaption").filter(caption=>caption.visible).length===2,"Gallery captions disappeared after resizing");
        captured=false;window.contentItem.grabToImage(result=>{result.saveToFile("/tmp/bloodyShell-release-notes-narrow.png");captured=true;});
        until(()=>captured,"Narrow screenshot failed");
        notes.text="![Missing screenshot](docs/images/0.1.0/missing.png)\n\n### Still readable\n- Text survives.";
        until(()=>previews().length===1 && previews()[0].status===Image.Error,"Failed image never reached its fallback");
        check(tests.findAll(notes,"releaseImageTile")[0].height===96 && tests.findAll(notes,"releaseMarkdown").some(text=>text.text.includes("Still readable")),"Image failure hid the remaining notes");
        notes.text="### Text only\n- No screenshots.";events.wait(30);
        check(previews().length===0 && notes.implicitHeight>0,"Text-only releases retained images or became empty");
        console.log("RELEASE_NOTES_PASSED HTML and Markdown galleries, tagged URLs, attachments, captions, code fences, wide/narrow layout, image fitting, keyboard/pointer activation, failure fallback and text-only releases");Qt.quit();
    }catch(error){console.error("RELEASE_NOTES_FAILED",error);Qt.quit();}}}
}
'''
        (base / "shell.qml").write_text(shell.replace("SAMPLE", json.dumps(sample)).replace("BASE_URL", json.dumps(prefix)))
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(base / "runtime"), XDG_CACHE_HOME=str(base / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "RELEASE_NOTES_PASSED" in output, output
        assert not any(error in output for error in ("RELEASE_NOTES_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign", "is not a type")), output


def release_notes_page_checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-release-notes-page-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "version").write_text("0.0.1\n")
        cache = base / "cache/bloodyShell/current-release.json"
        cache.parent.mkdir(parents=True)
        cache.write_text(json.dumps(dict(repo="bloodykgrapes/bloodyShell", release=dict(tag="v0.0.1", version="0.0.1", name="0.0.1", notes="Cached current changelog.", date="2026-11-15", url="", prerelease=False))))
        (base / "bin/curl").write_text('#!/bin/sh\nprintf "{}\\n404"\n')
        (base / "bin/curl").chmod(0o700)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        (base / "modules/services/ServiceGreeter.qml").write_text("pragma Singleton\nimport Quickshell\nSingleton {}\n")
        prefix = "https://raw.githubusercontent.com/bloodykgrapes/bloodyShell/v0.1.0/"
        source = base / "modules/ui/overlay/settings/components/SettingsReleaseNotes.qml"
        source.write_text(source.read_text().replace("source: tile.modelData.source", "source: tile.modelData.source.replace(" + json.dumps(prefix) + ", " + json.dumps(base.as_uri() + "/") + ")"))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"

ShellRoot {
    function check(ok,message) { if(!ok)throw new Error(message); }
    Window {
        id: window; visible:true; width:1000; height:700
        PageUpdates {id:page; anchors.fill:parent}
        TestCase {id:events;when:false;optional:true}
    }
    Timer {interval:100;running:true;repeat:true;onTriggered:{
        if(!Config.initialized || !ServiceUpdate.versionReady)return;
        stop();
        try {
            const current=events.findChild(page,"currentChangelog");
            check(current && current.visible && current.summary==="0.0.1" && !current.expanded,"Current changelog foldout is missing or has the wrong version");
            check(!events.findChild(current,"releaseNotesCard"),"Closed current changelog eagerly created its content");
            for(let i=0;i<100 && !ServiceUpdate.currentRelease.notes;i++)events.wait(10);
            check(ServiceUpdate.currentRelease.notes==="Cached current changelog.","Current notes depend on an online update check");
            current.expanded=true;events.wait(100);
            let currentCard=events.findChild(current,"releaseNotesCard");
            check(currentCard && !currentCard.collapsible && !events.findChild(currentCard,"releaseNotesToggle").visible,"Current foldout has a second expand/collapse control");
            check(events.findChild(currentCard,"releaseNotesBody").text==="Cached current changelog.","Foldout does not display the cached current release");
            current.expanded=false;events.wait(100);
            check(!events.findChild(current,"releaseNotesCard"),"Collapsing the foldout retained its rendered content");
            const release={tag:"v0.1.0",version:"0.1.0",name:"0.1.0",date:"2026-11-15T00:00:00Z",prerelease:false,url:"https://github.com/bloodykgrapes/bloodyShell/releases/tag/v0.1.0",
                notes:'<p align="center"><img src="missing.png" alt="Screenshot" width="98%"><br><sub><b>Preview</b></sub></p>\\n\\n### Added\\n'+Array.from({length:35},(_,i)=>"- Release note "+i).join("\\n")};
            ServiceUpdate.releases=[release];events.wait(150);
            check(ServiceUpdate.currentRelease.version==="0.0.1" && ServiceUpdate.currentRelease.notes==="Cached current changelog.","An available update replaced the installed changelog");
            let card=events.findChild(page,"releaseNotesCard"), body=events.findChild(card,"releaseNotesBody"), toggle=events.findChild(card,"releaseNotesToggle");
            check(card && body && toggle && card.tall && toggle.visible && !card.expanded,"Long release notes did not start collapsed");
            check(body.baseUrl==="https://raw.githubusercontent.com/bloodykgrapes/bloodyShell/v0.1.0/" && body.blocks[0].images.length===1,"Page did not pass the release tag or parse its images");
            const collapsed=card.height;
            toggle.clicked();events.wait(450);
            check(card.expanded && card.height>collapsed+150 && page.contentHeight>page.height,"Show more did not expand gallery and text into page scrolling");
            toggle.clicked();events.wait(450);
            check(!card.expanded && Math.abs(card.height-collapsed)<2,"Show less did not restore the collapsed height");
            ServiceUpdate.releases=[Object.assign({},release,{notes:""})];events.wait(100);
            card=events.findChild(page,"releaseNotesCard");body=events.findChild(card,"releaseNotesBody");toggle=events.findChild(card,"releaseNotesToggle");
            check(body.text.includes(Tr.tr("settings.updates.noReleaseNotes")) && body.blocks.length===1 && !toggle.visible,"Empty release notes lost their fallback or retained a gallery");
            ServiceUpdate.releases=[];ServiceUpdate.error="Offline";events.wait(50);
            check(!events.findChild(page,"pendingChangelogs").visible && current.visible,"No updates hid the installed changelog or kept empty update notes");
            current.expanded=true;events.wait(100);
            currentCard=events.findChild(current,"releaseNotesCard");
            check(events.findChild(currentCard,"releaseNotesBody").text==="Cached current changelog.","Offline state lost the installed changelog");
            Config.set("shellLanguage","ru");
            for(let i=0;i<100 && Tr.tr("settings.updates.changelog")!=="Список изменений";i++)events.wait(10);
            check(current.title==="Список изменений","Changelog foldout did not follow the language");
            ServiceUpdate.version="9.9.9";events.wait(50);
            for(let i=0;i<100 && !ServiceUpdate.currentNotesMissing;i++)events.wait(10);
            check(current.summary==="9.9.9" && !events.findChild(current,"releaseNotesCard") && events.findChild(current,"currentChangelogStatus").label===Tr.tr("settings.updates.unpublished"),"Unpublished version displayed cached notes for another version");
            console.log("RELEASE_NOTES_PAGE_PASSED installed changelog foldout, offline/disabled checks, pending-release separation, lazy cleanup, localization, tagged images, expanded heights, scrolling and empty notes");Qt.quit();
        }catch(error){console.error("RELEASE_NOTES_PAGE_FAILED",error);Qt.quit();}
    }}
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "RELEASE_NOTES_PAGE_PASSED" in output, output
        assert not any(error in output for error in ("RELEASE_NOTES_PAGE_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign", "is not a type")), output


if __name__ == "__main__":
    service_load_checks()
    checks()
    package_list_checks()
    confirmation_checks()
    popup_layout_checks()
    popup_animation_checks()
    release_notes_checks()
    release_notes_page_checks()
