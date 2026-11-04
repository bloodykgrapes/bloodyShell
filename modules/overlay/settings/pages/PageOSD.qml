import QtQuick

import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    title: "OSD"
    subtitle: Tr.tr("settings.osd.onScreenFeedbackForHint")

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            SettingsSwitch { checked: Config.osdEnabled; onToggled: value => Config.set("osdEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.osd.preview")
            enabled: Config.osdEnabled
            SettingsButton { text: Tr.tr("common.show"); onClicked: ServiceOSD.preview() }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.style")

        SettingsRow
        {
            label: Tr.tr("common.position")
            enabled: Config.osdEnabled
            SettingsChoices
            {
                options: [{ label: Tr.tr("common.top"), value: Enums.EdgeTop }, { label: Tr.tr("common.bottom"), value: Enums.EdgeBottom }, { label: Tr.tr("common.left"), value: Enums.EdgeLeft }, { label: Tr.tr("common.right"), value: Enums.EdgeRight }]
                current: Config.osdSide
                onSelected: value => Config.set("osdSide", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.osd.displayTime")
            enabled: Config.osdEnabled
            SettingsStepper { value: Config.osdDuration / 1000; from: 0.6; to: 6; step: 0.2; decimals: 1; suffix: " s"; onEdited: value => Config.set("osdDuration", Math.round(value * 1000)) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.osd.showOnChangeOf")
        enabled: Config.osdEnabled

        SettingsRow
        {
            label: Tr.tr("common.volume")
            SettingsSwitch { checked: Config.osdTypeVolume; onToggled: value => Config.set("osdTypeVolume", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.osd.brightness")
            SettingsSwitch { checked: Config.osdTypeBrightness; onToggled: value => Config.set("osdTypeBrightness", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.network")
            SettingsSwitch { checked: Config.osdTypeNetwork; onToggled: value => Config.set("osdTypeNetwork", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.bluetooth")
            SettingsSwitch { checked: Config.osdTypeBluetooth; onToggled: value => Config.set("osdTypeBluetooth", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.keyboardLayout")
            SettingsSwitch { checked: Config.osdTypeLayout; onToggled: value => Config.set("osdTypeLayout", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.osd.batteryAndCharging")
            SettingsSwitch { checked: Config.osdTypeBattery; onToggled: value => Config.set("osdTypeBattery", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.notifications")

        SettingsRow
        {
            label: Tr.tr("settings.osd.showNotifications")
            description: Tr.tr("settings.osd.whenOffNotificationsOnly")
            SettingsSwitch { checked: Config.notificationsEnabled; onToggled: value => Config.set("notificationsEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.doNotDisturb")
            description: Tr.tr("settings.osd.silencesNotificationPopUps")
            SettingsSwitch { checked: ServiceNotifications.dnd; onToggled: value => ServiceNotifications.dnd = value }
        }
        SettingsRow
        {
            label: Tr.tr("settings.osd.displayTime")
            description: Tr.tr("settings.osd.usedWhenTheAppDoesntSet")
            enabled: Config.notificationsEnabled
            SettingsStepper { value: Config.notificationsDuration / 1000; from: 1; to: 30; step: 1; suffix: " s"; onEdited: value => Config.set("notificationsDuration", Math.round(value * 1000)) }
        }
    }
}
