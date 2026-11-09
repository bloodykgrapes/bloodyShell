import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("common.notifications")
    subtitle: Tr.tr("settings.notifications.description")

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            label: Tr.tr("settings.notifications.popups")
            description: Tr.tr("settings.notifications.popupsHint")
            Toggle { checked: Config.notificationsEnabled; onToggled: value => Config.set("notificationsEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.notifications.duration")
            description: Tr.tr("settings.notifications.durationHint")
            enabled: Config.notificationsEnabled
            SettingsStepper { value: Config.notificationsDuration / 1000; from: 1; to: 30; step: 1; suffix: " s"; onEdited: value => Config.set("notificationsDuration", Math.round(value * 1000)) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.notifications.dockBadges")
            Toggle { checked: Config.dockBadges; onToggled: value => Config.set("dockBadges", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.doNotDisturb")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            description: Tr.tr("settings.notifications.dndHint")
            Toggle { checked: ServiceNotifications.dnd; onToggled: value => ServiceNotifications.dnd = value }
        }
        SettingsRow
        {
            label: Tr.tr("settings.notifications.rememberDnd")
            description: Tr.tr("settings.notifications.rememberDndHint")
            Toggle { checked: Config.notificationsRememberDnd; onToggled: value => Config.set("notificationsRememberDnd", value) }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.lockScreen")

        SettingsRow
        {
            label: Tr.tr("common.notifications")
            Toggle { checked: Config.lockNotifications; onToggled: value => Config.set("lockNotifications", value) }
        }
        SettingsRow
        {
            enabled: Config.lockNotifications
            label: Tr.tr("settings.notifications.lockContent")
            description: Tr.tr("settings.notifications.lockContentHint")
            Toggle { checked: Config.lockNotificationsContent; onToggled: value => Config.set("lockNotificationsContent", value) }
        }
    }
}
