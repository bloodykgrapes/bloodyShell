#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def checks():
    with tempfile.TemporaryDirectory(prefix="bloodyshell-controls-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules", base / "modules")
        for name in ("assets", "translations"):
            (base / name).symlink_to(ROOT / name)
        for folder in ("config/bloodyShell", "cache", "runtime"):
            (base / folder).mkdir(parents=True, mode=0o700)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps({"themeAnimations": 0, "helperSeen": True}))
        (base / "modules/services/ServiceAppearance.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property color accent: "#8ecbff" }\n')
        (base / "modules/core/MenuState.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { function close() {} }\n')
        (base / "modules/services/ServicePower.qml").write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property string pendingAction: ""; property var actions: []; function run(action) { actions = actions.concat([action]); } }\n')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/animations"
import "modules/common"
import "modules/core"
import "modules/services"
import "modules/ui/overlay/power"
import "modules/ui/overlay/settings/components"

ShellRoot
{
    Window
    {
        id: window
        visible: true
        width: 680; height: 520; color: Theme.colorSolid
        function check(ok, message) { if (!ok) throw new Error(message); }
        function find(item, predicate)
        {
            if (predicate(item)) return item;
            for (const child of item.children || []) { const found = find(child, predicate); if (found) return found; }
            return null;
        }
        Item
        {
            id: host
            anchors.fill: parent
            readonly property alias popupLayer: popups
            SettingsRow
            {
                id: longRow
                x: 20; y: 20; width: 600
                label: "A long translated label that must wrap before it reaches the controls"
                description: "A description below the label."
                SettingsButton { id: rowButton; width: 220; text: "Action" }
            }
            SettingsRow
            {
                id: valueRow
                x: 20; y: longRow.y + longRow.height + 6; width: 600
                label: "A longer translated label"
                valueText: "/a/very/long/path/that/must/not/reserve/its/full/implicit/width"
            }
            SettingsCombo
            {
                id: combo
                x: 20; y: 420; width: 240
                options: ["First", "Second", "Third", "Fourth", "Fifth", "Sixth"]
                current: "First"
                onSelected: value => current = value
            }
            SettingsSlider { id: slider; x: 290; y: 420; value: 0.5; onMoved: value => slider.value = value }
            Toggle { id: toggle; x: 560; y: 420; onToggled: value => checked = value }
            MenuItem { id: menu; x: 20; y: 360; width: 220; text: "Menu action"; property int clicks: 0; onClicked: clicks++ }
            ShellText { id: literal; x: 20; y: 330; label: "<b>A title & name</b>" }
            SettingsGroup { id: group; x: 20; y: 180; width: 600; title: "Section"; SettingsRow { label: "Content" } }
            RevealSection { id: section; x: 20; y: 290; ShellText { label: "Animated section" } }
            SettingsDisclosure { id: disclosure; x: 380; y: 290; width: 240; title: "Details"; SettingsRow { label: "Content" } }
            SettingsToggles {
                id: chips; x: -5000; width: 180
                options: [{label:"A long monitor name that must fit", value:"display"}]
                onToggled: (value, on) => checked = on ? [value] : []
            }
            SettingsRow {
                id: valueControlRow; x: -5000; width: 320
                label: "A dependency with an action"
                valueText: "Installed"
                SettingsButton { text: "Update application" }
            }
            Item { id: popups; anchors.fill: parent; z: 100 }
        }
        SettingsPageSlot { id: slot; visible: false }
        Item { id: bound; property real goal: 0; width: goal; Glide on width {} }
        Loader { id: powerTest; anchors.centerIn: parent; active: false; sourceComponent: Component { PowerContent {} } }
        TestCase
        {
            id: input
            when: false
            optional: true
            function exercise()
            {
                const label = window.find(longRow, item => item !== longRow && item.label === longRow.label);
                const valueLabel = window.find(valueRow, item => item !== valueRow && item.label === valueRow.label);
                const value = window.find(valueRow, item => item.visible && item.label === valueRow.valueText);
                window.check(label.width > 0 && label.mapToItem(longRow, label.width, 0).x <= rowButton.mapToItem(longRow, 0, 0).x - 16, "Settings label overlaps controls");
                window.check(label.height > label.font.pixelSize * 1.5, "Long label did not wrap");
                window.check(valueLabel.width > 200 && valueLabel.mapToItem(valueRow, valueLabel.width, 0).x < value.x, "Long value consumed the label width");
                window.check(literal.textFormat === Text.PlainText, "External titles are interpreted as markup");
                const chip = window.find(chips, item => item !== chips && item.modelData !== undefined);
                window.check(chip && chip.width <= chips.width, "Monitor chip exceeds its container");
                chip.forceActiveFocus(); keyClick(Qt.Key_Space);
                window.check(chips.checked.indexOf("display") >= 0, "Monitor chips cannot be selected with the keyboard");
                window.check(valueControlRow.vertical && window.find(valueControlRow, item => item.label === valueControlRow.valueText && item.visible), "Stacking controls hid their status value");

                for (const mode of [0, 1, 2])
                {
                    Config.set("themeAnimations", mode);
                    combo.forceActiveFocus(); keyClick(Qt.Key_Space); wait(30);
                    window.check(combo.open && OverlayState.settingsPopup, "Keyboard did not open dropdown");
                    const list = window.find(popups, item => item.count === combo.options.length && item.currentIndex !== undefined);
                    window.check(list && list.activeFocus, "Dropdown did not receive keyboard focus");
                    const panel = list.parent;
                    window.check(panel.y >= 8 && panel.y + panel.height <= popups.height - 8, "Dropdown escaped the bottom screen edge");
                    keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); wait(20);
                    window.check(combo.current === "Second" && !combo.open && combo.activeFocus && !OverlayState.settingsPopup, "Dropdown selection did not return focus");
                    combo.current = "First";
                    keyClick(Qt.Key_Down); wait(20); keyClick(Qt.Key_Escape);
                    window.check(!combo.open && combo.activeFocus, "Escape did not restore dropdown focus");
                    combo.toggle(); wait(20); combo.enabled = false;
                    window.check(!combo.open && !OverlayState.settingsPopup, "Disabled dropdown retained its popup");
                    combo.enabled = true;

                    slider.forceActiveFocus(); slider.value = 0.5;
                    keyClick(Qt.Key_Right); window.check(Math.abs(slider.value - 0.55) < 0.0001, "Keyboard slider step is wrong");
                    keyClick(Qt.Key_Home); window.check(slider.value === 0, "Slider Home did not reach minimum");
                    keyClick(Qt.Key_End); window.check(slider.value === 1, "Slider End did not reach maximum");
                    slider.value = 0.5;
                    mouseWheel(slider, 20, 14, 120, 0, Qt.NoButton, Qt.NoModifier);
                    window.check(slider.value === 0.5, "Horizontal wheel changed slider value");
                    toggle.forceActiveFocus(); keyClick(Qt.Key_Enter);
                    window.check(toggle.checked, "Toggle did not handle keypad Enter");
                    keyClick(Qt.Key_Space); window.check(!toggle.checked, "Toggle did not handle Space");
                    menu.forceActiveFocus(); keyClick(Qt.Key_Return);
                    window.check(menu.clicks === mode + 1, "Menu action is not keyboard accessible");
                    wait(600);
                }

                Config.set("themeAnimations", 2);
                bound.goal = 100;
                section.shown = false;
                disclosure.expanded = true;
                toggle.checked = true;
                group.enter(5);
                slot.enter(Qt.resolvedUrl("modules/ui/overlay/settings/pages/PageShortcuts.qml"), 1);
                wait(40);
                slot.leave(1);
                combo.forceActiveFocus(); combo.toggle(); wait(20);
                Config.set("themeAnimations", 0);
                wait(0);
                bound.goal = 200;
                wait(0);
                window.check(bound.width === 200, "Animation-mode change removed the width binding");
                window.check(section.opacity === 0 && group.opacity === 1 && group.rise === 0, "Sections stayed partially animated");
                window.check(window.find(disclosure, item => item.progress !== undefined && item.reveal !== undefined).reveal === 1, "Disclosure stayed partially expanded");
                window.check(window.find(toggle, item => item.extension !== undefined).position === 1, "Switch thumb stayed between states");
                window.check(String(slot.source) === "" && !slot.enabled, "Closed page retained interactive content");
                combo.open = false;
                combo.choose(4);
                window.check(combo.current === "First", "A closing dropdown accepted another selection");
                combo.options = [];
                combo.toggle(); window.check(!combo.open, "Empty dropdown opened");
                powerTest.active = true;
                const power = powerTest.item;
                power.select(3); power.current().press(); wait(180);
                power.select(4); wait(850);
                window.check(ServicePower.actions.length === 0, "Changing selection completed the previous power action");
                power.current().press(); wait(180); power.active = false; wait(850);
                window.check(ServicePower.actions.length === 0, "Closing power menu completed a held action");
                console.log("CONTROLS_PASSED label layout, literal text, keyboard controls, dropdown bounds/focus, and animation cancellation");
                Qt.quit();
            }
        }
        Timer
        {
            interval: 180; running: Config.initialized
            onTriggered: { try { input.exercise(); } catch (error) { console.error("CONTROLS_FAILED", error); Qt.quit(); } }
        }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "CONTROLS_PASSED" in output, output
        assert not re.search(r"CONTROLS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


def layout_checks():
    import runpy
    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-settings-layout-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "modules/core"
import "modules/ui/overlay/settings"

ShellRoot {
    id: tests
    property int scenario: 0
    property int pageIndex: 0
    property int settling: 0
    property int ticks: 0
    property bool configure: true
    function check(ok, message) { if (!ok) throw new Error(message); }
    function loaded(item, source) {
        if (String(item.source) === String(source) && item.status === Loader.Ready && item.item) return item.item;
        for (const child of item.children || []) { const result = loaded(child, source); if (result) return result; }
        return null;
    }
    function inspect(item, page) {
        if (item.visible && item.width > 0) {
            if (item.controlAvailableWidth !== undefined) {
                check(Number.isFinite(item.height) && item.height > 0, "Invalid row height");
            }
            if (item.preferredWidth !== undefined || item.maximumWidth !== undefined || typeof item.nudge === "function") {
                let row = item.parent;
                while (row && row !== page && row.controlAvailableWidth === undefined) row = row.parent;
                const point = item.mapToItem(page, 0, 0);
                check(point.x >= -0.5 && point.x + item.width <= page.width + 0.5, "Control extends beyond page: " + item + " " + point.x + "/" + item.width + "/" + page.width);
                if (row && row.controlAvailableWidth !== undefined) {
                    const local = item.mapToItem(row, 0, 0);
                    check(local.x >= row.inset - 0.5 && local.x + item.width <= row.width - row.inset + 0.5, "Control escapes its row: " + item + " " + local.x + "/" + item.width + "/" + row.width);
                }
            }
        }
        for (const child of item.children || []) inspect(child, page);
    }
    Window {
        id: window; visible: true; width: 1080; height: 720
        SettingsContent { id: settings; anchors.fill: parent }
    }
    Timer {
        interval: 100; repeat: true; running: Config.initialized
        onTriggered: {
            if (++tests.ticks > 220) { console.error("SETTINGS_LAYOUT_FAILED timeout", tests.scenario, tests.pageIndex); Qt.quit(); return; }
            try {
                if (tests.configure) {
                    window.width = tests.scenario === 0 ? 1080 : tests.scenario === 1 ? 760 : 800;
                    window.height = tests.scenario === 0 ? 720 : 600;
                    Config.set("themeStyle", tests.scenario === 2 ? Enums.ThemeLight : Enums.ThemeDark);
                    Config.set("shellLanguage", tests.scenario === 1 ? "ru" : "en");
                    OverlayState.settingsPage = 0;
                    tests.configure = false; tests.settling = 0; return;
                }
                if (++tests.settling < 3) return;
                const page = tests.loaded(settings, Registry.settings[tests.pageIndex].page);
                if (!page) return;
                tests.inspect(page, page);
                tests.pageIndex++;
                if (tests.pageIndex === Registry.settings.length) {
                    tests.pageIndex = 0; tests.scenario++; tests.configure = true;
                    if (tests.scenario === 3) { console.log("SETTINGS_LAYOUT_PASSED every page, compact/large layouts, Russian and both themes"); Qt.quit(); return; }
                } else OverlayState.settingsPage = tests.pageIndex;
                tests.settling = 0;
            } catch (error) { console.error("SETTINGS_LAYOUT_FAILED", Registry.settings[tests.pageIndex].id, tests.scenario, error); Qt.quit(); }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=27)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "SETTINGS_LAYOUT_PASSED" in output, output
        assert not re.search(r"SETTINGS_LAYOUT_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Cannot specify anchors|is not a type|Failed to load configuration", output), output


def display_checks():
    import runpy

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-display-placement-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        (base / "config/niri/bloodyShell").mkdir(parents=True)
        (base / "config/niri/config.kdl").write_text('include "bloodyShell/07-user-output.kdl"\n')
        output_config = base / "config/niri/bloodyShell/07-user-output.kdl"
        output_config.write_text("")
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        service = base / "modules/services/ServiceDisplay.qml"
        service.write_text(service.read_text().replace("function refresh() { reader.running = true }", "function refresh() {}"))
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/services"
import "modules/ui/overlay/settings/components"
import "modules/src/DisplayLayout.js" as DisplayLayout

ShellRoot {
    Window {
        id: window; width: 700; height: 500; visible: true
        Flickable {
            id: page; anchors.fill: parent; contentHeight: 1200
            SettingsDisplayLayout { id: layout; x: 20; y: 20; width: 520; onPicked: name => selected = name }
        }
        TestCase {
            id: events; name: "DisplayPlacement"; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function output(name, x, y, w, h) {
                return { name: name, logical: {x:x, y:y, width:w, height:h, scale:2, transform:"Normal"},
                    current_mode:0, modes:[{width:w*2, height:h*2, refresh_rate:60000}], vrr_enabled:false };
            }
            function setOutputs(list) {
                Config.set("displays", {});
                ServiceDisplay.outputs = list;
                wait(260);
            }
            function tile(name) { return findChild(layout, "displayTile-" + name); }
            function position(name) { return tile(name).mapToItem(window.contentItem, 20, 20); }
            function snap(name, x, y, w, h) { return DisplayLayout.snap(layout.positions, {name:name,x:x,y:y,w:w,h:h}, 8 / layout.frame.s); }
            function startDrag(name, dx, dy) {
                const p = position(name);
                mousePress(window.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, 0);
                mouseMove(window.contentItem, p.x + 8, p.y + 8, 0);
                mouseMove(window.contentItem, p.x + dx, p.y + dy, 0);
                wait(30);
                check(layout.dragging && layout.preview, "Dragging has no snapped preview");
                return Qt.point(p.x + dx, p.y + dy);
            }
            function release(p) { mouseRelease(window.contentItem, p.x, p.y, Qt.LeftButton, Qt.NoModifier, 0); wait(40); }
            function valid(p, name, w, h) {
                const others = layout.positions.filter(o => o.name !== name);
                check(!others.some(o => p.x < o.x+o.w && p.x+w > o.x && p.y < o.y+o.h && p.y+h > o.y), "Snapping overlaps another display");
                check(others.some(o => ((p.x === o.x+o.w || p.x+w === o.x) && p.y < o.y+o.h && p.y+h > o.y)
                    || ((p.y === o.y+o.h || p.y+h === o.y) && p.x < o.x+o.w && p.x+w > o.x)), "Snapping leaves an unreachable display");
            }
            function exercise() {
                setOutputs([output("A",0,0,1920,1080), output("B",1920,0,1920,1000)]);
                check(snap("B",1920,70,1920,1000).y === 80, "Bottom alignment loses to an earlier top target");
                check(snap("B",1920,43,1920,1000).y === 40, "Nearest centre alignment is not selected");
                setOutputs([output("A",0,0,1920,1080), output("B",0,-1080,1800,1080)]);
                check(snap("B",110,-1080,1800,1080).x === 120, "Right alignment loses to an earlier left target");
                setOutputs([output("A",0,0,1920,1080), output("B",1920,0,1920,400)]);
                check(snap("B",1920,170,1920,400).y === 170, "Snapping pulls distant alignments");
                setOutputs([output("A",-1920,-1080,1920,1080), output("B",0,-1080,1080,1920)]);
                const negative = snap("B",-10,-1080,1080,1920);
                check(negative.x === 0 && negative.y === -1080, "Scaled or rotated displays use physical dimensions");
                setOutputs([output("A",0,0,1920,1080), output("B",0,1080,1920,1000), output("C",1920,0,1920,1080)]);
                valid(snap("B",2000,100,1920,1000), "B", 1920, 1000);
                for (let x = -2000; x <= 4000; x += 500)
                    for (let y = -1500; y <= 2000; y += 500)
                        valid(snap("B",x,y,1920,1000), "B", 1920, 1000);
                const oldFrame = layout.frame;
                layout.width = 320; wait(260);
                check(layout.frame.s < oldFrame.s, "Resizing retains a stale layout scale");
                for (const name of ["A","B","C"]) {
                    const t = tile(name);
                    check(t.x >= 0 && t.y >= 0 && t.x+t.width <= layout.width && t.y+t.height <= layout.height, "Resized display escapes the editor");
                }
                layout.width = 520;
                for (const mode of [0,1,2]) {
                    Config.set("themeAnimations",mode);
                    setOutputs([output("A",0,0,1920,1080), output("B",1920,0,1920,1000)]);
                    const b = position("B");
                    mouseClick(window.contentItem,b.x,b.y,Qt.LeftButton,Qt.NoModifier,0);
                    check(layout.selected === "B" && Object.keys(Config.displays).length === 0, "Selecting a display also changes its position");
                    const end = startDrag("B",0,55);
                    const preview = {x:layout.preview.x,y:layout.preview.y};
                    const activeTile = tile("B"), activeFrame = layout.frame;
                    ServiceDisplay.outputs = JSON.parse(JSON.stringify(ServiceDisplay.outputs));
                    wait(30);
                    check(layout.dragging && tile("B") === activeTile && layout.frame === activeFrame, "Output refresh replaces a dragged display or its coordinate frame");
                    check(page.contentY === 0 && Object.keys(Config.displays).length === 0, "Dragging scrolls the page or applies before release");
                    release(end);
                    check(!layout.dragging && Config.displays.B.position.x === preview.x && Config.displays.B.position.y === preview.y, "Drop does not apply the previewed position");
                    check(Config.displays.A.position.x === 0 && Config.displays.A.position.y === 0, "Placement leaves the other display automatically positioned");
                    wait(500);
                    check(ServiceDisplay.error === "", "Placement failed to save");
                    setOutputs([output("A",0,0,1920,1080), output("B",1920,0,1920,1000)]);
                    const cancelled = startDrag("B",0,45);
                    layout.enabled = false;
                    release(cancelled); layout.enabled = true;
                    check(!layout.dragging && Object.keys(Config.displays).length === 0, "Cancelled drag commits a position");
                    const unplugged = startDrag("B",0,45);
                    ServiceDisplay.outputs = [output("A",0,0,1920,1080)];
                    release(unplugged);
                    check(!layout.dragging && Object.keys(Config.displays).length === 0, "Unplugging a display commits an unfinished drag");
                }
                Config.set("displays", {Disconnected:{enabled:false}});
                ServiceDisplay.outputs = [output("A",0,0,1920,1080), output("B",1920,0,1920,1000)];
                ServiceDisplay.change("B","position",{x:-1920,y:0});
                check(Config.displays.Disconnected.enabled === false, "Placement discards disconnected display settings");
                wait(700);
                check(ServiceDisplay.error === "", "Final placement failed to save");
                console.log("DISPLAY_PLACEMENT_PASSED nearest edges/centres, negative/scaled/rotated coordinates, collision avoidance, preview/drop, resize, refresh, cancellation, hotplug and saved positions in all animation modes");
                Qt.quit();
            }
        }
        Timer { interval:100; running:Config.initialized; onTriggered: { try { events.exercise(); } catch(error) { console.error("DISPLAY_PLACEMENT_FAILED",error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, text=True, capture_output=True, timeout=20)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "DISPLAY_PLACEMENT_PASSED" in output, output
        assert not re.search(r"DISPLAY_PLACEMENT_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output
        saved = output_config.read_text()
        assert 'output "A"' in saved and 'position x=0 y=0' in saved
        assert 'output "B"' in saved and 'position x=-1920 y=0' in saved
        assert 'output "Disconnected"' in saved and '    off' in saved


def scroll_checks():
    import runpy

    prepare = runpy.run_path(str(ROOT / "scripts/tests/screenshot_checks.py"))["prepare"]
    with tempfile.TemporaryDirectory(prefix="bloodyshell-scrolling-") as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / "home").mkdir()
        env.update(HOME=str(base / "home"), XDG_STATE_HOME=str(base / "state"))
        env.pop("WAYLAND_DISPLAY", None)
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/common"
import "modules/core"
import "modules/ui/overlay/settings/components"

ShellRoot {
    Window {
        id: window; visible: true; width: 700; height: 650
        Flickable {
            id: view; x: 20; y: 20; width: 240; height: 180
            contentWidth: width; contentHeight: 2000; clip: true
            boundsBehavior: Flickable.StopAtBounds
            SmoothScroll { id: scroll; view: view }
            Rectangle { width: view.width; height: view.contentHeight; color: "#222222"; MouseArea { anchors.fill: parent } }
            SettingsSlider { id: slider; x: 10; y: 60; width: 200; value: 0.5; onMoved: value => slider.value = value }
        }
        Flickable {
            id: outer; x: 300; y: 20; width: 280; height: 380
            contentWidth: width; contentHeight: 1500; clip: true
            boundsBehavior: Flickable.StopAtBounds
            SmoothScroll { id: outerScroll; view: outer }
            Flickable {
                id: inner; x: 20; y: 60; width: 220; height: 100
                contentWidth: width; contentHeight: 600; clip: true
                boundsBehavior: Flickable.StopAtBounds
                SmoothScroll { id: innerScroll; view: inner }
                Rectangle { width: inner.width; height: inner.contentHeight; color: "#444444" }
            }
        }
        ListView {
            id: list; x: 20; y: 240; width: 240; height: 140; clip: true
            model: 50; topMargin: 8; bottomMargin: 12
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle { required property int index; width: list.width; height: 40; color: "#222222" }
            SmoothScroll { id: listScroll; view: list }
        }
        ListView {
            id: horizontal; x: 20; y: 430; width: 240; height: 80; clip: true
            model: 40; orientation: ListView.Horizontal; flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle { required property int index; width: 50; height: horizontal.height; color: "#333333" }
            SmoothScroll { id: horizontalScroll; view: horizontal }
        }
        SettingsPage {
            id: page; x: 300; y: 430; width: 280; height: 180; title: "Scroll test"
            Rectangle { width: parent.width; height: 1500; color: "#222222" }
        }
        Loader { id: wallpapers; anchors.fill: parent; active: false; source: "modules/ui/overlay/wallpapers/components/WallpapersContent.qml" }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function near(actual, expected, message) { check(Math.abs(actual - expected) < 0.6, message + ": " + actual + " expected " + expected); }
            function turn(item, angle = -120) { mouseWheel(item, item.width - 20, item.height - 20, 0, angle, Qt.NoButton, Qt.NoModifier, 0); }
            function exercise() {
                for (const mode of [0, 1, 2]) {
                    Config.set("themeAnimations", mode);
                    for (const speed of [1, 2.5, 4]) {
                        Config.set("scrollSpeed", speed);
                        scroll.scrollTo(0, false); turn(view);
                        if (mode > 0) check(scroll.running && view.contentY < 48 * speed, "Mouse wheel did not animate");
                        wait(300); near(view.contentY, 48 * speed, "Wheel ignored speed");
                        scroll.scrollTo(0, false); turn(view); turn(view); turn(view, 120);
                        wait(300); near(view.contentY, 48 * speed, "Fast wheel input lost distance or direction");
                        scroll.scrollTo(0, false);
                        check(scroll.handleWheel(-7, 0), "Pixel scroll was ignored");
                        near(view.contentY, 7 * speed, "Touchpad pixels ignored speed");
                        check(!scroll.running, "Touchpad input was animated twice");
                    }
                }
                Config.set("scrollSpeed", 1); Config.set("themeAnimations", 1);
                scroll.scrollTo(0, false); turn(view); wait(40);
                Config.set("themeAnimations", 0);
                check(!scroll.running, "Disabling animations retained wheel motion");
                near(view.contentY, 48, "Disabling animations lost the wheel destination");
                Config.set("themeAnimations", 1); turn(view); wait(40); view.contentY = 70;
                wait(300); near(view.contentY, 70, "Wheel motion overrode external scrolling");
                turn(view); wait(30); view.visible = false;
                check(!scroll.running, "Hidden view retained wheel motion");
                view.visible = true;
                turn(view); view.contentHeight = 100; wait(20);
                check(!scroll.running && view.contentY === 0, "Shrinking content retained an invalid destination");
                view.contentHeight = 2000;
                Config.set("themeAnimations", 0); scroll.scrollTo(0, false);
                const value = slider.value;
                mouseWheel(slider, 20, slider.height / 2, 0, 120, Qt.NoButton, Qt.NoModifier, 0);
                check(slider.value > value && view.contentY === 0, "Scrolling a slider scrolled its page");
                listScroll.scrollTo(listScroll.minimum, false); const start = list.contentY;
                turn(list); near(list.contentY - start, 48, "List margins changed wheel distance");
                horizontalScroll.scrollTo(0, false);
                mouseWheel(horizontal, 120, 40, -120, 0, Qt.NoButton, Qt.NoModifier, 0);
                near(horizontal.contentX, 48, "Horizontal scrolling ignored speed");
                turn(page); near(page.contentY, 48, "Settings page ignored wheel speed");
                outerScroll.scrollTo(0, false); innerScroll.scrollTo(0, false); turn(inner);
                near(inner.contentY, 48, "Nested list did not scroll"); near(outer.contentY, 0, "Both nested lists scrolled");
                innerScroll.scrollTo(innerScroll.maximum, false); turn(inner);
                near(outer.contentY, 48, "Nested list did not hand off scrolling at its edge");
                scroll.scrollTo(scroll.maximum, false); turn(view);
                near(view.contentY, scroll.maximum, "Scroll escaped its lower bound");
                scroll.scrollTo(0, false); turn(view, 120); near(view.contentY, 0, "Scroll escaped its upper bound");
                Config.set("wallpaperDirectory", ""); wallpapers.active = true; wait(30);
                const picker = wallpapers.item;
                picker.images = Array(10).fill(String(Qt.resolvedUrl("fixture.png")).slice(7));
                picker.instant = false; picker.begin(); wait(20);
                turn(picker); check(picker.index === 1, "Wallpaper list did not scroll");
                Config.set("scrollSpeed", 3); Config.set("themeAnimations", 1);
                turn(picker); check(picker.index === 4 && picker.pos < 4, "Wallpaper list ignored speed or animations");
                wait(550); near(picker.pos, 4, "Wallpaper scroll did not settle");
                Config.set("scrollSpeed", 1); Config.set("themeAnimations", 0);
                mouseWheel(picker, picker.width / 2, picker.height / 2, 120, 0, Qt.NoButton, Qt.NoModifier, 0);
                check(picker.index === 5, "Wallpaper list ignored horizontal scrolling");
                console.log("SCROLLING_PASSED all speeds and animation modes, wheel bursts/reversal, touchpad pixels, cancellation, controls, nested views, margins, horizontal lists, and wallpaper carousel");
                Qt.quit();
            }
        }
        Timer {
            interval: 180; running: Config.initialized
            onTriggered: { try { input.exercise(); } catch (error) { console.error("SCROLLING_FAILED", error); Qt.quit(); } }
        }
    }
}
''')
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "SCROLLING_PASSED" in output, output
        assert not re.search(r"SCROLLING_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration", output), output


def tray_backend_checks():
    from contextlib import redirect_stdout
    import io
    import runpy
    from unittest.mock import Mock, patch
    from gi.repository import Gio, GLib

    api = runpy.run_path(str(ROOT / 'scripts/lib/desktop.py'))
    addresses = ['org.example.Tray/StatusNotifierItem']
    calls = []
    def node(identifier, props=None, children=None):
        return (identifier, props or {}, children or [])
    child = GLib.Variant('(ia{sv}av)', node(3, {'label':GLib.Variant('s', '_Child')}))
    layout = node(0, children=[
        GLib.Variant('(ia{sv}av)', node(1, {'label':GLib.Variant('s', '_Open__now'), 'toggle-type':GLib.Variant('s','checkmark'), 'toggle-state':GLib.Variant('i',1)})),
        GLib.Variant('(ia{sv}av)', node(2, {'label':GLib.Variant('s','More'), 'children-display':GLib.Variant('s','submenu')}, [child])),
        GLib.Variant('(ia{sv}av)', node(4, {'visible':GLib.Variant('b',False)})),
        GLib.Variant('(ia{sv}av)', node(5, {'type':GLib.Variant('s','separator')})),
        GLib.Variant('(ia{sv}av)', node(6, {'label':GLib.Variant('s','Disabled'), 'enabled':GLib.Variant('b',False)}))
    ])
    def call(service, path, interface, method, parameters, reply, flags, timeout, cancel):
        calls.append((service, path, interface, method, parameters.unpack()))
        if method == 'Get': return GLib.Variant('(v)', (GLib.Variant('as', addresses),))
        if method == 'GetNameOwner': return GLib.Variant('(s)', (':1.42',))
        if method == 'GetAll':
            return GLib.Variant('(a{sv})', ({'Id':GLib.Variant('s','fixture'), 'Title':GLib.Variant('s','Fixture'), 'Menu':GLib.Variant('o','/NO_DBUSMENU')},))
        if method == 'GetLayout': return GLib.Variant('(u(ia{sv}av))', (1, layout))
        if method == 'AboutToShow': return GLib.Variant('(b)', (False,))
        assert method in ('ContextMenu','Event'), calls[-1]
        return GLib.Variant('()', ())
    bus = Mock()
    bus.call_sync.side_effect = call
    def invoke(*args):
        output = io.StringIO()
        with patch('sys.argv', ['tray-menu', *args]), redirect_stdout(output):
            assert api['tray_menu_main']() == 0
        return json.loads(output.getvalue()) if output.getvalue() else None
    with patch.object(Gio, 'bus_get_sync', return_value=bus):
        data = invoke('open','fixture','Fixture')
        assert data['owner'] == ':1.42' and data['path'] == '/StatusNotifierItem/Menu'
        assert [entry['id'] for entry in data['items']] == [1,2,5,6]
        assert data['items'][0]['text'] == 'Open_now' and data['items'][0]['checkState'] == 2 and data['items'][0]['buttonType'] == 1
        assert data['items'][1]['children'][0]['text'] == 'Child' and data['items'][1]['hasChildren']
        assert data['items'][2]['isSeparator'] and not data['items'][3]['enabled']
        assert sum(call[3] == 'ContextMenu' for call in calls) == 1
        assert invoke('read',data['owner'],data['path']) == data
        assert sum(call[3] == 'ContextMenu' for call in calls) == 1, 'Refresh sent another right-click notification'
        invoke('activate',data['owner'],data['path'],'3')
        assert calls[-1] == (':1.42','/StatusNotifierItem/Menu','com.canonical.dbusmenu','Event',(3,'clicked',0,0))
        before = len(calls)
        try: invoke('read','org.example.Unpinned','/Menu')
        except ValueError: pass
        else: raise AssertionError('Unpinned tray destination was accepted')
        assert len(calls) == before
        addresses.append('org.example.Other/StatusNotifierItem')
        try: invoke('open','fixture','Fixture')
        except RuntimeError: pass
        else: raise AssertionError('Ambiguous tray destination was accepted')
        assert sum(call[3] == 'ContextMenu' for call in calls) == 1
    print('Tray backend passed: hidden exports, typed D-Bus replies, action states, nested menus, polling, exact activation and ambiguous/stale destinations.')


def tray_checks():
    import runpy

    prepare = runpy.run_path(str(ROOT / 'scripts/tests/screenshot_checks.py'))['prepare']
    with tempfile.TemporaryDirectory(prefix='bloodyShell-tray-input-') as temporary:
        base = Path(temporary)
        env = prepare(base)
        (base / 'home').mkdir()
        env.update(HOME=str(base / 'home'), XDG_STATE_HOME=str(base / 'state'))
        env.pop('WAYLAND_DISPLAY', None)
        env['TEST_TRAY_BASE'] = str(base)
        (base / 'scripts/lib/desktop.py').write_text(r'''import json, os, sys, time
from pathlib import Path

def tray_menu_main():
    args = sys.argv[1:]
    with (Path(os.environ['TEST_TRAY_BASE']) / 'menu-calls').open('a') as output:
        output.write(json.dumps(args) + '\n')
    if args[0] == 'activate': return 0
    time.sleep(0.08)
    if args[0] == 'open' and args[1] != 'tray-input-fixture':
        print('Tray item is unavailable', file=sys.stderr)
        return 1
    def entry(identifier, text):
        return dict(id=identifier, text=text, enabled=True, isSeparator=False, icon='', buttonType=0, checkState=0, hasChildren=False, children=[])
    switch = entry(1, 'Switch'); switch.update(buttonType=1, checkState=2)
    submenu = entry(2, 'More'); submenu.update(hasChildren=True, children=[entry(3, 'Child action')])
    separator = entry(4, ''); separator['isSeparator'] = True
    print(json.dumps(dict(owner=':1.42', path='/StatusNotifierItem/Menu', items=[switch, submenu, separator, entry(5, 'Disabled') | {'enabled':False}])))
    return 0
''')
        menu = base / 'modules/ui/bar/menus/MenuTray.qml'
        source = menu.read_text().replace('Array.from(SystemTray.items.values)', 'TestTray.items')
        source = source.replace('QsMenuOpener { id: opener; menu: menuTray.level }', 'QtObject { id: opener; property var children: ({values:[]}) }')
        menu.write_text(source)
        (base / 'modules/core/TestTray.qml').write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property var items: [] }\n')
        with (base / 'modules/core/qmldir').open('a') as output:
            output.write('\nsingleton TestTray 1.0 TestTray.qml\n')
        (base / 'modules/core/MenuState.qml').write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { property var trayContextItem: null; property bool menuKeyboard: false; function close() { trayContextItem = null; } }\n')
        (base / 'modules/services/ServiceWindowActions.qml').write_text('pragma Singleton\nimport Quickshell\nSingleton { function activateTrayItem(item) { item.activate(); return "activated"; } }\n')
        (base / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "modules/core"
import "modules/ui/bar/menus"
ShellRoot {
    QtObject {
        id: app
        property string id: "tray-input-fixture"
        property string title: "Example app"
        property string tooltipTitle: "Example app"
        property string icon: ""
        property bool hasMenu: true
        property var menu: null
        property int status: 1
        property int launches: 0
        property int secondary: 0
        function activate() { launches++; }
        function secondaryActivate() { secondary++; }
    }
    Component.onCompleted: TestTray.items = [app]
    Window {
        id: window
        visible: true; width: 700; height: 600
        MenuTray { id: menu; anchors.centerIn: parent; width: implicitWidth; height: implicitHeight }
        TestCase {
            id: input; when: false; optional: true
            function check(ok, message) { if (!ok) throw new Error(message); }
            function find(item, name) {
                if (item.objectName === name) return item;
                for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
                return null;
            }
            function until(predicate, message) {
                for (let i=0; i<150; i++) { if (predicate()) return; wait(20); }
                throw new Error(message);
            }
            function exercise() {
                const button = find(menu, "trayApp");
                check(button, "Tray app was not created");
                button.pressAndHoldInterval = 40;
                for (const mode of [0, 1, 2]) {
                    Config.set("themeAnimations", mode);
                    MenuState.trayContextItem = null; wait(500);
                    mouseMove(button, button.width / 2, button.height / 2); wait(450);
                    const point = button.mapToItem(window.contentItem, button.width / 2, button.height / 2);
                    mousePress(window.contentItem, point.x, point.y, Qt.RightButton);
                    check(MenuState.trayContextItem === app && menu.contextOpen, "Physical right press did not open app actions");
                    wait(450);
                    check(menu.contextItem === app && find(menu, "trayContext").visible, "Held right button lost the context menu");
                    mouseRelease(window.contentItem, point.x, point.y, Qt.RightButton);
                    wait(30);
                    check(MenuState.trayContextItem === app && menu.contextOpen, "Right release closed the context menu");
                    check(app.launches === mode && app.secondary === mode, "Right click activated the app");
                    MenuState.trayContextItem = null; wait(500);
                    mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton);
                    check(MenuState.trayContextItem === app, "Short secondary click did not open app actions");
                    MenuState.trayContextItem = null; wait(500);
                    mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton);
                    check(app.launches === mode + 1 && MenuState.trayContextItem === null, "Left click no longer activates the app");
                    mouseClick(button, button.width / 2, button.height / 2, Qt.MiddleButton);
                    check(app.secondary === mode + 1 && MenuState.trayContextItem === null, "Middle click no longer runs the secondary action");
                    button.forceActiveFocus(); keyClick(Qt.Key_Menu);
                    check(MenuState.trayContextItem === app, "Keyboard context menu no longer works");
                    MenuState.trayContextItem = null; wait(500);
                    app.hasMenu = false;
                    mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton);
                    check(MenuState.trayContextItem === app && app.launches === mode + 1 && app.secondary === mode + 1, "App without an advertised menu did not request exported actions");
                    until(() => menu.actionEntries.length === 4 && find(menu, "trayActions").count === 4, "Exported actions were not rendered");
                    check(menu.actionEntries[0].checkState === Qt.Checked && !menu.actionEntries[3].enabled && menu.menuError === "", "Exported action states were lost");
                    menu.activate(menu.actionEntries[1]);
                    until(() => find(menu, "trayActions").count === 1, "Exported submenu was not rendered");
                    check(menu.levelTitle === "More" && menu.actionEntries[0].text === "Child action", "Exported submenu title or content is wrong");
                    menu.back();
                    check(menu.stack.length === 0 && menu.levelTitle === app.title, "Exported submenu did not return to the root");
                    menu.activate(menu.actionEntries[1]);
                    menu.activate(menu.actionEntries[0]);
                    until(() => MenuState.trayContextItem === null, "Exported action did not finish and close its menu");
                    wait(500);
                    app.id = "missing";
                    mouseClick(button, button.width / 2, button.height / 2, Qt.RightButton);
                    until(() => menu.menuError !== "", "Unavailable exported menu did not report an error");
                    check(menu.actionEntries.length === 0, "Unavailable app retained another app's actions");
                    MenuState.trayContextItem = null; wait(500);
                    app.id = "tray-input-fixture"; app.hasMenu = true;
                }
                app.hasMenu = false;
                menu.toggleContext(app);
                until(() => menu.actionEntries.length === 4, "Menu did not reopen for the action lifecycle check");
                menu.activate(menu.actionEntries[1]);
                menu.activate(menu.actionEntries[0]);
                MenuState.trayContextItem = null;
                MenuState.trayContextItem = app;
                wait(250);
                until(() => menu.actionEntries.length === 4, "Reopened menu lost its exported actions");
                check(MenuState.trayContextItem === app, "An old action completion closed the reopened menu");
                MenuState.trayContextItem = null;
                console.log("TRAY_INPUT_PASSED secondary input, exported actions, submenus, errors, cleanup, stale completions, primary/middle actions and keyboard in every animation mode");
                Qt.quit();
            }
        }
        Timer { interval: 250; running: Config.initialized; onTriggered: { try { input.exercise(); } catch (error) { console.error("TRAY_INPUT_FAILED", error); Qt.quit(); } } }
    }
}
''')
        result = subprocess.run(['qs', '-p', str(base), '--no-color'], env=env, capture_output=True, text=True, timeout=20)
        calls = [json.loads(line) for line in (base / 'menu-calls').read_text().splitlines()]
        assert [call for call in calls if call[0] == 'activate'] == [['activate', ':1.42', '/StatusNotifierItem/Menu', '3']] * 4, calls
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and 'TRAY_INPUT_PASSED' in output, output
        assert not re.search(r'TRAY_INPUT_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|Failed to load configuration', output), output


if __name__ == "__main__":
    checks()
    tray_backend_checks()
    tray_checks()
    layout_checks()
    display_checks()
    scroll_checks()
