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
    property bool hasPerformanceProfile: true
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

ShellRoot
{
    QtObject
    {
        id: battery
        property bool isLaptopBattery: true
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
                    if (step === 0)
                    {
                        window.check(ServicePower.percent === 64 && ServicePower.infoPower === "- 8.3 W", "Discharging information is incorrect");
                        window.check(ServicePower.healthPercent === 92, "Battery health percentage is incorrect");
                        window.check(menu.estimate === Tr.tr("menu.battery.left").arg(ServicePower.timeText), "Discharging estimate is missing");
                        window.check(!window.wave().animating, "Animations-off still runs the wave");
                        window.check(window.profiles().length === 3 && window.profiles().filter(row => row.selected).length === 1, "Power profile selection is incorrect");
                        const saver = window.profiles()[0];
                        saver.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                        window.check(ServicePower.profileID === 0, "Keyboard profile selection did not reach the service");
                        battery.state = UPowerDeviceState.Charging;
                        Config.themeAnimations = Enums.AnimationsStandard;
                    }
                    if (step === 1)
                    {
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
                        TestPower.hasPerformanceProfile = false;
                        battery.state = UPowerDeviceState.PendingCharge;
                        battery.percentage = 0.5;
                        Config.themeAnimations = 0;
                    }
                    if (step === 4)
                    {
                        window.check(window.profiles().length === 2 && !ServicePower.setProfile(2), "Unavailable performance mode can still be selected");
                        window.check(menu.estimate === "", "Pending charge shows a stale discharge estimate");
                        battery.state = UPowerDeviceState.Discharging;
                        battery.percentage = 0.08;
                        Config.themeStyle = Enums.ThemeLight;
                        Config.shellLanguage = "ru";
                    }
                    if (step === 5)
                    {
                        if (Tr.language !== "ru" || Tr.strings["common.battery"] === "Battery") return;
                        window.check(menu.levelColor === Theme.colorCritical, "Low battery has no warning color");
                        window.check(window.profiles()[0].text === Tr.tr("menu.battery.saver"), "Profiles did not translate");
                        window.check(window.all(menu, item => item.label !== undefined && item.visible).every(item => item.width > 0), "Translated text has no room");
                        battery.isLaptopBattery = false;
                    }
                    if (step === 6)
                    {
                        window.check(!ServicePower.present && menu.estimate === "" && !window.wave().animating, "Absent battery shows live charge details");
                        const link = window.all(menu, item => item.text === Tr.tr("menu.battery.settings") && item.clicked !== undefined)[0];
                        link.clicked();
                        window.check(OverlayState.current === "settings" && Registry.settings[OverlayState.settingsPage].id === "power", "Power settings shortcut opens the wrong page");
                    console.log("BATTERY_PASSED charge states, keyboard profiles, missing hardware, translations and animation lifecycle");
                        TestPower.device = null;
                        stop(); Qt.callLater(() => Qt.quit()); return;
                    }
                    step++;
                }
                catch (error) { console.error("BATTERY_FAILED", step, error); stop(); Qt.quit(); }
            }
        }
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


if __name__ == "__main__":
    checks()
