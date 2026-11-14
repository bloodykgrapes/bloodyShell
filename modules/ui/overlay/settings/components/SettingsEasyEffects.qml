pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "../../../../common"
import "../../../../core"

SettingsDisclosure
{
    id: effects

    required property bool active
    property var state: ({installed: false, running: false, bypass: null, command: [], presets: {output: [], input: []}, current: {output: "", input: ""}})
    property bool scanned: false
    property string error: ""
    readonly property bool busy: probe.busy || action.busy
    readonly property var helper: Paths.commandFor("easyeffects")

    title: "EasyEffects"
    description: Tr.tr("settings.easyEffects.description")
    icon: Icon.settingsSound
    summary: !scanned ? Tr.tr("common.checking") : !state.installed ? Tr.tr("common.notInstalled")
        : !state.running ? Tr.tr("settings.easyEffects.stopped") : Tr.tr("settings.easyEffects.running")

    function refresh()
    {
        if (!active || busy) return;
        probe.run(helper.concat(["status"]));
    }
    function apply(args)
    {
        if (!active || busy || !state.running) return;
        error = "";
        action.run(helper.concat(args));
    }
    function receive(text)
    {
        try { state = JSON.parse(text); scanned = true; error = state.error || ""; }
        catch (failure) { error = Tr.tr("settings.easyEffects.failed"); }
    }

    onActiveChanged: if (active) refresh()
    onExpandedChanged: if (expanded) refresh()
    Component.onCompleted: refresh()

    Timer
    {
        interval: 2500
        repeat: true
        running: effects.active && effects.expanded
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
        visible: effects.scanned && !effects.state.installed
        label: Tr.tr("common.notInstalled")
        description: Tr.tr("settings.easyEffects.installHint")
        SettingsButton
        {
            objectName: "easyEffectsDependencies"
            text: Tr.tr("common.updates")
            onClicked: OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === "updates")
        }
    }
    SettingsRow
    {
        visible: effects.state.installed
        label: Tr.tr(effects.state.running ? "settings.easyEffects.running" : "settings.easyEffects.stopped")
        description: effects.state.running ? "" : Tr.tr("settings.easyEffects.startHint")
        SettingsButton
        {
            objectName: "openEasyEffects"
            text: Tr.tr("settings.easyEffects.open")
            enabled: !effects.busy && effects.state.command.length > 0
            onClicked:
            {
                Quickshell.execDetached(effects.state.command);
                OverlayState.hide("settings");
            }
        }
    }
    SettingsRow
    {
        visible: effects.state.installed
        label: Tr.tr("settings.easyEffects.effects")
        description: Tr.tr("settings.easyEffects.effectsHint")
        Toggle
        {
            objectName: "easyEffectsEnabled"
            checked: effects.state.running && effects.state.bypass === false
            enabled: effects.state.running && !effects.busy && effects.error === ""
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
            readonly property var presets: effects.state.presets[modelData.pipeline] || []
            visible: effects.state.installed
            label: modelData.label
            description: presets.length === 0 ? Tr.tr("settings.easyEffects.noPresets") : ""
            SettingsCombo
            {
                objectName: "easyEffectsPreset-" + presetRow.modelData.pipeline
                preferredWidth: 300
                options: presetRow.presets
                current: effects.state.current[presetRow.modelData.pipeline] || ""
                placeholderText: Tr.tr("settings.select")
                enabled: effects.state.running && !effects.busy && effects.error === "" && options.length > 0
                onSelected: value => effects.apply(["preset", presetRow.modelData.pipeline, value])
            }
        }
    }
    SettingsRow
    {
        visible: effects.error !== ""
        label: Tr.tr("common.actionFailed")
        description: effects.error
        SettingsButton
        {
            text: Tr.tr("common.refresh")
            enabled: !effects.busy
            onClicked: effects.refresh()
        }
    }
}
