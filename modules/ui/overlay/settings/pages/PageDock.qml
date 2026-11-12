pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageDock

    title: Tr.tr("common.dock")
    subtitle: Tr.tr("settings.dock.description")

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle { checked: Config.dockEnabled; onToggled: value => Config.set("dockEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            SettingsChoices
            {
                options: Registry.edgeOptions
                current: Config.dockSide
                onSelected: value => Config.set("dockSide", value)
            }
        }
        SettingsRow
        {
            visible: Quickshell.screens.length > 1
            label: Tr.tr("common.monitors")
            stacked: true
            SettingsToggles
            {
                options: Quickshell.screens.map(m => ({ label: m.name, value: m.name }))
                checked: Config.screensShown("dockScreens")
                onToggled: (value, on) => Config.toggleScreen("dockScreens", value, on)
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
            Toggle { checked: Config.dockHideAuto; onToggled: value => Config.set("dockHideAuto", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.showOnEmptyWorkspace")
            description: Tr.tr("common.emptyWorkspaceHint")
            enabled: Config.dockHideAuto
            Toggle { checked: Config.dockHideSmart; onToggled: value => Config.set("dockHideSmart", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.style")

        SettingsRow
        {
            label: Tr.tr("common.dock")
            description: Tr.tr("settings.frame.styleHint")
            stacked: true
            SettingsStyleChoices
            {
                kind: "frame"
                options: Registry.frameOptions
                namePrefix: "frameStyle-dock-"
                current: Config.dockType
                onSelected: value => Config.set("dockType", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.groupWindowsByApp")
            Toggle { checked: Config.dockMerge; onToggled: value => Config.set("dockMerge", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.iconSize")
            SettingsStepper { value: Config.dockIconSize; from: 24; to: 72; step: 2; suffix: " px"; onEdited: value => Config.set("dockIconSize", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.dock.pinnedApplications")
        subtitle: Tr.tr("settings.dock.pinnedHint")

        Repeater
        {
            model: Config.dockPinned

            SettingsRow
            {
                id: pinnedRow

                required property string modelData

                label: ServiceApplications.appName(modelData, modelData)
                description: modelData

                SettingsButton
                {
                    text: Tr.tr("common.unpin")
                    icon: Icon.unpin
                    onClicked: ServiceDock.unpin(pinnedRow.modelData)
                }
            }
        }
        SettingsRow
        {
            visible: Config.dockPinned.length === 0
            label: Tr.tr("settings.dock.noPinnedApplications")
        }
    }
}
