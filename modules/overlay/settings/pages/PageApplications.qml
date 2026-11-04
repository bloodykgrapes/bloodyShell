import QtQuick

import "../../../components/settings"
import "../../../core"
import "../../../services"

SettingsPage
{
    id: pageApplications

    title: Tr.tr("common.applications")
    subtitle: Tr.tr("settings.applications.installedApplicationsWithA")

    property string query: ""
    readonly property var apps: ServiceApplications.search(query.trim().toLocaleLowerCase())

    SettingsGroup
    {
        title: pageApplications.apps.length + (pageApplications.apps.length === 1 ? " application" : " applications")

        SettingsRow
        {
            label: Tr.tr("menu.user.search")
            stacked: true

            SettingsInput
            {
                width: parent.width
                placeholderText: Tr.tr("settings.applications.nameDescriptionOrDesktopId")
                onTextEdited: value => pageApplications.query = value
            }
        }

        Repeater
        {
            model: pageApplications.apps

            SettingsRow
            {
                id: appRow

                required property var modelData

                label: modelData.name
                description: modelData.id

                Row
                {
                    spacing: 6

                    SettingsButton
                    {
                        readonly property bool pinned: ServiceDock.isPinned(appRow.modelData.id)
                        text: pinned ? Tr.tr("common.unpin") : Tr.tr("dock.pin")
                        icon: pinned ? Icon.unpin : Icon.pin
                        onClicked: ServiceDock.togglePin(appRow.modelData.id)
                    }
                    SettingsButton
                    {
                        text: Tr.tr("settings.applications.launch")
                        onClicked:
                        {
                            ServiceApplications.launchEntry(appRow.modelData);
                            OverlayState.hide("settings");
                        }
                    }
                }
            }
        }
        SettingsRow
        {
            visible: pageApplications.apps.length === 0
            label: Tr.tr("settings.applications.noMatchingApplications")
        }
    }
}
