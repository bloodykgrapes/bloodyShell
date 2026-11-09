import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageDisplay

    title: Tr.tr("common.display")
    subtitle: Tr.tr("settings.display.description")

    Component.onCompleted: ServiceDisplay.refresh()

    property string selected: ""
    readonly property var  output: ServiceDisplay.output(selected)
    readonly property var  display: output ? ServiceDisplay.stateOf(selected) : null
    readonly property bool several: ServiceDisplay.outputs.length > 1

    Connections
    {
        target: ServiceDisplay
        function onOutputsChanged()
        {
            if (!ServiceDisplay.output(pageDisplay.selected))
                pageDisplay.selected = ServiceDisplay.outputs.length > 0 ? ServiceDisplay.outputs[0].name : "";
        }
    }

    function parseMode(s)
    {
        const m = /^(\d+)x(\d+)@([\d.]+)$/.exec(String(s || ""));
        return m ? { width: parseInt(m[1], 10), height: parseInt(m[2], 10), rate: parseFloat(m[3]) } : null;
    }
    readonly property var current: display ? parseMode(display.mode) : null

    readonly property var resolutions:
    {
        if (!output) return [];
        const seen = {}, out = [];
        for (const m of output.modes)
        {
            const key = m.width + "x" + m.height;
            if (seen[key]) continue;
            seen[key] = true;
            out.push({ label: m.width + " × " + m.height + (m.is_preferred ? "  (native)" : ""), value: key });
        }
        return out;
    }
    readonly property var rates:
    {
        if (!output || !current) return [];
        return output.modes
            .filter(m => m.width === current.width && m.height === current.height)
            .sort((a, b) => b.refresh_rate - a.refresh_rate)
            .map(m => ({ label: (m.refresh_rate / 1000).toFixed(m.refresh_rate % 1000 === 0 ? 0 : 2) + " Hz", value: ServiceDisplay.modeString(m) }));
    }

    function setResolution(key)
    {
        const [w, h] = key.split("x").map(n => parseInt(n, 10));
        const best = output.modes.filter(m => m.width === w && m.height === h).sort((a, b) => b.refresh_rate - a.refresh_rate)[0];
        if (best) ServiceDisplay.change(selected, "mode", ServiceDisplay.modeString(best));
    }

    SettingsGroup
    {
        visible: ServiceDisplay.confirming || ServiceDisplay.error !== ""
        title: ServiceDisplay.confirming ? Tr.tr("settings.display.confirmTitle") : Tr.tr("settings.display.displaySettings")

        SettingsRow
        {
            visible: ServiceDisplay.confirming
            label: Tr.tr("settings.display.revertCountdown").arg(ServiceDisplay.countdown)
            description: Tr.tr("settings.display.revertHint")

            Row
            {
                spacing: 8
                SettingsButton { text: Tr.tr("settings.display.revert"); onClicked: ServiceDisplay.revert() }
                SettingsButton { text: Tr.tr("settings.display.keep"); icon: Icon.check; onClicked: ServiceDisplay.keep() }
            }
        }
        SettingsRow
        {
            visible: !ServiceDisplay.confirming && ServiceDisplay.error !== ""
            label: Tr.tr("settings.display.saveFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceDisplay.error
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.display.monitor")
        enabled: pageDisplay.output !== null && !ServiceDisplay.confirming

        SettingsRow
        {
            visible: pageDisplay.several
            label: Tr.tr("settings.display.arrangement")
            description: Tr.tr("settings.display.arrangementHint")
            stacked: true

            SettingsDisplayLayout
            {
                selected: pageDisplay.selected
                onPicked: name => pageDisplay.selected = name
            }
        }
        SettingsRow
        {
            visible: !pageDisplay.several
            label: pageDisplay.output ? pageDisplay.output.name : Tr.tr("common.noDisplays")
            valueText: pageDisplay.output ? [pageDisplay.output.make, pageDisplay.output.model].filter(x => x).join(" ") : ""
        }
        SettingsRow
        {
            visible: pageDisplay.several
            label: Tr.tr("common.enabled")

            Toggle
            {
                checked: pageDisplay.display ? pageDisplay.display.enabled !== false : true
                onToggled: value => ServiceDisplay.change(pageDisplay.selected, "enabled", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.resolution")

            SettingsCombo
            {
                width: 300
                options: pageDisplay.resolutions
                current: pageDisplay.current ? pageDisplay.current.width + "x" + pageDisplay.current.height : ""
                placeholderText: Tr.tr("settings.display.noAvailableModes")
                onSelected: value => pageDisplay.setResolution(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.refreshRate")

            SettingsCombo
            {
                width: 300
                options: pageDisplay.rates
                current: pageDisplay.display ? pageDisplay.display.mode : ""
                onSelected: value => ServiceDisplay.change(pageDisplay.selected, "mode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.scale")

            SettingsStepper
            {
                value: pageDisplay.display ? pageDisplay.display.scale : 1
                from: 0.5; to: 3; step: 0.25; decimals: 2; suffix: "×"
                onEdited: value => ServiceDisplay.change(pageDisplay.selected, "scale", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.rotation")

            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.display.normal"), value: "normal" }, { label: "90°", value: "90" }, { label: "180°", value: "180" }, { label: "270°", value: "270" }]
                current: pageDisplay.display ? pageDisplay.display.transform : "normal"
                onSelected: value => ServiceDisplay.change(pageDisplay.selected, "transform", value)
            }
        }
        SettingsRow
        {
            visible: pageDisplay.output !== null && pageDisplay.output.vrr_supported
            label: Tr.tr("settings.display.variableRefreshRate")

            SettingsChoices
            {
                options: [{ label: Tr.tr("common.off"), value: "off" }, { label: Tr.tr("settings.display.on"), value: "on" }, { label: Tr.tr("settings.display.onDemand"), value: "on-demand" }]
                current: pageDisplay.display ? pageDisplay.display.vrr : "off"
                onSelected: value => ServiceDisplay.change(pageDisplay.selected, "vrr", value)
            }
        }
    }

    property date now: new Date()
    Timer { interval: 60000; running: pageDisplay.active; repeat: true; onTriggered: pageDisplay.now = new Date() }

    SettingsGroup
    {
        title: Tr.tr("settings.display.nightLight")
        subtitle: Tr.tr("settings.display.nightLightHint")

        SettingsRow
        {
            label: Tr.tr("settings.display.nightLight")
            description: !ServiceDisplay.nightLightInstalled ? Tr.tr("settings.display.nightLightUnavailable")
                : ServiceDisplay.nightLightError !== "" ? ServiceDisplay.nightLightError
                : Config.nightLightMode === 0 ? Tr.tr("common.off")
                : Config.nightLightMode === 1 ? Tr.tr("settings.display.alwaysOn")
                : ServiceDisplay.nightLightHoursSet ? (ServiceDisplay.nightLightActiveAt(pageDisplay.now) ? Tr.tr("settings.display.scheduledOn").arg(Config.nightLightTo) : Tr.tr("settings.display.scheduledOff").arg(Config.nightLightFrom))
                : Tr.tr("settings.display.customHoursHint")
            enabled: ServiceDisplay.nightLightInstalled
            stacked: true

            SettingsChoices
            {
                options: [{ label: Tr.tr("common.off"), value: 0 }, { label: Tr.tr("settings.display.always"), value: 1 }, { label: Tr.tr("settings.display.customHours"), value: 2 }]
                current: Config.nightLightMode
                onSelected: value => Config.set("nightLightMode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.colorTemperature")
            description: Tr.tr("settings.display.temperatureHint")
            enabled: ServiceDisplay.nightLightInstalled && Config.nightLightMode !== 0

            SettingsStepper
            {
                value: Config.nightLightTemperature
                from: 2500; to: 6000; step: 250; suffix: " K"
                onEdited: value => Config.set("nightLightTemperature", Math.round(value))
            }
        }
        SettingsRow
        {
            visible: Config.nightLightMode === 2
            label: Tr.tr("settings.display.hours")
            description: Tr.tr("settings.display.scheduleHint")

            Row
            {
                spacing: 8

                SettingsInput
                {
                    width: 90
                    text: Config.nightLightFrom
                    placeholderText: "20:00"
                    onEditingFinished: if (ServiceDisplay.validTime(text)) Config.set("nightLightFrom", text.trim()); else text = Config.nightLightFrom
                }
                ShellText { anchors.verticalCenter: parent.verticalCenter; label: "to"; color: Theme.text3 }
                SettingsInput
                {
                    width: 90
                    text: Config.nightLightTo
                    placeholderText: "07:00"
                    onEditingFinished: if (ServiceDisplay.validTime(text)) Config.set("nightLightTo", text.trim()); else text = Config.nightLightTo
                }
            }
        }
    }
}
