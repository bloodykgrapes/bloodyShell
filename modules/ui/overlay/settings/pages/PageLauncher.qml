import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    title: Tr.tr("settings.launcher.title")
    subtitle: Tr.tr("settings.launcher.description")

    SettingsRowGroup
    {
        title: Tr.tr("settings.structure.look")

        SettingsRow
        {
            label: Tr.tr("common.style")
            stacked: true
            SettingsStyleChoices
            {
                kind: "launcher"
                options: Registry.launcherStyleOptions
                namePrefix: "launcherStyle-"
                current: Config.launcherStyle
                onSelected: value => Config.set("launcherStyle", value)
            }
        }

        SettingsRow
        {
            label: Tr.tr("settings.launcher.maxResults")
            description: Tr.tr("settings.launcher.maxResultsHint")
            SettingsStepper
            {
                objectName: "launcherMaxResults"
                value: Config.launcherMaxResults
                from: 3; to: 14; step: 1
                onEdited: value => Config.set("launcherMaxResults", value)
            }
        }
    }
}
