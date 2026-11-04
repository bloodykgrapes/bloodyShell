import QtQuick
import Quickshell

import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pageDock

    title: Tr.tr("common.dock")
    subtitle: Tr.tr("settings.dock.positionHidingBehaviourGeometryHint")

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            SettingsSwitch { checked: Config.dockEnabled; onToggled: value => Config.set("dockEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            SettingsChoices
            {
                options: [{ label: Tr.tr("common.top"), value: Enums.EdgeTop }, { label: Tr.tr("common.bottom"), value: Enums.EdgeBottom }, { label: Tr.tr("common.left"), value: Enums.EdgeLeft }, { label: Tr.tr("common.right"), value: Enums.EdgeRight }]
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
            description: Tr.tr("common.slidesAwayUntilThe")
            SettingsSwitch { checked: Config.dockHideAuto; onToggled: value => Config.set("dockHideAuto", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.showOnEmptyWorkspace")
            description: Tr.tr("common.keepsVisibleWhileThe")
            enabled: Config.dockHideAuto
            SettingsSwitch { checked: Config.dockHideSmart; onToggled: value => Config.set("dockHideSmart", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.style")

        SettingsRow
        {
            label: Tr.tr("common.dock")
            description: Tr.tr("settings.dock.defaultGrowsOutOfHint")
            stacked: true

            Row
            {
                spacing: 10
                Repeater
                {
                    model: [{ label: Tr.tr("common.default"), value: Enums.DockAttached }, { label: Tr.tr("common.floating"), value: Enums.DockFloating }]

                    SettingsStyleCard
                    {
                        required property var modelData
                        kind: "dock"
                        value: modelData.value
                        label: modelData.label
                        width: 180
                        current: Config.dockType === modelData.value
                        onClicked: Config.set("dockType", modelData.value)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.groupWindowsByApp")
            SettingsSwitch { checked: Config.dockMerge; onToggled: value => Config.set("dockMerge", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.notificationBadges")
            SettingsSwitch { checked: Config.dockBadges; onToggled: value => Config.set("dockBadges", value) }
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
        subtitle: Tr.tr("settings.dock.pinAppsFromTheHint")

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
