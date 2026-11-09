import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.desktop")
    subtitle: Tr.tr("settings.desktop.description")

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            label: Tr.tr("settings.desktop.equalizer")
            description: Tr.tr("settings.desktop.equalizerHint")
            Toggle { checked: Config.desktopEqualizer; onToggled: value => Config.set("desktopEqualizer", value) }
        }
    }
}
