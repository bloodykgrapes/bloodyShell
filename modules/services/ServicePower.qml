pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

import "../common"
import "../core"

Singleton
{
    id: servicePower

    function formatTime(seconds)
    {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? Tr.tr("service.power.hoursMinutes").arg(h).arg(m) : Tr.tr("service.power.minutes").arg(m);
    }
    function statusOf(s)
    {
        switch (s)
        {
            case UPowerDeviceState.Charging:         return Tr.tr("service.power.charging");
            case UPowerDeviceState.Discharging:      return Tr.tr("service.power.discharging");
            case UPowerDeviceState.FullyCharged:     return Tr.tr("service.power.fullyCharged");
            case UPowerDeviceState.Empty:            return Tr.tr("common.empty");
            case UPowerDeviceState.PendingCharge:
            case UPowerDeviceState.PendingDischarge: return Tr.tr("service.power.notCharging");
            default:                                 return Tr.tr("service.power.unknown");
        }
    }

    readonly property var device: UPower.displayDevice

    readonly property bool present: device?.isLaptopBattery === true

    readonly property real level: present ? device.percentage : 0
    readonly property int  percent: Math.round(level * 100)

    readonly property int chargeState: present ? device.state : UPowerDeviceState.Unknown

    readonly property bool charging: chargeState === UPowerDeviceState.Charging
    readonly property bool discharging: chargeState === UPowerDeviceState.Discharging
    readonly property bool full: chargeState === UPowerDeviceState.FullyCharged
    readonly property bool low: present && !charging && percent <= 15

    readonly property string status: statusOf(chargeState)
    readonly property string timeText: present && (charging || discharging) ? formatTime(charging ? device.timeToFull : device.timeToEmpty) : ""

    readonly property string infoPower: present ? (charging ? "+ " : discharging ? "- " : "") + Math.abs(device.changeRate).toFixed(1) + " W" : ""
    readonly property string infoCapacity: present ? device.energy.toFixed(1) + " / " + device.energyCapacity.toFixed(1) + " W·h" : ""

    property string pendingAction: ""

    function run(action)
    {
        if (pendingAction !== "" || !["lock", "logout", "switch", "suspend", "reboot", "poweroff"].includes(action)) return;

        pendingAction = action;

        if (action === "lock")
        {
            ServiceLock.lock();
            pendingAction = "";
        }

        else if (action === "logout")
        {
            if (ServiceCompositor.logoutCommand.length > 0) actionProcess.run(ServiceCompositor.logoutCommand);
            else pendingAction = "";
        }

        else if (action === "switch")
        {
            pendingAction = "";
        }

        else if (action === "suspend")
        {
            ServiceLock.lock();
            actionProcess.run(["systemctl", "suspend"]);
        }

        else if (action === "reboot")
            actionProcess.run(["systemctl", "reboot"]);

        else if (action === "poweroff")
            actionProcess.run(["systemctl", "poweroff"]);
    }

    CommandProcess
    {
        id: actionProcess
        onCompleted: code =>
        {
            if (code !== 0) console.warn("ServicePower:", servicePower.pendingAction, errorText || "command failed (" + code + ")");
            servicePower.pendingAction = "";
        }
    }

    property var history: []
    property var health: ({})
    readonly property int healthPercent: health.full > 0 && health.design > 0 ? Math.round(health.full / health.design * 100)
                                       : present && device.healthSupported ? Math.round(device.healthPercentage) : -1

    readonly property string batteryName:
    {
        const list = UPower.devices.values || [];
        const b = list.find(d => d.isLaptopBattery && d.nativePath);
        return b ? b.nativePath || "" : "";
    }

    function refreshDetails()
    {
        if (batteryName !== "") historyReader.running = true;
        healthReader.running = true;
    }

    Process
    {
        id: historyReader

        command: ["busctl", "--system", "--json=short", "call", "org.freedesktop.UPower",
                  "/org/freedesktop/UPower/devices/battery_" + servicePower.batteryName,
                  "org.freedesktop.UPower.Device", "GetHistory", "suu", "charge", "86400", "240"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                let reply;
                try { reply = JSON.parse(text) } catch (e) { return }
                const rows = reply && reply.data && reply.data[0] ? reply.data[0] : [];

                servicePower.history = rows.filter(r => r[2] !== 0)
                    .map(r => ({ t: r[0], v: Math.max(0, Math.min(1, r[1] / 100)), charging: r[2] === 1 || r[2] === 4 }))
                    .sort((a, b) => a.t - b.t);
            }
        }
    }

    Process
    {
        id: healthReader
        command: ["sh", "-c", "for b in /sys/class/power_supply/*; do [ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] || continue; "
                  + "for f in energy_full energy_full_design charge_full charge_full_design cycle_count model_name manufacturer technology; do "
                  + "[ -r \"$b/$f\" ] && printf '%s=%s\\n' \"$f\" \"$(cat \"$b/$f\")\"; done; break; done"]
        stdout: StdioCollector
        {
            onStreamFinished:
            {
                const v = {};
                for (const line of text.split("\n"))
                {
                    const eq = line.indexOf("=");
                    if (eq > 0) v[line.substring(0, eq)] = line.substring(eq + 1).trim();
                }

                const energy = v.energy_full !== undefined;
                const num = k => v[k] !== undefined ? parseInt(v[k], 10) / 1e6 : 0;
                servicePower.health = {
                    full: energy ? num("energy_full") : num("charge_full"),
                    design: energy ? num("energy_full_design") : num("charge_full_design"),
                    unit: energy ? "W·h" : "A·h",
                    cycles: v.cycle_count !== undefined ? parseInt(v.cycle_count, 10) : -1,
                    model: v.model_name || "",
                    vendor: v.manufacturer || "",
                    technology: v.technology || ""
                };
            }
        }
    }
}
