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

    SettingsRowGroup
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
    }

    SettingsDisclosure
    {
        objectName: "barWidgets"
        title: Tr.tr("settings.bar.widgets")
        icon: Icon.widgets

        SettingsRow
        {
            label: Tr.tr("common.windowTitle")
            SettingsChoices
            {
                objectName: "barWindowTitle"
                options: [
                    { label: Tr.tr("settings.bar.title"), value: 0 },
                    { label: Tr.tr("settings.bar.appName"), value: 1 },
                    { label: Tr.tr("settings.bar.appId"), value: 2 }
                ]
                current: Config.barWidgetWindowMode
                onSelected: value => Config.set("barWidgetWindowMode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("common.keyboardLayout")
            Toggle { objectName: "barKeyboardLayout"; checked: Config.barWidgetKeyboardLayout; onToggled: value => Config.set("barWidgetKeyboardLayout", value) }
        }
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
    }

    SettingsDisclosure
    {
        objectName: "barDynamicIsland"
        title: Tr.tr("shell.dynamicIsland")
        icon: Icon.settingsOSD

        Repeater
        {
            model: [
                {label: "common.volume", key: "osdTypeVolume"},
                {label: "settings.island.brightness", key: "osdTypeBrightness"},
                {label: "common.battery", key: "osdTypeBattery"},
                {label: "settings.island.keyboard", key: "osdTypeLayout"},
                {label: "settings.island.media", key: "islandMedia"},
                {label: "common.network", key: "osdTypeNetwork"},
                {label: "common.bluetooth", key: "osdTypeBluetooth"},
                {label: "settings.island.recording", key: "islandRecordingIndicator"}
            ]

            SettingsRow
            {
                id: eventRow
                required property var modelData
                label: Tr.tr(modelData.label)
                enabled: Config.islandEnabled

                Toggle
                {
                    objectName: "island-" + eventRow.modelData.key
                    checked: Config[eventRow.modelData.key]
                    onToggled: value => Config.set(eventRow.modelData.key, value)
                }
            }
        }
    }
}
