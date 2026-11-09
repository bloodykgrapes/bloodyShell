import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("common.launcher")
    subtitle: Tr.tr("settings.launcher.description")

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            description: Tr.tr("settings.launcher.enabledHint")
            Toggle { checked: Config.launcherEnabled; onToggled: value => Config.set("launcherEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.launcher.resultRows")
            description: Tr.tr("settings.launcher.rowsHint")
            SettingsStepper { value: Config.launcherRows; from: 3; to: 12; step: 1; onEdited: value => Config.set("launcherRows", value) }
        }
    }
}
