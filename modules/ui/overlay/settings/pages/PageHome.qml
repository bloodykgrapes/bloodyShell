import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.structure.home")

    SettingsRowGroup
    {
        title: Tr.tr("common.settings")

        Repeater
        {
            model: Registry.settings.filter(page => ["appearance", "wallpaper", "display", "windows", "components", "updates"].includes(page.id))

            SettingsRow
            {
                required property var modelData

                label: modelData.title
                icon: modelData.icon

                Button
                {
                    text: Tr.tr("common.open")
                    icon: Icon.chevronRight
                    radius: height / 2
                    onClicked: OverlayState.settingsPage = Registry.settings.findIndex(page => page.id === modelData.id)
                }
            }
        }
    }
}
