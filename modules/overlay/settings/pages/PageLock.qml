import QtQuick

import "../../../components/settings"
import "../../../core"

SettingsPage
{
    title: Tr.tr("common.lockScreen")
    subtitle: Tr.tr("settings.lock.whatTheLockScreen")

    SettingsGroup
    {
        title: Tr.tr("common.show")

        SettingsRow
        {
            label: Tr.tr("settings.lock.musicPlayer")
            SettingsSwitch { checked: Config.lockMediaPlayer; onToggled: value => Config.set("lockMediaPlayer", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.notifications")
            SettingsSwitch { checked: Config.lockNotifications; onToggled: value => Config.set("lockNotifications", value) }
        }
    }
}
