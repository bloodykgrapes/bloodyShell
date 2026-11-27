pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"

Column
{
    id: panelControls

    required property string prefix

    width: parent ? parent.width : 600
    spacing: Theme.settingsSectionGap

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.look")
        SettingsRow
        {
            visible: panelControls.prefix === "bar"
            label: Tr.tr("common.style")
            SettingsChoices
            {
                objectName: "barStyle"
                options: Registry.barStyleOptions
                current: Config.barType
                onSelected: value => Config.set("barType", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.structure.attach")
            Toggle
            {
                objectName: panelControls.prefix + "Attach"
                checked: Config[panelControls.prefix + "Attach"]
                onToggled: value => Config.set(panelControls.prefix + "Attach", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            SettingsChoices
            {
                objectName: panelControls.prefix + "Position"
                options: Registry.edgeOptions
                current: Config[panelControls.prefix + "Side"]
                onSelected: value => Config.set(panelControls.prefix + "Side", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.panels.attachCurve")
            description: Tr.tr("settings.panels.attachCurveHint")
            enabled: Config[panelControls.prefix + "Attach"]

            SettingsSlider
            {
                objectName: panelControls.prefix + "AttachCurve"
                value: Config[panelControls.prefix + "AttachCurve"]
                from: 40
                to: 80
                step: 1
                valueText: Math.round(shown)
                onMoved: value => Config.set(panelControls.prefix + "AttachCurve", Math.round(value))
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.visibility")
        SettingsRow
        {
            label: Tr.tr("common.autoHide")
            description: Tr.tr("common.autoHideHint")
            Toggle
            {
                objectName: panelControls.prefix + "HideAuto"
                checked: Config[panelControls.prefix + "HideAuto"]
                onToggled: value => Config.set(panelControls.prefix + "HideAuto", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.showOnEmptyWorkspace")
            description: Tr.tr("common.emptyWorkspaceHint")
            enabled: Config[panelControls.prefix + "HideAuto"]
            Toggle
            {
                objectName: panelControls.prefix + "HideSmart"
                checked: Config[panelControls.prefix + "HideSmart"]
                onToggled: value => Config.set(panelControls.prefix + "HideSmart", value)
            }
        }
    }

    SettingsRowGroup
    {
        visible: panelControls.prefix === "bar"
        title: Tr.tr("settings.panels.interaction")

        SettingsRow
        {
            label: Tr.tr("settings.panels.scrollAction")
            description: Tr.tr("settings.panels.scrollActionHint")

            SettingsChoices
            {
                objectName: "barScrollAction"
                options: Registry.scrollActionOptions
                current: Config.barScrollAction
                onSelected: value => Config.set("barScrollAction", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.panels.hoverExpand")
            description: Tr.tr("settings.panels.hoverExpandHint")
            enabled: Config.islandEnabled

            Toggle
            {
                objectName: "barHoverExpand"
                checked: Config.barHoverExpand
                onToggled: value => Config.set("barHoverExpand", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.panels.hoverDelay")
            enabled: Config.islandEnabled && Config.barHoverExpand

            SettingsSlider
            {
                objectName: "barHoverDelay"
                value: Config.barHoverDelay
                from: 150
                to: 500
                step: 10
                valueText: Math.round(shown) + " ms"
                onMoved: value => Config.set("barHoverDelay", Math.round(value))
            }
        }
    }
}
