pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

import "../core"

Singleton
{
    id: profiles

    readonly property bool onBattery: UPower.onBattery
    readonly property bool sourceReady: ServicePower.device?.ready === true
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property bool held: PowerProfiles.holds.length > 0
    readonly property var values: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property int current:
    {
        const index = values.indexOf(PowerProfiles.profile);
        return index >= 0 ? index : 1;
    }
    readonly property var options: [
        {value:0, label:Tr.tr("settings.power.powerSaver"), hint:Tr.tr("menu.battery.saverHint"), icon:Icon.profileSaver},
        {value:1, label:Tr.tr("common.balanced"), hint:Tr.tr("menu.battery.balancedHint"), icon:Icon.profileBalanced},
        {value:2, label:Tr.tr("common.performance"), hint:Tr.tr("menu.battery.performanceHint"), icon:Icon.profilePerformance}
    ].slice(0, hasPerformance ? 3 : 2)

    property bool pendingAutomatic: false

    function supported(index) { return Number.isInteger(index) && index >= 0 && index <= 2 && (index !== 2 || hasPerformance); }

    function preference(source)
    {
        return source === "battery" ? Config.powerProfileBattery : Config.powerProfilePlugged;
    }

    function effective(source)
    {
        const saved = preference(source);
        return saved === 2 && !hasPerformance ? 1 : saved;
    }

    function apply(index, explicit = false)
    {
        if (!supported(index)) return false;
        if (current !== index || (explicit && held)) PowerProfiles.profile = values[index];
        return true;
    }

    function setPreference(source, index)
    {
        if (!["battery", "plugged"].includes(source) || !supported(index)) return false;
        Config.set(source === "battery" ? "powerProfileBattery" : "powerProfilePlugged", index);
        if (sourceReady && (source === "battery") === onBattery)
        {
            pendingAutomatic = false;
            return apply(index, true);
        }
        return true;
    }

    function setCurrent(index) { return setPreference(onBattery ? "battery" : "plugged", index); }

    function schedule()
    {
        pendingAutomatic = true;
        synchronize.restart();
    }

    function applyAutomatic()
    {
        if (!pendingAutomatic || !Config.initialized || !sourceReady || held) return;
        pendingAutomatic = false;
        apply(effective(onBattery ? "battery" : "plugged"));
    }

    onOnBatteryChanged: schedule()
    onSourceReadyChanged: schedule()
    onHasPerformanceChanged: schedule()
    onHeldChanged: if (!held && pendingAutomatic) synchronize.restart()
    Component.onCompleted: schedule()

    Timer { id: synchronize; interval: 0; onTriggered: profiles.applyAutomatic(); }
    Connections
    {
        target: Config
        function onInitializedChanged() { profiles.schedule(); }
        function onPowerProfileBatteryChanged() { if (profiles.onBattery) profiles.schedule(); }
        function onPowerProfilePluggedChanged() { if (!profiles.onBattery) profiles.schedule(); }
    }
}
