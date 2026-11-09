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
            Row
            {
                id: styleCards
                width: parent.width
                spacing: 10

                Repeater
                {
                    model: [Enums.InFrame, Enums.OutFrame, Enums.Filled, Enums.Islands]
                    SettingsStyleCard
                    {
                        required property int modelData
                        objectName: "frameStyle-dock-" + modelData
                        kind: "frame"
                        width: Math.min(150, (styleCards.width - styleCards.spacing * 3) / 4)
                        value: modelData
                        label: Tr.tr(modelData === Enums.InFrame ? "settings.frame.inFrame" : modelData === Enums.OutFrame ? "settings.frame.outFrame" : modelData === Enums.Filled ? "settings.frame.filled" : "settings.frame.islands")
                        current: Config.dockType === modelData
                        onClicked: Config.set("dockType", modelData)
                    }
                }
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
