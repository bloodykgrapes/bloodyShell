pragma ComponentBehavior: Bound

import QtQuick

import "../../../../common"
import "../../../../core"
import "../components"

SettingsPage
{
    id: pageComponents

    title: Tr.tr("settings.components.title")
    subtitle: Tr.tr("settings.components.description")

    readonly property var componentPages: Registry.settings.filter(page => page.parent === "components")
    readonly property var descriptions:
    ({
        capture: Tr.tr("settings.components.captureDescription"),
        onScreenKeyboard: Tr.tr("settings.components.keyboardDescription"),
        launcher: Tr.tr("settings.components.launcherDescription"),
        lock: Tr.tr("settings.components.lockDescription"),
        login: Tr.tr("settings.components.loginDescription"),
        easyEffects: Tr.tr("settings.components.effectsDescription"),
        plymouth: Tr.tr("settings.components.plymouthDescription")
    })

    SettingsRowGroup
    {
        title: Tr.tr("settings.components.pages")

        Repeater
        {
            model: pageComponents.componentPages

            SettingsRow
            {
                id: componentRow

                required property var modelData
                objectName: "component-" + modelData.id
                icon: modelData.icon
                label: modelData.title
                description: pageComponents.descriptions[modelData.id] || ""

                Button
                {
                    text: Tr.tr("common.open")
                    icon: Icon.chevronRight
                    radius: height / 2
                    onClicked: OverlayState.settingsPage = Registry.settingsIndex(componentRow.modelData.id)
                }
            }
        }
    }
}
