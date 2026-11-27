import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.lockScreen")
    subtitle: Tr.tr("settings.lock.description")

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.layout")

        SettingsRow
        {
            label: Tr.tr("settings.lock.avatar")
            Toggle
            {
                objectName: "lockAvatar"
                checked: Config.lockAvatar
                onToggled: value => Config.set("lockAvatar", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.lock.name")
            Toggle
            {
                objectName: "lockName"
                checked: Config.lockName
                onToggled: value => Config.set("lockName", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.lock.clock")
            Toggle
            {
                objectName: "lockClock"
                checked: Config.lockClock
                onToggled: value => Config.set("lockClock", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.lock.date")
            Toggle
            {
                objectName: "lockDate"
                checked: Config.lockDate
                onToggled: value => Config.set("lockDate", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.lock.music")
            Toggle
            {
                objectName: "lockMusic"
                checked: Config.lockMusic
                onToggled: value => Config.set("lockMusic", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.lock.notifications")
            Toggle
            {
                checked: Config.lockNotifications
                onToggled: value => Config.set("lockNotifications", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.structure.notificationContent")
            enabled: Config.lockNotifications
            Toggle
            {
                checked: Config.lockNotificationsContent
                onToggled: value => Config.set("lockNotificationsContent", value)
            }
        }
    }
}
