import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.desktop")
    subtitle: Tr.tr("settings.desktop.description")

    SettingsRowGroup
    {
        objectName: "visualizerOptions"
        title: Tr.tr("settings.components.visualizer")

        SettingsRow
        {
            label: Tr.tr("common.style")
            stacked: true

            SettingsStyleChoices
            {
                kind: "equalizer"
                options: Registry.equalizerOptions
                namePrefix: "equalizerStyle-"
                current: Config.equalizerStyle
                onSelected: value => Config.set("equalizerStyle", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.components.visualizerOpacity")
            SettingsSlider
            {
                objectName: "visualizerOpacity"
                from: 0.25
                step: 0.05
                value: Config.desktopEqualizerOpacity
                valueText: Math.round(shown * 100) + "%"
                onMoved: value => Config.set("desktopEqualizerOpacity", value)
            }
        }
    }
}
