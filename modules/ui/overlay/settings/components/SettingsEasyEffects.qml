pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "../../../../common"
import "../../../../core"

SettingsRowGroup
{
    id: effects

    required property bool active
    property var effectState: ({installed: false, running: false, bypass: null, command: [], presets: {output: [], input: []}, current: {output: "", input: ""}})
    property bool scanned: false
    property string error: ""
    readonly property bool busy: probe.busy || action.busy
    readonly property var helper: Paths.commandFor("easyeffects")

    title: Tr.tr("settings.easyEffects.effects")

    function refresh()
    {
        if (!active || busy) return;
        probe.run(helper.concat(["status"]));
    }
    function apply(args)
    {
        if (!active || busy || !effectState.running) return;
        error = "";
        action.run(helper.concat(args));
    }
    function receive(text)
    {
        try { effectState = JSON.parse(text); scanned = true; error = effectState.error || ""; }
        catch (failure) { error = Tr.tr("settings.easyEffects.failed"); }
    }

    onActiveChanged: if (active) refresh()
    Component.onCompleted: refresh()

    Timer
    {
        interval: 2500
        repeat: true
        running: effects.active
        onTriggered: effects.refresh()
    }
    CommandProcess
    {
        id: probe
        stdout: StdioCollector { id: result }
        onCompleted: code =>
        {
            if (code === 0) effects.receive(result.text);
            else effects.error = errorMessage(Tr.tr("settings.easyEffects.failed"));
        }
    }
    CommandProcess
    {
        id: action
        stdout: StdioCollector { id: actionResult }
        onCompleted: code =>
        {
            if (code === 0) effects.receive(actionResult.text);
            else effects.error = errorMessage(Tr.tr("settings.easyEffects.failed"));
        }
    }

    SettingsRow
    {
        visible: effects.scanned && !effects.effectState.installed
        label: Tr.tr("common.notInstalled")
        description: Tr.tr("settings.easyEffects.installHint")
        Button
        {
            objectName: "easyEffectsDependencies"
            text: Tr.tr("common.updates")
            onClicked: OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "hub")
        }
    }
    SettingsRow
    {
        visible: effects.effectState.installed
        label: Tr.tr(effects.effectState.running ? "settings.easyEffects.running" : "settings.easyEffects.stopped")
        description: effects.effectState.running ? "" : Tr.tr("settings.easyEffects.startHint")
        Button
        {
            objectName: "openEasyEffects"
            text: Tr.tr("settings.easyEffects.open")
            enabled: !effects.busy && effects.effectState.command.length > 0
            onClicked:
            {
                Quickshell.execDetached(effects.effectState.command);
                OverlayState.hide("settings");
            }
        }
    }
    SettingsRow
    {
        visible: effects.effectState.installed
        label: Tr.tr("settings.easyEffects.effects")
        description: Tr.tr("settings.easyEffects.effectsHint")
        Toggle
        {
            objectName: "easyEffectsEnabled"
            checked: effects.effectState.running && effects.effectState.bypass === false
            enabled: effects.effectState.running && !effects.busy && effects.error === ""
            onToggled: value => effects.apply(["effects", value ? "true" : "false"])
        }
    }
    Repeater
    {
        model: [
            {pipeline: "output", label: Tr.tr("settings.easyEffects.outputPreset")},
            {pipeline: "input", label: Tr.tr("settings.easyEffects.inputPreset")}
        ]
        SettingsRow
        {
            id: presetRow
            required property var modelData
            readonly property var presets: effects.effectState.presets[modelData.pipeline] || []
            visible: effects.effectState.installed
            label: modelData.label
            description: presets.length === 0 ? Tr.tr("settings.easyEffects.noPresets") : ""
            SettingsDropdown
            {
                objectName: "easyEffectsPreset-" + presetRow.modelData.pipeline
                preferredWidth: 300
                options: presetRow.presets
                current: effects.effectState.current[presetRow.modelData.pipeline] || ""
                placeholderText: Tr.tr("settings.select")
                enabled: effects.effectState.running && !effects.busy && effects.error === "" && options.length > 0
                onSelected: value => effects.apply(["preset", presetRow.modelData.pipeline, value])
            }
        }
    }
    SettingsRow
    {
        visible: effects.error !== ""
        label: Tr.tr("common.actionFailed")
        description: effects.error
        Button
        {
            text: Tr.tr("common.refresh")
            enabled: !effects.busy
            onClicked: effects.refresh()
        }
    }
}
