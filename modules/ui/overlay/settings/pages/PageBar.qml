pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.bar")
    subtitle: Tr.tr("settings.bar.description")

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle { checked: Config.barEnabled; onToggled: value => Config.set("barEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.position")
            SettingsChoices
            {
                options: [{ label: Tr.tr("common.top"), value: Enums.EdgeTop }, { label: Tr.tr("common.bottom"), value: Enums.EdgeBottom }, { label: Tr.tr("common.left"), value: Enums.EdgeLeft }, { label: Tr.tr("common.right"), value: Enums.EdgeRight }]
                current: Config.barSide
                onSelected: value => Config.set("barSide", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.style")
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
                        objectName: "frameStyle-bar-" + modelData
                        kind: "frame"
                        width: Math.min(150, (styleCards.width - styleCards.spacing * 3) / 4)
                        value: modelData
                        label: Tr.tr(modelData === Enums.InFrame ? "settings.frame.inFrame" : modelData === Enums.OutFrame ? "settings.frame.outFrame" : modelData === Enums.Filled ? "settings.frame.filled" : "settings.frame.islands")
                        current: Config.barType === modelData
                        onClicked: Config.set("barType", modelData)
                    }
                }
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.menu")
            description: Tr.tr("settings.bar.menuStyleHint")
            stacked: true
            Row
            {
                id: menuCards
                width: parent.width
                spacing: 10

                Repeater
                {
                    model: [Enums.MenuDefault, Enums.MenuFloating]
                    SettingsStyleCard
                    {
                        required property int modelData
                        objectName: "menuStyle-" + modelData
                        kind: "menu"
                        width: Math.min(150, (menuCards.width - menuCards.spacing) / 2)
                        value: modelData
                        label: Tr.tr(modelData === Enums.MenuDefault ? "common.default" : "common.floating")
                        current: Config.barMenu === modelData
                        onClicked: Config.set("barMenu", modelData)
                    }
                }
            }
        }
        SettingsRow
        {
            visible: Quickshell.screens.length > 1
            label: Tr.tr("common.monitors")
            stacked: true
            SettingsToggles
            {
                options: Quickshell.screens.map(screen => ({ label: screen.name, value: screen.name }))
                checked: Config.screensShown("barScreens")
                onToggled: (value, on) => Config.toggleScreen("barScreens", value, on)
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
            Toggle { checked: Config.barHideAuto; onToggled: value => Config.set("barHideAuto", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.showOnEmptyWorkspace")
            description: Tr.tr("common.emptyWorkspaceHint")
            enabled: Config.barHideAuto
            Toggle { checked: Config.barHideSmart; onToggled: value => Config.set("barHideSmart", value) }
        }
    }


    SettingsGroup
    {
        title: Tr.tr("settings.bar.widgets")
        
        SettingsRow
        {
            label: Tr.tr("settings.bar.volumePercentage")
            Toggle { checked: Config.barWidgetVolumeValue; onToggled: value => Config.set("barWidgetVolumeValue", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.batteryPercentage")
            Toggle { checked: Config.barWidgetBatteryValue; onToggled: value => Config.set("barWidgetBatteryValue", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.windowTitle")
            SettingsChoices
            {
                options: [{ label: Tr.tr("settings.bar.title"), value: false }, { label: Tr.tr("settings.bar.appId"), value: true }]
                current: Config.barWidgetWindowAppID
                onSelected: value => Config.set("barWidgetWindowAppID", value)
            }
        }
    }
}