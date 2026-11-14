pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"

Column
{
    id: displayControls

    required property bool active
    visible: ServiceCompositor.supports("displays")

    width: parent ? parent.width : 600
    spacing: 20

    Component.onCompleted:
    {
        selected = ServiceDisplay.outputs.length > 0 ? ServiceDisplay.outputs[0].name : "";
        ServiceDisplay.refresh();
    }
    onActiveChanged: if (!active && ServiceDisplay.confirming) ServiceDisplay.revert()
    Component.onDestruction: if (ServiceDisplay.confirming) ServiceDisplay.revert()

    property string selected: ""
    readonly property var  output: ServiceDisplay.output(selected)
    readonly property var  display: output ? ServiceDisplay.stateOf(selected) : null
    readonly property bool several: ServiceDisplay.outputs.length > 1

    Connections
    {
        target: ServiceDisplay
        function onOutputsChanged()
        {
            if (!ServiceDisplay.output(displayControls.selected))
                displayControls.selected = ServiceDisplay.outputs.length > 0 ? ServiceDisplay.outputs[0].name : "";
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

    SettingsConfirmation
    {
        objectName: "displayConfirmation"
        host: displayControls
        visible: displayControls.active && ServiceDisplay.confirming
        title: Tr.tr("settings.display.confirmTitle")
        description: Tr.tr("settings.display.revertCountdown").arg(ServiceDisplay.countdown) + "\n" + Tr.tr("settings.display.revertHint")
        acceptText: Tr.tr("settings.display.keep")
        cancelText: Tr.tr("settings.display.revert")
        onAccepted: ServiceDisplay.keep()
        onRejected: if (ServiceDisplay.confirming) ServiceDisplay.revert()
    }

    SettingsGroup
    {
        visible: ServiceDisplay.error !== ""
        title: Tr.tr("settings.display.displaySettings")
        SettingsRow
        {
            label: Tr.tr("settings.display.saveFailed")
            badge: Tr.tr("common.error")
            badgeColor: Theme.colorCritical
            description: ServiceDisplay.error
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.display.monitor")
        enabled: displayControls.output !== null && !ServiceDisplay.confirming

        SettingsRow
        {
            visible: displayControls.several
            label: Tr.tr("settings.display.arrangement")
            description: Tr.tr("settings.display.arrangementHint")
            stacked: true

            SettingsDisplayLayout
            {
                objectName: "displayLayout"
                selected: displayControls.selected
                onPicked: name => displayControls.selected = name
            }
        }
        SettingsRow
        {
            visible: !displayControls.several
            label: displayControls.output ? displayControls.output.name : Tr.tr("common.noDisplays")
            valueText: displayControls.output ? [displayControls.output.make, displayControls.output.model].filter(x => x).join(" ") : ""
        }
        SettingsRow
        {
            visible: displayControls.several
            label: Tr.tr("common.enabled")

            Toggle
            {
                checked: displayControls.display ? displayControls.display.enabled !== false : true
                onToggled: value => ServiceDisplay.change(displayControls.selected, "enabled", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.resolution")

            SettingsCombo
            {
                preferredWidth: 300
                objectName: "displayResolution"
                options: displayControls.resolutions
                current: displayControls.current ? displayControls.current.width + "x" + displayControls.current.height : ""
                placeholderText: Tr.tr("settings.display.noAvailableModes")
                onSelected: value => displayControls.setResolution(value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.refreshRate")

            SettingsCombo
            {
                preferredWidth: 300
                objectName: "displayRefreshRate"
                options: displayControls.rates
                current: displayControls.display ? displayControls.display.mode : ""
                onSelected: value => ServiceDisplay.change(displayControls.selected, "mode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.scale")

            SettingsStepper
            {
                objectName: "displayScale"
                value: displayControls.display ? displayControls.display.scale : 1
                from: 0.5; to: 3; step: 0.25; decimals: 2; suffix: "×"
                onEdited: value => ServiceDisplay.change(displayControls.selected, "scale", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.rotation")

            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.display.normal"), value: "normal" }, { label: "90°", value: "90" }, { label: "180°", value: "180" }, { label: "270°", value: "270" }]
                current: displayControls.display ? displayControls.display.transform : "normal"
                onSelected: value => ServiceDisplay.change(displayControls.selected, "transform", value)
            }
        }
        SettingsRow
        {
            visible: displayControls.output !== null && displayControls.output.vrr_supported
            label: Tr.tr("settings.display.variableRefreshRate")

            SettingsChoices
            {
                options: [{ label: Tr.tr("common.off"), value: "off" }, { label: Tr.tr("settings.display.on"), value: "on" }, { label: Tr.tr("settings.display.onDemand"), value: "on-demand" }]
                current: displayControls.display ? displayControls.display.vrr : "off"
                onSelected: value => ServiceDisplay.change(displayControls.selected, "vrr", value)
            }
        }
    }

}
