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
            label: Tr.tr("settings.desktop.blur")
            description: Tr.tr("settings.desktop.blurHint")
            SettingsChoices
            {
                options: [
                    { label: Tr.tr("settings.desktop.blurDisabled"), value: Enums.BlurDisabled },
                    { label: Tr.tr("settings.desktop.blurWindow"), value: Enums.BlurWindowPresented },
                    { label: Tr.tr("settings.desktop.blurAlways"), value: Enums.BlurAlways }
                ]
                current: Config.desktopBlur
                onSelected: value => Config.set("desktopBlur", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.desktop.equalizer")
            description: Tr.tr("settings.desktop.equalizerHint")
            Toggle { checked: Config.desktopEqualizer; onToggled: value => Config.set("desktopEqualizer", value) }
        }
    }
}
