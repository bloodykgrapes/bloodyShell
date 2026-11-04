import QtQuick

import "../../../components/settings"
import "../../../core"

SettingsPage
{
    title: Tr.tr("common.launcher")
    subtitle: Tr.tr("settings.launcher.theApplicationSearchOpenedHint")

    SettingsGroup
    {
        SettingsRow
        {
            label: Tr.tr("common.enabled")
            description: Tr.tr("settings.launcher.whenOffTheLauncher")
            SettingsSwitch { checked: Config.launcherEnabled; onToggled: value => Config.set("launcherEnabled", value) }
        }
        SettingsRow
        {
            label: Tr.tr("settings.launcher.resultRows")
            description: Tr.tr("settings.launcher.moreResultsScroll")
            SettingsStepper { value: Config.launcherRows; from: 3; to: 12; step: 1; onEdited: value => Config.set("launcherRows", value) }
        }
    }
}
