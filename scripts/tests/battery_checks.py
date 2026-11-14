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
    with tempfile.TemporaryDirectory(prefix="bloodyshell-battery-") as temporary:
        base = Path(temporary)
        shutil.copytree(ROOT / "modules", base / "modules")
        for name in ("assets", "translations"):
            (base / name).symlink_to(ROOT / name)
        for name in ("runtime", "config/bloodyShell", "cache"):
            (base / name).mkdir(parents=True, mode=0o700)
        (base / "config/bloodyShell/settings.json").write_text(json.dumps(dict(themeAnimations=0, helperSeen=True, shellLanguage="en")))

        def stub(name, body):
            (base / f"modules/services/{name}.qml").write_text("pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n" + body + "\n}\n")

        stub("ServiceAppearance", 'property color accent: "#8ecbff"; function iconPath(name) { return ""; }')
        stub("ServiceBluetooth", 'property bool connected: false; property bool enabled: false')
        stub("ServiceNetwork", 'property bool connectedEthernet: false; property bool connectedWiFi: false; property real signal: 0; function strengthPercent(value) { return 0; }')
        stub("ServiceAudio", 'property bool muted: false; property real volume: 0')
        stub("ServiceNotifications", 'property bool dnd: false')
        source = (base / "modules/services/ServicePower.qml").read_text()
        source = source.replace("UPower.displayDevice", "TestPower.device").replace("UPower.devices", "TestPower.devices").replace("PowerProfiles.", "TestPower.")
        (base / "modules/services/ServicePower.qml").write_text(source)
        profiles = base / "modules/services/ServicePowerProfiles.qml"
        profiles.write_text(profiles.read_text().replace("UPower.onBattery", "TestPower.onBattery").replace("PowerProfiles.", "TestPower."))
        (base / "modules/core/qmldir").open("a").write("\nsingleton TestPower 1.0 TestPower.qml\n")
        (base / "modules/core/TestPower.qml").write_text('''pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
Singleton
{
    property var device: null
    readonly property var devices: ({values: device ? [device] : []})
    property int profile: PowerProfile.Balanced
    property int profileChanges: 0
    onProfileChanged: profileChanges++
    property bool hasPerformanceProfile: true
    property bool onBattery: true
    property var holds: []
}
''')
        (base / "shell.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.UPower
import "modules/core"
import "modules/services"
import "modules/ui/bar/menus"
import "modules/ui/overlay/settings/pages"

ShellRoot
{
    QtObject
    {
        id: battery
        property bool isLaptopBattery: true
        property bool ready: true
        property real percentage: 0.64
        property int state: UPowerDeviceState.Discharging
        property int timeToEmpty: 7200
        property int timeToFull: 3600
        property real changeRate: 8.3
        property real energy: 30.7
        property real energyCapacity: 48
        property bool healthSupported: true
        property real healthPercentage: 92
        property string nativePath: "BAT_TEST"
    }
    Component.onCompleted: TestPower.device = battery
    Window
    {
        id: window
        visible: true
        width: 360; height: 600
        color: Theme.colorSolid
        MenuBattery { id: menu; x: 20; y: 16; width: 320; height: implicitHeight }
        Loader { id: settings; anchors.fill: parent; active: false; sourceComponent: PagePower {} }
        TestCase { id: input; when: false }
        function check(ok, message) { if (!ok) throw new Error(message); }
        function all(item, predicate) {
            const found = predicate(item) ? [item] : [];
            for (const child of item.children || []) found.push(...all(child, predicate));
            return found;
        }
        function profiles() { return all(menu, item => item.modelData && item.modelData.value !== undefined); }
        function wave() { return all(menu, item => item.animating !== undefined)[0]; }
        Timer
        {
            interval: 130; repeat: true; running: Config.initialized && Tr.strings["common.battery"] !== undefined
            property int step: 0
            property real pausedPhase: 0
            onTriggered:
            {
                try
                {
                    if (Quickshell.env("TEST_POWER_RESTORE") === "1")
                    {
                        window.check(Config.powerProfileBattery === 2 && Config.powerProfilePlugged === 0, "Per-source preferences were not restored");
                        window.check(ServicePowerProfiles.current === 2, "Startup did not apply the saved battery profile");
                        TestPower.onBattery = false; input.wait(20);
                        window.check(ServicePowerProfiles.current === 0, "Restored AC profile was not applied");
                        console.log("POWER_RESTORE_PASSED"); stop(); TestPower.device = null; Qt.quit(); return;
                    }
                    if (step === 0)
                    {
                        window.check(Config.powerProfileBattery === 0 && Config.powerProfilePlugged === 1 && ServicePowerProfiles.current === 0, "Default battery policy was not applied");
                        window.check(ServicePower.percent === 64 && ServicePower.infoPower === "- 8.3 W", "Discharging information is incorrect");
                        window.check(ServicePower.healthPercent === 92, "Battery health percentage is incorrect");
                        window.check(menu.estimate === Tr.tr("menu.battery.left").arg(ServicePower.timeText), "Discharging estimate is missing");
                        window.check(!window.wave().animating, "Animations-off still runs the wave");
                        window.check(window.profiles().length === 3 && window.profiles().filter(row => row.selected).length === 1, "Power profile selection is incorrect");
                        const saver = window.profiles()[0];
                        saver.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                        window.check(ServicePowerProfiles.current === 0 && Config.powerProfileBattery === 0, "Keyboard profile selection did not reach the service or current-source preference");
                        const changes = TestPower.profileChanges;
                        window.check(ServicePowerProfiles.setPreference("plugged", 2), "Inactive power-source preference was rejected");
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 0 && Config.powerProfilePlugged === 2 && TestPower.profileChanges === changes, "Editing the inactive source changed the current profile");
                        TestPower.onBattery = false;
                        battery.state = UPowerDeviceState.Charging;
                        Config.themeAnimations = Enums.AnimationsStandard;
                    }
                    if (step === 1)
                    {
                        window.check(ServicePowerProfiles.current === 2, "Plugging in did not apply the AC profile");
                        window.check(ServicePower.infoPower === "+ 8.3 W" && menu.estimate === Tr.tr("menu.battery.untilFull").arg(ServicePower.timeText), "Charging status or estimate is incorrect");
                        window.check(window.wave().animating, "Standard animations lost the liquid effect");
                        menu.visible = false;
                        pausedPhase = window.wave().phase;
                    }
                    if (step === 2)
                    {
                        window.check(!window.wave().animating && window.wave().phase === pausedPhase, "Hidden menu continues animating");
                        menu.visible = true;
                        battery.state = UPowerDeviceState.FullyCharged;
                        battery.percentage = 1;
                        battery.changeRate = 0;
                        Config.themeAnimations = Enums.AnimationsFluid;
                    }
                    if (step === 3)
                    {
                        if (window.wave().shown < 1) return;
                        window.check(menu.estimate === "" && ServicePower.infoPower === "0.0 W", "Fully charged battery shows a discharge estimate or negative draw");
                        window.check(!window.wave().animating, "Full battery needlessly runs the wave");
                        window.check(!ServicePowerProfiles.onBattery && ServicePowerProfiles.current === 2, "Fully charged battery was treated as unplugged");
                        TestPower.hasPerformanceProfile = false;
                        battery.state = UPowerDeviceState.PendingCharge;
                        battery.percentage = 0.5;
                        Config.themeAnimations = 0;
                    }
                    if (step === 4)
                    {
                        window.check(window.profiles().length === 2 && !ServicePowerProfiles.setCurrent(2), "Unavailable performance mode can still be selected");
                        window.check(ServicePowerProfiles.current === 1 && Config.powerProfilePlugged === 2, "Unsupported Performance did not fall back to Balanced while keeping its saved choice");
                        window.check(menu.estimate === "", "Pending charge shows a stale discharge estimate");
                        battery.state = UPowerDeviceState.Discharging;
                        TestPower.onBattery = true;
                        battery.percentage = 0.08;
                        Config.themeStyle = Enums.ThemeLight;
                        Config.shellLanguage = "ru";
                    }
                    if (step === 5)
                    {
                        if (Tr.language !== "ru" || Tr.strings["common.battery"] === "Battery") return;
                        window.check(menu.levelColor === Theme.colorCritical, "Low battery has no warning color");
                        window.check(window.profiles()[0].text === Tr.tr("settings.power.powerSaver"), "Profiles did not translate");
                        window.check(ServicePowerProfiles.current === 0, "Unplugging did not restore the battery profile");
                        window.check(window.all(menu, item => item.label !== undefined && item.visible).every(item => item.width > 0), "Translated text has no room");
                        battery.isLaptopBattery = false;
                        TestPower.onBattery = false;
                    }
                    if (step === 6)
                    {
                        window.check(!ServicePower.present && menu.estimate === "" && !window.wave().animating, "Absent battery shows live charge details");
                        window.check(ServicePowerProfiles.current === 1, "A desktop did not use the plugged-in profile");
                        const link = window.all(menu, item => item.text === Tr.tr("menu.battery.settings") && item.clicked !== undefined)[0];
                        link.clicked();
                        window.check(OverlayState.current === "settings" && Registry.settings[OverlayState.settingsPage].id === "power", "Power settings shortcut opens the wrong page");
                    }
                    if (step === 7)
                    {
                        TestPower.hasPerformanceProfile = true;
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 2, "Restored Performance support did not reapply the saved profile");
                        TestPower.holds = [{profile:PowerProfile.Performance}];
                        Config.set("powerProfilePlugged", 1);
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 2 && ServicePowerProfiles.pendingAutomatic, "Automatic policy interrupted an application hold");
                        TestPower.holds = [];
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 1 && !ServicePowerProfiles.pendingAutomatic, "Deferred profile was not applied after a hold ended");
                        TestPower.profile = PowerProfile.PowerSaver;
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 0, "Policy continuously overwrites externally selected profiles");
                        battery.ready = false;
                        ServicePowerProfiles.setPreference("plugged", 1);
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 0, "Policy applied before the power source was ready");
                        battery.ready = true;
                        input.wait(20);
                        window.check(ServicePowerProfiles.current === 1, "Policy did not apply when the power source became ready");
                        window.check(!ServicePowerProfiles.setPreference("invalid", 0) && !ServicePowerProfiles.setPreference("battery", 1.5) && !ServicePowerProfiles.setCurrent(-1), "Invalid profile was accepted");
                        window.check(!Config.valid("powerProfileBattery", 1.5) && !Config.valid("powerProfilePlugged", 3), "Config accepts invalid profile values");
                        menu.visible = false;
                        settings.active = true;
                    }
                    if (step === 8)
                    {
                        const batteryChoice = input.findChild(settings.item, "powerProfileBattery");
                        const pluggedChoice = input.findChild(settings.item, "powerProfilePlugged");
                        window.check(batteryChoice && pluggedChoice, "Power settings are not split by source");
                        batteryChoice.selected(2);
                        window.check(Config.powerProfileBattery === 2 && ServicePowerProfiles.current === 1, "Inactive-source settings applied immediately");
                        pluggedChoice.selected(0);
                        window.check(Config.powerProfilePlugged === 0 && ServicePowerProfiles.current === 0, "Current-source settings did not apply");
                        TestPower.onBattery = true; input.wait(20);
                        window.check(ServicePowerProfiles.current === 2, "Configured battery profile was not applied");
                        window.check(batteryChoice.width > 0 && pluggedChoice.width > 0, "Compact localized profile controls have no room");
                        console.log("BATTERY_PASSED charge states, per-source policy/settings, menu persistence, holds, external changes, missing hardware, translations and animation lifecycle");
                        stop(); finish.start(); return;
                    }
                    step++;
                }
                catch (error) { console.error("BATTERY_FAILED", step, error); stop(); Qt.quit(); }
            }
        }
        Timer { id:finish; interval:350; onTriggered:{ TestPower.device = null; Qt.quit(); } }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-bus", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/tmp/bloodyshell-test-no-system-bus")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(["qs", "-p", str(base), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "BATTERY_PASSED" in output, output
        assert not re.search(r"BATTERY_FAILED|ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type|Failed to load configuration", output), output
        saved = json.loads((base / "config/bloodyShell/settings.json").read_text())
        assert saved["powerProfileBattery"] == 2 and saved["powerProfilePlugged"] == 0, saved
        restored = subprocess.run(["qs", "-p", str(base), "--no-color"], env=dict(env, TEST_POWER_RESTORE="1"), capture_output=True, text=True, timeout=5)
        output = restored.stdout + restored.stderr
        assert restored.returncode == 0 and "POWER_RESTORE_PASSED" in output, output


if __name__ == "__main__":
    checks()
