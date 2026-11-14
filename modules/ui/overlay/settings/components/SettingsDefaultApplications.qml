pragma ComponentBehavior: Bound

import QtQuick

import "../../../../core"
import "../../../../services"

SettingsDisclosure
{
    title: Tr.tr("settings.defaultApplications.title")
    description: Tr.tr("settings.defaultApplications.description")
    icon: Icon.settingsApplications

    Repeater
    {
        model: [
            {role: "browser", shortcut: "Super+W", label: Tr.tr("settings.defaultApplications.browser")},
            {role: "file-manager", shortcut: "Super+E", label: Tr.tr("settings.defaultApplications.fileManager")},
            {role: "terminal", shortcut: "Super+T", label: Tr.tr("settings.defaultApplications.terminal")}
        ]

        SettingsRow
        {
            id: appRow
            required property var modelData
            label: modelData.label
            valueText: modelData.shortcut

            SettingsCombo
            {
                objectName: "defaultApplication-" + appRow.modelData.role
                preferredWidth: 300
                options: ServiceApplications.defaultOptions(appRow.modelData.role)
                current: ServiceApplications.defaultSelection(appRow.modelData.role)
                placeholderText: Tr.tr(ServiceApplications.defaultsBusy ? "common.loading" : "settings.defaultApplications.noApplications")
                enabled: options.length > 0
                onSelected: value => ServiceApplications.setDefault(appRow.modelData.role, value)
            }
        }
    }

    SettingsRow
    {
        visible: ServiceApplications.defaultsError !== ""
        label: Tr.tr("common.actionFailed")
        description: ServiceApplications.defaultsError
        SettingsButton
        {
            objectName: "refreshDefaultApplications"
            text: Tr.tr("common.refresh")
            icon: Icon.reload
            enabled: !ServiceApplications.defaultsBusy
            onClicked: ServiceApplications.refreshDefaults()
        }
    }
}
