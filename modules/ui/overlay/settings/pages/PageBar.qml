pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"
import "../components" as Parts

SettingsPage
{
    title: Tr.tr("common.bar")
    subtitle: Tr.tr("settings.bar.description")

    Parts.SettingsPanelControls { prefix: "bar" }

    SettingsGroup
    {
        title: Tr.tr("common.style")

        SettingsRow
        {
            label: Tr.tr("common.bar")
            description: Tr.tr("settings.frame.styleHint")
            stacked: true
            SettingsStyleChoices
            {
                kind: "frame"
                options: Registry.frameOptions
                namePrefix: "frameStyle-bar-"
                current: Config.barType
                onSelected: value => Config.set("barType", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.menu")
            description: Tr.tr("settings.bar.menuStyleHint")
            stacked: true
            SettingsStyleChoices
            {
                kind: "menu"
                options: Registry.menuOptions
                namePrefix: "menuStyle-"
                current: Config.barMenu
                onSelected: value => Config.set("barMenu", value)
            }
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
