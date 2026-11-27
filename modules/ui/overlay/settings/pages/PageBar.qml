pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageBar

    title: Tr.tr("common.bar")
    subtitle: Tr.tr("settings.bar.description")

    header: SettingsShellPreview { pageHeight: pageBar.height }

    SettingsPanelControls { prefix: "bar" }

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.events")
        enabled: Config.islandEnabled

        SettingsRow
        {
            label: Tr.tr("settings.structure.staysFor")
            SettingsStepper
            {
                objectName: "islandDuration"
                value: Config.osdDuration / 1000
                from: 1; to: 6; step: 0.5; decimals: 1; suffix: " s"
                onEdited: value => Config.set("osdDuration", Math.round(value * 1000))
            }
        }

        Repeater
        {
            model: [
                { label: "common.volume", key: "osdTypeVolume" },
                { label: "settings.island.brightness", key: "osdTypeBrightness" },
                { label: "common.battery", key: "osdTypeBattery" },
                { label: "settings.island.keyboard", key: "osdTypeLayout" },
                { label: "common.network", key: "osdTypeNetwork" },
                { label: "common.bluetooth", key: "osdTypeBluetooth" },
                { label: "settings.island.usb", key: "osdTypeUSB" },
                { label: "settings.island.screenshots", key: "osdTypeScreenshot" },
                { label: "settings.island.recordings", key: "osdTypeRecording" }
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

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.activities")
        enabled: Config.islandEnabled

        SettingsRow
        {
            label: Tr.tr("settings.island.recording")
            Toggle
            {
                objectName: "island-islandRecordingIndicator"
                checked: Config.islandRecordingIndicator
                onToggled: value => Config.set("islandRecordingIndicator", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.camera")
            Toggle
            {
                objectName: "island-islandCameraIndicator"
                checked: Config.islandCameraIndicator
                onToggled: value => Config.set("islandCameraIndicator", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.media")
            Toggle
            {
                objectName: "island-islandMedia"
                checked: Config.islandMedia
                onToggled: value => Config.set("islandMedia", value)
            }
        }
    }

    SettingsRowGroup
    {
        title: Tr.tr("common.notifications")

        SettingsRow
        {
            label: Tr.tr("common.doNotDisturb")
            SettingsDropdown
            {
                options: [{label: Tr.tr("common.off"), value: -1}].concat(ServiceNotifications.dndOptions)
                current: ServiceNotifications.dnd ? ServiceNotifications.dndMinutes : -1
                onSelected: value => ServiceNotifications.setDnd(value >= 0, Math.max(0, value))
            }
        }

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle
            {
                objectName: "notificationsEnabled"
                checked: Config.notificationsEnabled
                onToggled: value => Config.set("notificationsEnabled", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.structure.staysFor")
            enabled: Config.notificationsEnabled
            SettingsStepper
            {
                objectName: "notificationsDuration"
                value: Config.notificationsDuration / 1000
                from: 2; to: 12; step: 0.5; decimals: 1; suffix: " s"
                onEdited: value => Config.set("notificationsDuration", Math.round(value * 1000))
            }
        }
    }

    SettingsRowGroup
    {
        objectName: "barWidgets"
        title: Tr.tr("settings.bar.widgets")

        SettingsRow
        {
            visible: !Registry.usesStatusBubbles(Config.barType)
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
            Toggle
            {
                objectName: "barKeyboardLayout"
                checked: Config.barWidgetKeyboardLayout
                onToggled: value => Config.set("barWidgetKeyboardLayout", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.volumePercentage")
            Toggle
            {
                checked: Config.barWidgetVolumeValue
                onToggled: value => Config.set("barWidgetVolumeValue", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.bar.batteryPercentage")
            Toggle
            {
                checked: Config.barWidgetBatteryValue
                onToggled: value => Config.set("barWidgetBatteryValue", value)
            }
        }
    }
}
