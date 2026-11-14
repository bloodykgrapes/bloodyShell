import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"
import "../components" as Parts

SettingsPage
{
    id: pageDisplay

    title: Tr.tr("common.display")
    subtitle: Tr.tr("settings.display.description")

    Parts.SettingsDisplayControls { active: pageDisplay.active }

    property date now: new Date()
    Timer { interval: 60000; running: pageDisplay.active; repeat: true; onTriggered: pageDisplay.now = new Date() }

    SettingsGroup
    {
        title: Tr.tr("settings.display.nightLight")
        subtitle: Tr.tr("settings.display.nightLightHint")

        SettingsRow
        {
            label: Tr.tr("settings.display.nightLight")
            description: !ServiceDisplay.nightLightInstalled ? Tr.tr("settings.display.nightLightUnavailable")
                : ServiceDisplay.nightLightError !== "" ? ServiceDisplay.nightLightError
                : Config.nightLightMode === 0 ? Tr.tr("common.off")
                : Config.nightLightMode === 1 ? Tr.tr("settings.display.alwaysOn")
                : ServiceDisplay.nightLightHoursSet ? (ServiceDisplay.nightLightActiveAt(pageDisplay.now) ? Tr.tr("settings.display.scheduledOn").arg(Config.nightLightTo) : Tr.tr("settings.display.scheduledOff").arg(Config.nightLightFrom))
                : Tr.tr("settings.display.customHoursHint")
            enabled: ServiceDisplay.nightLightInstalled

            SettingsChoices
            {
                options: [{ label: Tr.tr("common.off"), value: 0 }, { label: Tr.tr("settings.display.always"), value: 1 }, { label: Tr.tr("settings.display.customHours"), value: 2 }]
                current: Config.nightLightMode
                onSelected: value => Config.set("nightLightMode", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.display.colorTemperature")
            description: Tr.tr("settings.display.temperatureHint")
            enabled: ServiceDisplay.nightLightInstalled && Config.nightLightMode !== 0

            SettingsStepper
            {
                value: Config.nightLightTemperature
                from: 2500; to: 6000; step: 250; suffix: " K"
                onEdited: value => Config.set("nightLightTemperature", Math.round(value))
            }
        }
        SettingsRow
        {
            visible: Config.nightLightMode === 2
            label: Tr.tr("settings.display.hours")
            description: Tr.tr("settings.display.scheduleHint")

            Row
            {
                spacing: 8

                SettingsInput
                {
                    width: 90
                    text: Config.nightLightFrom
                    placeholderText: "20:00"
                    onEditingFinished: if (ServiceDisplay.validTime(text)) Config.set("nightLightFrom", text.trim()); else text = Config.nightLightFrom
                }
                ShellText { anchors.verticalCenter: parent.verticalCenter; label: "to"; color: Theme.text3 }
                SettingsInput
                {
                    width: 90
                    text: Config.nightLightTo
                    placeholderText: "07:00"
                    onEditingFinished: if (ServiceDisplay.validTime(text)) Config.set("nightLightTo", text.trim()); else text = Config.nightLightTo
                }
            }
        }
    }
}
