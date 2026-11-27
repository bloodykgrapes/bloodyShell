import QtQuick
import Quickshell

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"
import "../components" as Parts

SettingsPage
{
    id: pageDisplay

    title: Tr.tr("settings.structure.displays")
    subtitle: Tr.tr("settings.display.description")

    Parts.SettingsDisplayControls { active: pageDisplay.active }

    SettingsRowGroup
    {
        visible: Quickshell.screens.length > 1
        title: Tr.tr("settings.structure.screens")

        SettingsRow
        {
            label: Tr.tr("settings.structure.mainScreen")
            description: Tr.tr("settings.display.mainScreenHint")

            SettingsDropdown
            {
                objectName: "primaryScreen"
                preferredWidth: 240
                options: Quickshell.screens.map(screen => ({ label: screen.name, value: screen.name }))
                current: {
                    const connected = Quickshell.screens.some(screen => screen.name === Config.primaryScreen);
                    return connected ? Config.primaryScreen : ServiceIsland.primaryOutput;
                }
                onSelected: value => Config.set("primaryScreen", value)
            }
        }

        PanelMonitors { panel: "bar"; label: Tr.tr("common.bar") }
        PanelMonitors { panel: "dock"; label: Tr.tr("common.dock") }
    }

    component PanelMonitors: SettingsRow
    {
        id: monitorRow
        required property string panel
        readonly property string key: panel + "Screens"

        SettingsToggles
        {
            objectName: monitorRow.panel + "Monitors"
            options: Quickshell.screens.map(screen => ({label: screen.name, value: screen.name}))
            checked: Config.screensShown(monitorRow.key)
            onToggled: (value, on) => Config.toggleScreen(monitorRow.key, value, on)
        }
    }

    property date now: new Date()
    Timer { interval: 60000; running: pageDisplay.active; repeat: true; onTriggered: pageDisplay.now = new Date() }

    SettingsRowGroup
    {
        title: Tr.tr("settings.display.nightLight")

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
