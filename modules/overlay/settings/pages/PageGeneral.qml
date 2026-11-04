import QtQuick

import "../../../components/settings"
import "../../../core"

SettingsPage
{
    id: pageGeneral

    title: Tr.tr("common.general")
    subtitle: Tr.tr("settings.general.behaviourOfTheShellItself")

    property bool confirmReset: false
    Timer { id: confirmTimer; interval: 3000; onTriggered: pageGeneral.confirmReset = false }

    SettingsGroup
    {
        title: Tr.tr("helper.setup")
        SettingsRow
        {
            label: Tr.tr("helper.open")
            description: Tr.tr("helper.openDescription")
            SettingsButton { text: Tr.tr("common.open"); icon: Icon.settingsGeneral; onClicked: OverlayState.show("helper") }
        }
    }

    SettingsGroup
    {
        title: Tr.tr("common.input")

        SettingsRow
        {
            label: Tr.tr("settings.general.scrollSpeed")
            description: Tr.tr("settings.general.multiplierForMouseWheel")

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
            description: Tr.tr("settings.general.printsExtraMessagesToTheShell")

            SettingsSwitch
            {
                checked: Config.debug
                onToggled: value => Config.set("debug", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("settings.general.resetAllSettings")
            description: Tr.tr("settings.general.restoresEverySettingTo")

            SettingsButton
            {
                danger: true
                text: pageGeneral.confirmReset ? Tr.tr("settings.general.clickAgainToConfirm") : Tr.tr("settings.general.reset")
                onClicked:
                {
                    if (pageGeneral.confirmReset) { Config.reset(); pageGeneral.confirmReset = false; }
                    else { pageGeneral.confirmReset = true; confirmTimer.restart(); }
                }
            }
        }
    }
}
