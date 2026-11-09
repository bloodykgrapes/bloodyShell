import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.lockScreen")
    subtitle: Tr.tr("settings.lock.description")

    SettingsGroup
    {
        title: Tr.tr("common.show")

        SettingsRow
        {
            label: Tr.tr("settings.lock.media")
            Toggle { checked: Config.lockMediaPlayer; onToggled: value => Config.set("lockMediaPlayer", value) }
        }
    }
}
