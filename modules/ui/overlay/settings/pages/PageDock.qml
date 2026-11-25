pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"
import "../components" as Parts

SettingsPage
{
    id: pageDock

    title: Tr.tr("common.dock")
    subtitle: Tr.tr("settings.dock.description")

    Parts.SettingsPanelControls { prefix: "dock" }

    SettingsRowGroup
    {
        objectName: "dockStyleOptions"
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
            SettingsStepper { value: Config.dockIconSize; from: 24; to: 72; step: 2; suffix: " px"; onEdited: value => Config.set("dockIconSize", value) }
        }
    }

    SettingsDisclosure
    {
        objectName: "dockPinnedApplications"
        title: Tr.tr("settings.dock.pinnedApplications")
        description: Tr.tr("settings.dock.pinnedHint")
        icon: Icon.pin
        summary: String(Config.dockPinned.length)

        Repeater
        {
            model: Config.dockPinned

            SettingsRow
            {
                id: pinnedRow

                required property string modelData

                label: ServiceApplications.appName(modelData, modelData)
                description: modelData

                Button
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
