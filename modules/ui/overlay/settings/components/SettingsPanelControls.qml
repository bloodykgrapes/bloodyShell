pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"

Column
{
    id: panelControls

    required property string prefix
    width: parent ? parent.width : 600
    spacing: Theme.settingsSectionGap

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle
            {
                objectName: panelControls.prefix + "Enabled"
                checked: Config[panelControls.prefix + "Enabled"]
                onToggled: value => Config.set(panelControls.prefix + "Enabled", value)
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
            visible: Quickshell.screens.length > 1
            label: Tr.tr("common.monitors")
            SettingsToggles
            {
                objectName: panelControls.prefix + "Monitors"
                options: Quickshell.screens.map(screen => ({label:screen.name, value:screen.name}))
                checked: Config.screensShown(panelControls.prefix + "Screens")
                onToggled: (value, on) => Config.toggleScreen(panelControls.prefix + "Screens", value, on)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.hiding")
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
}
