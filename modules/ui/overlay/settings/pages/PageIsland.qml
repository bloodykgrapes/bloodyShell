import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("shell.dynamicIsland")
    subtitle: Tr.tr("settings.island.description")

    SettingsGroup
    {
        title: Tr.tr("common.general")

        SettingsRow
        {
            label: Tr.tr("common.enabled")
            Toggle { checked: Config.islandEnabled; onToggled: value => Config.set("islandEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.valueChanges")
            Toggle { checked: Config.osdEnabled; onToggled: value => Config.set("osdEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.duration")
            enabled: Config.osdEnabled
            SettingsStepper { value: Config.osdDuration / 1000; from: 0.6; to: 6; step: 0.2; decimals: 1; suffix: " s"; onEdited: value => Config.set("osdDuration", Math.round(value * 1000)) }
        }
        SettingsRow
        {
            label: Tr.tr("common.preview")
            enabled: Config.osdEnabled
            SettingsButton { text: Tr.tr("common.show"); onClicked: ServiceOSD.preview() }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.island.events")
        enabled: Config.osdEnabled

        SettingsRow
        {
            label: Tr.tr("common.volume")
            Toggle { checked: Config.osdTypeVolume; onToggled: value => Config.set("osdTypeVolume", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.brightness")
            Toggle { checked: Config.osdTypeBrightness; onToggled: value => Config.set("osdTypeBrightness", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.network")
            Toggle { checked: Config.osdTypeNetwork; onToggled: value => Config.set("osdTypeNetwork", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.bluetooth")
            Toggle { checked: Config.osdTypeBluetooth; onToggled: value => Config.set("osdTypeBluetooth", value) }
        }
        SettingsRow
        {
            label: Tr.tr("common.keyboardLayout")
            Toggle { checked: Config.osdTypeLayout; onToggled: value => Config.set("osdTypeLayout", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.island.battery")
            Toggle { checked: Config.osdTypeBattery; onToggled: value => Config.set("osdTypeBattery", value) }
        }
    }
}
