import QtQuick

import "../../../../core"
import "../../../../services"
import "../components"

SettingsPage
{
    id: pageApplications

    title: Tr.tr("common.applications")
    subtitle: Tr.tr("settings.applications.description")

    property string query: ""
    readonly property var apps: ServiceApplications.search(query.trim().toLocaleLowerCase())
    onQueryChanged: resetScroll()

    onActiveChanged: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onCompleted: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onDestruction: ServiceApplications.setAutostartActive(pageApplications, false)

    header: SettingsInput
    {
        objectName: "applicationsSearch"
        width: parent.width
        placeholderText: Tr.tr("settings.applications.searchPlaceholder")
        onTextEdited: value => pageApplications.query = value
    }

    SettingsAutostart { objectName: "autostartSection" }

    SettingsGroup
    {
        title: Tr.tr("settings.applications.count").arg(pageApplications.apps.length)

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
            label: Tr.tr("settings.applications.noMatches")
        }
    }
}
