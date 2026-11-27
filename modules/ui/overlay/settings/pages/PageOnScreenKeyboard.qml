import QtQuick

import "../../../../common"
import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    title: Tr.tr("keyboard.title")
    subtitle: Tr.tr("settings.components.keyboardDescription")

    SettingsRowGroup
    {
        title: Tr.tr("keyboard.mode")

        SettingsRow
        {
            label: Tr.tr("keyboard.showAtBar")
            description: Tr.tr("keyboard.modeHint")
            Toggle
            {
                objectName: "virtualKeyboardEnabled"
                checked: Config.virtualKeyboardEnabled
                onToggled: value => Config.set("virtualKeyboardEnabled", value)
            }
        }
        SettingsRow
        {
            label: Tr.tr("keyboard.status")
            valueText: ServiceVirtualKeyboard.status !== "" ? ServiceVirtualKeyboard.status : Tr.tr("keyboard.ready")
        }
    }
}
