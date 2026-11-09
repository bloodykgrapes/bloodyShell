import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    id: pageGeneral

    title: Tr.tr("common.general")
    subtitle: Tr.tr("settings.general.description")

    property bool confirmReset: false
    Timer { id: confirmTimer; interval: 3000; onTriggered: pageGeneral.confirmReset = false }

    SettingsGroup
    {
        title: Tr.tr("helper.setup")
        SettingsRow
        {
            label: Tr.tr("helper.setup")
            description: Tr.tr("helper.openHint")
            SettingsButton { text: Tr.tr("common.open"); icon: Icon.settingsGeneral; onClicked: OverlayState.show("helper") }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.input")

        SettingsRow
        {
            label: Tr.tr("settings.general.scrollSpeed")
            description: Tr.tr("settings.general.scrollSpeedHint")

            SettingsStepper
            {
                value: Config.scrollSpeed
                from: 1; to: 4; step: 0.25; decimals: 2; suffix: "×"
                onEdited: value => Config.set("scrollSpeed", value)
            }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("settings.general.advanced")

        SettingsRow
        {
            label: Tr.tr("settings.general.debugLogging")
            description: Tr.tr("settings.general.debugLoggingHint")

            Toggle
            {
                checked: Config.debug
                onToggled: value => Config.set("debug", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.general.resetAllSettings")
            description: Tr.tr("settings.general.resetHint")

            SettingsButton
            {
                danger: true
                text: pageGeneral.confirmReset ? Tr.tr("settings.general.confirmReset") : Tr.tr("settings.general.reset")
                onClicked:
                {
                    if (pageGeneral.confirmReset) { Config.reset(); pageGeneral.confirmReset = false; }
                    else { pageGeneral.confirmReset = true; confirmTimer.restart(); }
                }
            }
        }
    }
}
