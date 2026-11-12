#!/usr/bin/env python3
"""Exercise grouped imports and modal confirmations without changing user files."""

import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-import-dialog-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        env["XDG_STATE_HOME"] = str(base / "state")
        (base / "scripts/lib/resources.py").write_text('''import json, sys
def resources_main():
    if sys.argv[1:] == ["status"]:
        print(json.dumps(dict(terminal=[], entries=[
            dict(id="compositor",kind="compositor",destination="/fixture/niri"),
            dict(id="dots",kind="dots",programs=["fastfetch","kitty"],destination="/fixture/config"),
            dict(id="greeter",kind="greeter",destination="/fixture/greeter"),
            dict(id="wallpapers",kind="wallpapers",destination="/fixture/wallpapers")
        ])))
    elif sys.argv[1:] == ["import", "wallpapers"]:
        print(json.dumps(dict(settings={})))
    else:
        raise AssertionError("Unexpected import: " + repr(sys.argv))
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/pages"
import "modules/ui/overlay/settings/components"

ShellRoot {
    id: tests
    property int phase: 0
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
            SettingsButton { id: background; x: 2; y: 2; text: "Background"; onClicked: tests.backgroundClicks++; }
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
                    const ids = ["compositor", "dots", "greeter", "wallpapers"];
                    tests.check(ServiceResources.entries.map(entry=>entry.id).join(",") === ids.join(","), "Import order is incorrect");
                    tests.check(ids.map(id=>tests.find(page, "importRow-"+id).label).join(",") === "Compositor,Dots,Login screen,Wallpapers", "Import labels are incorrect");
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
                    const position = accept.mapToItem(dialog.background, 0, 0);
                    tests.check(position.x >= 0 && position.x + accept.width <= dialog.background.width, "Localized buttons overflow the popup");
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
                    ServiceDependencies.entries = [{tool:"fixture",supported:true,removable:true,installed:true,required:false,packages:[]}];
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
                    tests.find(imports, "importResource-greeter").clicked(); tests.phase++;
                } else if (tests.phase === 12) {
                    if (!dialog.opened) return;
                    pageLoader.active = false; tests.phase++;
                } else if (tests.phase === 13) {
                    tests.check(ServiceResources.pending === null && !OverlayState.settingsPopup, "Destroying the page left a modal grab");
                    tests.click(background);
                    tests.check(tests.backgroundClicks === 1, "Popup still intercepts input after page destruction");
                    console.log("IMPORT_DIALOG_PASSED order, labels, focus, Escape, cancel, outside click, errors, localization, dependency dialog, confirmation and destruction");
                    Qt.quit();
                }
            } catch (error) { console.error("IMPORT_DIALOG_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
}
''')
        for animation in (0, 2):
            settings = base / "config/bloodyShell/settings.json"
            settings.write_text(json.dumps(dict(helperSeen=True, themeAnimations=animation, shellLanguage="en")))
            result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=16)
            output = result.stdout + result.stderr
            print(output)
            assert result.returncode == 0 and "IMPORT_DIALOG_PASSED" in output, output
            assert not any(error in output for error in ("IMPORT_DIALOG_FAILED", "ReferenceError", "TypeError", "Binding loop", "Cannot assign", "Unable to assign")), output
    print("Import dialogs passed with animations disabled and fluid animations; no real configuration imports or package operations ran.")


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
        instrument("services", "ServiceNetwork", {
            "forgetNetwork": ("name", "testForgotten = name; testForgets++;")
        }, '    property string testForgotten: ""\n    property int testForgets: 0')
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
    function pendingMount() { ServiceStorage.pending = {label:"Test volume", mode:"persistent", target:"/mnt/Test Data"}; }
    function pendingAccount(count) { ServiceUser.pending = {values:{}, changes:Array.from({length:count}, (_, i) => ({label:"Field " + i, before:"Previous value", after:"Updated value"}))}; }
    Window {
        id: window; visible: true; width: 900; height: 680
        Item {
            anchors.fill: parent
            readonly property alias popupLayer: popupLayer
            Loader { id: pageLoader; anchors.fill: parent; sourceComponent: general }
            Item { id: popupLayer; anchors.fill: parent; z: 1000 }
        }
        Component { id: general; PageGeneral {} }
        Component { id: display; PageDisplay {} }
        Component { id: storage; PageStorage {} }
        Component { id: account; PageUser {} }
        Component { id: networks; PageNetworks {} }
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
                    tests.click(tests.find(page, "requestReset")); tests.phase++;
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
                    pageLoader.sourceComponent = networks; tests.phase++;
                } else if (tests.phase === 19) { page.forgetFor = "Example Wi-Fi"; tests.phase++;
                } else if (tests.phase === 20) {
                    const dialog = tests.find(page, "forgetConfirmation"); if (!dialog.opened) return;
                    tests.check(dialog.danger, "Forgetting Wi-Fi lost destructive styling");
                    tests.click(tests.find(dialog.contentItem, "acceptConfirmation")); tests.phase++;
                } else if (tests.phase === 21) {
                    tests.check(ServiceNetwork.testForgets === 1 && ServiceNetwork.testForgotten === "Example Wi-Fi", "Forget did not target the confirmed network");
                    if (tests.find(page, "forgetConfirmation").visible) return;
                    page.forgetFor = "Keep Wi-Fi"; tests.phase++;
                } else if (tests.phase === 22) {
                    const dialog = tests.find(page, "forgetConfirmation"); if (!dialog.opened) return;
                    pageLoader.active = false; tests.phase++;
                }
            } catch (error) { console.error("CONFIRMATIONS_FAILED", tests.phase, error); Qt.quit(); }
        }
    }
    Timer {
        interval: 100; running: tests.phase === 23; repeat: true
        onTriggered: {
            if (OverlayState.settingsPopup) return;
            if (ServiceNetwork.testForgets !== 1) console.error("CONFIRMATIONS_FAILED destruction applied an operation");
            else console.log("CONFIRMATIONS_PASSED reset, display recovery, mount, account changes, Wi-Fi forgetting, cancellation, bounded long content, and destruction");
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
                    else check(dialog.reveal > 0 && dialog.reveal < 1 && dialog.scale < 1, "Popup has no opening fade or scale");
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


if __name__ == "__main__":
    checks()
    confirmation_checks()
    popup_animation_checks()
