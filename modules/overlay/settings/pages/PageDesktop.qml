import QtQuick

import "../../../components/settings"
import "../../../core"

SettingsPage
{
    title: Tr.tr("common.desktop")
    subtitle: Tr.tr("settings.desktop.customizeYourDesktop")

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            label: Tr.tr("settings.desktop.equalizer")
            description: Tr.tr("settings.desktop.equalizerDescription")
            SettingsSwitch { checked: Config.desktopEqualizer; onToggled: value => Config.set("desktopEqualizer", value) }
        }
    }
}
