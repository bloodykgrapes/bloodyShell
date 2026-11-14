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

    SettingsConfirmation
    {
        objectName: "resetConfirmation"
        host: pageGeneral
        visible: pageGeneral.active && pageGeneral.confirmReset
        title: Tr.tr("settings.general.resetAllSettings")
        description: Tr.tr("settings.general.resetHint")
        acceptText: Tr.tr("settings.general.reset")
        danger: true
        onAccepted: { pageGeneral.confirmReset = false; Config.reset(); }
        onRejected: pageGeneral.confirmReset = false
    }
    SettingsGroup
    {
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
                objectName: "requestReset"
                text: Tr.tr("settings.general.reset")
                onClicked: pageGeneral.confirmReset = true
            }
        }
    }
}
