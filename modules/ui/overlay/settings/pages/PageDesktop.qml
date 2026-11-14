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

        SettingsRow
        {
            label: Tr.tr("settings.desktop.equalizerOpacity")
            enabled: Config.desktopEqualizer
            SettingsSlider
            {
                from: 0.25
                step: 0.05
                value: Config.desktopEqualizerOpacity
                valueText: Math.round(shown * 100) + "%"
                onMoved: value => Config.set("desktopEqualizerOpacity", value)
            }
        }
    }
}
