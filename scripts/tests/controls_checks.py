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
                const value = window.find(valueRow, item => item.label === valueRow.valueText);
                window.check(label.width > 0 && label.mapToItem(longRow, label.width, 0).x <= rowButton.mapToItem(longRow, 0, 0).x - 16, "Settings label overlaps controls");
                window.check(label.height > label.font.pixelSize * 1.5, "Long label did not wrap");
                window.check(valueLabel.width > 200 && valueLabel.mapToItem(valueRow, valueLabel.width, 0).x < value.x, "Long value consumed the label width");
                window.check(literal.textFormat === Text.PlainText, "External titles are interpreted as markup");

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
                   XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "CONTROLS_PASSED" in output, output
        assert not re.search(r"CONTROLS_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output


if __name__ == "__main__":
    checks()
