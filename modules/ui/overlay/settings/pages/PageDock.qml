pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    id: pageDock

    title: Tr.tr("common.dock")
    subtitle: Tr.tr("settings.dock.description")

    header: SettingsShellPreview { pageHeight: pageDock.height }

    SettingsPanelControls { prefix: "dock" }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.icons")

        SettingsRow
        {
            label: Tr.tr("settings.dock.notificationBadges")
            Toggle { objectName: "dockNotificationBadges"; checked: Config.dockBadges; onToggled: value => Config.set("dockBadges", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.groupWindowsByApp")
            Toggle { checked: Config.dockMerge; onToggled: value => Config.set("dockMerge", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.dock.iconSize")
            SettingsStepper
            {
                objectName: "dockIconSize"
                value: Config.dockIconSize
                from: 24; to: 72; step: 2; suffix: " px"
                onEdited: value => Config.set("dockIconSize", value)
            }
        }
    }
}
