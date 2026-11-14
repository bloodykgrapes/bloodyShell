import QtQuick

import "../../../../core"
import "../../../../services"
import "../components"
import "../components" as Parts

SettingsPage
{
    id: pageApplications

    title: Tr.tr("common.applications")
    subtitle: Tr.tr("settings.applications.description")

    property string query: ""
    readonly property var apps: ServiceApplications.search(query.trim().toLocaleLowerCase())
    onQueryChanged: resetScroll()

    onActiveChanged:
    {
        ServiceApplications.setAutostartActive(pageApplications, active);
        if (!active && !OverlayState.popupsSuspended)
        {
            applicationMenu.close();
            applicationRemoval.close();
        }
    }
    Component.onCompleted: ServiceApplications.setAutostartActive(pageApplications, active)
    Component.onDestruction: ServiceApplications.setAutostartActive(pageApplications, false)

    header: SettingsInput
    {
        objectName: "applicationsSearch"
        width: parent.width
        placeholderText: Tr.tr("settings.applications.searchPlaceholder")
        onTextEdited: value => pageApplications.query = value
    }

    Parts.SettingsApplicationMenu
    {
        id: applicationMenu
        host: pageApplications
        onDeleteRequested: app => applicationRemoval.request(app)
    }
    Parts.SettingsApplicationRemoval
    {
        id: applicationRemoval
        host: pageApplications
    }

    SettingsAutostart { objectName: "autostartSection" }
    Parts.SettingsDefaultApplications { objectName: "defaultApplicationsSection" }

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

                objectName: "applicationRow-" + modelData.id

                icon: ServiceApplications.iconFor(modelData.id) || Icon.settingsApplications
                label: modelData.name
                description: modelData.id

                TapHandler
                {
                    parent: appRow
                    acceptedButtons: Qt.RightButton
                    onTapped: eventPoint => applicationMenu.openFor(appRow.modelData, appRow, eventPoint.position.x, eventPoint.position.y)
                }

                Row
                {
                    spacing: 6

                    SettingsButton
                    {
                        id: menuButton
                        objectName: "applicationMenu-" + appRow.modelData.id
                        text: Tr.tr("settings.applications.actions")
                        icon: Icon.chevronDown
                        onClicked: applicationMenu.openFor(appRow.modelData, menuButton, 0, menuButton.height + 6)
                        Keys.onPressed: event =>
                        {
                            if (event.key !== Qt.Key_Menu && !(event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) return;
                            applicationMenu.openFor(appRow.modelData, menuButton, 0, menuButton.height + 6);
                            event.accepted = true;
                        }
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
